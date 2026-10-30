class_name Models
## Which fighters use a VRM anime model. Fighters not listed fall back to the procedural ToonRig.
## Drop a VRoid export at characters/<id>/model.vrm and add it here to give a fighter its own model.
## Sample bases (VRM Public License 1.0, see CREDITS.md):
##   seed_san.vrm      "Seed-san" by VirtualCast, Inc. (credit required)
##   twist_sample.vrm  VRM1_Constraint_Twist_Sample by pixiv Inc.

## A fighter's own model at characters/<id>/model.vrm always wins over the list below.
static func spec(id: String) -> Dictionary:
	var own := "res://characters/%s/model.vrm" % id
	if FileAccess.file_exists(own):
		return {file = own}
	return LIST.get(id, {})


const SEED := "res://characters/_base/seed_san.vrm"
const GIRL := "res://characters/_base/twist_sample.vrm"

const LIST := {
	"vex": {file = SEED},
	"sora": {file = GIRL, tint = {"Tops": Color(1, 1, 1), "Bottoms": Color(0.35, 0.38, 0.8), "Hair": Color(0.35, 0.33, 0.4)}},
	"ember": {file = GIRL, tint = {"Tops": Color(0.75, 0.35, 1.0), "Bottoms": Color(0.7, 0.3, 0.95), "Hair": Color(1.0, 0.45, 0.35), "Shoes": Color(1.0, 0.85, 0.4)}},
	"mara": {file = GIRL, tint = {"Tops": Color(1.0, 0.25, 0.3), "Bottoms": Color(1.0, 0.3, 0.3), "Hair": Color(0.25, 0.2, 0.2), "Body": Color(0.62, 0.45, 0.36), "Face_00_SKIN": Color(0.62, 0.45, 0.36)}},
}
