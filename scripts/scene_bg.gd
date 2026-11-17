extends Node2D
## Фон экрана заказа (вид спереди). Режимы:
## "back" — стена, окно со снегом, гирлянда, лампа, часы, ёлка;
## "front" — тёплый свет лампы, виньетка и салют; "vignette" — только виньетка (экран упаковки).

const U = preload("res://scripts/util.gd")

const WIN := Rect2(40, 70, 236, 250)
const LAMP := Vector2(640, 100)
const COUNTER_Y := 540.0

var mode := "back"
var time := 0.0
var sky_color := Color(0.106, 0.137, 0.278)
var sky_target := Color(0.106, 0.137, 0.278)
var clock_minutes := 1020.0
var clock_target := 1020.0
var flash := 0.0
var flakes: Array = []
var fireworks: Array = []
var bulb_colors: Array = []
var glow_tex: GradientTexture2D
var vignette_tex: GradientTexture2D


func _ready() -> void:
	bulb_colors = [Color("#e24b4b"), Color("#f2c14e"), Color("#4bb36b"), Color("#4b8fe2")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		flakes.append({
			"x": rng.randf_range(WIN.position.x, WIN.end.x),
			"y": rng.randf_range(WIN.position.y, WIN.end.y),
			"r": rng.randf_range(1.0, 3.0),
			"v": rng.randf_range(14.0, 40.0),
			"ph": rng.randf_range(0.0, TAU),
		})
	glow_tex = _make_radial(Color(1.0, 0.82, 0.5, 0.30), Color(1.0, 0.82, 0.5, 0.0), 0.0)
	vignette_tex = _make_radial(Color(0.0, 0.0, 0.0, 0.0), Color(0.03, 0.0, 0.05, 0.5), 0.45)


func _make_radial(inner: Color, outer: Color, inner_at: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([inner_at, 1.0])
	g.colors = PackedColorArray([inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func set_sky(c: Color) -> void:
	sky_target = c


func set_clock(minutes: float) -> void:
	clock_target = minutes


func set_clock_instant(minutes: float) -> void:
	clock_target = minutes
	clock_minutes = minutes


func spawn_firework() -> void:
	if mode == "back":
		flash = 1.0
		return
	var cols := [Color("#ffd166"), Color("#ef476f"), Color("#06d6a0"), Color("#118ab2"), Color("#f78c6b")]
	var col: Color = cols[randi() % cols.size()]
	fireworks.append({
		"pos": Vector2(randf_range(120.0, 1160.0), randf_range(70.0, 300.0)),
		"t": 0.0, "col": col, "r": randf_range(70.0, 120.0), "n": 26,
	})


func clear_fireworks() -> void:
	fireworks.clear()
	flash = 0.0


func _process(delta: float) -> void:
	time += delta
	sky_color = sky_color.lerp(sky_target, minf(delta * 1.5, 1.0))
	clock_minutes = move_toward(clock_minutes, clock_target, delta * 45.0)
	flash = maxf(flash - delta * 1.5, 0.0)
	if mode == "back":
		for f in flakes:
			f["y"] += f["v"] * delta
			f["x"] += sin(time * 0.9 + f["ph"]) * 7.0 * delta
			if f["y"] > WIN.end.y - 4.0:
				f["y"] = WIN.position.y
				f["x"] = randf_range(WIN.position.x, WIN.end.x)
	for i in range(fireworks.size() - 1, -1, -1):
		fireworks[i]["t"] += delta
		if fireworks[i]["t"] > 1.8:
			fireworks.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if mode == "front":
		_draw_front(true)
	elif mode == "vignette":
		_draw_front(false)
	else:
		_draw_back()


# --- Передний слой: свет, виньетка, салют ------------------------------------

func _draw_front(with_glow: bool) -> void:
	if with_glow:
		var breathe := 0.94 + 0.06 * sin(time * 1.7)
		draw_texture_rect(glow_tex, Rect2(LAMP - Vector2(560, 440), Vector2(1120, 880)), false, Color(1, 1, 1, breathe))
		draw_texture_rect(glow_tex, Rect2(LAMP - Vector2(220, 180), Vector2(440, 360)), false, Color(1, 0.95, 0.8, 0.8 * breathe))
	draw_texture_rect(vignette_tex, Rect2(0, 0, 1280, 720), false)
	for fw in fireworks:
		var t: float = fw["t"]
		var col: Color = fw["col"]
		var life := clampf(t / 1.8, 0.0, 1.0)
		var rr: float = fw["r"]
		var n: int = fw["n"]
		var pos: Vector2 = fw["pos"]
		for k in n:
			var a := TAU * float(k) / float(n)
			var d := rr * (1.0 - pow(1.0 - minf(t / 1.2, 1.0), 2.0))
			var p := pos + Vector2(cos(a), sin(a)) * d + Vector2(0.0, 30.0 * t * t)
			var alpha := (1.0 - life) * 0.95
			draw_circle(p, 3.0, Color(col.r, col.g, col.b, alpha))
			draw_circle(p, 7.0, Color(col.r, col.g, col.b, alpha * 0.18))


# --- Задний слой ----------------------------------------------------------------

func _draw_back() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#3b2a35"))
	for x in range(0, 1280, 64):
		draw_rect(Rect2(float(x), 0, 32, 540), Color(1, 1, 1, 0.025))
	draw_rect(Rect2(0, 430, 1280, 120), Color("#2b1e26"))
	draw_rect(Rect2(0, 426, 1280, 6), Color("#4b3441"))
	for i in 6:
		draw_rect(Rect2(60.0 + float(i) * 210.0, 450, 150, 80), Color(0, 0, 0, 0.12), false, 2.0)
	_draw_window()
	_draw_clock()
	_draw_tree()
	_draw_lamp()
	_draw_garland()


func _draw_window() -> void:
	draw_rect(Rect2(WIN.position - Vector2(10, 10), WIN.size + Vector2(20, 20)), Color("#2a1d18"))
	var top := sky_color
	var bottom := sky_color.lerp(Color("#3d4d80"), 0.55)
	draw_polygon(
		PackedVector2Array([WIN.position, Vector2(WIN.end.x, WIN.position.y), WIN.end, Vector2(WIN.position.x, WIN.end.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)
	for i in 22:
		var sx := WIN.position.x + 6.0 + U.hash2(i, 1) * (WIN.size.x - 12.0)
		var sy := WIN.position.y + 6.0 + U.hash2(i, 2) * 100.0
		var a := 0.35 + 0.6 * absf(sin(time * 1.3 + float(i)))
		draw_circle(Vector2(sx, sy), 1.2, Color(1, 1, 1, a))
	var moon := Vector2(WIN.end.x - 50.0, WIN.position.y + 46.0)
	draw_circle(moon, 26.0, Color(1.0, 0.97, 0.85, 0.08))
	draw_circle(moon, 15.0, Color(0.96, 0.94, 0.84))
	if flash > 0.0:
		draw_rect(WIN, Color(1.0, 0.9, 0.7, 0.14 * flash))
	var houses := [[0.03, 0.22, 40.0], [0.27, 0.18, 56.0], [0.48, 0.26, 36.0], [0.76, 0.21, 62.0]]
	var ground_y := WIN.end.y - 16.0
	for idx in houses.size():
		var h: Array = houses[idx]
		var hx: float = WIN.position.x + float(h[0]) * WIN.size.x
		var hw: float = float(h[1]) * WIN.size.x
		var hh: float = h[2]
		var hy := ground_y - hh
		draw_rect(Rect2(hx, hy, hw, hh + 2.0), Color(0.06, 0.07, 0.14))
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 4.0, hy), Vector2(hx + hw * 0.5, hy - 16.0), Vector2(hx + hw + 4.0, hy)]), Color(0.08, 0.09, 0.17))
		draw_line(Vector2(hx - 4.0, hy), Vector2(hx + hw * 0.5, hy - 16.0), Color(0.85, 0.9, 1.0, 0.8), 2.0)
		draw_line(Vector2(hx + hw * 0.5, hy - 16.0), Vector2(hx + hw + 4.0, hy), Color(0.85, 0.9, 1.0, 0.8), 2.0)
		for k in 3:
			if U.hash2(idx, k + 11) > 0.35:
				var wx := hx + 6.0 + float(k) * (hw - 14.0) / 3.0
				var wy := hy + 8.0 + U.hash2(idx, k + 3) * (hh - 22.0)
				var flick := 0.8 + 0.2 * sin(time * 0.7 + float(idx * 3 + k))
				draw_rect(Rect2(wx, wy, 7, 8), Color(1.0, 0.8, 0.4, 0.9 * flick))
	draw_rect(Rect2(WIN.position.x, ground_y, WIN.size.x, 16.0), Color(0.78, 0.83, 0.94))
	for f in flakes:
		var r: float = f["r"]
		draw_circle(Vector2(f["x"], f["y"]), r, Color(1, 1, 1, 0.55 + 0.35 * (r / 3.0)))
	draw_rect(Rect2(WIN.position.x + WIN.size.x * 0.5 - 3.0, WIN.position.y, 6, WIN.size.y), Color("#2a1d18"))
	draw_rect(Rect2(WIN.position.x, WIN.position.y + WIN.size.y * 0.5 - 3.0, WIN.size.x, 6), Color("#2a1d18"))
	draw_rect(Rect2(WIN.position.x - 16.0, WIN.end.y + 10.0, WIN.size.x + 32.0, 12.0), Color("#4a3426"))
	draw_rect(Rect2(WIN.position.x - 10.0, WIN.end.y + 6.0, WIN.size.x + 20.0, 6.0), Color(0.9, 0.93, 1.0, 0.9))
	U.stroke(self, U.rect_pts(Rect2(WIN.position - Vector2(10, 10), WIN.size + Vector2(20, 20))), U.INK, 4.0, time, 1.4)


func _draw_clock() -> void:
	var c := Vector2(1195, 120)
	draw_circle(c + Vector2(2, 4), 48.0, Color(0, 0, 0, 0.25))
	draw_circle(c, 46.0, Color("#4a3426"))
	draw_circle(c, 40.0, Color("#efe3c8"))
	for i in 12:
		var a := TAU * float(i) / 12.0 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 33.0, c + d * 38.0, Color("#5a4636"), 2.0)
	var h := fmod(clock_minutes / 60.0, 12.0)
	var m := fmod(clock_minutes, 60.0)
	var ah := h / 12.0 * TAU - PI * 0.5
	var am := m / 60.0 * TAU - PI * 0.5
	draw_line(c, c + Vector2(cos(ah), sin(ah)) * 21.0, Color("#3a2a22"), 4.0)
	draw_line(c, c + Vector2(cos(am), sin(am)) * 31.0, Color("#3a2a22"), 2.5)
	draw_circle(c, 3.5, Color("#c0392b"))
	U.stroke(self, U.ellipse(c, 46.0, 46.0, 0.0, 36), U.INK, 3.0, time, 1.0)


func _draw_tree() -> void:
	var b := Vector2(1090, 548)
	draw_rect(Rect2(b.x - 9.0, b.y - 16.0, 18.0, 22.0), Color("#5a3a24"))
	var t1 := PackedVector2Array([b + Vector2(-72, -10), b + Vector2(72, -10), b + Vector2(0, -78)])
	var t2 := PackedVector2Array([b + Vector2(-58, -62), b + Vector2(58, -62), b + Vector2(0, -118)])
	var t3 := PackedVector2Array([b + Vector2(-42, -102), b + Vector2(42, -102), b + Vector2(0, -158)])
	U.fill_stroke(self, t1, Color("#1d4a38"), 3.0, time)
	U.fill_stroke(self, t2, Color("#235a43"), 3.0, time)
	U.fill_stroke(self, t3, Color("#2a6b4f"), 3.0, time)
	var lights := [Vector2(-38, -26), Vector2(30, -34), Vector2(-14, -52), Vector2(46, -48), Vector2(-30, -78), Vector2(22, -86), Vector2(-8, -112), Vector2(14, -132)]
	for i in lights.size():
		var lp: Vector2 = lights[i]
		var col: Color = bulb_colors[i % bulb_colors.size()]
		var blink := 0.5 + 0.5 * sin(time * 2.6 + float(i) * 1.9)
		draw_circle(b + lp, 9.0, Color(col.r, col.g, col.b, 0.18 * blink))
		draw_circle(b + lp, 3.6, col.darkened(0.4).lerp(col, blink))
	var sp := b + Vector2(0, -162)
	draw_circle(sp, 14.0, Color(1.0, 0.85, 0.4, 0.2))
	U.fill_stroke(self, U.star(sp, 11.0, 4.5, 5, 0.0), Color("#f2c14e"), 2.5, time)


func _draw_lamp() -> void:
	draw_line(Vector2(LAMP.x, 0), Vector2(LAMP.x, 54), Color("#1d1519"), 2.0)
	var shade := PackedVector2Array([Vector2(LAMP.x - 30, 54), Vector2(LAMP.x + 30, 54), Vector2(LAMP.x + 52, 92), Vector2(LAMP.x - 52, 92)])
	U.fill_stroke(self, shade, Color("#2d2230"), 3.0, time)
	draw_rect(Rect2(LAMP.x - 52, 90, 104, 4), Color("#4b3a4a"))
	draw_circle(Vector2(LAMP.x, 98), 9.0, Color(1.0, 0.92, 0.6))
	draw_circle(Vector2(LAMP.x, 98), 16.0, Color(1.0, 0.85, 0.5, 0.25))


func _draw_garland() -> void:
	var pins := [0.0, 320.0, 640.0, 960.0, 1280.0]
	var bulb_i := 0
	for s in 4:
		var x0: float = pins[s]
		var x1: float = pins[s + 1]
		var pts := PackedVector2Array()
		for k in 17:
			var u := float(k) / 16.0
			pts.append(Vector2(lerpf(x0, x1, u), 12.0 + 26.0 * 4.0 * u * (1.0 - u)))
		draw_polyline(pts, Color(0.12, 0.25, 0.18), 3.0)
		for k in range(1, 16, 2):
			var p := pts[k] + Vector2(0, 9)
			var blink := 0.55 + 0.45 * sin(time * 2.2 + float(bulb_i) * 1.3)
			var col: Color = bulb_colors[bulb_i % bulb_colors.size()]
			draw_circle(p, 11.0, Color(col.r, col.g, col.b, 0.16 * blink))
			draw_circle(p, 5.5, col.darkened(0.35).lerp(col, blink))
			bulb_i += 1
