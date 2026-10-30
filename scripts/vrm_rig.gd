class_name VrmRig
extends Node3D
## Anime fighter from a VRM 1.0 avatar. The game's poses drive an invisible joint proxy
## (same layout as ToonRig); each frame the proxy is retargeted onto the VRM humanoid skeleton.
## Same interface as ToonRig: build(), apply_pose(), set_flash(), set_glow(), head.

const OUTLINE := preload("res://shaders/outline.gdshader")
static var _shader_cache := {}
static var _file_cache := {}   # path -> PackedByteArray

var proxy: ToonRig
var model: Node3D
var skel: Skeleton3D
var head := Node3D.new()          # marker used by portraits / camera
var k := 1.0                      # model scale so the hips sit at 0.95
var bones := {}                   # humanoid name -> bone index
var rest_g := {}                  # bone index -> rest global Transform3D (skeleton space)
var rest_l := {}                  # bone index -> local Transform3D used for undriven bones
var order: Array[int] = []        # parents before children
var mats: Array[ShaderMaterial] = []
var expressions := {}             # preset -> [[MeshInstance3D, blend index, weight]]
var face := ""
var foot_rest := {}               # bone -> rest height
var arm_axis := {}                # limb -> rest hinge axis
var accent := Color.WHITE
var qb := Basis.IDENTITY          # model -> rig rotation (VRM 0.x models face -Z, so they are turned 180°)
var qi := Basis.IDENTITY
var constraints: Array = []      # VRMC_node_constraint: rotation / roll / aim


static func has_model(C: Dictionary) -> bool:
	return not Models.spec(C.id).is_empty()


func build(C: Dictionary) -> void:
	var spec: Dictionary = Models.spec(C.id)
	accent = C.accent
	proxy = ToonRig.new()
	proxy.joints_only = true
	proxy.build_joints()
	proxy.visible = false
	add_child(proxy)
	add_child(head)
	_load(spec.file)
	_restyle(spec.get("tint", {}))
	_index_skeleton()
	_make_fists()
	scale = Vector3.ONE * float(C.scale)


# ---------------------------------------------------------------- loading
func _load(path: String) -> void:
	if not _file_cache.has(path):
		_file_cache[path] = FileAccess.get_file_as_bytes(path)
	var bytes: PackedByteArray = _file_cache[path]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_buffer(bytes, path.get_base_dir(), state)
	model = doc.generate_scene(state)
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	# Read the VRM humanoid map and expressions straight from the glTF JSON chunk.
	var json_len := bytes.decode_u32(12)
	var j: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var nodes := state.get_nodes()
	var bone_of := func(ni: int) -> int:
		var bi := skel.find_bone(nodes[ni].resource_name)
		return bi if bi >= 0 else skel.find_bone(String(nodes[ni].resource_name).validate_node_name())
	if not j.extensions.has("VRMC_vrm"):
		_load_vrm0(j, state, bone_of)
		return
	var vrm: Dictionary = j.extensions.VRMC_vrm
	for hb in vrm.humanoid.humanBones:
		var bi: int = bone_of.call(int(vrm.humanoid.humanBones[hb].node))
		if bi >= 0:
			bones[hb] = bi
	var axes := {"PositiveX": Vector3.RIGHT, "NegativeX": Vector3.LEFT, "PositiveY": Vector3.UP, "NegativeY": Vector3.DOWN,
		"PositiveZ": Vector3.BACK, "NegativeZ": Vector3.FORWARD, "X": Vector3.RIGHT, "Y": Vector3.UP, "Z": Vector3.BACK}
	for ni in j.nodes.size():
		var ext: Dictionary = j.nodes[ni].get("extensions", {})
		if not ext.has("VRMC_node_constraint"): continue
		var con: Dictionary = ext.VRMC_node_constraint.constraint
		var kind: String = con.keys()[0]
		var c: Dictionary = con[kind]
		var dst: int = bone_of.call(ni)
		var src: int = bone_of.call(int(c.source))
		if dst < 0 or src < 0: continue
		constraints.append({kind = kind, dst = dst, src = src, w = float(c.get("weight", 1.0)),
			axis = axes.get(c.get("aimAxis", c.get("rollAxis", "X")), Vector3.RIGHT)})
	if vrm.has("expressions") and vrm.expressions.has("preset"):
		for name in vrm.expressions.preset:
			var binds: Array = []
			for b in vrm.expressions.preset[name].get("morphTargetBinds", []):
				var n = state.get_scene_node(int(b.node))
				if is_instance_valid(n) and n is MeshInstance3D:
					binds.append([n, int(b.index), float(b.weight)])
			expressions[name] = binds


## VRM 0.x: humanBones is a list, expressions are "blendShapeGroups", and the model faces -Z.
func _load_vrm0(j: Dictionary, state: GLTFState, bone_of: Callable) -> void:
	var vrm: Dictionary = j.extensions.VRM
	for hb in vrm.humanoid.humanBones:
		var bi: int = bone_of.call(int(hb.node))
		if bi >= 0:
			bones[hb.bone] = bi
	qb = Basis(Vector3.UP, PI)
	qi = qb.inverse()
	model.rotation.y = PI
	# Map glTF mesh index -> scene MeshInstance3D nodes that use it.
	var mesh_nodes := {}
	var gnodes := state.get_nodes()
	for ni in gnodes.size():
		if gnodes[ni].mesh >= 0:
			var n = state.get_scene_node(ni)
			if is_instance_valid(n) and n is MeshInstance3D:
				mesh_nodes[gnodes[ni].mesh] = mesh_nodes.get(gnodes[ni].mesh, []) + [n]
	var rename := {"joy": "happy", "sorrow": "sad", "fun": "surprised", "angry": "angry", "neutral": "neutral"}
	for g in vrm.get("blendShapeMaster", {}).get("blendShapeGroups", []):
		var preset: String = String(g.get("presetName", "")).to_lower()
		if not rename.has(preset): continue
		var binds: Array = []
		for b in g.get("binds", []):
			for n in mesh_nodes.get(int(b.mesh), []):
				binds.append([n, int(b.index), float(b.weight) / 100.0])
		expressions[rename[preset]] = binds


func _shader(key: String) -> Shader:
	if _shader_cache.has(key):
		return _shader_cache[key]
	var modes := "diffuse_toon, specular_disabled"
	var defs := ""
	if "nocull" in key: modes += ", cull_disabled"
	if "blend" in key:
		modes += ", depth_draw_opaque"
		defs += "#define USE_ALPHA\n"
	if "scissor" in key: defs += "#define USE_SCISSOR\n"
	var s := Shader.new()
	s.code = "shader_type spatial;\nrender_mode %s;\n%s#include \"res://shaders/toon_tex.gdshaderinc\"\n" % [modes, defs]
	_shader_cache[key] = s
	return s


## Replace imported PBR materials with the cel shader (+ outlines), applying per-fighter tints.
func _restyle(tint: Dictionary) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("thickness", 0.0035)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			var src = mi.get_active_material(si)
			if not (src is BaseMaterial3D):
				continue
			var name := String(src.resource_name)
			var blend: bool = src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			var scissor: bool = src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			var key := ("blend" if blend else "scissor" if scissor else "opaque") + ("_nocull" if src.cull_mode == BaseMaterial3D.CULL_DISABLED else "")
			var m := ShaderMaterial.new()
			m.shader = _shader(key)
			var hidden := false
			for pat in tint:
				if tint[pat] is String and tint[pat] == "hide" and pat.to_lower() in name.to_lower():
					hidden = true
			if hidden:
				# Remove this clothing piece (e.g. the base model's school tie).
				var inv := StandardMaterial3D.new()
				inv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				inv.albedo_color = Color(0, 0, 0, 0)
				mi.set_surface_override_material(si, inv)
				continue
			var col: Color = src.albedo_color
			for pat in tint:
				if tint[pat] is String: continue
				if pat.to_lower() in name.to_lower():
					# A tint is a Color, or {c = Color, sat = 0..2, bright = 0..2} for full recolors.
					var t = tint[pat]
					if t is Dictionary:
						# VRoid stores much of its color in the material color, not the texture: recolor both.
						var sat: float = t.get("sat", 1.0)
						var l := col.get_luminance()
						col = Color(l, l, l, col.a).lerp(col, clampf(sat, 0.0, 1.0)) * t.get("c", Color.WHITE)
						m.set_shader_parameter("saturation", t.get("sat", 1.0))
						m.set_shader_parameter("brightness", t.get("bright", 1.0))
					else:
						col *= t
			m.set_shader_parameter("albedo", col)
			m.set_shader_parameter("tex", src.albedo_texture if src.albedo_texture else PlaceholderTexture2D.new())
			m.set_shader_parameter("shade", col.darkened(0.3).lerp(Color(0.55, 0.5, 0.75), 0.4) if src.albedo_texture == null else Color(0.66, 0.6, 0.8))
			if src.emission_enabled:
				m.set_shader_parameter("emission_strength", 0.6)
			var lname := name.to_lower()
			if not blend and not ("eye" in lname or "mouth" in lname or "brow" in lname or "face" in lname and not "skin" in lname):
				m.next_pass = outline
			if src.albedo_texture == null and not blend:
				m.set_shader_parameter("tex", _white())
			mi.set_surface_override_material(si, m)
			mats.append(m)


static var _white_tex: ImageTexture
static func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


# ---------------------------------------------------------------- skeleton
func _index_skeleton() -> void:
	for b in skel.get_bone_count():
		rest_g[b] = skel.get_bone_global_rest(b)
		rest_l[b] = skel.get_bone_rest(b)
	var roots: Array = []
	for b in skel.get_bone_count():
		if skel.get_bone_parent(b) < 0:
			roots.append(b)
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var b: int = stack.pop_front()
		order.append(b)
		for c in skel.get_bone_children(b):
			stack.append(c)
	var hip_y: float = rest_g[bones.hips].origin.y
	k = 0.95 / hip_y
	model.scale = Vector3.ONE * k
	for f in ["leftFoot", "rightFoot", "leftToes", "rightToes"]:
		if bones.has(f):
			foot_rest[bones[f]] = rest_g[bones[f]].origin.y
	# Hinge axes in the rest pose: the proxy's limbs hang straight down with the hinge along X.
	for limb in [["leftUpperArm", "leftLowerArm"], ["rightUpperArm", "rightLowerArm"], ["leftUpperLeg", "leftLowerLeg"], ["rightUpperLeg", "rightLowerLeg"]]:
		var d := _rest_dir(limb[0], limb[1])
		arm_axis[limb[0]] = Quaternion(Vector3.DOWN, d) * (qi * Vector3.RIGHT)


func _rest_dir(a: String, b: String) -> Vector3:
	return (rest_g[bones[b]].origin - rest_g[bones[a]].origin).normalized()


func _make_fists() -> void:
	for side in ["left", "right"]:
		if not bones.has(side + "Hand") or not bones.has(side + "MiddleProximal"):
			continue
		var fdir: Vector3 = (rest_g[bones[side + "MiddleProximal"]].origin - rest_g[bones[side + "Hand"]].origin).normalized()
		var axis_w: Vector3 = fdir.cross(Vector3.DOWN).normalized()
		for finger in ["Index", "Middle", "Ring", "Little", "Thumb"]:
			for seg in ["Proximal", "Intermediate", "Distal", "Metacarpal"]:
				var n: String = side + finger + seg
				if not bones.has(n): continue
				var b: int = bones[n]
				var ang := 1.25
				var aw := axis_w
				if finger == "Thumb":
					# Tuck the thumb across the curled fingers instead of curling it like a finger.
					ang = 0.85 if seg != "Metacarpal" else 0.5
					aw = qi * Vector3.RIGHT
				var axis_l: Vector3 = (rest_g[b].basis.inverse() * aw).normalized()
				var t: Transform3D = rest_l[b]
				t.basis = t.basis * Basis(axis_l, ang)
				rest_l[b] = t


# ---------------------------------------------------------------- posing
static func _frame(dir: Vector3, axis: Vector3) -> Basis:
	var y := dir.normalized()
	var x := (axis - y * axis.dot(y))
	if x.length() < 1e-4:
		x = Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	x = x.normalized()
	return Basis(x, y, x.cross(y))


func _rel(n: Node3D) -> Transform3D:
	return proxy.global_transform.affine_inverse() * n.global_transform


func apply_pose(p: PackedFloat32Array, ground := true) -> void:
	proxy.apply_pose(p, false)
	var hips_t := _rel(proxy.hips)
	var hips_d := hips_t.basis.orthonormalized()
	var torso_l := proxy.torso.basis
	var head_l := proxy.head.basis
	var spine_d := hips_d * Basis().slerp(torso_l, 0.5)
	var chest_d := hips_d * torso_l
	var neck_d := chest_d * Basis().slerp(head_l, 0.5)
	var head_d := chest_d * head_l
	var toS := func(b: Basis) -> Basis: return qi * b * qb   # rig-space rotation -> skeleton space
	hips_d = toS.call(hips_d); spine_d = toS.call(spine_d); chest_d = toS.call(chest_d)
	neck_d = toS.call(neck_d); head_d = toS.call(head_d)
	var want := {}   # bone -> desired global basis (skeleton space)
	var put := func(name: String, delta: Basis) -> void:
		if bones.has(name):
			want[bones[name]] = delta * rest_g[bones[name]].basis
	put.call("hips", hips_d)
	put.call("spine", spine_d)
	put.call("chest", chest_d)
	put.call("upperChest", chest_d)
	put.call("neck", neck_d)
	put.call("head", head_d)
	# Limbs: aim each segment along the proxy's segment, keeping the elbow/knee hinge aligned.
	for L in [["leftUpperArm", "leftLowerArm", "leftHand", proxy.l_s, proxy.l_e], ["rightUpperArm", "rightLowerArm", "rightHand", proxy.r_s, proxy.r_e],
			["leftUpperLeg", "leftLowerLeg", "leftFoot", proxy.l_h, proxy.l_k], ["rightUpperLeg", "rightLowerLeg", "rightFoot", proxy.r_h, proxy.r_k]]:
		if not (bones.has(L[0]) and bones.has(L[1]) and bones.has(L[2])):
			continue
		var up_b := qi * _rel(L[3]).basis
		var lo_b := qi * _rel(L[4]).basis
		var hinge := lo_b.x
		var ax_r: Vector3 = arm_axis[L[0]]
		var r_up := _frame(-up_b.y, hinge) * _frame(_rest_dir(L[0], L[1]), ax_r).inverse()
		var r_lo := _frame(-lo_b.y, hinge) * _frame(_rest_dir(L[1], L[2]), ax_r).inverse()
		want[bones[L[0]]] = r_up * rest_g[bones[L[0]]].basis
		want[bones[L[1]]] = r_lo * rest_g[bones[L[1]]].basis
		want[bones[L[2]]] = r_lo * rest_g[bones[L[2]]].basis
	# Hips translation (proxy units -> skeleton units).
	var hip_pos: Vector3 = rest_g[bones.hips].origin + qi * (hips_t.origin - Vector3(0, 0.95, 0)) / k
	# Solve once, evaluate constraints from that result, then solve again with them applied.
	var first := _solve(want, hip_pos, {})
	var over := {}
	for c in constraints:
		over[c.dst] = _constraint_local(c, first[0], first[1])
	var res := _solve(want, hip_pos, over)
	var G: Dictionary = res[0]
	var Ls: Dictionary = res[1]
	for b in order:
		skel.set_bone_pose_rotation(b, Ls[b].basis.get_rotation_quaternion())
		skel.set_bone_pose_position(b, Ls[b].origin)
	# Keep feet on the floor: no foot may sink below its rest height.
	var lift := 0.0
	if ground and not foot_rest.is_empty():
		var low := INF
		for b in foot_rest:
			low = minf(low, G[b].origin.y - foot_rest[b])
		lift = -low * k
		if p[Pose.LIFT] > 0.001:
			lift = maxf(lift, 0.0)
	model.position.y = lift
	head.position = model.transform * G[bones.head].origin + Vector3(0, 0.06, 0)


## Walk the hierarchy turning desired global rotations into local poses. Returns [globals, locals].
func _solve(want: Dictionary, hip_pos: Vector3, over: Dictionary) -> Array:
	var G := {}
	var Ls := {}
	for b in order:
		var par := skel.get_bone_parent(b)
		var pg: Transform3D = G[par] if par >= 0 else Transform3D.IDENTITY
		var gt: Transform3D
		if over.has(b):
			gt = pg * over[b]
		elif want.has(b):
			var origin: Vector3 = hip_pos if b == bones.hips else (pg * rest_l[b]).origin
			gt = Transform3D(want[b], origin)
		else:
			gt = pg * rest_l[b]
		G[b] = gt
		Ls[b] = pg.affine_inverse() * gt
	return [G, Ls]


func _constraint_local(c: Dictionary, G: Dictionary, Ls: Dictionary) -> Transform3D:
	var rest: Transform3D = rest_l[c.dst]
	var w: float = c.w
	if c.kind == "aim":
		var par := skel.get_bone_parent(c.dst)
		var pg: Transform3D = G[par] if par >= 0 else Transform3D.IDENTITY
		var base := pg * rest
		var from: Vector3 = (base.basis * c.axis).normalized()
		var to: Vector3 = (G[c.src].origin - base.origin).normalized()
		if from.length() < 0.5 or to.length() < 0.5 or from.dot(to) > 0.9999:
			return rest
		var q := Quaternion.IDENTITY.slerp(Quaternion(from, to), w)
		return Transform3D(pg.basis.inverse() * (Basis(q) * base.basis), rest.origin)
	var delta := Quaternion(rest_l[c.src].basis.orthonormalized().inverse() * Ls[c.src].basis.orthonormalized())
	if c.kind == "roll":
		var a: Vector3 = c.axis
		var proj := Vector3(delta.x, delta.y, delta.z).project(a)
		var tw := Quaternion(proj.x, proj.y, proj.z, delta.w)
		delta = tw.normalized() if tw.length() > 1e-5 else Quaternion.IDENTITY
	return Transform3D(rest.basis * Basis(Quaternion.IDENTITY.slerp(delta, w)), rest.origin)


func set_flash(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("flash", v)


func set_glow(v: float) -> void:
	# Surge-ready glow: tint the rim light with the fighter's accent color.
	var strong := v > 1.0
	for m in mats:
		m.set_shader_parameter("rim_color", accent if strong else Color(0.75, 0.88, 1.0))
		m.set_shader_parameter("rim_amount", 0.25 + (v - 0.9) * 0.4 if strong else 0.18)


func set_face(name: String) -> void:
	if name == face:
		return
	for e in expressions.values():
		for bind in e:
			bind[0].set_blend_shape_value(bind[1], 0.0)
	face = name
	if expressions.has(name):
		for bind in expressions[name]:
			bind[0].set_blend_shape_value(bind[1], bind[2])
