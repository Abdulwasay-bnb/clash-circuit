class_name Models
## Which VRM anime model each fighter uses. A fighter's own model at characters/<id>/model.vrm
## always wins (see VROID_GUIDE.md). Otherwise a shared base is restyled per fighter.
##
## Bases (credits in CREDITS.md):
##   seed_san.vrm      "Seed-san" by VirtualCast, Inc. (VRM Public License 1.0, credit required)
##   twist_sample.vrm  VRM1_Constraint_Twist_Sample by pixiv Inc. (VRM Public License 1.0)
##   base_male.vrm     VRoid "Base_Male" by the VRoid Project (CC0)
##
## Tints match material names. Value = Color multiplier, {c, sat, bright} to recolor, or "hide":
## sat 0 = greyscale, bright > 1 lightens (e.g. silver hair).

static func spec(id: String) -> Dictionary:
	var own := "res://characters/%s/model.vrm" % id
	if FileAccess.file_exists(own):
		return {file = own}
	return LIST.get(id, {})


const SEED := "res://characters/_base/seed_san.vrm"
const GIRL := "res://characters/_base/twist_sample.vrm"
const MALE := "res://characters/_base/base_male.vrm"

const LIST := {
	"vex": {file = SEED},
	# Taekwondo: white dobok top, navy pants, jet-black hair
	"sora": {file = GIRL, tint = {
		"Tops": {c = Color(1, 1, 1), sat = 0.0, bright = 1.25},
		"Bottoms": Color(0.3, 0.33, 0.75),
		"Hair": {c = Color(0.55, 0.55, 0.62), sat = 0.3, bright = 0.7},
		"Shoes": {c = Color(1, 1, 1), sat = 0.0, bright = 1.2}}},
	# Luchadora: royal purple, flame-orange hair, gold boots
	"ember": {file = GIRL, tint = {
		"Tops": Color(0.7, 0.3, 1.0),
		"Bottoms": Color(0.55, 0.22, 0.85),
		"Hair": {c = Color(1.0, 0.42, 0.25), sat = 1.6, bright = 1.3},
		"Shoes": Color(1.0, 0.82, 0.3)}},
	# Boxer: red kit, deep brown skin, black braids
	"mara": {file = GIRL, tint = {
		"Tops": Color(1.0, 0.22, 0.28),
		"Bottoms": Color(1.0, 0.25, 0.25),
		"Hair": {c = Color(0.35, 0.3, 0.3), sat = 0.5, bright = 0.55},
		"Body_00_SKIN": Color(0.6, 0.42, 0.32), "Face_00_SKIN": Color(0.6, 0.42, 0.32)}},
	# Dock brawler: crimson tank, steel-grey work pants, dark skin, near-black hair
	"bastion": {file = MALE, tint = {
		"Tops": Color(0.75, 0.16, 0.16), "Tie": "hide",
		"Bottoms": {c = Color(0.55, 0.6, 0.7), sat = 0.2, bright = 0.8},
		"Shoes": Color(0.45, 0.3, 0.2),
		"Hair": {c = Color(0.3, 0.27, 0.25), sat = 0.4, bright = 0.45},
		"Body_00_SKIN": Color(0.62, 0.45, 0.34), "Face_00_SKIN": Color(0.62, 0.45, 0.34)}},
	# Capoeira: green tank, white abada pants, tan skin, dark-brown hair
	"lio": {file = MALE, tint = {
		"Tops": Color(0.35, 0.85, 0.5), "Tie": "hide",
		"Bottoms": {c = Color(1, 1, 1), sat = 0.0, bright = 1.3},
		"Shoes": {c = Color(0.9, 0.9, 0.9), sat = 0.0, bright = 1.1},
		"Hair": {c = Color(0.55, 0.4, 0.28), sat = 0.8, bright = 0.6},
		"Body_00_SKIN": Color(0.8, 0.6, 0.45), "Face_00_SKIN": Color(0.8, 0.6, 0.45)}},
	# Kung-fu master: crimson jacket with gold, black trousers, silver hair
	"tao": {file = MALE, tint = {
		"Tops": Color(0.72, 0.12, 0.1), "Tie": "hide",
		"Bottoms": {c = Color(0.3, 0.3, 0.32), sat = 0.0, bright = 0.45},
		"Shoes": {c = Color(0.3, 0.3, 0.3), sat = 0.0, bright = 0.35},
		"Hair": {c = Color(1, 1, 1.04), sat = 0.0, bright = 1.3},
		"Body_00_SKIN": Color(0.95, 0.8, 0.68), "Face_00_SKIN": Color(0.95, 0.8, 0.68)}},
	# Muay Thai: red rash guard, royal-blue Thai shorts, bronze skin, black hair
	"kael": {file = MALE, tint = {
		"Tops": Color(0.95, 0.25, 0.3), "Tie": "hide",
		"Bottoms": Color(0.25, 0.4, 1.0),
		"Shoes": {c = Color(1, 1, 1), sat = 0.0, bright = 1.2},
		"Hair": {c = Color(0.3, 0.28, 0.28), sat = 0.3, bright = 0.4},
		"Body_00_SKIN": Color(0.82, 0.62, 0.46), "Face_00_SKIN": Color(0.82, 0.62, 0.46)}},
}
