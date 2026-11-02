class_name Models
## Which VRM model each fighter uses, and their costumes.
## A fighter's own model at characters/<id>/model.vrm always replaces the base model (see VROID_GUIDE.md);
## costume accessories still apply on top of it.
##
## Bases (credits in CREDITS.md):
##   seed_san.vrm      "Seed-san" by VirtualCast, Inc. (VRM Public License 1.0, credit required)
##   twist_sample.vrm  VRM1_Constraint_Twist_Sample by pixiv Inc. (VRM Public License 1.0)
##   base_male.vrm     VRoid "Base_Male" by the VRoid Project (CC0)
##
## Costume = {name, tint, acc}
##   tint: material-name substring -> Color multiplier, {c, sat, bright} recolor (sat 0 = grey), or "hide"
##   acc:  accessories attached to bones: [kind, Color] with kind in
##         gloves, wraps, headband, belt, sash, armbands, visor, kneepads, shoulders

const SEED := "res://characters/_base/seed_san.vrm"
const GIRL := "res://characters/_base/twist_sample.vrm"
const MALE := "res://characters/_base/base_male.vrm"


static func spec(id: String, costume := 0) -> Dictionary:
	if not LIST.has(id):
		return {}
	var e: Dictionary = LIST[id]
	var cs: Dictionary = e.costumes[clampi(costume, 0, e.costumes.size() - 1)]
	var own := "res://characters/%s/model.vrm" % id
	if FileAccess.file_exists(own):
		return {file = own, tint = {}, acc = cs.get("acc", [])}
	return {file = e.file, tint = _with_prints(cs.get("tint", {}), PRINTS.get(id, [])[costume] if costume < PRINTS.get(id, []).size() else {}), acc = cs.get("acc", [])}


## Merge a costume's prints into its tints (a plain Color tint becomes {c = Color} so it can carry a pattern).
static func _with_prints(tint: Dictionary, prints: Dictionary) -> Dictionary:
	var out := tint.duplicate()
	for part in prints:
		var t = out.get(part, {})
		var d: Dictionary = (t as Dictionary).duplicate() if t is Dictionary else {c = t if t is Color else Color.WHITE}
		d.pat = prints[part]
		out[part] = d
	return out


static func costume_names(id: String) -> Array:
	return LIST[id].costumes.map(func(c): return c.name) if LIST.has(id) else ["Classic"]


static func skin(c: Color) -> Dictionary:
	return {"Body_00_SKIN": c, "Face_00_SKIN": c}


## Costume prints per fighter, in costume order: material-name substring -> pattern (see VrmRig._set_pattern).
const PRINTS := {
	"vex": [
		{"huku": {kind = "grid", a = Color(0.2, 0.75, 0.95), b = Color(0.5, 1.0, 1.0), scale = 1.2}},
		{"huku": {kind = "grid", a = Color(0.55, 0.12, 0.15), b = Color(1.0, 0.35, 0.3), scale = 1.2}},
		{"huku": {kind = "camo", a = Color(0.2, 0.21, 0.24), b = Color(0.45, 0.47, 0.5), scale = 1.0}},
	],
	"sora": [
		{"Bottoms": {kind = "gradient", a = Color(0.08, 0.08, 0.12), o = 0.25}},
		{"Tops": {kind = "camo", a = Color(0.32, 0.34, 0.38), b = Color(0.8, 0.82, 0.86), scale = 1.0}},
		{"Tops": {kind = "diagonal", a = Color(0.82, 0.76, 0.74), b = Color(0.9, 0.7, 0.2), scale = 1.0}},
	],
	"ember": [
		{"Bottoms": {kind = "flames", a = Color(1.0, 0.45, 0.1), b = Color(1.0, 0.85, 0.3), o = 0.12},
			"Tops": {kind = "diagonal", a = Color(1.0, 0.75, 0.2), b = Color(0.35, 0.1, 0.55), scale = 0.8}},
		{"Tops": {kind = "scales", a = Color(0.35, 0.05, 0.02), b = Color(1.0, 0.45, 0.15), scale = 1.0},
			"Bottoms": {kind = "flames", a = Color(1.0, 0.35, 0.1), b = Color(1.0, 0.8, 0.25), o = 0.12}},
		{"Tops": {kind = "dots", a = Color(1.0, 0.82, 0.35), scale = 1.0}},
	],
	"mara": [
		{"Bottoms": {kind = "bands", a = Color(1.0, 1.0, 1.0), b = Color(1.0, 0.8, 0.25), o = 0.0, scale = 1.0}},
		{"Tops": {kind = "pinstripes", a = Color(1.0, 0.8, 0.3), scale = 1.0}},
		{"Tops": {kind = "camo", a = Color(0.5, 0.52, 0.56), b = Color(0.9, 0.9, 0.92), scale = 1.0}},
	],
	"bastion": [
		{"Tops": {kind = "plaid", a = Color(0.12, 0.05, 0.05), b = Color(0.95, 0.75, 0.3), scale = 1.0}},
		{"Tops": {kind = "bands", a = Color(0.85, 0.88, 0.9), b = Color(0.2, 0.2, 0.2), o = 0.05, scale = 0.6}},
		{"Bottoms": {kind = "camo", a = Color(0.26, 0.28, 0.33), b = Color(0.42, 0.45, 0.52), scale = 1.0}},
	],
	"lio": [
		{"Tops": {kind = "gradient", a = Color(1.0, 0.85, 0.2), o = 0.75}},
		{"Tops": {kind = "diagonal", a = Color(0.25, 0.45, 1.0), b = Color(1.0, 1.0, 1.0), scale = 0.8},
			"Bottoms": {kind = "dots", a = Color(1.0, 0.85, 0.2), scale = 1.0}},
		{},
	],
	"tao": [
		{"Tops": {kind = "scales", a = Color(0.95, 0.72, 0.25), b = Color(0.6, 0.08, 0.06), scale = 1.0}},
		{"Tops": {kind = "scales", a = Color(0.08, 0.3, 0.2), b = Color(0.25, 0.75, 0.5), scale = 1.0}},
		{"Tops": {kind = "gradient", a = Color(0.85, 0.85, 0.85), o = 0.68}},
	],
	"kael": [
		{"Bottoms": {kind = "pinstripes", a = Color(1.0, 1.0, 1.0), scale = 0.6}},
		{"Bottoms": {kind = "scales", a = Color(0.65, 0.42, 0.08), b = Color(1.0, 0.85, 0.35), scale = 1.0}},
		{"Tops": {kind = "camo", a = Color(0.95, 0.5, 0.08), b = Color(0.7, 0.32, 0.05), scale = 1.4}},
	],
}


static var LIST := {
	"vex": {file = SEED, costumes = [
		{name = "Prototype", tint = {"huku": {c = Color(0.95, 0.97, 1.0), sat = 1.0, bright = 0.78}}, acc = [["visor", Color(0.18, 0.9, 1.0)]]},
		{name = "Crimson Unit", tint = {"hair": {c = Color(0.9, 0.25, 0.3), sat = 0.0, bright = 1.0}, "huku": {c = Color(0.85, 0.38, 0.4), sat = 0.0, bright = 0.75}, "green_emit": Color(1.0, 0.3, 0.3)},
			acc = [["visor", Color(1.0, 0.25, 0.3)], ["shoulders", Color(0.25, 0.08, 0.1)]]},
		{name = "Stealth", tint = {"huku": {c = Color(0.35, 0.37, 0.42), sat = 0.0, bright = 0.6}, "hair": {c = Color(0.85, 0.85, 0.9), sat = 0.0, bright = 1.2}},
			acc = [["visor", Color(0.6, 1.0, 0.4)], ["kneepads", Color(0.12, 0.13, 0.15)]]},
	]},
	"sora": {file = GIRL, costumes = [
		{name = "Dobok", tint = {
			"Tops": {c = Color(0.92, 0.93, 0.96), sat = 0.0, bright = 0.74}, "Bottoms": Color(0.3, 0.33, 0.75),
			"Hair": {c = Color(0.22, 0.22, 0.28), sat = 0.2, bright = 0.55}, "Shoes": {c = Color(0.92, 0.92, 0.94), sat = 0.0, bright = 0.95}}.merged(skin(Color(0.86, 0.72, 0.64))),
			acc = [["headband", Color(0.45, 0.95, 0.6)], ["belt", Color(0.08, 0.08, 0.1)]]},
		{name = "Street", tint = {
			"Tops": {c = Color(0.55, 0.57, 0.62), sat = 0.0, bright = 0.75}, "Bottoms": Color(0.35, 0.45, 0.7),
			"Hair": {c = Color(0.55, 0.35, 0.25), sat = 0.6, bright = 0.7}, "Shoes": Color(1.0, 0.4, 0.4)}.merged(skin(Color(0.86, 0.72, 0.64))),
			acc = [["wraps", Color(0.95, 0.95, 0.95)]]},
		{name = "Champion", tint = {
			"Tops": Color(1.0, 0.3, 0.3), "Bottoms": {c = Color(0.25, 0.25, 0.28), sat = 0.0, bright = 0.5},
			"Hair": {c = Color(0.22, 0.22, 0.28), sat = 0.2, bright = 0.55}}.merged(skin(Color(0.86, 0.72, 0.64))),
			acc = [["headband", Color(1.0, 0.25, 0.25)], ["belt", Color(1.0, 0.8, 0.25)]]},
	]},
	"ember": {file = GIRL, costumes = [
		{name = "Luchadora", tint = {
			"Tops": Color(0.7, 0.3, 1.0), "Bottoms": Color(0.55, 0.22, 0.85),
			"Hair": {c = Color(1.0, 0.42, 0.25), sat = 1.6, bright = 1.3}, "Shoes": Color(1.0, 0.82, 0.3)}.merged(skin(Color(0.8, 0.62, 0.5))),
			acc = [["belt", Color(1.0, 0.75, 0.2)], ["wraps", Color(1.0, 0.55, 0.15)], ["kneepads", Color(0.55, 0.2, 0.85)]]},
		{name = "Inferno", tint = {
			"Tops": Color(1.0, 0.3, 0.18), "Bottoms": {c = Color(0.2, 0.2, 0.22), sat = 0.0, bright = 0.45},
			"Hair": {c = Color(1.0, 0.85, 0.35), sat = 1.2, bright = 1.2}, "Shoes": {c = Color(0.2, 0.2, 0.2), sat = 0.0, bright = 0.4}}.merged(skin(Color(0.8, 0.62, 0.5))),
			acc = [["belt", Color(0.15, 0.15, 0.15)], ["wraps", Color(1.0, 0.35, 0.15)], ["kneepads", Color(1.0, 0.35, 0.15)]]},
		{name = "Gala", tint = {
			"Tops": {c = Color(0.95, 0.95, 1.0), sat = 0.0, bright = 0.72}, "Bottoms": {c = Color(0.95, 0.95, 1.0), sat = 0.0, bright = 0.85},
			"Hair": {c = Color(1.0, 0.42, 0.25), sat = 1.6, bright = 1.3}, "Shoes": Color(1.0, 0.82, 0.3)}.merged(skin(Color(0.8, 0.62, 0.5))),
			acc = [["belt", Color(1.0, 0.8, 0.3)], ["sash", Color(1.0, 0.8, 0.3)]]},
	]},
	"mara": {file = GIRL, costumes = [
		{name = "Title Fight", tint = {
			"Tops": Color(1.0, 0.22, 0.28), "Bottoms": Color(1.0, 0.25, 0.25),
			"Hair": {c = Color(0.35, 0.3, 0.3), sat = 0.5, bright = 0.55}}.merged(skin(Color(0.6, 0.42, 0.32))),
			acc = [["gloves", Color(0.9, 0.12, 0.15)], ["belt", Color(1.0, 0.8, 0.25)]]},
		{name = "Gold Belt", tint = {
			"Tops": {c = Color(0.25, 0.25, 0.28), sat = 0.0, bright = 0.45}, "Bottoms": Color(1.0, 0.8, 0.3),
			"Hair": {c = Color(0.35, 0.3, 0.3), sat = 0.5, bright = 0.55}}.merged(skin(Color(0.6, 0.42, 0.32))),
			acc = [["gloves", Color(1.0, 0.78, 0.2)], ["belt", Color(1.0, 0.85, 0.3)]]},
		{name = "Training", tint = {
			"Tops": {c = Color(0.7, 0.72, 0.76), sat = 0.0, bright = 0.8}, "Bottoms": Color(0.3, 0.4, 0.8),
			"Hair": {c = Color(0.35, 0.3, 0.3), sat = 0.5, bright = 0.55}}.merged(skin(Color(0.6, 0.42, 0.32))),
			acc = [["gloves", Color(0.2, 0.4, 0.95)], ["headband", Color(0.95, 0.95, 0.95)]]},
	]},
	"bastion": {file = MALE, costumes = [
		{name = "Dock Brawler", tint = {
			"Tops": Color(0.75, 0.16, 0.16), "Tie": "hide",
			"Bottoms": {c = Color(0.55, 0.6, 0.7), sat = 0.2, bright = 0.8}, "Shoes": Color(0.45, 0.3, 0.2),
			"Hair": {c = Color(0.3, 0.27, 0.25), sat = 0.4, bright = 0.45}}.merged(skin(Color(0.62, 0.45, 0.34))),
			acc = [["wraps", Color(0.12, 0.12, 0.12)], ["belt", Color(1.0, 0.45, 0.15)]]},
		{name = "Hi-Vis", tint = {
			"Tops": Color(1.0, 0.6, 0.12), "Tie": "hide",
			"Bottoms": Color(0.25, 0.3, 0.45), "Shoes": Color(0.3, 0.22, 0.15),
			"Hair": {c = Color(0.3, 0.27, 0.25), sat = 0.4, bright = 0.45}}.merged(skin(Color(0.62, 0.45, 0.34))),
			acc = [["wraps", Color(0.9, 0.9, 0.9)], ["kneepads", Color(0.15, 0.15, 0.15)]]},
		{name = "Night Shift", tint = {
			"Tops": Color(0.2, 0.28, 0.5), "Tie": "hide",
			"Bottoms": {c = Color(0.2, 0.2, 0.22), sat = 0.0, bright = 0.5}, "Shoes": Color(0.2, 0.15, 0.12),
			"Hair": {c = Color(0.3, 0.27, 0.25), sat = 0.4, bright = 0.45}}.merged(skin(Color(0.62, 0.45, 0.34))),
			acc = [["wraps", Color(0.15, 0.35, 0.8)], ["shoulders", Color(0.12, 0.14, 0.2)]]},
	]},
	"lio": {file = MALE, costumes = [
		{name = "Roda", tint = {
			"Tops": Color(0.35, 0.85, 0.5), "Tie": "hide",
			"Bottoms": {c = Color(1, 1, 1), sat = 0.0, bright = 1.0}, "Shoes": {c = Color(0.9, 0.9, 0.9), sat = 0.0, bright = 0.95},
			"Hair": {c = Color(0.55, 0.4, 0.28), sat = 0.8, bright = 0.6}}.merged(skin(Color(0.8, 0.6, 0.45))),
			acc = [["sash", Color(0.25, 0.85, 0.45)]]},
		{name = "Carnival", tint = {
			"Tops": Color(1.0, 0.85, 0.2), "Tie": "hide",
			"Bottoms": Color(0.25, 0.45, 1.0), "Shoes": Color(1.0, 0.85, 0.2),
			"Hair": {c = Color(0.55, 0.4, 0.28), sat = 0.8, bright = 0.6}}.merged(skin(Color(0.8, 0.6, 0.45))),
			acc = [["sash", Color(1.0, 0.85, 0.2)], ["headband", Color(0.25, 0.45, 1.0)]]},
		{name = "Mestre", tint = {
			"Tops": {c = Color(1, 1, 1), sat = 0.0, bright = 0.95}, "Tie": "hide",
			"Bottoms": {c = Color(1, 1, 1), sat = 0.0, bright = 1.0}, "Shoes": {c = Color(1, 1, 1), sat = 0.0, bright = 0.95},
			"Hair": {c = Color(0.8, 0.8, 0.82), sat = 0.0, bright = 1.0}}.merged(skin(Color(0.7, 0.52, 0.38))),
			acc = [["sash", Color(0.75, 0.35, 0.95)], ["armbands", Color(0.75, 0.35, 0.95)]]},
	]},
	"tao": {file = MALE, costumes = [
		{name = "Iron Monk", tint = {
			"Tops": Color(0.72, 0.12, 0.1), "Tie": "hide",
			"Bottoms": {c = Color(0.3, 0.3, 0.32), sat = 0.0, bright = 0.45}, "Shoes": {c = Color(0.3, 0.3, 0.3), sat = 0.0, bright = 0.35},
			"Hair": {c = Color(1, 1, 1.04), sat = 0.0, bright = 1.3}}.merged(skin(Color(0.95, 0.8, 0.68))),
			acc = [["sash", Color(0.95, 0.75, 0.3)], ["wraps", Color(0.95, 0.75, 0.3)]]},
		{name = "Jade", tint = {
			"Tops": Color(0.2, 0.65, 0.45), "Tie": "hide",
			"Bottoms": {c = Color(0.3, 0.3, 0.32), sat = 0.0, bright = 0.4}, "Shoes": {c = Color(0.3, 0.3, 0.3), sat = 0.0, bright = 0.35},
			"Hair": {c = Color(1, 1, 1.04), sat = 0.0, bright = 1.3}}.merged(skin(Color(0.95, 0.8, 0.68))),
			acc = [["sash", Color(0.1, 0.1, 0.1)], ["armbands", Color(0.95, 0.75, 0.3)]]},
		{name = "Ink", tint = {
			"Tops": {c = Color(0.2, 0.2, 0.22), sat = 0.0, bright = 0.35}, "Tie": "hide",
			"Bottoms": {c = Color(1, 1, 1), sat = 0.0, bright = 0.9}, "Shoes": {c = Color(0.3, 0.3, 0.3), sat = 0.0, bright = 0.35},
			"Hair": {c = Color(1, 1, 1.04), sat = 0.0, bright = 1.3}}.merged(skin(Color(0.95, 0.8, 0.68))),
			acc = [["sash", Color(0.85, 0.15, 0.15)], ["wraps", Color(0.9, 0.9, 0.9)]]},
	]},
	"kael": {file = MALE, costumes = [
		{name = "Stadium", tint = {
			"Tops": Color(0.95, 0.25, 0.3), "Tie": "hide",
			"Bottoms": Color(0.25, 0.4, 1.0), "Shoes": {c = Color(1, 1, 1), sat = 0.0, bright = 0.95},
			"Hair": {c = Color(0.3, 0.28, 0.28), sat = 0.3, bright = 0.4}}.merged(skin(Color(0.82, 0.62, 0.46))),
			acc = [["headband", Color(0.9, 0.15, 0.2)], ["wraps", Color(0.95, 0.95, 0.95)], ["armbands", Color(0.9, 0.15, 0.2)]]},
		{name = "Gold Shorts", tint = {
			"Tops": {c = Color(0.25, 0.25, 0.28), sat = 0.0, bright = 0.45}, "Tie": "hide",
			"Bottoms": Color(1.0, 0.78, 0.25), "Shoes": {c = Color(1, 1, 1), sat = 0.0, bright = 0.95},
			"Hair": {c = Color(0.3, 0.28, 0.28), sat = 0.3, bright = 0.4}}.merged(skin(Color(0.82, 0.62, 0.46))),
			acc = [["headband", Color(1.0, 0.8, 0.3)], ["wraps", Color(1.0, 0.8, 0.3)], ["armbands", Color(0.15, 0.15, 0.15)]]},
		{name = "Black Tiger", tint = {
			"Tops": {c = Color(0.2, 0.2, 0.22), sat = 0.0, bright = 0.35}, "Tie": "hide",
			"Bottoms": {c = Color(0.2, 0.2, 0.22), sat = 0.0, bright = 0.35}, "Shoes": {c = Color(0.3, 0.3, 0.3), sat = 0.0, bright = 0.4},
			"Hair": {c = Color(0.3, 0.28, 0.28), sat = 0.3, bright = 0.4}}.merged(skin(Color(0.82, 0.62, 0.46))),
			acc = [["headband", Color(1.0, 0.55, 0.1)], ["wraps", Color(1.0, 0.55, 0.1)], ["kneepads", Color(0.15, 0.15, 0.15)]]},
	]},
}
