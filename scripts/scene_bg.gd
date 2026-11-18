extends Node2D
## Фон экрана заказа (вид спереди). Режимы:
## "back" — стена, окно со снегом, гирлянда, лампа, часы, ёлка;
## "front" — тёплый свет лампы, виньетка и салют; "vignette" — только виньетка (экран упаковки).

const U = preload("res://scripts/util.gd")

const T_BACK := preload("res://art/shop/order_back.jpg")
const WIN := Rect2(410, 145, 276, 153)   # стекло окна на плите комнаты, сюда падает снег
const LAMP := Vector2(640, 250)
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
	glow_tex = _make_radial(Color(1.0, 0.82, 0.5, 0.09), Color(1.0, 0.82, 0.5, 0.0), 0.0)
	vignette_tex = _make_radial(Color(0.0, 0.0, 0.0, 0.0), Color(0.03, 0.0, 0.05, 0.24), 0.5)


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
		draw_texture_rect(glow_tex, Rect2(LAMP - Vector2(220, 180), Vector2(440, 360)), false, Color(1, 0.95, 0.8, 0.45 * breathe))
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
	# комната нарисована целиком (плита), здесь только то, что живёт: снег за окном и вспышка салюта
	draw_texture_rect(T_BACK, Rect2(0, 0, 1280, 720), false)
	for f in flakes:
		var fy: float = f["y"]
		var fa := 0.9 * minf((fy - WIN.position.y) / 12.0, 1.0)
		draw_circle(Vector2(f["x"], fy), f["r"], Color(1, 1, 1, clampf(fa, 0.0, 0.9)))
	if flash > 0.0:
		draw_rect(WIN, Color(1, 0.95, 0.8, 0.55 * flash))
