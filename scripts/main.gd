class_name Main
extends Node3D
## Game root: arena, camera, combat resolution, effects, audio, match flow.

const GRAV := 0.0072
const ARENA_R := 7.4
const ADDITIVE := preload("res://shaders/additive.gdshader")

var ui: GameUI
var camera: Camera3D
var mode := ""
var cfg := {}
var picks: Array = []
var F: Array = []
var inputs: Array = []
var ai: Array = [null, null]
var wins := [0, 0]
var round_n := 1
var frame := 0
var hitstop := 0
var slow := 0
var shake := 0.0
var time_left := 60
var phase := "menu"
var phase_t := 0
var winner := -1
var cam_a = null
var dummy := 0
var fd = null
var surge_cam = null
var paused := false
var portraits := {}
var preview: Array = [null, null]
var cam_pos := Vector3(0, 1.6, 6)
var cam_look := Vector3(0, 1, 0)
var sparks: Array = []
var rings: Array = []
var spark_i := 0
var ring_i := 0
var sounds := {}
var players: Array = []
var player_i := 0
var t_now := 0.0
var autotest := ""
var stage: Stage
var trials: Array = []
var trial_i := 0
var trial_step := 0
var trial_done := {}

const DUMMY := ["Stand (no guard)", "Guard all", "Crouch", "CPU"]


static func make_rig(C: Dictionary) -> Node3D:
	var r = VrmRig.new() if VrmRig.has_model(C) else ToonRig.new()
	r.build(C)
	return r


func _ready() -> void:
	Data.load_all()
	_setup_input_map()
	set_stage("neon")
	_build_fx()
	_build_audio()
	camera = Camera3D.new()
	camera.fov = 38
	camera.far = 200
	add_child(camera)
	ui = GameUI.new()
	ui.G = self
	add_child(ui)
	ui.build()
	portraits = await _make_portraits()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			autotest = a.substr(11)
	if autotest != "":
		_run_autotest()
	else:
		ui.show_title()


func _setup_input_map() -> void:
	var add := func(action: String, key: Key) -> void:
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action, e)
	add.call("ui_up", KEY_W); add.call("ui_down", KEY_S); add.call("ui_left", KEY_A); add.call("ui_right", KEY_D)
	add.call("ui_accept", KEY_U); add.call("ui_cancel", KEY_J)


# ------------------------------------------------------------------ world
func _mesh(m: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m; mi.material_override = mat; mi.position = pos; mi.rotation = rot
	add_child(mi)
	return mi


func set_stage(sid: String) -> void:
	if stage != null and stage.id == sid: return
	if stage != null: stage.queue_free()
	stage = Stage.make(sid)
	add_child(stage)


func _build_fx() -> void:
	var oct := SphereMesh.new(); oct.radius = 0.035; oct.height = 0.07; oct.radial_segments = 4; oct.rings = 2
	for i in 100:
		var m := ShaderMaterial.new(); m.shader = ADDITIVE
		var mi := _mesh(oct, m)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("v", Vector3.ZERO); mi.set_meta("life", 0.0); mi.set_meta("max", 1.0)
		sparks.append(mi)
	var tor := TorusMesh.new(); tor.inner_radius = 0.15; tor.outer_radius = 0.2; tor.ring_segments = 4
	for i in 8:
		var m := ShaderMaterial.new(); m.shader = ADDITIVE
		var mi := _mesh(tor, m)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("life", 0.0); mi.set_meta("size", 1.0)
		rings.append(mi)


func burst(p: Vector3, color: Color, n: int, speed: float) -> void:
	for i in n:
		var mi: MeshInstance3D = sparks[spark_i % sparks.size()]
		spark_i += 1
		mi.position = p; mi.visible = true
		mi.material_override.set_shader_parameter("color", color)
		var v := Vector3(randf() - 0.5, randf() * 0.8, randf() - 0.5).normalized() * speed * randf_range(0.4, 1.2)
		var life := randf_range(0.25, 0.5)
		mi.set_meta("v", v); mi.set_meta("life", life); mi.set_meta("max", life)


func ring(p: Vector3, color: Color, size: float) -> void:
	var mi: MeshInstance3D = rings[ring_i % rings.size()]
	ring_i += 1
	mi.position = p; mi.visible = true
	mi.material_override.set_shader_parameter("color", color)
	mi.set_meta("life", 0.25); mi.set_meta("size", size)


func _update_fx(dt: float) -> void:
	for mi in sparks:
		if not mi.visible: continue
		var life: float = mi.get_meta("life") - dt
		if life <= 0:
			mi.visible = false; continue
		var v: Vector3 = mi.get_meta("v")
		mi.position += v * dt
		v.y -= 7.0 * dt
		mi.set_meta("v", v); mi.set_meta("life", life)
		var k: float = life / mi.get_meta("max")
		mi.material_override.set_shader_parameter("alpha", k)
		mi.scale = Vector3.ONE * (0.6 + k)
	for mi in rings:
		if not mi.visible: continue
		var life: float = mi.get_meta("life") - dt
		if life <= 0:
			mi.visible = false; continue
		mi.set_meta("life", life)
		var t := 1.0 - life / 0.25
		mi.scale = Vector3.ONE * mi.get_meta("size") * (1.0 + t * 5.0)
		mi.material_override.set_shader_parameter("alpha", 1.0 - t)
		mi.look_at(camera.global_position)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)


# ------------------------------------------------------------------ audio (synthesized)
func _build_audio() -> void:
	for k in ["hit", "heavy", "block", "whoosh", "thud", "grab", "ko", "surge", "ui", "ok", "vs"]:
		sounds[k] = _synth(k)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6
		add_child(p)
		players.append(p)


func _synth(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var spec := {
		hit = [0.12, 1400.0, 0.7, 140.0, 55.0, 0.6], heavy = [0.28, 900.0, 0.9, 110.0, 35.0, 0.9],
		block = [0.06, 6000.0, 0.45, 1500.0, 900.0, 0.12], whoosh = [0.14, 1800.0, 0.18, 0.0, 0.0, 0.0],
		thud = [0.2, 300.0, 0.6, 70.0, 40.0, 0.5], grab = [0.08, 900.0, 0.4, 0.0, 0.0, 0.0],
		ko = [1.1, 600.0, 0.8, 200.0, 30.0, 0.35], surge = [0.5, 2500.0, 0.3, 220.0, 880.0, 0.25],
		ui = [0.05, 0.0, 0.0, 660.0, 990.0, 0.08], ok = [0.14, 0.0, 0.0, 520.0, 1560.0, 0.1], vs = [0.6, 500.0, 0.7, 90.0, 45.0, 0.3],
	}
	var s: Array = spec[kind]
	var dur: float = s[0]
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var a: float = exp(-TAU * maxf(1.0, s[1]) / rate) if s[1] > 0 else 0.0
	var phase_acc := 0.0
	for i in n:
		var t := float(i) / rate
		var env := pow(1.0 - t / dur, 2.0)
		var nz := randf() * 2.0 - 1.0
		lp = lp * a + nz * (1.0 - a)
		var v: float = lp * s[2] * (3.0 if kind == "block" else 1.6)
		if kind == "block":
			v = (nz - lp) * s[2]   # high-passed click
		if s[5] > 0:
			var f: float = s[3] * pow(s[4] / s[3], t / dur)
			phase_acc += TAU * f / rate
			var wave := sin(phase_acc) if kind != "ko" else fposmod(phase_acc / TAU, 1.0) * 2.0 - 1.0
			v += wave * s[5]
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func sfx(k: String) -> void:
	if not sounds.has(k): return
	var p: AudioStreamPlayer = players[player_i % players.size()]
	player_i += 1
	p.stream = sounds[k]
	p.play()


# ------------------------------------------------------------------ portraits
func _make_portraits() -> Dictionary:
	var out := {}
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new(); cam.fov = 26
	vp.add_child(cam)
	var key := DirectionalLight3D.new(); key.light_energy = 1.4; key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(20), 0)
	vp.add_child(key)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.95); env.environment.ambient_light_energy = 0.7
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	for C in Data.ROSTER:
		var rig := make_rig(C)
		vp.add_child(rig)
		rig.apply_pose(C.pose.guard)
		rig.rotation.y = -0.45
		var hp: Vector3 = rig.head.global_position
		cam.position = hp + Vector3(0.3, 0.08, 1.55)
		cam.look_at(hp + Vector3(0, -0.02, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		out[C.id] = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else PlaceholderTexture2D.new()
		rig.queue_free()
	vp.queue_free()
	return out


# ------------------------------------------------------------------ input
const KM := [
	{l = [KEY_A], r = [KEY_D], u = [KEY_W], d = [KEY_S], b = [[KEY_U], [KEY_I], [KEY_J], [KEY_K]]},
	{l = [KEY_LEFT], r = [KEY_RIGHT], u = [KEY_UP], d = [KEY_DOWN], b = [[KEY_KP_4, KEY_O], [KEY_KP_5, KEY_P], [KEY_KP_1, KEY_L], [KEY_KP_2, KEY_SEMICOLON]]},
]
var test_keys := {}   # used by autotest to fake key presses


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k) or test_keys.get(k, false)


func _raw(i: int) -> Array:
	var m: Dictionary = KM[i]
	var any := func(a: Array) -> bool:
		for k in a:
			if _key(k): return true
		return false
	var held := 0
	for j in 4:
		if any.call(m.b[j]): held |= 1 << j
	var x: int = (1 if any.call(m.r) else 0) - (1 if any.call(m.l) else 0)
	var y: int = (1 if any.call(m.u) else 0) - (1 if any.call(m.d) else 0)
	return [x, y, held]


func _pad(i: int):
	var pads := Input.get_connected_joypads()
	if i >= pads.size(): return null
	var dev: int = pads[i]
	var x := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
	var y := -Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT): x = -1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT): x = 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP): y = 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN): y = -1
	var held := 0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_X): held |= 1
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_Y): held |= 2
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_A): held |= 4
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_B): held |= 8
	return [int(signf(x)) if absf(x) > 0.5 else 0, int(signf(y)) if absf(y) > 0.5 else 0, held]


func read_player(i: int) -> InputBuf.Frame:
	var inp: InputBuf = inputs[i]
	if ai[i] != null:
		var o: Array = ai[i].think(F[i], F[1 - i])
		return inp.frame(o[0], o[1], o[2])
	if i == 1 and mode == "training":
		var o := _dummy_think()
		return inp.frame(o[0], o[1], o[2])
	var r := _raw(i)
	if mode != "2p" and i == 0:
		var r2 := _raw(1)
		r = [clampi(r[0] + r2[0], -1, 1), clampi(r[1] + r2[1], -1, 1), r[2] | r2[2]]
	var p = _pad(i)
	if p != null:
		r = [clampi(r[0] + p[0], -1, 1), clampi(r[1] + p[1], -1, 1), r[2] | p[2]]
	# Camera keeps P1 on the left, so "right" means forward for P1 and back for P2.
	return inp.frame(r[0] if i == 0 else -r[0], r[1], r[2])


func _dummy_think() -> Array:
	var A: Fighter = F[0]
	var B: Fighter = F[1]
	B.no_guard = dummy == 0
	if dummy == 2: return [0, -1, 0]
	if dummy == 1 and A.state == "attack" and A.move.lvl == "low": return [-1, -1, 0]
	return [0, 0, 0]


# ------------------------------------------------------------------ match flow
func start_match(c: Dictionary, p: Array) -> void:
	clear_preview()
	for f in F:
		f.rig.queue_free()
	cfg = c; picks = p; mode = c.mode
	set_stage(c.get("stage", Stage.LIST.pick_random().id))
	F = [Fighter.new(self, p[0], 0), Fighter.new(self, p[1], 1)]
	inputs = [InputBuf.new(), InputBuf.new()]
	ai = [null, FighterAI.new(self, c.lv) if mode == "cpu" else null]
	wins = [0, 0]; round_n = 1; frame = 0; dummy = 0; fd = null; paused = false
	trials = Data.trials(p[0]) if mode == "training" else []
	trial_i = 0; trial_step = 0; trial_done = {}
	ui.hide_screen()
	ui.show_hud(self)
	start_round()


func start_round() -> void:
	F[0].reset(-1.2); F[1].reset(1.2)
	ui.chip = [100.0, 100.0]
	time_left = 60; hitstop = 0; slow = 0; winner = -1; cam_a = null; surge_cam = null
	ui.set_round_label("TRAINING" if mode == "training" else "ROUND %d" % round_n)
	if mode == "training":
		phase = "fight"; F[0].meter = 100.0
		return
	phase = "intro"; phase_t = 110
	ui.announce("FINAL ROUND" if wins[0] == 1 and wins[1] == 1 else "ROUND %d" % round_n, "")


func ko_start(w: Fighter) -> void:
	if phase != "fight": return
	phase = "ko"; phase_t = 210; winner = w.side; slow = 60
	ui.announce("PERFECT K.O." if w.hp >= w.max_hp else "K.O.", "ko")
	sfx("ko")


func time_up() -> void:
	var a: float = F[0].hp / F[0].max_hp
	var b: float = F[1].hp / F[1].max_hp
	phase = "ko"; phase_t = 170
	winner = 0 if a > b else 1 if b > a else -1
	ui.announce("TIME", "ko")


func end_round() -> void:
	if winner == -1:
		wins[0] += 1; wins[1] += 1
	else:
		wins[winner] += 1
	if wins[0] >= 2 or wins[1] >= 2:
		phase = "end"
		ui.show_end_delayed()
	else:
		round_n += 1
		start_round()


func leave_game() -> void:
	for f in F:
		f.rig.queue_free()
	F = []
	phase = "menu"; paused = false
	ui.hide_hud()


func _physics_process(_dt: float) -> void:
	if F.is_empty() or paused or phase == "menu":
		return
	tick()


func tick() -> void:
	var ins := [read_player(0), read_player(1)]
	if hitstop > 0:
		hitstop -= 1
		F[0].collect(ins[0]); F[1].collect(ins[1])
		return
	if slow > 0:
		slow -= 1
		if slow % 3: return
	frame += 1
	F[0].save_prev(); F[1].save_prev()
	var A: Fighter = F[0]
	var B: Fighter = F[1]
	var live := phase == "fight"
	A.control(ins[0] if live else InputBuf.NEUTRAL)
	B.control(ins[1] if live else InputBuf.NEUTRAL)
	A.step(B); B.step(A)
	var r1 = check(A, B)
	var r2 = check(B, A)       # resolve simultaneously so trades are possible
	if r1 != null: r1.m = A.move; r1.rem = remaining(A)
	if r2 != null: r2.m = B.move; r2.rem = remaining(B)
	if r1 != null: apply_hit(A, B, r1)
	# A throw and a hit landing on the same frame: the grab wins, the other hit is dropped
	# (otherwise the thrower gets knocked out of the throw and the victim is left frozen).
	var grabbed := A.state in ["throwing", "thrown"] or B.state in ["throwing", "thrown"]
	if r2 != null and not (grabbed and r2.type != "throw"): apply_hit(B, A, r2)
	A.physics(); B.physics(); separate(A, B)
	if A.state in Fighter.FREE_FACE: A.face_to(B, 0.3)
	if B.state in Fighter.FREE_FACE: B.face_to(A, 0.3)
	A.tick_pose(); B.tick_pose()
	if surge_cam != null:
		surge_cam.t -= 1
		if surge_cam.t <= 0: surge_cam = null
	match phase:
		"intro":
			phase_t -= 1
			if phase_t == 45: ui.announce("FIGHT!", "fight")
			if phase_t <= 0: phase = "fight"
		"fight":
			if mode == "training": training_tick()
			elif frame % 60 == 0:
				time_left -= 1
				if time_left <= 0: time_up()
		"ko":
			var w: Fighter = F[winner] if winner >= 0 else null
			if w != null and phase_t < 110 and w.can_act(): w.set_state("win")
			phase_t -= 1
			if phase_t <= 0: end_round()


# ------------------------------------------------------------------ combat
func remaining(att: Fighter) -> int:
	return att.move.end - att.sf


func check(att: Fighter, def: Fighter):
	if att.state != "attack" or att.has_hit: return null
	var m := att.move
	if m.trans or att.sf < m.s or att.sf >= m.s + m.a: return null   # only active frames hit
	if def.state in Fighter.INVULN: return null
	var fx := sin(att.face)
	var fz := cos(att.face)
	var dx := def.pos.x - att.pos.x
	var dz := def.pos.z - att.pos.z
	var fwd := dx * fx + dz * fz
	var lat := absf(dx * fz - dz * fx)
	var air := def.state == "air"
	var ds: float = def.C.scale
	# Airborne bodies are bigger targets, which keeps juggles consistent.
	if fwd < -0.1 or fwd > m.range * att.C.scale + 0.22 * ds + (0.35 if air else 0.0) or lat > 0.32 * ds + (0.25 if air else 0.05):
		return null
	if m.is_throw:
		return null if (air or def.is_low() or def.state in ["hit", "block"] or def.is_jumping()) else {type = "throw", fwd = fwd}
	if air:
		return null if (def.juggle >= 10 or (m.lvl == "low" and def.pos.y > 0.45)) else {type = "hit", fwd = fwd, ch = false}
	if m.lvl == "high" and def.is_low(): return null     # highs whiff on crouchers
	if m.lvl == "low" and def.is_jumping(): return null  # lows whiff on hops
	if def.state == "attack" and def.move.armor and def.sf < def.move.s and not def.armor_used:
		return {type = "armor", fwd = fwd}
	if def.is_blocking(m.lvl): return {type = "block", fwd = fwd}
	return {type = "hit", fwd = fwd, ch = def.state == "attack" and def.sf < def.move.s}


func hurt(def: Fighter, dmg: int, att: Fighter) -> void:
	def.hp = maxf(1.0 if mode == "training" else 0.0, def.hp - dmg)
	att.meter = minf(100.0, att.meter + dmg * 0.9)
	def.meter = minf(100.0, def.meter + dmg * 1.1)


func apply_hit(att: Fighter, def: Fighter, res: Dictionary) -> void:
	var m: Data.Move = res.m   # snapshot: a trade may already have cancelled att.move
	var rem: int = res.rem
	var f := att.fwd()
	att.has_hit = true
	if res.type == "throw":
		if att.state != "attack": return   # the grab was interrupted in the same frame
		start_throw(att, def, m); return
	var air := def.state == "air"
	var was_low := def.is_low()
	var hy: float = def.pos.y + 0.95 if air else (1.5 if m.lvl == "high" else 0.35 if m.lvl == "low" else 1.05) * def.C.scale
	var d := maxf(0.25, res.fwd - 0.28 * def.C.scale)
	var cp := Vector3(att.pos.x + f.x * d, hy, att.pos.z + f.z * d)
	if res.type == "armor":
		hurt(def, roundi(m.dmg * att.C.power * 0.6), att); def.armor_used = true; def.flash = 1.0
		hitstop = 8; burst(cp, Color(1, 0.82, 0.4), 14, 3.0); sfx("block"); ui.pop_text("ARMOR", def.side)
		return
	if res.type == "block":
		def.set_state("block"); def.stun = maxi(4, rem + int(m.blk if m.blk != null else 0))
		def.crouch_block = m.lvl == "low"
		def.vel = f * (m.push * 0.8 if m.push > 0 else 0.05)
		att.meter = minf(100.0, att.meter + 2); def.meter = minf(100.0, def.meter + 3)
		def.kick(m.lvl, m.dmg / 10.0, true)
		hitstop = 5; burst(cp, Color(0.5, 0.85, 1.0), 10, 2.5); sfx("block"); fd_log(att, "BLOCK")
		return
	# Damage scaling: each extra hit in a combo is worth 10% less (min 30%).
	var sc := maxf(0.3, 1.0 - 0.1 * def.combo_hits) if def.combo_hits > 0 else 1.0
	var dmg := maxi(1, roundi(m.dmg * att.C.power * sc * (1.2 if res.ch else 1.0)))
	hurt(def, dmg, att); def.combo_hits += 1; def.combo_dmg += dmg; def.flash = 1.0
	var launch: bool = m.launch or (res.ch and m.ch_launch)
	if air or launch or m.kd or def.hp <= 0:
		if air:
			def.vy = maxf(def.vy, maxf(0.028, 0.072 - 0.006 * def.juggle)); def.air_v = f * 0.008; def.juggle += 1
		elif launch:
			def.vy = 0.14; def.air_v = f * 0.003; def.juggle = 1; def.pos.y = 0.01
			if att.state == "attack" and att.move == m:
				att.sf = maxi(att.sf, m.end - 12)   # a landed launcher recovers fast enough to juggle
		else:
			def.vy = 0.12 if m.surge else 0.08; def.air_v = f * (0.075 if m.surge else 0.04); def.juggle = 7; def.pos.y = 0.01
		if def.hp <= 0:
			def.vy = maxf(def.vy, 0.1); def.air_v = f * 0.05
		if def.state != "air": def.set_state("air")
		def.move = null; def.queued = ""; def.stance = ""
	else:
		def.set_state("hit")
		def.stun = maxi(6, rem + int(m.hit if m.hit != null else 0) + (8 if res.ch else 0))
		def.hit_lvl = m.lvl; def.hit_crouch = was_low; def.move = null; def.queued = ""; def.stance = ""
		def.vel = f * (m.push if m.push > 0 else 0.045)
	def.kick("high" if air else m.lvl, m.dmg / 10.0 * (1.4 if res.ch else 1.0))
	att.recoil(m.dmg / 10.0)
	var big: bool = m.surge or launch or m.kd or res.ch
	hitstop = 40 if m.surge else 10 if big else 7
	shake = 0.35 if m.surge else 0.16 if big else 0.07
	burst(cp, att.C.accent if m.surge else Color(1, 0.82, 0.4) if res.ch else Color.WHITE, 22 if big else 12, 4.5 if big else 3.0)
	ring(cp, att.C.accent if m.surge else Color.WHITE, 1.0 if big else 0.6)
	sfx("heavy" if big else "hit")
	if res.ch: ui.pop_text("COUNTER HIT", att.side)
	elif launch and not air: ui.pop_text("LAUNCH", att.side)
	if m.surge: ui.screen_flash(att.C.accent)
	fd_log(att, "COUNTER HIT" if res.ch else "HIT")
	trial_hit(att, def, m)
	if def.hp <= 0: ko_start(att)


func start_throw(att: Fighter, def: Fighter, m: Data.Move) -> void:
	att.set_state("throwing"); att.victim = def; att.tm = m; att.throw_dir = att.fwd(); att.move = null
	def.set_state("thrown"); def.thrower = att; def.break_throw = false; def.cmd_thrown = m.cmd_throw; def.thrown_by = m.throw_type
	def.pend = 0; def.buffer = null; def.throw_t = 0.0; def.move = null; def.stance = ""
	hitstop = 4; sfx("grab")
	ui.pop_text(m.name.to_upper(), att.side)


func separate(A: Fighter, B: Fighter) -> void:
	if A.state == "thrown" or B.state == "thrown" or A.pos.y > 0.6 or B.pos.y > 0.6: return
	var dx := B.pos.x - A.pos.x
	var dz := B.pos.z - A.pos.z
	var d := maxf(0.0001, Vector2(dx, dz).length())
	var mn: float = 0.32 * (A.C.scale + B.C.scale)
	if d < mn:
		var p := (mn - d) / 2.0
		A.pos.x -= dx / d * p; A.pos.z -= dz / d * p
		B.pos.x += dx / d * p; B.pos.z += dz / d * p


# ------------------------------------------------------------------ training
func fd_log(att: Fighter, res: String) -> void:
	if mode != "training" or att.side != 0 or fd == null: return
	fd.res = res; fd.adv = null; fd.tr = {f = 0, a = -1, d = -1}


func training_tick() -> void:
	var A: Fighter = F[0]
	var B: Fighter = F[1]
	for f in F:
		if f.can_act() and f.hp < f.max_hp:
			f.refill += 1
			if f.refill > 50:
				f.hp = f.max_hp; f.refill = 0; ui.chip[f.side] = 100.0
		else:
			f.refill = 0
	if A.can_act(): A.meter = 100.0
	if trial_step > 0 and B.combo_hits == 0 and B.can_act(): trial_step = 0   # combo dropped
	if fd != null and fd.tr != null:   # measure real frame advantage: who can act first after contact
		var tr: Dictionary = fd.tr
		tr.f += 1
		if B.state in ["air", "down", "ko"]:
			fd.adv = "LAUNCH" if B.state == "air" else "KND"; fd.tr = null; return
		if tr.a < 0 and A.can_act(): tr.a = tr.f
		if tr.d < 0 and B.can_act(): tr.d = tr.f
		if tr.a >= 0 and tr.d >= 0:
			fd.adv = tr.d - tr.a; fd.tr = null
		elif tr.f > 150:
			fd.tr = null


func trial_hit(att: Fighter, def: Fighter, m: Data.Move) -> void:
	if mode != "training" or att.side != 0 or trials.is_empty(): return
	var keys: Array = trials[trial_i].keys
	if def.combo_hits == 1: trial_step = 0
	if trial_step < keys.size() and m.key == keys[trial_step]:
		trial_step += 1
	else:
		trial_step = 1 if m.key == keys[0] else 0
	if trial_step >= keys.size():
		trial_done[trial_i] = true
		trial_step = 0
		ui.announce("TRIAL CLEAR!", "fight")
		sfx("ok")


func cycle_trial() -> void:
	if trials.is_empty(): return
	trial_i = (trial_i + 1) % trials.size()
	trial_step = 0


func cycle_dummy() -> void:
	dummy = (dummy + 1) % DUMMY.size()
	ai[1] = FighterAI.new(self, 1) if dummy == 3 else null
	F[1].no_guard = false


func reset_training() -> void:
	F[0].reset(-1.2); F[1].reset(1.2); F[0].meter = 100.0; fd = null; cam_a = null; ui.chip = [100.0, 100.0]


# ------------------------------------------------------------------ per-frame visuals
func _process(dt: float) -> void:
	t_now += dt
	if not F.is_empty():
		for f in F:
			f.render(t_now)
		_update_camera()
		ui.update_hud(self)
	else:
		_menu_camera()
	_update_fx(dt)


func _update_camera() -> void:
	var A: Fighter = F[0]
	var B: Fighter = F[1]
	var dv := Vector2(B.pos.x - A.pos.x, B.pos.z - A.pos.z)
	var sep := maxf(0.001, dv.length())
	dv /= sep
	var ta := atan2(-dv.y, dv.x)   # camera sits on the side that keeps P1 screen-left
	cam_a = ta if cam_a == null else lerp_angle(cam_a, ta, 0.08)
	var cx := (A.pos.x + B.pos.x) / 2.0
	var cz := (A.pos.z + B.pos.z) / 2.0
	var air := maxf(A.pos.y, B.pos.y) * 0.35
	var dist := maxf(3.7, sep * 1.15 + 2.5)
	var h := 1.45 + air
	var ly := 1.05 + air
	var ang: float = cam_a
	if surge_cam != null:
		var S: Fighter = surge_cam.f
		cx = S.pos.x; cz = S.pos.z; dist = 2.4; h = 1.15; ly = 1.3; ang += -0.5 if S.side else 0.5
	if phase == "intro" and phase_t > 50:
		dist += (phase_t - 50) * 0.03; ang += (phase_t - 50) * 0.006
	if phase == "end" or (phase == "ko" and phase_t < 100 and winner >= 0):
		var W: Fighter = F[maxi(0, winner)]
		cx = W.pos.x; cz = W.pos.z; dist = 3.0; ly = 1.2; h = 1.3
		ang = W.face + (-0.5 if W.side else 0.5)
	cam_pos = cam_pos.lerp(Vector3(cx + sin(ang) * dist, h, cz + cos(ang) * dist), 0.1)
	cam_look = cam_look.lerp(Vector3(cx, ly, cz), 0.14)
	camera.position = cam_pos
	if shake > 0.002:
		camera.position += Vector3(randf() - 0.5, randf() - 0.5, 0) * shake
		shake *= 0.86
	camera.look_at(cam_look)


func _menu_camera() -> void:
	var sel: bool = ui.view == "select"
	var a := t_now * 0.11
	if sel:
		cam_pos = cam_pos.lerp(Vector3(0, 1.25, 5.3), 0.08); cam_look = cam_look.lerp(Vector3(0, 1.08, 0), 0.08)
	else:
		cam_pos = Vector3(sin(a) * 5.6, 1.45, cos(a) * 5.6); cam_look = Vector3(0, 1.05, 0)
	camera.position = cam_pos
	camera.look_at(cam_look)
	for i in 2:
		var pv = preview[i]
		if pv == null: continue
		var r = pv.rig
		r.position = Vector3((1.3 if i else -1.3) if sel else (1.55 if i else -1.55), 0, 0)
		r.rotation.y = ((-0.45 if i else 0.45) if sel else (-PI / 2 if i else PI / 2))
		pv.disp = Pose.lerp_p(pv.disp, pv.C.pose.win if pv.win else pv.C.pose.guard, 0.12)
		var q: PackedFloat32Array = pv.disp.duplicate()
		if not pv.win:
			Idle.apply(pv.C.id, q, t_now + i * 0.9)
		r.apply_pose(q)


func set_preview(side: int, C: Dictionary) -> void:
	if preview[side] != null and preview[side].C == C: return
	if preview[side] != null: preview[side].rig.queue_free()
	var rig := make_rig(C)
	add_child(rig)
	# glowing pedestal in the fighter's color
	for spec in [[0.42, 0.62, 0.9], [0.0, 0.62, 0.18]]:
		var m := ShaderMaterial.new(); m.shader = ADDITIVE
		m.set_shader_parameter("color", C.accent); m.set_shader_parameter("alpha", spec[2])
		var mesh: Mesh
		if spec[0] > 0.0:
			var tor := TorusMesh.new(); tor.inner_radius = spec[0]; tor.outer_radius = spec[1]; tor.rings = 48
			mesh = tor
		else:
			var disc := CylinderMesh.new(); disc.top_radius = spec[1]; disc.bottom_radius = spec[1]; disc.height = 0.01
			mesh = disc
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m; mi.position.y = 0.01
		mi.scale = Vector3(1, 0.05, 1) if spec[0] > 0.0 else Vector3.ONE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(mi)
	preview[side] = {C = C, rig = rig, disp = C.pose.guard.duplicate(), win = false}


func clear_preview() -> void:
	for i in 2:
		if preview[i] != null:
			preview[i].rig.queue_free()
			preview[i] = null


# ------------------------------------------------------------------ automated checks (xvfb)
func _run_autotest() -> void:
	var shot := func(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shot_%s.png" % name)
	match autotest:
		"title":
			ui.show_title()
			await get_tree().create_timer(1.0).timeout
			await shot.call("title")
		"stagesel":
			ui.show_stage({mode = "cpu", lv = 1}, [Data.by_id("ember"), Data.by_id("bastion")])
			ui.stage_sel.i = 2
			ui._render_stage()
			await get_tree().create_timer(2.0).timeout
			await shot.call("stagesel")
		"select":
			ui.show_select({mode = "cpu", lv = 1})
			await get_tree().create_timer(1.0).timeout
			await shot.call("select")
		"fight":
			var ids := ["mara", "lio"]
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--pair="): ids = a.substr(7).split(",")
			var st := "neon"
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--stage="): st = a.substr(8)
			start_match({mode = "cpu", lv = 2, stage = st}, [Data.by_id(ids[0]), Data.by_id(ids[1])])
			ai[0] = FighterAI.new(self, 2)
			await get_tree().create_timer(6.0).timeout
			await shot.call("fight")
			print("AUTOTEST hp=", F[0].hp, ",", F[1].hp, " phase=", phase)
			var t0 := Time.get_ticks_usec()
			for i in 100:
				F[0].render(t_now); F[1].render(t_now)
			print("AUTOTEST pose cost per frame (both fighters): %.2f ms" % ((Time.get_ticks_usec() - t0) / 100000.0))
		"moves":
			start_match({mode = "training"}, [Data.by_id("kael"), Data.by_id("bastion")])
			await get_tree().create_timer(0.3).timeout
			ui.show_pause(); ui.show_moves(0)
			await get_tree().create_timer(0.5).timeout
			await shot.call("moves")
		"closeup":
			var id := "sora"
			var mv := ""
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--id="): id = a.substr(5)
				if a.begins_with("--move="): mv = a.substr(7)
			var C := Data.by_id(id)
			var rig := make_rig(C)
			add_child(rig)
			var p: PackedFloat32Array = C.pose.guard
			if mv != "":
				var m: Data.Move = C.moves[mv]
				p = m.track[m.track.size() - 1][1]
			rig.apply_pose(p)
			rig.rotation.y = 0.5
			ui.hide_screen()
			set_process(false)
			camera.position = Vector3(1.1, 1.3, 1.9)
			camera.look_at(Vector3(0, 1.05, 0))
			await get_tree().create_timer(0.5).timeout
			await shot.call("closeup")
		"trials":
			for id in ["kael", "bastion", "mara", "vex", "sora"]:
				start_match({mode = "training"}, [Data.by_id(id), Data.by_id("bastion")])
				F[0].reset(-0.55); F[1].reset(0.55)
				for t in trials.size():
					print("AUTOTEST trials ", id, " #", t, " ", trials[t].name, " ", trials[t].keys)
				# trial index of the launcher juggle
				for t in trials.size():
					if trials[t].name == "Launcher Juggle": trial_i = t
				var keys: Array = trials[trial_i].keys
				var launcher: String = keys[0]
				var seq := []
				var dirs := {df = [KEY_D, KEY_S], d = [KEY_S], b = [KEY_A], f = [KEY_D], uf = [KEY_D, KEY_W]}
				var btn := {"1": KEY_U, "2": KEY_I, "3": KEY_J, "4": KEY_K}
				var pre := launcher.rstrip("1234")
				var dk: Array = dirs.get(pre, [])
				seq.append([dk, 2]); seq.append([dk + [btn[launcher.right(1)]], 4]); seq.append([[], 30])
				# follow-up string: keys[1] is its first button, each later key adds one button
				for j in range(1, keys.size()):
					seq.append([[btn[keys[j].right(1)]], 3]); seq.append([[], 5])
				for i in 10: await get_tree().physics_frame
				var trace := []
				for st in seq:
					test_keys.clear()
					for kk in st[0]: test_keys[kk] = true
					for i in st[1]:
						await get_tree().physics_frame
						trace.append("%s/%d|%s y%.2f h%d" % [F[0].move.key if F[0].move else F[0].state, F[0].sf, F[1].state, F[1].pos.y, F[1].combo_hits])
				test_keys.clear()
				var best := 0
				for i in 90:
					await get_tree().physics_frame
					best = maxi(best, F[1].combo_hits)
					trace.append("%s/%d|%s y%.2f h%d d%.2f" % [F[0].move.key if F[0].move else F[0].state, F[0].sf, F[1].state, F[1].pos.y, F[1].combo_hits, F[0].dist_to(F[1])])
				if id == "bastion": print("AUTOTEST TRACE ", " ; ".join(trace))
				print("AUTOTEST juggle %-8s keys=%s cleared=%s max_hits=%d" % [id, keys, trial_done.get(trial_i, false), best])
		"springs":
			start_match({mode = "cpu", lv = 2}, [Data.by_id("vex"), Data.by_id("ember")])
			ai[0] = FighterAI.new(self, 2)
			var stats := {}
			for f in 300:
				await get_tree().physics_frame
				if f % 30 != 29: continue
				for fi in 2:
					var r = F[fi].rig
					if not (r is VrmRig): continue
					var mx := 0.0
					var tot := 0.0
					var n := 0
					var bad := false
					for chain in r.springs:
						for jn in chain:
							var q: Quaternion = r.skel.get_bone_pose_rotation(jn.b)
							var rq: Quaternion = r.rest_l[jn.b].basis.get_rotation_quaternion()
							var ang := rad_to_deg(q.angle_to(rq))
							if is_nan(ang): bad = true
							mx = maxf(mx, ang); tot += ang; n += 1
					var key: String = F[fi].C.id
					if not stats.has(key): stats[key] = []
					stats[key].append("%.0f/%.0f%s" % [tot / maxf(1, n), mx, " NaN!" if bad else ""])
			for k in stats:
				print("AUTOTEST springs %s joints=%d avg/max deg over time: %s" % [k, _count_joints(k), " ".join(stats[k])])
			var t0 := Time.get_ticks_usec()
			for i in 100:
				F[0].render(t_now); F[1].render(t_now)
			print("AUTOTEST pose+springs cost per frame (both): %.2f ms" % ((Time.get_ticks_usec() - t0) / 100000.0))
			await shot.call("fight")
		"trade":
			for setup in [["throw vs jab", "12", "1", 2], ["jab vs throw", "1", "12", -2], ["throw vs throw", "12", "12", 0]]:
				start_match({mode = "training"}, [Data.by_id("tao"), Data.by_id("lio")])
				dummy = 0
				F[0].reset(-0.5); F[1].reset(0.5)
				for i in 5: await get_tree().physics_frame
				# line the active frames up so both connect on the same tick
				var d: int = setup[3]
				if d >= 0:
					F[0].start_move(setup[1])
					for i in d: await get_tree().physics_frame
					F[1].start_move(setup[2])
				else:
					F[1].start_move(setup[2])
					for i in -d: await get_tree().physics_frame
					F[0].start_move(setup[1])
				var states := []
				for i in 150:
					await get_tree().physics_frame
					if i % 30 == 29: states.append("%s/%s" % [F[0].state, F[1].state])
				print("AUTOTEST trade %-15s -> %s  final ok=%s" % [setup[0], " ".join(states), str(not (F[0].state in ["thrown", "throwing"] or F[1].state in ["thrown", "throwing"]))])
		"combat":
			await _combat_checks()
		"string":
			start_match({mode = "training"}, [Data.by_id("mara"), Data.by_id("bastion")])
			F[0].reset(-0.55); F[1].reset(0.55)
			for i in 10: await get_tree().physics_frame
			var plan := {0: KEY_U, 8: KEY_I, 17: KEY_U}
			var log := []
			for f in 60:
				test_keys.clear()
				for start in plan:
					if f >= start and f < start + 4: test_keys[plan[start]] = true
				await get_tree().physics_frame
				log.append("%d:%s/%s q=%s" % [f, F[0].move.key if F[0].move else F[0].state, F[0].sf, F[0].queued])
			print("AUTOTEST ", " ".join(log))
	get_tree().quit()


func _count_joints(id: String) -> int:
	for f in F:
		if f.C.id == id and f.rig is VrmRig:
			var n := 0
			for chain in f.rig.springs: n += chain.size()
			return n
	return 0


func _combat_checks() -> void:
	# Drive inputs through the real input path and report frame data.
	var cases := [
		["kael", 1, [[[KEY_U], 4]], "jab vs guard"],
		["vex", 1, [[[KEY_D, KEY_S], 2], [[KEY_D, KEY_S, KEY_I], 4]], "df+2 vs guard"],
		["sora", 0, [[[KEY_A, KEY_J], 4], [[], 12], [[KEY_K], 4]], "crane 4"],
		["ember", 1, [[[KEY_D], 3], [[], 2], [[KEY_D], 3], [[KEY_D, KEY_U], 4]], "ff+1 command throw"],
		["bastion", 0, [[[KEY_S], 14], [[], 1], [[KEY_I], 4]], "ws2"],
		["mara", 0, [[[KEY_U], 4], [[], 4], [[KEY_I], 4], [[], 5], [[KEY_U], 4]], "1,2,1 string"],
	]
	for c in cases:
		start_match({mode = "training"}, [Data.by_id(c[0]), Data.by_id("bastion")])
		dummy = c[1]
		F[0].reset(-0.55); F[1].reset(0.55)
		for i in 10: await get_tree().physics_frame
		var hp0: float = F[1].hp
		for step in c[2]:
			test_keys.clear()
			for k in step[0]: test_keys[k] = true
			for i in step[1]: await get_tree().physics_frame
		test_keys.clear()
		var min_hp := hp0
		for i in 80:
			await get_tree().physics_frame
			min_hp = minf(min_hp, F[1].hp)
		print("AUTOTEST %-20s move=%s res=%s adv=%s dmg=%d" % [c[3], fd.m.key if fd != null else "-", fd.res if fd != null else "-", str(fd.adv) if fd != null else "-", hp0 - min_hp])
