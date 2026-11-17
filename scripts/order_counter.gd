extends Node2D
## Экран заказа: мы смотрим из-за прилавка глазами маленького эльфа. Прилавок крупным планом на первом плане,
## на нём касса, банка чаевых, календарь, полка «в наличии», кот, кружка и рамка. Над прилавком клиент,
## сверху четыре вывески-счётчика, внизу две плашки. Здесь же облачка речи и мыслей и подарок при выдаче.

signal item_given
signal offer_pressed(item_id: String)

const Data = preload("res://scripts/data.gd")
const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")

const T_COUNTER := preload("res://art/shop/order_counter.png")
const T_REGISTER := preload("res://art/shop/register.png")
const T_JAR := preload("res://art/shop/jar.png")
const T_CALENDAR := preload("res://art/shop/calendar.png")
const T_STAND := preload("res://art/shop/stand.png")
const T_MUG := preload("res://art/shop/mug.png")
const T_FRAME := preload("res://art/shop/frame.png")
const T_PHOTOS := preload("res://art/shop/photos.png")
const T_ITEMS := {
	"bear": preload("res://art/shop/item_bear.png"),
	"ornament": preload("res://art/shop/item_ornament.png"),
	"ball": preload("res://art/shop/item_ball.png"),
	"train": preload("res://art/shop/item_train.png"),
}

# Прилавок: плита начинается на этой высоте, всё что выше (клиент, комната) рисуется раньше
const COUNTER_TEX_Y := 482.7
const COUNTER_TEX_H := 237.3

# Вещи на прилавке: точка на столешнице (низ спрайта по центру) и высота в игровых px
const REG_POS := Vector2(118, 592)
const REG_H := 262.0
const JAR_POS := Vector2(300, 580)
const JAR_H := 160.0
const JAR_SLOT := Vector2(300, 432)
const CAL_POS := Vector2(440, 575)
const CAL_H := 150.0
const STAND_POS := Vector2(760, 590)
const STAND_H := 250.0
const CAT_POS := Vector2(990, 590)
const CAT_SCALE := 1.0 / 1.5   # кадры кота хранятся в полуторном размере
const MUG_POS := Vector2(1075, 565)
const MUG_H := 82.0
const FRAME_POS := Vector2(1170, 596)
const FRAME_H := 190.0
const PHOTOS_POS := Vector2(1215, 640)
const PHOTOS_H := 62.0

# Полка со ступенями: куда ставится каждый товар (по порядку Data.STOCK) и его размер
const SHELF_POS := [Vector2(765, 408), Vector2(715, 468), Vector2(805, 468), Vector2(760, 528)]
const SHELF_SIZE := {"bear": Vector2(70, 84), "ornament": Vector2(54, 73), "ball": Vector2(92, 56), "train": Vector2(116, 46)}

const CUSTOMER_HAND := Vector2(520, 470)
const GIFT_POS := Vector2(565, 548)
const MOUTH := Vector2(545, 345)

# Вывески сверху и две плашки внизу (вставки для текста)
const TOP_PLAQUES := [Rect2(112, 12, 246, 64), Rect2(386, 12, 248, 64), Rect2(660, 12, 246, 64), Rect2(932, 12, 248, 64)]
const INSET_DAYS := Rect2(403, 642, 203, 54)
const INSET_MONEY := Rect2(735, 642, 204, 55)

const BUBBLE_X := 600.0
const BUBBLE_W := 480.0
const BUBBLE_FONT := 25
const BUBBLE_TOP := 92.0
const BUBBLE_COLOR := Color(0.99, 0.96, 0.9)
const TEXT_LIGHT := Color("#f7e6b5")

var time := 0.0
var font: Font
var bubble_style: StyleBoxFlat
var thought_style: StyleBoxFlat
var bubble_text := ""
var bubble_kind := "speech"   # speech или thought (мысли клиента)
var bubble_name := ""
var bubble_t := 1.0
var offer_enabled := false
var shelf_hover := -1
var tips_shown := 0
var info: Dictionary = {}
var fly_coins: Array = []
var hearts: Array = []
var cat_frames: Array = []     # 16 кадров: 0-1 спит клубком, 2-6 просыпается и садится, 6-7 улыбается, 8-13 укладывается
var cat_state := "sleep"       # sleep, wake, happy, settle
var cat_t := 0.0
var cat_happy_left := 0.0
var cat_frame := 0
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
	for i in 16:
		cat_frames.append(load("res://art/shop/cat_%d.png" % i))
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


func set_tips(n: int) -> void:
	tips_shown = n
	fly_coins.clear()


func add_tip_coins(n: int) -> void:
	for i in n:
		fly_coins.append({"t": -0.22 * float(i), "from": CUSTOMER_HAND + Vector2(20, -20), "to": JAR_SLOT})


func pay_pop() -> void:
	reg_pop = 1.0
	AudioSynth.play_sfx("coin", 0.0, 0.9)


## Выбранный подарок едет на прилавок.
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
	give = {}
	gift_look = {}
	fly_coins.clear()
	tips_shown = 0


## Данные для вывесок и плашек. Ключи: night, nights, clock (минуты), date, day, month, customer, customers,
## patience (0..1, меньше нуля если не идёт), secs, cash, earned, spent, days.
func set_info(d: Dictionary) -> void:
	info = d


# --- Ввод ------------------------------------------------------------------------

func _cat_size() -> Vector2:
	var tex: Texture2D = cat_frames[cat_frame]
	return Vector2(tex.get_width(), tex.get_height()) * CAT_SCALE


func _cat_rect() -> Rect2:
	var sz := _cat_size()
	return Rect2(CAT_POS.x - sz.x * 0.5 - 6.0, CAT_POS.y - sz.y - 6.0, sz.x + 12.0, sz.y + 12.0)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		var p := get_global_mouse_position()
		var over_cat := _cat_rect().has_point(p)
		shelf_hover = _shelf_at(p) if offer_enabled else -1
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (over_cat or shelf_hover >= 0) else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var p2 := get_global_mouse_position()
			if offer_enabled and _shelf_at(p2) >= 0:
				AudioSynth.play_sfx("click")
				offer_pressed.emit(str(Data.STOCK[_shelf_at(p2)]))
			elif _cat_rect().has_point(p2):
				_pet_cat()


func _pet_cat() -> void:
	if cat_state == "sleep" or cat_state == "settle":
		cat_state = "wake"
		cat_t = 0.0
	elif cat_state == "happy":
		cat_happy_left = 2.6
	if purr_cd > 0.0:
		return
	purr_cd = 1.4
	AudioSynth.play_sfx("purr")
	var top := CAT_POS.y - _cat_size().y
	for i in 2:
		hearts.append({"pos": Vector2(CAT_POS.x - 30.0 + float(i) * 24.0, top + 10.0), "t": -0.2 * float(i)})


## Кадр кота по состоянию: клубок дышит, при касании просыпается, садится и улыбается, потом укладывается.
func _update_cat(delta: float) -> void:
	cat_t += delta
	if cat_state == "sleep":
		cat_frame = int(cat_t / 1.4) % 2
	elif cat_state == "wake":
		var k := int(cat_t * 7.0)
		cat_frame = 2 + mini(k, 4)
		if k >= 4:
			cat_state = "happy"
			cat_t = 0.0
			cat_happy_left = 2.6
	elif cat_state == "happy":
		cat_frame = 6 + int(cat_t * 3.5) % 2
		cat_happy_left -= delta
		if cat_happy_left <= 0.0:
			cat_state = "settle"
			cat_t = 0.0
	else:
		var k2 := int(cat_t * 4.5)
		cat_frame = 8 + mini(k2, 5)
		if k2 >= 6:
			cat_state = "sleep"
			cat_t = 0.0


# --- Обновление ------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	bubble_t = minf(bubble_t + delta / 0.7, 1.0)
	gift_t = minf(gift_t + delta / 0.6, 1.0)
	purr_cd = maxf(purr_cd - delta, 0.0)
	jar_bump = maxf(jar_bump - delta * 2.5, 0.0)
	reg_pop = maxf(reg_pop - delta * 2.2, 0.0)
	_update_cat(delta)
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
	_draw_props()
	_draw_shelf()
	_draw_cat()
	_draw_plaques()
	_draw_gift()
	_draw_give()
	_draw_bubble()
	_draw_coins_and_hearts()


## Спрайт вещи: низ по центру в точке feet, высота h; squash сжимает по вертикали (прыжок кассы и банки).
func _prop(tex: Texture2D, feet: Vector2, h: float, squash: float = 1.0, lift: float = 0.0) -> void:
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var sx := 1.0 + (1.0 - squash) * 0.5
	var hh := h * squash
	draw_texture_rect(tex, Rect2(feet.x - w * sx * 0.5, feet.y - hh - lift, w * sx, hh), false)


func _txt(pos: Vector2, text: String, size: int, col: Color, outline: bool = true, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if outline:
		draw_string_outline(font, pos, text, align, width, size, 6, U.INK)
	draw_string(font, pos, text, align, width, size, col)


func _draw_counter() -> void:
	draw_texture_rect(T_COUNTER, Rect2(0.0, COUNTER_TEX_Y, 1280.0, COUNTER_TEX_H), false)


func _draw_props() -> void:
	# касса подпрыгивает, когда клиент платит
	_prop(T_REGISTER, REG_POS, REG_H, 1.0 - 0.08 * sin(reg_pop * PI) * reg_pop)
	# банка: монеты внутри рисуются под стеклом
	var bump := -absf(sin(jar_bump * PI * 3.0)) * 4.0 * jar_bump
	var n := mini(tips_shown, 48)
	for i in n:
		var col_i := i % 6
		var row_i := floori(float(i) / 6.0)
		var hsh := U.hash2(i, 7)
		var p := Vector2(JAR_POS.x - 29.0 + float(col_i) * 11.5 + hsh * 4.0, JAR_POS.y - 12.0 - float(row_i) * 6.5 + bump)
		U.fill_stroke(self, U.ellipse(p, 7.5, 4.2), Color("#e3b84b"), 2.0, time, 0.4)
		draw_circle(p + Vector2(-2.0, -1.0), 1.4, Color(1, 0.95, 0.6, 0.85))
	_prop(T_JAR, JAR_POS, JAR_H, 1.0, -bump)
	# настольный календарь с сегодняшней датой
	_prop(T_CALENDAR, CAL_POS, CAL_H)
	var day := str(info.get("day", ""))
	if day != "":
		draw_set_transform(Vector2(426.0, 528.0), -0.12, Vector2.ONE)
		draw_string(font, Vector2(-30.0, 0.0), day, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 38, U.INK)
		draw_string(font, Vector2(-30.0, 20.0), str(info.get("month", "")), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, Color("#8a4a3a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_prop(T_STAND, STAND_POS, STAND_H)
	_prop(T_MUG, MUG_POS, MUG_H)
	_prop(T_FRAME, FRAME_POS, FRAME_H)
	_prop(T_PHOTOS, PHOTOS_POS, PHOTOS_H)


func _draw_cat() -> void:
	var tex: Texture2D = cat_frames[cat_frame]
	var h := float(tex.get_height()) * CAT_SCALE
	var br := 1.0 - 0.02 * sin(time * 1.6) if cat_state == "sleep" else 1.0
	_prop(tex, CAT_POS, h, br)


# --- Вывески сверху и плашки внизу --------------------------------------------------

func _clock_text(minutes: float) -> String:
	var m := int(fposmod(minutes, 1440.0))
	var h24 := m / 60
	var h12 := (h24 + 11) % 12 + 1
	return "%d:%02d %s" % [h12, m % 60, "AM" if h24 < 12 else "PM"]


func _draw_heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-4.5, -3.0) * s, 5.5 * s, col)
	draw_circle(c + Vector2(4.5, -3.0) * s, 5.5 * s, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9.5, -0.5) * s, c + Vector2(9.5, -0.5) * s, c + Vector2(0, 11.0) * s]), col)


func _draw_plaques() -> void:
	if info.is_empty():
		return
	var pl: Array = TOP_PLAQUES
	# 1. ночь и время
	var r1: Rect2 = pl[0]
	_txt(Vector2(r1.position.x, r1.position.y + 29.0), "Night %d of %d" % [int(info.get("night", 1)), int(info.get("nights", 3))], 25, TEXT_LIGHT, true, HORIZONTAL_ALIGNMENT_CENTER, r1.size.x)
	_txt(Vector2(r1.position.x, r1.position.y + 54.0), "%s · %s" % [_clock_text(float(info.get("clock", 1290.0))), str(info.get("date_short", ""))], 19, Color("#e8d4a0"), true, HORIZONTAL_ALIGNMENT_CENTER, r1.size.x)
	# 2. терпение клиента
	var r2: Rect2 = pl[1]
	var pat: float = float(info.get("patience", -1.0))
	if pat >= 0.0:
		_draw_heart(Vector2(r2.position.x + 34.0, r2.position.y + 36.0), 1.25, Color("#e8505b"))
		var frame := Rect2(r2.position.x + 58.0, r2.position.y + 22.0, 112.0, 26.0)
		draw_rect(frame, Color(0.12, 0.08, 0.07, 0.85))
		var filled := ceili(clampf(pat, 0.0, 1.0) * 10.0)
		var seg_col := Color("#5fd37a") if pat > 0.5 else (Color("#f2c14e") if pat > 0.25 else Color("#e8505b"))
		for i in 10:
			if i < filled:
				draw_rect(Rect2(frame.position.x + 3.0 + float(i) * 10.8, frame.position.y + 4.0, 8.8, frame.size.y - 8.0), seg_col)
		var secs := int(float(info.get("secs", 0.0)))
		_txt(Vector2(r2.position.x + 178.0, r2.position.y + 45.0), "%d:%02d" % [secs / 60, secs % 60], 24, TEXT_LIGHT, true)
	else:
		_txt(Vector2(r2.position.x, r2.position.y + 42.0), "Patience", 22, Color(0.9, 0.82, 0.62, 0.75), true, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x)
	# 3. касса
	var r3: Rect2 = pl[2]
	var cc := Vector2(r3.position.x + 40.0, r3.position.y + 36.0)
	U.fill_stroke(self, U.ellipse(cc, 17.0, 17.0, 0.0, 22), Color("#e3b84b"), 3.0, time, 0.5)
	draw_circle(cc + Vector2(-5.0, -5.0), 4.0, Color(1, 0.95, 0.65, 0.8))
	_txt(Vector2(r3.position.x + 66.0, r3.position.y + 47.0), str(int(info.get("cash", 0))), 36, TEXT_LIGHT, true)
	_txt(Vector2(r3.position.x + 150.0, r3.position.y + 28.0), "cash", 16, Color("#e8d4a0"), true)
	# 4. чаевые и номер клиента
	var r4: Rect2 = pl[3]
	_txt(Vector2(r4.position.x + 20.0, r4.position.y + 28.0), "Tips", 18, Color("#e8d4a0"), true)
	_txt(Vector2(r4.position.x + 20.0, r4.position.y + 54.0), str(tips_shown), 30, TEXT_LIGHT, true)
	_txt(Vector2(r4.position.x + 92.0, r4.position.y + 28.0), "Customer", 18, Color("#e8d4a0"), true)
	_txt(Vector2(r4.position.x + 92.0, r4.position.y + 54.0), "%d of %d" % [int(info.get("customer", 1)), int(info.get("customers", 1))], 28, TEXT_LIGHT, true)
	# внизу: дней до Нового года
	var days := int(info.get("days", 3))
	var d := str(days)
	var numw := font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	draw_string(font, Vector2(INSET_DAYS.position.x + 14.0, INSET_DAYS.end.y - 8.0), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, U.INK)
	var label := "day to\nNew Year" if days == 1 else "days to\nNew Year"
	draw_multiline_string(font, Vector2(INSET_DAYS.position.x + 24.0 + numw, INSET_DAYS.position.y + 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, -1, Color("#6a3d28"))
	# внизу: учёт денег за ночь
	draw_string(font, Vector2(INSET_MONEY.position.x + 12.0, INSET_MONEY.position.y + 26.0), "Earned +%d" % int(info.get("earned", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#8a5a10"))
	draw_string(font, Vector2(INSET_MONEY.position.x + 12.0, INSET_MONEY.end.y - 7.0), "spent %d  ·  cash %d" % [int(info.get("spent", 0)), int(info.get("cash", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#6a3d28"))


# --- Монеты и сердечки ----------------------------------------------------------------

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


func _draw_bubble() -> void:
	if bubble_text == "":
		return
	var tsize := font.get_multiline_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 56.0, BUBBLE_FONT)
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
		var tail := PackedVector2Array([Vector2(rect.position.x + 20.0, rect.end.y - 64.0), Vector2(rect.position.x + 20.0, rect.end.y - 14.0), MOUTH])
		draw_colored_polygon(tail, BUBBLE_COLOR)
		draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), U.INK, 4.0, true)
		draw_rect(Rect2(rect.position.x + 17.0, rect.end.y - 62.0, 6.0, 46.0), BUBBLE_COLOR)
	draw_string(font, Vector2(rect.position.x + 28.0, rect.position.y + 34.0), bubble_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.38, 0.26) if bubble_kind == "speech" else Color(0.32, 0.4, 0.62))
	draw_multiline_string(font, Vector2(rect.position.x + 28.0, rect.position.y + 44.0 + font.get_ascent(BUBBLE_FONT)), bubble_text,
		HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 56.0, BUBBLE_FONT, -1, U.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Подарок ---------------------------------------------------------------------------

func _draw_give() -> void:
	if give.is_empty():
		return
	var t: float = give["t"]
	var id: String = give["id"]
	var a := CUSTOMER_HAND
	var b := GIFT_POS
	var e := U.ease_in_out(t)
	var pos := a.lerp(b, e) + Vector2(0.0, -sin(e * PI) * 90.0)
	var s := 1.0 + 0.1 * sin(e * PI)
	var sz: Vector2 = SHELF_SIZE[id]
	draw_texture_rect(T_ITEMS[id], Rect2(pos - sz * s * 0.5, sz * s), false)


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

func _shelf_rect(i: int) -> Rect2:
	var id := str(Data.STOCK[i])
	var sz: Vector2 = SHELF_SIZE[id]
	var p: Vector2 = SHELF_POS[i]
	return Rect2(p.x - sz.x * 0.5, p.y - sz.y, sz.x, sz.y).grow(8.0)


func _shelf_at(p: Vector2) -> int:
	for i in Data.STOCK.size():
		if _shelf_rect(i).has_point(p):
			return i
	return -1


func _draw_shelf() -> void:
	for i in Data.STOCK.size():
		var id := str(Data.STOCK[i])
		var sz: Vector2 = SHELF_SIZE[id]
		var p: Vector2 = SHELF_POS[i]
		var hov := (i == shelf_hover)
		var hint := 0.0
		if offer_enabled:
			hint = 0.5 + 0.5 * sin(time * 4.0 + float(i))
		var k := 1.14 if hov else 1.0 + 0.03 * hint
		var s2 := sz * k
		if hov:
			draw_circle(p + Vector2(0.0, -sz.y * 0.5), 52.0, Color(1.0, 0.92, 0.55, 0.28))
		draw_texture_rect(T_ITEMS[id], Rect2(p.x - s2.x * 0.5, p.y - s2.y, s2.x, s2.y), false)
		if hov:
			var it: Dictionary = Data.ITEMS[id]
			_txt(Vector2(p.x - 80.0, p.y - sz.y - 18.0), str(it["name"]), 17, Color(1, 0.96, 0.85, 0.98), true, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
