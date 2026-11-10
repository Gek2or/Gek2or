class_name BloopieArt
extends RefCounted
## Procedural art for Bloopie. Every function draws one layer of the character
## into the given CanvasItem, in local coordinates where (0, 0) is the body centre.
## The layers map 1:1 to the nodes under BloopieActor/VisualRoot, so each of them
## can later be replaced by a hand-painted texture without touching gameplay code.

const INK := Color("#232946")
const RIM_LIGHT := Color("#FFD175")
const TOOTH := Color("#FFFDF9")
const BLUSH := Color("#FF8FA3")
const BLUSH_HATCH := Color("#E05772")
const IRIS_TOP := Color("#1E2542")
const IRIS_BOTTOM := Color("#8AC7F7")
const STAR := Color("#FFE9A8")

const BODY_RX := 205.0
const BODY_RY := 190.0 # 1.08 : 1.0
const OUTLINE := 7.0
const EYE_X := 84.0
const EYE_Y := -22.0

## Canon: exactly two upper front teeth, 25% smaller than a classic cartoon pair
## (40x26 -> 30x19.5), fused into one block with a single centre line.
const TEETH_WIDTH := 30.0
const TEETH_HEIGHT := 19.5

static var _glow_texture: GradientTexture2D

const CLOSED_EYES: Array[String] = ["sleepy", "laugh"]
const OPEN_MOUTH: Array[String] = ["excited", "laugh"]


# --- Geometry helpers ---------------------------------------------------------------

static func ellipse(center: Vector2, rx: float, ry: float, steps: int = 40, rotation: float = 0.0) -> PackedVector2Array:
	return arc(center, rx, ry, 0.0, TAU * (1.0 - 1.0 / steps), steps, rotation)


static func arc(center: Vector2, rx: float, ry: float, from: float, to: float, steps: int = 24, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := lerpf(from, to, float(i) / float(steps - 1))
		points.push_back(center + Vector2(cos(angle) * rx, sin(angle) * ry).rotated(rotation))
	return points


static func outline(ci: CanvasItem, points: PackedVector2Array, width: float = OUTLINE, color: Color = INK) -> void:
	var closed := points.duplicate()
	closed.push_back(points[0])
	ci.draw_polyline(closed, color, width, true)


static func blob(ci: CanvasItem, points: PackedVector2Array, fill: Color, width: float = OUTLINE) -> void:
	ci.draw_colored_polygon(points, fill)
	outline(ci, points, width)


static func star4(ci: CanvasItem, center: Vector2, radius: float, color: Color, rotation: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var r := radius if i % 2 == 0 else radius * 0.32
		points.push_back(center + Vector2.UP.rotated(rotation + i * TAU / 8.0) * r)
	ci.draw_colored_polygon(points, color)


static func heart(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 28:
		var t := i * TAU / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.push_back(center + Vector2(x, y) * size / 32.0)
	return points


## Soft radial glow (white texture tinted by `color`), shared by every layer.
static func glow(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = 128
		_glow_texture.height = 128
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
	ci.draw_texture_rect(_glow_texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func text(ci: CanvasItem, position: Vector2, value: String, size: int, fill: Color) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, INK)
	ci.draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


# --- Body layers --------------------------------------------------------------------

static func draw_shadow(ci: CanvasItem, _s: Dictionary) -> void:
	glow(ci, Vector2(0, BODY_RY + 6.0), 230.0, Color(INK, 0.35))
	ci.draw_colored_polygon(ellipse(Vector2(0, BODY_RY + 6.0), 196.0, 30.0, 32), Color(INK, 0.3))


static func draw_tufts(ci: CanvasItem, s: Dictionary) -> void:
	var base: Color = s.draw_palette.base
	var shade: Color = s.draw_palette.shade
	# x = how far the lobe sticks out, y = height on the body, z = lobe radius.
	var tufts := [Vector3(18, -34, 30), Vector3(36, 6, 35), Vector3(16, 44, 29)]
	if s.stage == 1:
		tufts = [Vector3(18, -16, 29), Vector3(24, 26, 30)]
	for side: float in [-1.0, 1.0]:
		var anchor := Vector2(side * 190.0, 34.0)
		for tuft: Vector3 in tufts:
			ci.draw_circle(anchor + Vector2(tuft.x * side, tuft.y), tuft.z + OUTLINE * 0.5, INK)
		for tuft: Vector3 in tufts:
			var center := anchor + Vector2(tuft.x * side, tuft.y)
			ci.draw_circle(center, tuft.z - OUTLINE * 0.5, shade.lerp(base, 0.35))
			ci.draw_circle(center + Vector2(-3, -5), tuft.z - OUTLINE * 0.5 - 5.0, base)
			ci.draw_circle(center + Vector2(-7, -10), tuft.z * 0.36, base.lightened(0.22))


static func draw_body(ci: CanvasItem, s: Dictionary) -> void:
	var base: Color = s.draw_palette.base
	var shade: Color = s.draw_palette.shade
	var silhouette := ellipse(Vector2.ZERO, BODY_RX, BODY_RY, 64)
	# Soft plush volume: stacked tones from the shadow rim up to the lit crown.
	ci.draw_colored_polygon(silhouette, shade)
	ci.draw_colored_polygon(ellipse(Vector2(-4, -8), 197.0, 180.0, 64), shade.lerp(base, 0.5))
	ci.draw_colored_polygon(ellipse(Vector2(-9, -16), 187.0, 168.0, 64), base)
	ci.draw_colored_polygon(ellipse(Vector2(-26, -40), 150.0, 126.0, 56), base.lightened(0.07))
	ci.draw_colored_polygon(ellipse(Vector2(-44, -64), 104.0, 82.0, 48), base.lightened(0.14))
	ci.draw_colored_polygon(ellipse(Vector2(0, 104), 112.0, 62.0, 40), Color(base.lightened(0.2), 0.45))
	glow(ci, Vector2(-70, -92), 120.0, Color(1, 1, 1, 0.5))
	ci.draw_colored_polygon(ellipse(Vector2(-84, -110), 54.0, 26.0, 28, -0.55), Color(1, 1, 1, 0.55))
	ci.draw_circle(Vector2(-128, -70), 9.0, Color(1, 1, 1, 0.5))
	if s.theme_id == "night":
		var belly_stars := [Vector3(-60, 118, 13), Vector3(4, 136, 9), Vector3(58, 112, 11), Vector3(-14, 100, 7), Vector3(96, 78, 7)]
		for star: Vector3 in belly_stars:
			star4(ci, Vector2(star.x, star.y), star.z, STAR)
	# Warm rim light from the fairy lights along the upper-right edge.
	ci.draw_polyline(arc(Vector2.ZERO, BODY_RX - 9.0, BODY_RY - 9.0, -PI * 0.44, PI * 0.1, 28), Color(RIM_LIGHT, 0.85), 7.0, true)
	outline(ci, silhouette)


static func draw_curl(ci: CanvasItem, s: Dictionary) -> void:
	var base: Color = s.draw_palette.base
	var shade: Color = s.draw_palette.shade
	var size: float = [0.88, 1.0, 1.14][s.stage - 1]
	var center := Vector2(14, -70) * size
	var outer_radius := 62.0 * size
	var inner_radius := 9.0 * size
	var start_angle := PI * 0.6
	var spiral_steps := 96
	# x, y = position, z = tube radius. A fat stem, then a 1.5-turn spiral whose
	# coils touch each other like a plush snail roll.
	var beads: Array[Vector3] = []
	var start := center + Vector2.from_angle(start_angle) * outer_radius
	for i in 10:
		var t := i / 10.0
		var position := Vector2(0, 30).lerp(start, t)
		beads.push_back(Vector3(position.x, position.y, lerpf(34.0, 25.0, t) * size))
	for i in spiral_steps + 1:
		var t := float(i) / spiral_steps
		var angle := start_angle + t * 1.5 * TAU
		var position := center + Vector2.from_angle(angle) * lerpf(outer_radius, inner_radius, t)
		beads.push_back(Vector3(position.x, position.y, lerpf(25.0, 10.0, t) * size))
	for bead in beads:
		ci.draw_circle(Vector2(bead.x, bead.y), bead.z + OUTLINE * 0.55, INK)
	for bead in beads:
		ci.draw_circle(Vector2(bead.x, bead.y), bead.z, shade.lerp(base, 0.55))
	for bead in beads:
		ci.draw_circle(Vector2(bead.x - bead.z * 0.12, bead.y - bead.z * 0.16), bead.z * 0.82, base)
	for bead in beads:
		ci.draw_circle(Vector2(bead.x - bead.z * 0.3, bead.y - bead.z * 0.34), bead.z * 0.34, base.lightened(0.3))
	# The ink crease between the coils: the outer edge of the inner turns.
	var crease := PackedVector2Array()
	for i in spiral_steps + 1:
		var t := float(i) / spiral_steps
		if t < 0.36:
			continue
		var angle := start_angle + t * 1.5 * TAU
		var radius := lerpf(outer_radius, inner_radius, t) + lerpf(25.0, 10.0, t) * size
		crease.push_back(center + Vector2.from_angle(angle) * radius)
	ci.draw_polyline(crease, INK, 5.5, true)
	# Seamless join with the head: repaint the body colour over the base outline.
	ci.draw_colored_polygon(ellipse(Vector2(0, 36), 36.0 * size, 20.0, 20), base)
	if s.theme_id == "forest":
		var leaf_at := center + Vector2(outer_radius * 0.9, -outer_radius * 1.25)
		blob(ci, ellipse(leaf_at, 30.0, 14.0, 16, -0.6), Color("#3F9A4E"), 4.5)
		ci.draw_line(leaf_at + Vector2(-20, 14), leaf_at + Vector2(20, -14), Color("#1F5A2C"), 3.5, true)


static func draw_paws(ci: CanvasItem, s: Dictionary) -> void:
	var base: Color = s.draw_palette.base
	var shade: Color = s.draw_palette.shade
	for side: float in [-1.0, 1.0]:
		var foot := ellipse(Vector2(side * 84.0, 166.0), 62.0, 42.0, 32, side * -0.2)
		ci.draw_colored_polygon(foot, shade)
		ci.draw_colored_polygon(ellipse(Vector2(side * 82.0, 160.0), 53.0, 33.0, 32, side * -0.2), shade.lerp(base, 0.45))
		ci.draw_colored_polygon(ellipse(Vector2(side * 78.0, 150.0), 34.0, 17.0, 24, side * -0.2), shade.lerp(base, 0.8))
		outline(ci, foot, 6.5)


# --- Face ------------------------------------------------------------------------------

static func draw_eyes(ci: CanvasItem, s: Dictionary) -> void:
	var expression: String = s.expression
	var closed: bool = s.blink > 0.5 or s.sleeping or CLOSED_EYES.has(expression)
	for side: float in [-1.0, 1.0]:
		var center := Vector2(side * EYE_X, EYE_Y)
		if expression == "love" and not s.sleeping:
			if s.blink > 0.5:
				_draw_closed_eye(ci, center, side, false)
			else:
				blob(ci, heart(center + Vector2(0, 4), 96.0), Color("#FF6F91"), 6.0)
				ci.draw_circle(center + Vector2(-16, -14), 8.0, Color(1, 1, 1, 0.9))
		elif closed:
			_draw_closed_eye(ci, center, side, expression == "laugh" and not s.sleeping)
		else:
			_draw_open_eye(ci, s, center, side)
		_draw_brow(ci, s, center, side)


static func _draw_closed_eye(ci: CanvasItem, center: Vector2, side: float, smiling: bool) -> void:
	var lid: PackedVector2Array
	if smiling:
		lid = arc(center + Vector2(0, 22), 46.0, 34.0, PI * 1.12, PI * 1.88, 18)
	else:
		lid = arc(center + Vector2(0, -2), 46.0, 26.0, PI * 0.1, PI * 0.9, 18)
	ci.draw_polyline(lid, INK, 9.0, true)
	var corner := lid[0] if side > 0.0 else lid[lid.size() - 1]
	for i in 2:
		var tip := corner + Vector2(side * (16.0 + i * 4.0), -6.0 + i * 14.0)
		ci.draw_line(corner, tip, INK, 5.0, true)


static func _draw_open_eye(ci: CanvasItem, s: Dictionary, center: Vector2, side: float) -> void:
	var expression: String = s.expression
	var rx := 54.0
	var ry := 68.0
	var iris_scale := 1.0
	var lid := 0.0
	var gaze := Vector2.ZERO
	match expression:
		"excited":
			rx = 53.0
			ry = 67.0
		"surprised":
			rx = 55.0
			ry = 57.0
			iris_scale = 0.72
		"sad":
			lid = 0.16
			gaze = Vector2(0, 5)
		"angry":
			lid = 0.24
		"proud":
			lid = 0.3
		"shy":
			lid = 0.18
			gaze = Vector2(11, 7)
		"curious":
			gaze = Vector2(5, -5)
		"confused":
			iris_scale = 0.9 if side < 0.0 else 1.0
	ci.draw_colored_polygon(ellipse(center, rx + 5.5, ry + 5.5, 40), INK)
	ci.draw_colored_polygon(ellipse(center, rx, ry, 40), Color.WHITE)

	var iris_rx := rx * 0.8 * iris_scale
	var iris_ry := ry * 0.84 * iris_scale
	var look: Vector2 = s.look
	var shift := look * 6.0 + gaze
	shift.x = clampf(shift.x, -(rx - iris_rx - 1.0), rx - iris_rx - 1.0)
	shift.y = clampf(shift.y, -(ry - iris_ry - 1.0), ry - iris_ry - 1.0)
	var iris_center := center + shift
	var iris := ellipse(iris_center, iris_rx, iris_ry, 36)
	var colors := PackedColorArray()
	for point in iris:
		var t := clampf((point.y - (iris_center.y - iris_ry)) / (iris_ry * 2.0), 0.0, 1.0)
		colors.push_back(IRIS_TOP.lerp(IRIS_BOTTOM, t * t))
	ci.draw_polygon(iris, colors)
	ci.draw_colored_polygon(ellipse(iris_center + Vector2(0, -iris_ry * 0.12), iris_rx * 0.52, iris_ry * 0.5, 24), Color("#141A33"))
	ci.draw_circle(iris_center + Vector2(-iris_rx * 0.36, -iris_ry * 0.42), iris_rx * 0.36, Color.WHITE)
	ci.draw_circle(iris_center + Vector2(iris_rx * 0.36, iris_ry * 0.4), iris_rx * 0.16, Color(1, 1, 1, 0.92))
	star4(ci, iris_center + Vector2(iris_rx * 0.34, -iris_ry * 0.08), iris_rx * 0.26, STAR)
	star4(ci, iris_center + Vector2(-iris_rx * 0.3, iris_ry * 0.42), iris_rx * 0.15, Color(1, 1, 1, 0.9))
	if expression == "excited":
		star4(ci, iris_center + Vector2(0, iris_ry * 0.1), iris_rx * 0.34, STAR, s.time * 1.5)

	if lid > 0.0:
		# Upper eyelid in body colour, closing the eye from the top by `lid` (0..1).
		var theta := asin(1.0 - 2.0 * lid)
		var cover := arc(center, rx + 6.5, ry + 6.5, PI + theta, TAU - theta, 20)
		ci.draw_colored_polygon(cover, s.palette.base)
		ci.draw_line(cover[0], cover[cover.size() - 1], INK, 8.0, true)
	# Thick upper lash line and 3 lashes on the outer corner.
	var lash_from := -PI * 0.08 if side > 0.0 else PI * 1.08
	var lash_to := -PI * 0.92 if side > 0.0 else PI * 1.92
	if lid == 0.0:
		ci.draw_polyline(arc(center, rx + 3.0, ry + 3.0, lash_from, lash_to, 20), INK, 9.0, true)
	for i in 3:
		var angle := -PI * (0.36 - i * 0.1)
		if side < 0.0:
			angle = PI - angle
		var direction := Vector2(cos(angle), sin(angle))
		var root := center + Vector2(direction.x * (rx + 4.0), direction.y * (ry + 4.0))
		if lid > 0.0:
			root.y = maxf(root.y, center.y - (ry + 6.5) * (1.0 - 2.0 * lid))
		var middle := root + direction * 12.0
		var tip := root + direction * 21.0 + Vector2(0, -7)
		ci.draw_polyline(PackedVector2Array([root, middle, tip]), INK, 5.5, true)


static func _draw_brow(ci: CanvasItem, s: Dictionary, center: Vector2, side: float) -> void:
	if s.sleeping:
		return
	var inner_dy := 0.0
	var outer_dy := 0.0
	var lift := 0.0
	var width := 5.5
	match s.expression:
		"sad":
			inner_dy = -16.0
			outer_dy = 8.0
			width = 7.0
		"angry":
			inner_dy = 22.0
			outer_dy = -8.0
			lift = 16.0
			width = 8.0
		"surprised":
			lift = -14.0
		"curious", "confused":
			lift = -18.0 if side > 0.0 else 4.0
			width = 7.0
		"proud":
			inner_dy = 4.0
			outer_dy = -4.0
			lift = 8.0
		"laugh", "excited":
			lift = -6.0
	var y := center.y - 64.0 - 26.0 + lift
	var inner := Vector2(center.x - side * 26.0, y + inner_dy)
	var outer := Vector2(center.x + side * 22.0, y + outer_dy)
	var middle := (inner + outer) * 0.5 + Vector2(0, -5)
	ci.draw_polyline(PackedVector2Array([inner, middle, outer]), INK, width, true)


static func draw_blush(ci: CanvasItem, s: Dictionary) -> void:
	var alpha := 0.72
	var grow := 1.0
	match s.expression:
		"shy":
			alpha = 1.0
			grow = 1.12
		"love":
			alpha = 0.92
		"angry":
			alpha = 0.9
			grow = 1.25
		"sad":
			alpha = 0.5
	for side: float in [-1.0, 1.0]:
		var center := Vector2(side * 146.0, 60.0)
		glow(ci, center, 74.0 * grow, Color(BLUSH, alpha * 0.75))
		ci.draw_colored_polygon(ellipse(center, 34.0 * grow, 19.0 * grow, 24), Color(BLUSH, alpha * 0.55))
		for i in range(-1, 2):
			var x := center.x + i * 13.0
			ci.draw_line(Vector2(x - 5, center.y + 8), Vector2(x + 5, center.y - 8), Color(BLUSH_HATCH, minf(1.0, alpha + 0.15)), 4.0, true)


static func draw_mouth(ci: CanvasItem, s: Dictionary) -> void:
	var expression: String = "sleepy" if s.sleeping else s.expression
	var talk: float = s.talk
	var center := Vector2(0, 66)
	var teeth_top := center + Vector2(0, 11)
	if talk > 0.12 or OPEN_MOUTH.has(expression):
		var openness := maxf(talk, 0.75 if OPEN_MOUTH.has(expression) else 0.0)
		var half_width := 46.0 if OPEN_MOUTH.has(expression) else 34.0
		var upper := arc(center + Vector2(0, -6), half_width, 12.0, PI * 0.96, PI * 0.04, 14)
		var lower := arc(center + Vector2(0, -4), half_width, 16.0 + 40.0 * openness, PI * 0.04, PI * 0.96, 18)
		var cavity := upper.duplicate()
		cavity.append_array(lower)
		blob(ci, cavity, Color("#4A2040"), 6.0)
		teeth_top = center + Vector2(0, 5)
	else:
		match expression:
			"sad":
				ci.draw_polyline(arc(center + Vector2(0, 30), 38.0, 20.0, PI * 1.16, PI * 1.84, 16), INK, 6.5, true)
				teeth_top = center + Vector2(0, 11)
			"angry":
				var line := PackedVector2Array([center + Vector2(-34, 14), center + Vector2(-12, 8), center + Vector2(12, 8), center + Vector2(34, 14)])
				ci.draw_polyline(line, INK, 6.5, true)
				teeth_top = center + Vector2(0, 9)
			"surprised", "confused":
				var o_center := center + (Vector2(0, 14) if expression == "surprised" else Vector2(10, 12))
				blob(ci, ellipse(o_center, 19.0, 21.0 if expression == "surprised" else 15.0, 24), Color("#4A2040"), 6.0)
				teeth_top = o_center + Vector2(0, -19.0 if expression == "surprised" else -13.0)
			"sleepy":
				ci.draw_polyline(arc(center + Vector2(0, -2), 30.0, 14.0, PI * 0.14, PI * 0.86, 14), INK, 6.5, true)
				teeth_top = center + Vector2(0, 11)
			_:
				ci.draw_polyline(arc(center + Vector2(0, -14), 58.0, 27.0, PI * 0.16, PI * 0.84, 20), INK, 6.5, true)
				teeth_top = center + Vector2(0, 12)
	draw_teeth(ci, teeth_top)


## The canonical tooth block: one rounded-bottom white rectangle hanging from the
## mouth line, split by exactly one thin ink line. `top_center` is the lip point.
static func draw_teeth(ci: CanvasItem, top_center: Vector2) -> void:
	var half := TEETH_WIDTH * 0.5
	var corner := 6.0
	var block := PackedVector2Array([top_center + Vector2(-half, 0), top_center + Vector2(half, 0)])
	block.append_array(arc(top_center + Vector2(half - corner, TEETH_HEIGHT - corner), corner, corner, 0.0, PI * 0.5, 6))
	block.append_array(arc(top_center + Vector2(-half + corner, TEETH_HEIGHT - corner), corner, corner, PI * 0.5, PI, 6))
	ci.draw_colored_polygon(block, TOOTH)
	outline(ci, block, 3.5)
	ci.draw_line(top_center + Vector2(0, 1), top_center + Vector2(0, TEETH_HEIGHT - 1.0), INK, 2.5, true)


# --- Hats ----------------------------------------------------------------------------------

static func draw_hat(ci: CanvasItem, s: Dictionary) -> void:
	match s.hat:
		"cosy":
			_draw_hood(ci, Color("#EBD0AA"), Color("#C9A57C"), true)
		"cat":
			var fur := Color("#F5A04C")
			for side: float in [-1.0, 1.0]:
				var ear := PackedVector2Array([Vector2(side * 62, -180), Vector2(side * 128, -262), Vector2(side * 168, -128)])
				blob(ci, ear, fur)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 92, -178), Vector2(side * 126, -228), Vector2(side * 146, -150)]), Color("#FFC7B8"))
			_draw_hood(ci, fur, Color("#D97C2B"), false)
		"frog":
			var skin := Color("#7BC678")
			for side: float in [-1.0, 1.0]:
				var eye_at := Vector2(side * 92, -196)
				ci.draw_circle(eye_at, 40.0, INK)
				ci.draw_circle(eye_at, 34.0, skin)
				ci.draw_circle(eye_at + Vector2(0, -4), 22.0, Color.WHITE)
				ci.draw_circle(eye_at + Vector2(side * -3, -2), 11.0, INK)
			_draw_hood(ci, skin, Color("#46894A"), false)
		"wizard":
			var cloth := Color("#7A52C7")
			var cone := PackedVector2Array([Vector2(-128, -150), Vector2(-62, -268), Vector2(-4, -352), Vector2(64, -404), Vector2(60, -330), Vector2(96, -246), Vector2(128, -150)])
			blob(ci, cone, cloth)
			ci.draw_polyline(PackedVector2Array([Vector2(-118, -168), Vector2(0, -150), Vector2(118, -168)]), Color("#FFD175"), 14.0, true)
			star4(ci, Vector2(8, -246), 26.0, STAR, 0.2)
			star4(ci, Vector2(-42, -206), 11.0, STAR)
			var brim := ellipse(Vector2(0, -144), 206.0, 42.0, 40)
			blob(ci, brim, Color("#B695F8"))


static func _draw_hood(ci: CanvasItem, fill: Color, shade: Color, knitted: bool) -> void:
	var outer := arc(Vector2(0, 0), BODY_RX + 9.0, BODY_RY + 10.0, PI * 1.02, PI * 1.98, 40)
	var inner := arc(Vector2(0, 26), 186.0, 152.0, PI * 1.98, PI * 1.02, 40)
	var hood := outer.duplicate()
	hood.append_array(inner)
	ci.draw_colored_polygon(hood, fill)
	if knitted:
		for i in 17:
			var angle := PI * (1.06 + i * 0.055)
			var a := Vector2(cos(angle) * (BODY_RX + 4.0), sin(angle) * (BODY_RY + 5.0))
			var b := Vector2(cos(angle) * 190.0, 26.0 + sin(angle) * 156.0)
			ci.draw_line(a.lerp(b, 0.12), a.lerp(b, 0.88), shade, 5.0, true)
	else:
		ci.draw_polyline(arc(Vector2(0, 24), 190.0, 156.0, PI * 1.06, PI * 1.94, 30), shade, 8.0, true)
	outline(ci, hood)


# --- Emotion decor, soap bubbles, play ball, cryo-capsule --------------------------------

static func draw_decor(ci: CanvasItem, s: Dictionary) -> void:
	var t: float = s.time
	if s.bubbles > 0.0:
		for i in 9:
			var phase := fmod(t * 0.55 + i * 0.37, 1.0)
			var position := Vector2(sin(i * 2.4) * 190.0 + sin(t * 2.0 + i) * 14.0, 150.0 - phase * 380.0)
			var radius := 14.0 + (i % 4) * 7.0
			var alpha := sin(phase * PI) * minf(1.0, s.bubbles)
			ci.draw_circle(position, radius, Color(0.82, 0.93, 1.0, 0.38 * alpha))
			ci.draw_arc(position, radius, 0.0, TAU, 24, Color(1, 1, 1, 0.9 * alpha), 3.0, true)
			ci.draw_circle(position + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.2, Color(1, 1, 1, alpha))
	if s.sleeping:
		for i in 3:
			var phase := fmod(t * 0.35 + i * 0.33, 1.0)
			var position := Vector2(150.0 + phase * 70.0 + sin(t * 1.4 + i) * 8.0, -170.0 - phase * 170.0)
			var size := int(34 + phase * 40)
			var font := ThemeDB.fallback_font
			var color := Color(1, 1, 1, sin(phase * PI))
			ci.draw_string_outline(font, position, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(INK, color.a))
			ci.draw_string(font, position, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		return
	match s.expression:
		"excited":
			for i in 6:
				var angle := -PI * 0.5 + (i - 2.5) * 0.52
				var position := Vector2(cos(angle), sin(angle)) * (265.0 + sin(t * 3.0 + i * 1.7) * 14.0) + Vector2(0, -20)
				star4(ci, position, 15.0 + 7.0 * sin(t * 5.0 + i * 2.1), STAR, t + i)
		"surprised":
			var bob := sin(t * 9.0) * 5.0
			text(ci, Vector2(120, -250 + bob), "!", 96, RIM_LIGHT)
			text(ci, Vector2(168, -226 - bob), "!", 72, RIM_LIGHT)
		"confused":
			var sway := sin(t * 3.0) * 7.0
			text(ci, Vector2(118 + sway, -244), "?", 92, Color("#B695F8"))
			text(ci, Vector2(-196 - sway, -212), "?", 68, Color("#B695F8"))
		"sad":
			var phase := fmod(t * 0.6, 1.0)
			var drop := Vector2(-EYE_X - 30.0, EYE_Y + 60.0 + phase * 70.0)
			var tear := ellipse(drop, 9.0, 13.0, 14)
			ci.draw_colored_polygon(tear, Color(0.62, 0.84, 1.0, 1.0 - phase))
			outline(ci, tear, 2.5, Color(INK, 1.0 - phase))
		"laugh":
			for side: float in [-1.0, 1.0]:
				var drop := Vector2(side * (EYE_X + 62.0), EYE_Y + 6.0 + absf(sin(t * 6.0)) * 6.0)
				ci.draw_colored_polygon(ellipse(drop, 7.0, 10.0, 12, side * 0.5), Color(0.72, 0.9, 1.0))
		"angry":
			for side: float in [-1.0, 1.0]:
				var puff := Vector2(side * 250.0, 70.0 - fmod(t * 0.8 + side * 0.25, 1.0) * 50.0)
				ci.draw_circle(puff, 15.0, Color(1, 1, 1, 0.55))
				ci.draw_circle(puff + Vector2(side * 16.0, -8.0), 10.0, Color(1, 1, 1, 0.4))
		"proud":
			var pulse := 0.35 + 0.2 * sin(t * 2.6)
			glow(ci, Vector2.ZERO, 340.0, Color(RIM_LIGHT, pulse))
			for i in 5:
				var angle := t * 0.6 + i * TAU / 5.0
				star4(ci, Vector2(cos(angle) * 258.0, sin(angle) * 240.0), 13.0, Color(STAR, 0.9), -t)
		"love":
			for i in 3:
				var phase := fmod(t * 0.45 + i * 0.33, 1.0)
				var position := Vector2(-150.0 + i * 150.0 + sin(t * 2.0 + i) * 12.0, -230.0 - phase * 90.0)
				ci.draw_colored_polygon(heart(position, 44.0), Color(1.0, 0.44, 0.57, sin(phase * PI)))
		"shy":
			for side: float in [-1.0, 1.0]:
				glow(ci, Vector2(side * 146.0, 60.0), 90.0, Color(BLUSH, 0.45 + 0.15 * sin(t * 3.0)))


static func draw_ball(ci: CanvasItem, _s: Dictionary) -> void:
	ci.draw_circle(Vector2.ZERO, 37.0, INK)
	ci.draw_circle(Vector2.ZERO, 32.0, Color("#F78FB3"))
	ci.draw_arc(Vector2.ZERO, 22.0, PI * 0.1, PI * 0.9, 12, Color("#D46A92"), 5.0, true)
	ci.draw_circle(Vector2(-11, -12), 8.0, Color(1, 1, 1, 0.85))


static func draw_capsule(ci: CanvasItem, s: Dictionary) -> void:
	var t: float = s.time
	var dome := ellipse(Vector2(0, -24), 292.0, 300.0, 56)
	ci.draw_colored_polygon(dome, Color(0.55, 0.82, 1.0, 0.26))
	ci.draw_polyline(arc(Vector2(0, -24), 262.0, 270.0, PI * 1.08, PI * 1.42, 16), Color(1, 1, 1, 0.6), 14.0, true)
	ci.draw_polyline(arc(Vector2(0, -24), 262.0, 270.0, PI * 1.47, PI * 1.53, 6), Color(1, 1, 1, 0.6), 14.0, true)
	outline(ci, dome, 7.0, Color(0.82, 0.95, 1.0, 0.95))
	for i in 7:
		var angle := i * 0.9 + 0.3
		var position := Vector2(cos(angle) * 210.0, -24.0 + sin(angle) * 220.0)
		star4(ci, position, 9.0 + 5.0 * sin(t * 1.5 + i), Color(0.9, 0.98, 1.0, 0.85), i)
	var base := PackedVector2Array([Vector2(-270, 212), Vector2(270, 212), Vector2(300, 262), Vector2(-300, 262)])
	blob(ci, base, Color("#2E3A6B"))
	var glow := 0.6 + 0.4 * sin(t * 1.8)
	ci.draw_line(Vector2(-210, 238), Vector2(210, 238), Color(0.55, 0.9, 1.0, glow), 9.0, true)
