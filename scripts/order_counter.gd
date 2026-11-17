extends Node2D
## Экран заказа: прилавок, касса, банка чаевых, кот, облачко с просьбой и кнопка «Принять заказ».
## Также показывает вещь клиента на пути к столу и готовый подарок при выдаче.

signal accept_pressed
signal item_given
signal offer_pressed(item_id: String)

const Data = preload("res://scripts/data.gd")
const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")
const ItemArt = preload("res://scripts/item_art.gd")

const COUNTER_Y := 540.0
const CUSTOMER_HAND := Vector2(470, 470)
const JAR_POS := Vector2(1205, 500)
const REG_POS := Vector2(130, 500)
const CAT_POS := Vector2(1000, 520)
const SHELF_X0 := 550.0
const SHELF_DX := 114.0
const SHELF_FIT := 86.0
const ACCEPT_RECT := Rect2(490, 598, 300, 66)
const CUSTOMER_RECT := Rect2(280, 120, 240, 420)
const GIFT_POS := Vector2(640, 510)
const BUBBLE_X := 540.0
const BUBBLE_W := 580.0
const BUBBLE_TOP := 36.0
const BUBBLE_COLOR := Color(0.99, 0.96, 0.9)

var time := 0.0
var font: Font
var bubble_style: StyleBoxFlat
var button_style: StyleBoxFlat
var jar_style: StyleBoxFlat
var accept_enabled := false
var accept_t := 0.0
var hover_accept := false
var bubble_text := ""
var bubble_kind := "speech"   # speech или thought (мысли клиента)
var offer_enabled := false
var shelf_hover := -1
var thought_style: StyleBoxFlat
var bubble_name := ""
var bubble_t := 1.0
var tips_shown := 0
var fly_coins: Array = []
var hearts: Array = []
var cat_ear_t := 0.0
var cat_next_ear := 4.0
var purr_cd := 0.0
var jar_bump := 0.0
var reg_pop := 0.0
var give: Dictionary = {}
var gift_look: Dictionary = {}
var gift_poly := PackedVector2Array()
var gift_t := 0.0
var input_enabled := true


func _ready() -> void:
	font = ThemeDB.fallback_font
	bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = BUBBLE_COLOR
	bubble_style.border_color = U.INK
	bubble_style.set_border_width_all(4)
	bubble_style.set_corner_radius_all(26)
	bubble_style.shadow_color = Color(0, 0, 0, 0.3)
	bubble_style.shadow_size = 8
	thought_style = StyleBoxFlat.new()
	thought_style.bg_color = Color(0.91, 0.94, 1.0)
	thought_style.border_color = U.INK
	thought_style.set_border_width_all(4)
	thought_style.set_corner_radius_all(44)
	thought_style.shadow_color = Color(0, 0, 0, 0.3)
	thought_style.shadow_size = 8
	button_style = StyleBoxFlat.new()
	button_style.bg_color = Color("#f0c05a")
	button_style.border_color = U.INK
	button_style.set_border_width_all(4)
	button_style.set_corner_radius_all(22)
	button_style.shadow_color = Color(0, 0, 0, 0.35)
	button_style.shadow_size = 8
	jar_style = StyleBoxFlat.new()
	jar_style.bg_color = Color(0.8, 0.9, 1.0, 0.12)
	jar_style.border_color = Color(0.9, 0.95, 1.0, 0.6)
	jar_style.set_border_width_all(3)
	jar_style.set_corner_radius_all(14)


# --- Публичное API -----------------------------------------------------------

## Мысли клиента: мы читаем их и подбираем подарок с полки.
func show_thought(person: String, text: String) -> void:
	bubble_kind = "thought"
	bubble_name = "Thoughts: " + person
	bubble_text = text
	bubble_t = 0.0


func set_offer(on: bool) -> void:
	offer_enabled = on
	shelf_hover = -1


func show_bubble(person: String, text: String) -> void:
	bubble_kind = "speech"
	bubble_name = person
	bubble_text = text
	bubble_t = 0.0


func hide_bubble() -> void:
	bubble_text = ""


func set_accept(on: bool) -> void:
	accept_enabled = on
	if on:
		accept_t = 0.0


func set_tips(n: int) -> void:
	tips_shown = n
	fly_coins.clear()


func add_tip_coins(n: int) -> void:
	for i in n:
		fly_coins.append({"t": -0.22 * float(i), "from": CUSTOMER_HAND + Vector2(20, -40), "to": JAR_POS + Vector2(0, -52)})


func pay_pop() -> void:
	reg_pop = 1.0
	AudioSynth.play_sfx("coin", 0.0, 0.9)


## Вещь клиента едет на прилавок.
func give_item(item_id: String) -> void:
	give = {"id": item_id, "t": 0.0}
	AudioSynth.play_sfx("pop_in")


func show_gift(look: Dictionary) -> void:
	gift_look = look
	gift_t = 0.0
	var kind: String = look["kind"]
	var w: float = look["w"]
	var h: float = look["h"]
	if look["wrap_mode"] == "shape":
		var sil := Shapes.silhouette(kind)
		var offs := Geometry2D.offset_polygon(sil, 6.0, Geometry2D.JOIN_ROUND)
		gift_poly = offs[0] if offs.size() > 0 else sil
	else:
		gift_poly = U.rect_pts(Rect2(-w * 0.5, -h * 0.5, w, h))
	AudioSynth.play_sfx("pop_in")


func clear_gift() -> void:
	gift_look = {}


func reset() -> void:
	bubble_text = ""
	offer_enabled = false
	accept_enabled = false
	give = {}
	gift_look = {}
	fly_coins.clear()
	tips_shown = 0


# --- Ввод ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		var p := get_global_mouse_position()
		hover_accept = accept_enabled and (ACCEPT_RECT.has_point(p) or CUSTOMER_RECT.has_point(p))
		var over_cat := p.distance_to(CAT_POS + Vector2(-5, 0)) < 50.0
		shelf_hover = _shelf_at(p) if offer_enabled else -1
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (hover_accept or over_cat or shelf_hover >= 0) else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var p2 := get_global_mouse_position()
			if p2.distance_to(CAT_POS + Vector2(-5, 0)) < 50.0:
				_pet_cat()
			elif offer_enabled and _shelf_at(p2) >= 0:
				AudioSynth.play_sfx("click")
				offer_pressed.emit(str(Data.STOCK[_shelf_at(p2)]))
			elif accept_enabled and (ACCEPT_RECT.has_point(p2) or CUSTOMER_RECT.has_point(p2)):
				accept_enabled = false
				hover_accept = false
				AudioSynth.play_sfx("click")
				accept_pressed.emit()


func _pet_cat() -> void:
	if purr_cd > 0.0:
		return
	purr_cd = 1.4
	AudioSynth.play_sfx("purr")
	for i in 2:
		hearts.append({"pos": CAT_POS + Vector2(-30.0 + float(i) * 18.0, -34.0), "t": -0.2 * float(i)})


# --- Обновление ------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	bubble_t = minf(bubble_t + delta / 0.7, 1.0)
	accept_t = minf(accept_t + delta / 0.5, 1.0)
	gift_t = minf(gift_t + delta / 0.6, 1.0)
	purr_cd = maxf(purr_cd - delta, 0.0)
	jar_bump = maxf(jar_bump - delta * 2.5, 0.0)
	reg_pop = maxf(reg_pop - delta * 2.2, 0.0)
	cat_next_ear -= delta
	if cat_next_ear <= 0.0:
		cat_ear_t = 0.25
		cat_next_ear = randf_range(3.0, 8.0)
	cat_ear_t = maxf(cat_ear_t - delta, 0.0)
	for i in range(hearts.size() - 1, -1, -1):
		hearts[i]["t"] += delta / 1.2
		hearts[i]["pos"] += Vector2(0.0, -28.0 * delta)
		if hearts[i]["t"] >= 1.0:
			hearts.remove_at(i)
	for i in range(fly_coins.size() - 1, -1, -1):
		fly_coins[i]["t"] += delta / 0.75
		if fly_coins[i]["t"] >= 1.0:
			fly_coins.remove_at(i)
			tips_shown += 1
			jar_bump = 1.0
			AudioSynth.play_sfx("coin", 0.0, randf_range(0.95, 1.15))
	if not give.is_empty():
		give["t"] += delta / 0.8
		if give["t"] >= 1.0:
			give = {}
			item_given.emit()
	queue_redraw()


# --- Рисование -------------------------------------------------------------------

func _draw() -> void:
	_draw_counter()
	_draw_register()
	_draw_jar()
	_draw_shelf()
	_draw_cat()
	_draw_gift()
	_draw_give()
	_draw_accept()
	_draw_bubble()
	_draw_coins_and_hearts()


func _draw_counter() -> void:
	draw_rect(Rect2(0, COUNTER_Y, 1280, 180), Color("#5a3a26"))
	for i in 4:
		var r := Rect2(30.0 + float(i) * 310.0, COUNTER_Y + 54.0, 270, 100)
		draw_rect(r, Color(0, 0, 0, 0.16))
		U.stroke(self, U.rect_pts(r), Color(0, 0, 0, 0.5), 3.0, time, 1.0)
	draw_rect(Rect2(0, COUNTER_Y, 1280, 30), Color("#8c5d3b"))
	draw_rect(Rect2(0, COUNTER_Y + 30.0, 1280, 6), Color(0, 0, 0, 0.3))
	U.stroke(self, PackedVector2Array([Vector2(0, COUNTER_Y), Vector2(1280, COUNTER_Y)]), U.INK, 5.0, time, 1.3, false)


func _draw_register() -> void:
	var c := REG_POS
	var sq := 1.0 + 0.10 * sin(reg_pop * PI) * reg_pop
	draw_set_transform(Vector2(0.0, (c.y + 40.0) * (1.0 - sq)), 0.0, Vector2(1.0, sq))
	U.fill_stroke(self, U.rect_pts(Rect2(c.x - 72.0, c.y - 28.0, 144.0, 70.0)), Color("#4b6a6a"), 4.0, time)
	U.fill_stroke(self, PackedVector2Array([Vector2(c.x - 54.0, c.y - 28.0), Vector2(c.x + 54.0, c.y - 28.0), Vector2(c.x + 40.0, c.y - 64.0), Vector2(c.x - 40.0, c.y - 64.0)]), Color("#35504f"), 4.0, time)
	draw_rect(Rect2(c.x - 32.0, c.y - 58.0, 64.0, 22.0), Color("#cfe8c8"))
	draw_colored_polygon(U.star(Vector2(c.x, c.y - 47.0), 8.0, 3.2, 4, 0.0), Color("#35504f"))
	for i in 6:
		draw_circle(Vector2(c.x - 40.0 + float(i % 3) * 20.0, c.y - 10.0 + float(i / 3) * 18.0), 6.0, Color("#e8d9a8"))
	draw_rect(Rect2(c.x - 50.0, c.y + 30.0, 100.0, 8.0), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_jar() -> void:
	var c := JAR_POS + Vector2(0.0, -absf(sin(jar_bump * PI * 3.0)) * 4.0 * jar_bump)
	draw_colored_polygon(U.ellipse(c + Vector2(0, 42), 42.0, 9.0), Color(0, 0, 0, 0.28))
	var n := mini(tips_shown, 48)
	for i in n:
		var col_i := i % 6
		var row_i := floori(float(i) / 6.0)
		var h := U.hash2(i, 7)
		var p := Vector2(c.x - 24.0 + float(col_i) * 9.6 + h * 3.0, c.y + 33.0 - float(row_i) * 5.2)
		draw_colored_polygon(U.ellipse(p, 6.2, 3.4), Color("#d9a92e"))
		draw_circle(p + Vector2(-1.5, -0.8), 1.1, Color(1, 0.95, 0.6, 0.8))
	draw_style_box(jar_style, Rect2(c.x - 36.0, c.y - 40.0, 72.0, 84.0))
	U.fill_stroke(self, U.rect_pts(Rect2(c.x - 40.0, c.y - 52.0, 80.0, 14.0)), Color("#c0392b"), 3.0, time)
	draw_string(font, Vector2(c.x - 40.0, c.y + 68.0), "Tips: " + str(tips_shown), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 15, Color(1, 0.93, 0.7))


func _draw_cat() -> void:
	var p := CAT_POS
	var br := 1.0 + 0.03 * sin(time * 1.6)
	var fur := Color("#c98a4b")
	var dark := Color("#8f5a2c")
	draw_colored_polygon(U.ellipse(p + Vector2(8, 28), 54.0, 8.0), Color(0, 0, 0, 0.25))
	var tail := PackedVector2Array()
	for k in 12:
		var u := float(k) / 11.0
		tail.append(p + Vector2(46.0 + u * 28.0, 18.0 - sin(u * PI) * 20.0 + sin(time * 1.3 + u * 2.0) * 3.0 * u))
	draw_polyline(tail, U.INK, 13.0, true)
	draw_polyline(tail, fur, 8.0, true)
	U.fill_stroke(self, U.ellipse(p + Vector2(8, 8), 46.0, 28.0 * br), fur, 3.5, time)
	for k in 3:
		var bx := p.x + 10.0 + float(k) * 14.0
		draw_line(Vector2(bx, p.y - 14.0), Vector2(bx + 4.0, p.y + 2.0), dark, 3.0)
	var hp := p + Vector2(-34, -6)
	var tw := sin(cat_ear_t * 40.0) * 0.25 if cat_ear_t > 0.0 else 0.0
	U.fill_stroke(self, PackedVector2Array([hp + Vector2(-20, -8), hp + Vector2(-17, -30), hp + Vector2(-4, -17)]), fur, 3.0, time)
	var ear2 := PackedVector2Array([Vector2(20, -8), Vector2(17, -30), Vector2(4, -17)])
	for k in ear2.size():
		ear2[k] = hp + ear2[k].rotated(tw)
	U.fill_stroke(self, ear2, fur, 3.0, time)
	U.fill_stroke(self, U.ellipse(hp, 22.0, 20.0), fur, 3.5, time)
	draw_arc(hp + Vector2(-8, -1), 5.0, 0.2, PI - 0.2, 8, U.INK, 2.5)
	draw_arc(hp + Vector2(8, -1), 5.0, 0.2, PI - 0.2, 8, U.INK, 2.5)
	draw_circle(hp + Vector2(0, 6), 2.4, Color("#e58a8a"))


func _draw_coins_and_hearts() -> void:
	for fc in fly_coins:
		var t: float = fc["t"]
		if t < 0.0:
			continue
		var a: Vector2 = fc["from"]
		var b: Vector2 = fc["to"]
		var pos := a.lerp(b, U.ease_in_out(t)) + Vector2(0.0, -sin(t * PI) * 110.0)
		var squash := 1.0 + 0.25 * sin(t * PI * 3.0)
		U.fill_stroke(self, U.ellipse(pos, 9.0 * squash, 6.0 / squash), Color("#e6b83a"), 2.5, time, 0.6)
	for h in hearts:
		var t2: float = h["t"]
		if t2 < 0.0:
			continue
		var pos2: Vector2 = h["pos"]
		var col := Color(1.0, 0.45, 0.55, 1.0 - t2)
		draw_circle(pos2 + Vector2(-4, -3), 5.0, col)
		draw_circle(pos2 + Vector2(4, -3), 5.0, col)
		draw_colored_polygon(PackedVector2Array([pos2 + Vector2(-9, 0), pos2 + Vector2(9, 0), pos2 + Vector2(0, 11)]), col)


func _draw_accept() -> void:
	if not accept_enabled:
		return
	var s := U.ease_out_back(accept_t) * (1.0 + 0.03 * sin(time * 4.0))
	if hover_accept:
		s *= 1.05
	var c := ACCEPT_RECT.get_center()
	draw_set_transform(c * (1.0 - s), 0.0, Vector2(s, s))
	draw_style_box(button_style, ACCEPT_RECT)
	draw_string(font, Vector2(ACCEPT_RECT.position.x, c.y + 11.0), "Take the order", HORIZONTAL_ALIGNMENT_CENTER, ACCEPT_RECT.size.x, 30, U.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bubble() -> void:
	if bubble_text == "":
		return
	var tsize := font.get_multiline_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 56.0, 28)
	var h := tsize.y + 66.0
	var rect := Rect2(BUBBLE_X, BUBBLE_TOP, BUBBLE_W, h)
	var s := maxf(U.ease_out_elastic(bubble_t), 0.001)
	var pivot := Vector2(rect.position.x, rect.end.y)
	draw_set_transform(pivot * (1.0 - s), 0.0, Vector2(s, s))
	if bubble_kind == "thought":
		draw_style_box(thought_style, rect)
		var puffs := [Vector2(rect.position.x + 26.0, rect.end.y + 18.0), Vector2(rect.position.x - 6.0, rect.end.y + 42.0), Vector2(rect.position.x - 30.0, rect.end.y + 62.0)]
		var radii := [13.0, 9.0, 6.0]
		for k in 3:
			var pc: Vector2 = puffs[k]
			U.fill_stroke(self, U.ellipse(pc, float(radii[k]), float(radii[k]), 0.0, 16), Color(0.91, 0.94, 1.0), 3.0, time)
		for k in 4:
			var sp := Vector2(rect.position.x + 40.0 + float(k) * (rect.size.x - 80.0) / 3.0, rect.position.y - 8.0 + 4.0 * sin(time * 3.0 + float(k)))
			draw_colored_polygon(U.star(sp, 7.0, 2.6, 4, time + float(k)), Color(0.7, 0.8, 1.0, 0.6 + 0.4 * sin(time * 4.0 + float(k))))
	else:
		draw_style_box(bubble_style, rect)
		var tail := PackedVector2Array([Vector2(rect.position.x + 20.0, rect.end.y - 64.0), Vector2(rect.position.x + 20.0, rect.end.y - 14.0), Vector2(478, 290)])
		draw_colored_polygon(tail, BUBBLE_COLOR)
		draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), U.INK, 4.0, true)
		draw_rect(Rect2(rect.position.x + 17.0, rect.end.y - 62.0, 6.0, 46.0), BUBBLE_COLOR)
	draw_string(font, Vector2(rect.position.x + 28.0, rect.position.y + 34.0), bubble_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.38, 0.26) if bubble_kind == "speech" else Color(0.32, 0.4, 0.62))
	draw_multiline_string(font, Vector2(rect.position.x + 28.0, rect.position.y + 44.0 + font.get_ascent(28)), bubble_text,
		HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 56.0, 28, -1, U.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Вещь и подарок --------------------------------------------------------------

func _draw_give() -> void:
	if give.is_empty():
		return
	var t: float = give["t"]
	var id: String = give["id"]
	var it: Dictionary = Data.ITEMS[id]
	var a := CUSTOMER_HAND
	var b := GIFT_POS
	var e := U.ease_in_out(t)
	var pos := a.lerp(b, e) + Vector2(0.0, -sin(e * PI) * 90.0)
	var s := 0.55 + 0.1 * sin(e * PI)
	draw_set_transform(pos, 0.0, Vector2(s, s))
	var col := Color.html(it["color"])
	var kind: String = it["kind"]
	if kind == "box":
		var w := float(it["w"])
		var h := float(it["h"])
		U.fill_stroke(self, U.rect_pts(Rect2(-w * 0.5, -h * 0.5, w, h)), col, 5.0, time)
		draw_rect(Rect2(-9.0, -h * 0.5, 18.0, h), Color("#dccfab"))
	else:
		ItemArt.draw(self, kind, it, time)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gift() -> void:
	if gift_look.is_empty():
		return
	var e := U.ease_out_back(gift_t)
	var s := 0.62 * maxf(e, 0.001)
	draw_set_transform(GIFT_POS + Vector2(0.0, 12.0 * (1.0 - e)), 0.0, Vector2(s, s))
	var base := Color.html(gift_look["base"])
	var acc := Color.html(gift_look["accent"])
	var shape: bool = gift_look["wrap_mode"] == "shape"
	var item_id: String = gift_look["item_id"]
	var tail_data: Array = []
	if shape and Data.ITEMS[item_id].has("tail"):
		tail_data = Data.ITEMS[item_id]["tail"]
	var ribbon_col := Color.html(gift_look["ribbon"]) if gift_look["ribbon"] != "" else Color(0, 0, 0, 0)
	var has_ribbon: bool = gift_look["ribbon"] != ""
	var bow: float = gift_look["bow"]
	# собранный хвост
	if not tail_data.is_empty():
		var b := Vector2(float(tail_data[0]), float(tail_data[1]))
		var d := Vector2(float(tail_data[2]), float(tail_data[3]))
		var ln: float = float(tail_data[4])
		var pp := d.rotated(PI * 0.5)
		var fan := PackedVector2Array([
			b - d * 10.0 + pp * -13.0, b + d * ln + pp * -36.0, b + d * (ln * 0.88) + pp * -16.0,
			b + d * (ln * 1.06), b + d * (ln * 0.88) + pp * 16.0, b + d * ln + pp * 36.0, b - d * 10.0 + pp * 13.0])
		U.fill_stroke(self, fan, base, 5.0, time)
	U.fill_stroke(self, gift_poly, base, 5.0, time)
	# рисунок бумаги: мелкие акценты
	var bounds := Rect2(-130, -130, 260, 260)
	for gx in range(-4, 5):
		for gy in range(-4, 5):
			var c := Vector2(float(gx) * 30.0 + float(gy % 2) * 15.0, float(gy) * 30.0)
			if bounds.has_point(c) and Geometry2D.is_point_in_polygon(c, gift_poly):
				draw_circle(c, 4.0, Color(acc.r, acc.g, acc.b, 0.7))
	if has_ribbon:
		if tail_data.is_empty():
			var w: float = gift_look["w"]
			var h: float = gift_look["h"]
			draw_rect(Rect2(-w * 0.5, -9.0, w, 18.0), ribbon_col)
			draw_rect(Rect2(-9.0, -h * 0.5, 18.0, h), ribbon_col)
			U.draw_bow(self, Vector2.ZERO, bow, ribbon_col, time)
		else:
			var b2 := Vector2(float(tail_data[0]), float(tail_data[1]))
			var d2 := Vector2(float(tail_data[2]), float(tail_data[3]))
			var pp2 := d2.rotated(PI * 0.5)
			draw_line(b2 + pp2 * -22.0, b2 + pp2 * 22.0, U.INK, 14.0)
			draw_line(b2 + pp2 * -22.0, b2 + pp2 * 22.0, ribbon_col, 9.0)
			U.draw_bow(self, b2 + d2 * 6.0, bow * 0.8, ribbon_col, time)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Полка «в наличии» ----------------------------------------------------------

func _shelf_scale(i: int) -> float:
	var it: Dictionary = Data.ITEMS[str(Data.STOCK[i])]
	var fit := SHELF_FIT * (1.3 if str(it["kind"]) == "train" else 1.0)
	return fit / maxf(float(it["w"]), float(it["h"]))


func _shelf_rect(i: int) -> Rect2:
	var x := SHELF_X0 + float(i) * SHELF_DX
	return Rect2(x - 52.0, COUNTER_Y - 104.0, 104.0, 108.0)


func _shelf_at(p: Vector2) -> int:
	for i in Data.STOCK.size():
		if _shelf_rect(i).has_point(p):
			return i
	return -1


func _draw_shelf() -> void:
	# табличка и деревянная подставка
	var x0 := SHELF_X0 - 62.0
	var x1 := SHELF_X0 + float(Data.STOCK.size() - 1) * SHELF_DX + 62.0
	draw_rect(Rect2(x0, COUNTER_Y - 6.0, x1 - x0, 8.0), Color("#a87c52"))
	U.stroke(self, U.rect_pts(Rect2(x0, COUNTER_Y - 6.0, x1 - x0, 8.0)), U.INK, 3.0, time, 1.0)
	draw_string(font, Vector2(x0, COUNTER_Y + 22.0), "In stock", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.93, 0.75, 0.8))
	for i in Data.STOCK.size():
		var id := str(Data.STOCK[i])
		var it: Dictionary = Data.ITEMS[id]
		var kind: String = it["kind"]
		var sc := _shelf_scale(i)
		var hov := (i == shelf_hover)
		var hint := 0.0
		if offer_enabled:
			hint = 0.5 + 0.5 * sin(time * 4.0 + float(i))
		var s := sc * (1.14 if hov else 1.0 + 0.03 * hint)
		var x := SHELF_X0 + float(i) * SHELF_DX
		var half_h := float(it["h"]) * 0.5 * s
		if hov:
			draw_circle(Vector2(x, COUNTER_Y - 6.0 - half_h), 56.0, Color(1.0, 0.92, 0.55, 0.22))
		draw_set_transform(Vector2(x, COUNTER_Y - 8.0 - half_h), 0.0, Vector2(s, s))
		ItemArt.draw(self, kind, it, time)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if hov:
			var nm: String = it["name"]
			draw_string(font, Vector2(x - 60.0, COUNTER_Y - 112.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 15, Color(1, 0.96, 0.85, 0.95))
