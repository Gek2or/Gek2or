extends CanvasItem
## Procedural interior for the three archetype rooms. One script serves two
## layers: "frame" (window frame and things hanging on it) and "sill" (the
## wooden sill, the props standing on it and the knitted cushion).
## Coordinates are canvas units of the 1080x1920 base view; everything is drawn
## oversized so taller phones never see an edge.

const INK := Color("#232946")
const WOOD := Color("#9A5F3C")
const WOOD_LIGHT := Color("#B97B4E")
const WOOD_DARK := Color("#6E4029")
const CUSHION := Color("#E6B39A")
const CUSHION_SHADE := Color("#C68C76")
const CUSHION_LIGHT := Color("#F3CDB6")
const CUSHION_STITCH := Color("#D29C86")
const SILL_TOP := 1330.0
const SILL_FRONT := 1610.0
const ANIMATION_INTERVAL := 1.0 / 12.0

@export_enum("frame", "sill") var layer := "frame"

var archetype := "supporter"

var _time := 0.0
var _redraw_clock := 0.0


func _ready() -> void:
	archetype = GameState.archetype
	set_process(layer == "sill")


func set_archetype(value: String) -> void:
	archetype = value
	queue_redraw()


func _process(delta: float) -> void:
	# Steam, lava-lamp blobs and the spinning record need gentle animation.
	_time += delta
	_redraw_clock -= delta
	if _redraw_clock <= 0.0:
		_redraw_clock = ANIMATION_INTERVAL
		queue_redraw()


func _draw() -> void:
	if layer == "frame":
		_draw_frame()
	else:
		_draw_sill()
		_draw_props(false)
		if archetype == "supporter":
			_draw_back_pillow()
		_draw_cushion()
		_draw_props(true)
		_place(Vector2.ZERO)


## Props stand either behind the big cushion (`front` = false) or in front of it.
func _draw_props(front: bool) -> void:
	match archetype:
		"explorer":
			_draw_explorer_props(front)
		"joker":
			_draw_joker_props(front)
		_:
			_draw_supporter_props(front)


## Moves the origin for the next prop, so each prop keeps its own local layout.
func _place(offset: Vector2, zoom: float = 1.0) -> void:
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))


# --- Shared helpers ---------------------------------------------------------------------------

func _blob(points: PackedVector2Array, fill: Color, width: float = 6.0) -> void:
	draw_colored_polygon(points, fill)
	BloopieArt.outline(self, points, width)


func _box(rect: Rect2, fill: Color, width: float = 6.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, INK, false, width)


func _oval(center: Vector2, rx: float, ry: float, fill: Color, width: float = 6.0, rotation: float = 0.0) -> void:
	_blob(BloopieArt.ellipse(center, rx, ry, 32, rotation), fill, width)


# --- Frame layer -------------------------------------------------------------------------------

func _draw_frame() -> void:
	var posts := [Rect2(-400, -500, 474, 2100), Rect2(1006, -500, 474, 2100)]
	for post: Rect2 in posts:
		draw_rect(post, WOOD)
	draw_rect(Rect2(-400, -500, 1880, 640), WOOD)
	if archetype == "explorer":
		# Attic: the roof slopes down over the left side of the window.
		draw_colored_polygon(PackedVector2Array([Vector2(74, 140), Vector2(560, 140), Vector2(74, 620)]), WOOD)
		draw_line(Vector2(560, 140), Vector2(74, 620), INK, 7.0, true)
		draw_line(Vector2(520, 140), Vector2(74, 580), WOOD_DARK, 5.0, true)
	else:
		draw_rect(Rect2(300, 140, 44, 1260), WOOD)
		draw_rect(Rect2(300, 140, 13, 1260), WOOD_LIGHT)
		draw_line(Vector2(300, 140), Vector2(300, 1400), INK, 6.0)
		draw_line(Vector2(344, 140), Vector2(344, 1400), INK, 6.0)
		# Crossbar, like the old cottage window in the concept art.
		draw_rect(Rect2(74, 620, 932, 36), WOOD)
		draw_rect(Rect2(74, 620, 932, 10), WOOD_LIGHT)
		draw_line(Vector2(74, 620), Vector2(1006, 620), INK, 6.0)
		draw_line(Vector2(74, 656), Vector2(1006, 656), INK, 6.0)
	for x: float in [-120.0, 20.0, 1040.0, 1170.0]:
		draw_line(Vector2(x, -400), Vector2(x + 6.0, 1500), Color(WOOD_DARK, 0.5), 5.0, true)
	draw_rect(Rect2(40, 140, 34, 1300), WOOD_LIGHT)
	draw_rect(Rect2(1006, 140, 34, 1300), WOOD_DARK)
	draw_rect(Rect2(74, 106, 932, 34), WOOD_DARK)
	draw_polyline(PackedVector2Array([Vector2(74, 1400), Vector2(74, 140), Vector2(1006, 140), Vector2(1006, 1400)]), INK, 7.0)
	match archetype:
		"explorer":
			_draw_star_chart()
		"joker":
			_draw_polaroid_string()
		_:
			_draw_hanging_plant()


func _draw_hanging_plant() -> void:
	var vine := Color("#4E8F58")
	for i in 3:
		var x := 120.0 + i * 46.0
		var length := 300.0 - i * 70.0
		draw_line(Vector2(x, 140), Vector2(x - 8.0, 140 + length), Color("#35653F"), 5.0, true)
		for j in 5:
			var y := 190.0 + j * (length - 60.0) / 5.0
			var side := -1.0 if (i + j) % 2 == 0 else 1.0
			_oval(Vector2(x + side * 22.0 - 4.0, y), 24.0, 13.0, vine.lightened(0.08 * j), 4.0, side * 0.6)


func _draw_star_chart() -> void:
	var sheet := Rect2(790, 196, 196, 150)
	_box(sheet, Color("#26305E"), 5.0)
	var stars := [Vector2(820, 300), Vector2(852, 252), Vector2(898, 268), Vector2(930, 226), Vector2(958, 290)]
	for i in stars.size() - 1:
		draw_line(stars[i], stars[i + 1], Color(1, 1, 1, 0.55), 3.0, true)
	for star: Vector2 in stars:
		BloopieArt.star4(self, star, 10.0, BloopieArt.STAR)
	draw_circle(Vector2(888, 196), 8.0, Color("#E05772"))


func _draw_polaroid_string() -> void:
	draw_line(Vector2(380, 420), Vector2(1000, 400), Color("#3A2A2A"), 4.0, true)
	var tints := [Color("#F7A8C4"), Color("#9CE5C8"), Color("#FFA96B"), Color("#B695F8")]
	for i in 4:
		var x := 430.0 + i * 140.0
		var top := Vector2(x, 418.0 - i * 4.5)
		var tilt := -0.08 + i * 0.05
		var card := PackedVector2Array()
		for corner: Vector2 in [Vector2(-44, 0), Vector2(44, 0), Vector2(44, 108), Vector2(-44, 108)]:
			card.push_back(top + corner.rotated(tilt))
		_blob(card, Color("#FFFDF9"), 4.0)
		var photo := PackedVector2Array()
		for corner: Vector2 in [Vector2(-34, 10), Vector2(34, 10), Vector2(34, 76), Vector2(-34, 76)]:
			photo.push_back(top + corner.rotated(tilt))
		draw_colored_polygon(photo, tints[i])
		draw_circle(top + Vector2(0, -2), 7.0, Color("#B97B4E"))


# --- Sill layer --------------------------------------------------------------------------------

func _draw_sill() -> void:
	draw_rect(Rect2(-400, SILL_TOP, 1880, SILL_FRONT - SILL_TOP), WOOD_LIGHT)
	# The wall under the sill fades into the shadow of the room.
	var wall := PackedVector2Array([Vector2(-400, SILL_FRONT), Vector2(1480, SILL_FRONT), Vector2(1480, 2700), Vector2(-400, 2700)])
	var deep := Color("#2A1B3D")
	draw_polygon(wall, PackedColorArray([WOOD, WOOD, deep, deep]))
	draw_rect(Rect2(-400, SILL_FRONT, 1880, 30), WOOD_DARK)
	draw_line(Vector2(-400, SILL_TOP), Vector2(1480, SILL_TOP), INK, 7.0)
	draw_line(Vector2(-400, SILL_FRONT), Vector2(1480, SILL_FRONT), INK, 7.0)
	for i in 5:
		var y := SILL_FRONT + 150.0 + i * 210.0
		draw_line(Vector2(-400, y), Vector2(1480, y + 12.0), Color(WOOD_DARK, 0.55), 5.0, true)
	for i in 4:
		var x := 90.0 + i * 300.0
		draw_line(Vector2(x, SILL_TOP + 30.0), Vector2(x + 150.0, SILL_TOP + 36.0), Color(WOOD, 0.8), 4.0, true)


func _draw_back_pillow() -> void:
	# A second knitted pillow leaning behind Bloopie, as in the concept art.
	_place(Vector2(250, 1190))
	var pillow := PackedVector2Array()
	for i in 40:
		var angle := i * TAU / 40.0
		# Superellipse: a soft square pillow.
		var corner := Vector2(signf(cos(angle)) * pow(absf(cos(angle)), 0.55) * 210.0, signf(sin(angle)) * pow(absf(sin(angle)), 0.55) * 250.0)
		pillow.push_back(corner.rotated(-0.2))
	draw_colored_polygon(pillow, CUSHION_SHADE)
	var face := PackedVector2Array()
	for point in pillow:
		face.push_back(point * 0.92 + Vector2(-6, -10))
	draw_colored_polygon(face, CUSHION)
	for row in 7:
		for column in 5:
			var at := Vector2(-150 + column * 72.0 + (row % 2) * 36.0, -190 + row * 58.0).rotated(-0.2)
			draw_polyline(PackedVector2Array([at + Vector2(-20, -16), at + Vector2(0, 12), at + Vector2(20, -16)]), CUSHION_STITCH, 8.0, true)
	BloopieArt.outline(self, pillow, 7.0)
	_place(Vector2.ZERO)


func _draw_cushion() -> void:
	var center := Vector2(540, 1440)
	var outer := BloopieArt.ellipse(center, 506.0, 158.0, 64)
	BloopieArt.glow(self, center + Vector2(0, 50), 640.0, Color(INK, 0.45))
	draw_colored_polygon(outer, CUSHION_SHADE)
	draw_colored_polygon(BloopieArt.ellipse(center + Vector2(0, -22), 486.0, 130.0, 64), CUSHION)
	draw_colored_polygon(BloopieArt.ellipse(center + Vector2(-40, -44), 380.0, 86.0, 48), Color(CUSHION_LIGHT, 0.55))
	# Chunky knit: rows of fat braided "V" stitches that follow the oval.
	for row in 6:
		var y := center.y - 112.0 + row * 44.0
		var squeeze := maxf(0.0, 1.0 - pow((y - center.y + 22.0) / 132.0, 2.0))
		var half_width := 480.0 * sqrt(squeeze)
		var x := -half_width + 34.0 + (row % 2) * 30.0
		while x < half_width - 34.0:
			var at := Vector2(center.x + x, y)
			var stitch := PackedVector2Array([at + Vector2(-19, -13), at + Vector2(0, 11), at + Vector2(19, -13)])
			draw_polyline(stitch, CUSHION_STITCH, 9.0, true)
			draw_line(at + Vector2(-17, -17), at + Vector2(-4, 0), Color(CUSHION_LIGHT, 0.7), 3.0, true)
			x += 60.0
	BloopieArt.outline(self, outer, 7.0)
	# Soft contact shadow where Bloopie sits.
	BloopieArt.glow(self, center + Vector2(0, -70), 330.0, Color(INK, 0.3))


func _draw_supporter_props(front: bool) -> void:
	if front:
		_draw_supporter_front()
		return
	# Potted plant in the left corner.
	_place(Vector2(-10, -300), 1.15)
	for i in 5:
		var angle := -PI * 0.5 + (i - 2) * 0.42
		var tip := Vector2(92, 1150) + Vector2.from_angle(angle) * 170.0
		draw_line(Vector2(92, 1180), tip, Color("#35653F"), 6.0, true)
		_oval(tip, 44.0, 22.0, Color("#5FA368").lightened(0.06 * i), 5.0, angle)
	_blob(PackedVector2Array([Vector2(36, 1170), Vector2(150, 1170), Vector2(134, 1290), Vector2(52, 1290)]), Color("#D98E63"))
	# Table lamp on the right.
	_place(Vector2(-40, 110))
	var lamp := Vector2(1010, 1300)
	BloopieArt.glow(self, lamp + Vector2(-10, -250), 420.0, Color(1.0, 0.8, 0.45, 0.5))
	draw_line(lamp + Vector2(-10, -200), lamp + Vector2(-10, -20), INK, 20.0)
	draw_line(lamp + Vector2(-10, -200), lamp + Vector2(-10, -20), Color("#C98F58"), 9.0)
	_oval(lamp + Vector2(-10, -12), 62.0, 20.0, Color("#C98F58"))
	_blob(PackedVector2Array([lamp + Vector2(-78, -330), lamp + Vector2(58, -330), lamp + Vector2(104, -190), lamp + Vector2(-124, -190)]), Color("#FFD98A"))


func _draw_supporter_front() -> void:
	# Sleeping ginger cat curled up in front of the cushion.
	_place(Vector2(40, 258))
	var cat := Vector2(112, 1322)
	_oval(cat, 104.0, 56.0, Color("#F2A154"))
	_oval(cat + Vector2(64, -8), 46.0, 40.0, Color("#F5AE66"))
	_blob(PackedVector2Array([cat + Vector2(40, -36), cat + Vector2(50, -70), cat + Vector2(72, -44)]), Color("#F5AE66"), 5.0)
	_blob(PackedVector2Array([cat + Vector2(78, -44), cat + Vector2(100, -66), cat + Vector2(104, -30)]), Color("#F5AE66"), 5.0)
	draw_arc(cat + Vector2(54, -6), 9.0, 0.1, PI - 0.1, 8, INK, 4.0, true)
	draw_arc(cat + Vector2(84, -6), 9.0, 0.1, PI - 0.1, 8, INK, 4.0, true)
	draw_arc(cat + Vector2(-20, 6), 78.0, PI * 0.25, PI * 0.8, 14, Color("#D97C2B"), 12.0, true)
	for i in 3:
		draw_arc(cat + Vector2(-50 + i * 34.0, -34), 16.0, PI * 1.15, PI * 1.85, 8, Color("#D97C2B"), 6.0, true)
	# Stack of books with a mug of hot cocoa.
	_place(Vector2(36, 236))
	_box(Rect2(826, 1338, 190, 44), Color("#7A52C7"))
	_box(Rect2(842, 1296, 170, 42), Color("#D46A92"))
	draw_rect(Rect2(842, 1310, 170, 8), Color("#FFFDF9"))
	var mug := Vector2(912, 1246)
	draw_arc(mug + Vector2(52, 4), 22.0, -PI * 0.5, PI * 0.5, 12, INK, 15.0, true)
	draw_arc(mug + Vector2(52, 4), 22.0, -PI * 0.5, PI * 0.5, 12, Color("#FFFDF9"), 6.0, true)
	_blob(PackedVector2Array([mug + Vector2(-50, -42), mug + Vector2(50, -42), mug + Vector2(42, 50), mug + Vector2(-42, 50)]), Color("#FFFDF9"))
	_oval(mug + Vector2(0, -42), 50.0, 13.0, Color("#8A5636"), 5.0)
	_draw_steam(mug + Vector2(0, -60))


func _draw_steam(from: Vector2) -> void:
	for i in 3:
		var phase := fmod(_time * 0.35 + i * 0.33, 1.0)
		var wisp := PackedVector2Array()
		for j in 8:
			var k := j / 7.0
			wisp.push_back(from + Vector2((i - 1) * 24.0 + sin(k * 5.0 + _time * 1.5 + i) * 12.0, -phase * 70.0 - k * 80.0))
		draw_polyline(wisp, Color(1, 1, 1, 0.5 * sin(phase * PI)), 7.0, true)


func _draw_explorer_props(front: bool) -> void:
	if front:
		_draw_explorer_front()
		return
	# Brass telescope on a tripod, pointing at the sky.
	_place(Vector2(-30, -330), 1.25)
	var pivot := Vector2(140, 1130)
	for foot: Vector2 in [Vector2(40, 1330), Vector2(140, 1340), Vector2(230, 1330)]:
		draw_line(pivot, foot, INK, 16.0, true)
		draw_line(pivot, foot, Color("#8A5636"), 7.0, true)
	var direction := Vector2.from_angle(-0.62)
	draw_line(pivot - direction * 90.0, pivot + direction * 210.0, INK, 54.0)
	draw_line(pivot - direction * 86.0, pivot + direction * 206.0, Color("#D9A441"), 42.0)
	draw_line(pivot + direction * 150.0, pivot + direction * 206.0, Color("#F1C767"), 42.0)
	draw_line(pivot - direction * 120.0, pivot - direction * 86.0, INK, 34.0)
	draw_circle(pivot, 20.0, INK)
	draw_circle(pivot, 13.0, Color("#F1C767"))
	# Globe.
	_place(Vector2(40, -30))
	var globe := Vector2(900, 1226)
	draw_arc(globe, 96.0, -PI * 0.42, PI * 0.72, 24, INK, 16.0, true)
	draw_arc(globe, 96.0, -PI * 0.42, PI * 0.72, 24, Color("#D9A441"), 7.0, true)
	_oval(globe, 78.0, 78.0, Color("#6FB7E8"))
	_oval(globe + Vector2(-24, -20), 30.0, 22.0, Color("#7BC678"), 4.0, 0.4)
	_oval(globe + Vector2(26, 24), 26.0, 16.0, Color("#7BC678"), 4.0, -0.3)
	draw_line(globe + Vector2(0, 96), globe + Vector2(0, 122), INK, 16.0)
	_oval(globe + Vector2(0, 124), 60.0, 16.0, Color("#8A5636"))
	# Lava lamp with slowly drifting blobs.
	_place(Vector2(-10, 60))
	var lava := Vector2(1012, 1180)
	_blob(PackedVector2Array([lava + Vector2(-26, -130), lava + Vector2(26, -130), lava + Vector2(44, 90), lava + Vector2(-44, 90)]), Color("#4B3A8C"))
	for i in 3:
		var phase := fmod(_time * 0.12 + i * 0.33, 1.0)
		draw_circle(lava + Vector2(sin(i * 2.0 + _time * 0.5) * 10.0, 70.0 - phase * 170.0), 13.0 + 5.0 * sin(phase * PI), Color("#FF8FA3"))
	_box(Rect2(lava.x - 50, lava.y + 90, 100, 44), Color("#D9A441"))
	_blob(PackedVector2Array([lava + Vector2(-28, -130), lava + Vector2(28, -130), lava + Vector2(16, -166), lava + Vector2(-16, -166)]), Color("#D9A441"))


func _draw_explorer_front() -> void:
	# Crystals.
	_place(Vector2(150, 250))
	var hues := [Color("#B695F8"), Color("#9CE5C8"), Color("#F7A8C4")]
	for i in 3:
		var base := Vector2(742 + i * 34.0, 1352)
		var height := 74.0 - absf(i - 1) * 22.0
		_blob(PackedVector2Array([base + Vector2(-18, 0), base + Vector2(-12, -height * 0.7), base + Vector2(0, -height), base + Vector2(12, -height * 0.7), base + Vector2(18, 0)]), hues[i], 5.0)


func _draw_joker_props(front: bool) -> void:
	if front:
		_draw_joker_front()
		return
	# Vinyl record player.
	_place(Vector2(0, -40))
	var deck := Rect2(20, 1250, 250, 96)
	_box(deck, Color("#D46A92"))
	var disc := Vector2(128, 1244)
	_oval(disc, 100.0, 30.0, Color("#232946"))
	for radius: float in [78.0, 56.0]:
		draw_arc(disc, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.16), 2.0, true)
	draw_colored_polygon(BloopieArt.ellipse(disc, 30.0, 9.0, 20), Color("#FFD175"))
	var needle := disc + Vector2(cos(_time * 2.0) * 60.0, sin(_time * 2.0) * 18.0)
	draw_circle(needle, 5.0, Color(1, 1, 1, 0.5))
	draw_line(Vector2(250, 1190), Vector2(180, 1236), INK, 12.0, true)
	draw_line(Vector2(250, 1190), Vector2(180, 1236), Color("#FFFDF9"), 5.0, true)
	draw_circle(Vector2(250, 1190), 14.0, INK)
	# Floating notes.
	for i in 2:
		var phase := fmod(_time * 0.3 + i * 0.5, 1.0)
		var note := Vector2(120 + i * 70.0 + sin(_time + i) * 12.0, 1170 - phase * 150.0)
		var alpha := sin(phase * PI)
		draw_circle(note, 13.0, Color(1, 0.82, 0.46, alpha))
		draw_line(note + Vector2(11, 0), note + Vector2(11, -44), Color(1, 0.82, 0.46, alpha), 5.0)


func _draw_joker_front() -> void:
	# Wind-up duck.
	_place(Vector2(60, 262))
	var duck := Vector2(900, 1300)
	_oval(duck, 70.0, 52.0, Color("#FFD34E"))
	_oval(duck + Vector2(-48, -56), 40.0, 38.0, Color("#FFD34E"))
	_blob(PackedVector2Array([duck + Vector2(-84, -60), duck + Vector2(-122, -50), duck + Vector2(-84, -38)]), Color("#FFA24B"), 5.0)
	draw_circle(duck + Vector2(-56, -64), 7.0, INK)
	_oval(duck + Vector2(14, -4), 34.0, 22.0, Color("#F5B62E"), 4.0, -0.3)
	var key_turn := sin(_time * 3.0)
	draw_line(duck + Vector2(60, -30), duck + Vector2(96, -52), INK, 9.0, true)
	_oval(duck + Vector2(108, -60), 8.0 + 14.0 * absf(key_turn), 22.0, Color("#C0C6D4"), 5.0, 0.5)
	# Spare pink ball.
	_place(Vector2(-890, 250))
	draw_circle(Vector2(1012, 1338), 37.0, INK)
	draw_circle(Vector2(1012, 1338), 31.0, Color("#F78FB3"))
	draw_circle(Vector2(1002, 1327), 8.0, Color(1, 1, 1, 0.85))
