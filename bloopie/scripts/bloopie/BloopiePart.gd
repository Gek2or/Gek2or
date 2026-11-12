extends Node2D
## One visual layer of Bloopie. Attach to any Node2D-derived node (Sprite2D,
## AnimatedSprite2D, ...) under BloopieActor; while the node has no texture or
## frames assigned, the layer is drawn procedurally by BloopieArt.

@export_enum("shadow", "tufts", "body", "curl", "eyes", "blush", "mouth", "paws", "hat", "decor", "ball", "capsule", "face_ink") var part := "body"

## Shared render state owned by BloopieActor.
var state := {}


func _draw() -> void:
	if state.is_empty() or _has_painted_art():
		return
	if part == "capsule" and state.get("capsule_painted", false):
		return
	match part:
		"shadow":
			BloopieArt.draw_shadow(self, state)
		"tufts":
			BloopieArt.draw_tufts(self, state)
		"body":
			BloopieArt.draw_body(self, state)
		"curl":
			BloopieArt.draw_curl(self, state)
		"eyes":
			BloopieArt.draw_eyes(self, state)
		"blush":
			BloopieArt.draw_blush(self, state)
		"mouth":
			BloopieArt.draw_mouth(self, state)
		"paws":
			BloopieArt.draw_paws(self, state)
		"hat":
			BloopieArt.draw_hat(self, state)
		"decor":
			BloopieArt.draw_decor(self, state)
		"ball":
			BloopieArt.draw_ball(self, state)
		"capsule":
			BloopieArt.draw_capsule(self, state)
		"face_ink":
			BloopieArt.draw_face_ink(self, state)


func _has_painted_art() -> bool:
	var node: Node2D = self
	if node is Sprite2D:
		return (node as Sprite2D).texture != null
	if node is AnimatedSprite2D:
		return (node as AnimatedSprite2D).sprite_frames != null
	return false
