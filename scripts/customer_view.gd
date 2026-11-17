extends Node2D
## Клиент за прилавком в стиле старых мультфильмов: контуры, перчатки, резиновые руки,
## глаза-«таблетки», пружинистые сжатия и растяжения. Масштабируется самим узлом.

signal arrived
signal left

const U = preload("res://scripts/util.gd")

const HOME_X := 400.0
const ENTER_FROM := 620.0
const FEET_Y := 337.0

var data: Dictionary = {}
var mood := 1
var state := "none"   # none, entering, idle, leaving
var x_off := ENTER_FROM
var t_state := 0.0
var time := 0.0
var react_t := 99.0
var blink_in := 3.0
var blinking := 0.0
var sparkle_t := 99.0


func _ready() -> void:
	position = Vector2(HOME_X + ENTER_FROM, 0)


func arrive(c: Dictionary) -> void:
	data = c
	mood = 1
	state = "entering"
	t_state = 0.0
	x_off = ENTER_FROM
	react_t = 99.0
	sparkle_t = 99.0


func set_mood(m: int) -> void:
	mood = m
	react_t = 0.0
	sparkle_t = 0.0


func leave() -> void:
	state = "leaving"
	t_state = 0.0


func reset() -> void:
	data = {}
	state = "none"
	x_off = ENTER_FROM
	position = Vector2(HOME_X + ENTER_FROM, 0)


func _process(delta: float) -> void:
	time += delta
	react_t += delta
	sparkle_t += delta
	blink_in -= delta
	if blink_in <= 0.0:
		blinking = 0.12
		blink_in = randf_range(2.5, 5.0)
	blinking = maxf(blinking - delta, 0.0)
	if state == "entering":
		t_state += delta / 1.1
		x_off = ENTER_FROM * (1.0 - U.ease_out_back(minf(t_state, 1.0)))
		if t_state >= 1.0:
			x_off = 0.0
			state = "idle"
			arrived.emit()
	elif state == "leaving":
		t_state += delta / 0.9
		x_off = ENTER_FROM * U.ease_in(t_state)
		if t_state >= 1.0:
			state = "none"
			data = {}
			left.emit()
	position = Vector2(HOME_X + x_off, 0)
	queue_redraw()


# --- Рисование -----------------------------------------------------------------

func _poly(pts: PackedVector2Array, fill: Color, w: float = 3.0) -> void:
	U.fill_stroke(self, pts, fill, w, time, 1.2)


func _blob(c: Vector2, rx: float, ry: float, fill: Color, w: float = 3.0) -> void:
	U.fill_stroke(self, U.ellipse(c, rx, ry, 0.0, 28), fill, w, time, 1.0)


## Резиновая рука: толстая изогнутая линия с контуром и перчаткой на конце.
func _arm(from: Vector2, to: Vector2, bend: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var mid := (from + to) * 0.5 + bend
	for k in 11:
		var u := float(k) / 10.0
		pts.append(from.lerp(mid, u).lerp(mid.lerp(to, u), u))
	draw_polyline(pts, U.INK, 17.0, true)
	draw_polyline(pts, col, 11.0, true)
	_blob(to, 12.0, 12.0, Color(0.98, 0.97, 0.94), 3.0)
	draw_line(to + Vector2(-9, 8), to + Vector2(9, 8), U.INK, 2.0)


func _draw() -> void:
	if data.is_empty():
		return
	var coat := Color.html(data["coat"])
	var skin := Color.html(data["skin"])
	var hair := Color.html(data["hair"])
	var hat: String = data["hat"]
	var hatc := Color.html(data["hatc"])

	# ритм «по кадрам»: 12 кадров в секунду, как в рисованной анимации
	var tt := floorf(time * 12.0) / 12.0
	var bob := sin(tt * 2.6)
	var sy := 1.0 + 0.035 * bob
	var sx := 1.0 - 0.025 * bob
	var jump := 0.0
	if state == "entering":
		jump = -absf(sin(tt * 13.0)) * 9.0
	if mood == 2 and react_t < 1.6:
		jump -= absf(sin(react_t * 8.5)) * 30.0 * exp(-react_t * 2.2)
	elif mood == 0 and react_t < 0.8:
		sx += sin(react_t * 40.0) * 0.015 * (1.0 - react_t / 0.8)
	draw_set_transform(Vector2(0.0, FEET_Y * (1.0 - sy) + jump), 0.0, Vector2(sx, sy))

	# туловище
	var body := PackedVector2Array([
		Vector2(-68, 345), Vector2(-64, 258), Vector2(-34, 222),
		Vector2(34, 222), Vector2(64, 258), Vector2(68, 345)])
	_poly(body, coat)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, 224), Vector2(34, 222), Vector2(62, 256), Vector2(66, 345), Vector2(10, 345)]), coat.darkened(0.14))
	for k in 3:
		_blob(Vector2(-1, 270 + float(k) * 26.0), 3.6, 3.6, coat.darkened(0.4), 2.0)
	draw_rect(Rect2(-11, 200, 22, 26), skin.darkened(0.1))
	_blob(Vector2(0, 228), 40.0, 13.0, hatc)
	_poly(PackedVector2Array([Vector2(14, 232), Vector2(32, 232), Vector2(34, 282), Vector2(18, 284)]), hatc.darkened(0.12), 2.5)

	# руки: левая лежит на прилавке, правая машет при радости и приходе
	var wave := state == "entering" or (mood == 2 and react_t < 2.2)
	var lhand := Vector2(-90, 328)
	var rhand := Vector2(90, 328)
	var rbend := Vector2(34, 0)
	if wave:
		rhand = Vector2(98, 196 + sin(tt * 16.0) * 14.0)
		rbend = Vector2(56, 10)
	_arm(Vector2(-56, 250), lhand, Vector2(-34, 0), coat.darkened(0.1))
	_arm(Vector2(56, 250), rhand, rbend, coat.darkened(0.1))

	# голова
	_blob(Vector2(-37, 172), 7.0, 8.0, skin.darkened(0.06), 2.5)
	_blob(Vector2(37, 172), 7.0, 8.0, skin.darkened(0.06), 2.5)
	_blob(Vector2(0, 170), 37.0, 39.0, skin)
	_draw_hair_and_hat(hair, hat, hatc)
	_draw_face()
	if mood == 2 and sparkle_t < 1.8:
		_draw_sparkles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hair_and_hat(hair: Color, hat: String, hatc: Color) -> void:
	if hat != "santa" and hat != "beanie":
		var cap := PackedVector2Array()
		for k in 17:
			var a := PI + PI * float(k) / 16.0
			cap.append(Vector2(cos(a) * 39.0, 166 + sin(a) * 38.0))
		cap.append(Vector2(36, 156))
		cap.append(Vector2(-36, 156))
		_poly(cap, hair, 2.5)
	match hat:
		"beanie":
			var dome := PackedVector2Array()
			for k in 17:
				var a2 := PI + PI * float(k) / 16.0
				dome.append(Vector2(cos(a2) * 41.0, 156 + sin(a2) * 36.0))
			_poly(dome, hatc)
			_poly(U.rect_pts(Rect2(-42, 150, 84, 14)), hatc.lightened(0.2), 2.5)
			_blob(Vector2(0, 118), 10.0, 10.0, Color(0.97, 0.97, 0.97), 2.5)
		"santa":
			_poly(PackedVector2Array([
				Vector2(-41, 154), Vector2(41, 154), Vector2(36, 118),
				Vector2(52, 104), Vector2(10, 92), Vector2(-30, 112)]), hatc)
			_poly(U.rect_pts(Rect2(-44, 146, 88, 15)), Color(0.97, 0.97, 0.97), 2.5)
			_blob(Vector2(50, 106), 10.0, 10.0, Color(0.97, 0.97, 0.97), 2.5)
		"cap":
			var dome2 := PackedVector2Array()
			for k in 17:
				var a3 := PI + PI * float(k) / 16.0
				dome2.append(Vector2(cos(a3) * 40.0, 154 + sin(a3) * 28.0))
			_poly(dome2, hatc)
			_poly(U.rect_pts(Rect2(-2, 150, 52, 8)), hatc.darkened(0.2), 2.5)
		"bun":
			_blob(Vector2(0, 126), 15.0, 15.0, hair, 2.5)


func _draw_face() -> void:
	var eh := 1.0 if blinking <= 0.0 else 0.15
	if mood == 2:
		draw_arc(Vector2(-14, 176), 6.0, PI * 1.1, PI * 1.9, 8, U.INK, 3.5)
		draw_arc(Vector2(14, 176), 6.0, PI * 1.1, PI * 1.9, 8, U.INK, 3.5)
	else:
		# глаза-«таблетки» с белой долей, как у героев старых мультфильмов
		for sgn in [-1.0, 1.0]:
			var s: float = sgn
			var ec := Vector2(14.0 * s, 171)
			draw_colored_polygon(U.ellipse(ec, 5.2, 8.0 * eh, 0.0, 16), U.INK)
			if eh > 0.5:
				draw_colored_polygon(PackedVector2Array([ec + Vector2(-2.5, -6), ec + Vector2(1.5, -6.5), ec + Vector2(-0.5, -0.5)]), Color(1, 1, 1))
	var brow_lift := -2.0 if mood == 2 else (3.0 if mood == 0 else 0.0)
	draw_line(Vector2(-23, 158 + brow_lift), Vector2(-7, 156 - brow_lift * 0.5), U.INK, 3.5)
	draw_line(Vector2(7, 156 - brow_lift * 0.5), Vector2(23, 158 + brow_lift), U.INK, 3.5)
	if mood >= 1:
		draw_circle(Vector2(-24, 185), 6.0, Color(0.95, 0.5, 0.5, 0.35))
		draw_circle(Vector2(24, 185), 6.0, Color(0.95, 0.5, 0.5, 0.35))
	match mood:
		0:
			draw_arc(Vector2(0, 198), 10.0, PI * 1.15, PI * 1.85, 10, U.INK, 3.0)
		1:
			draw_arc(Vector2(0, 183), 12.0, deg_to_rad(25.0), deg_to_rad(155.0), 12, U.INK, 3.0)
		_:
			var m := PackedVector2Array()
			for k in 13:
				var a := PI * float(k) / 12.0
				m.append(Vector2(cos(a) * 14.0, 184 + sin(a) * 12.0))
			_poly(m, Color("#5a2330"), 2.5)
			draw_colored_polygon(U.ellipse(Vector2(0, 191), 7.0, 4.0, 0.0, 14), Color("#e8808a"))


func _draw_sparkles() -> void:
	var fade := 1.0 - clampf((sparkle_t - 1.0) / 0.8, 0.0, 1.0)
	for i in 6:
		var a := TAU * float(i) / 6.0 + time * 1.5
		var r := 66.0 + 8.0 * sin(time * 5.0 + float(i))
		var p := Vector2(cos(a) * r, 168 + sin(a) * r * 0.8)
		draw_colored_polygon(U.star(p, 8.0, 3.0, 4, a), Color(1.0, 0.9, 0.4, fade))
