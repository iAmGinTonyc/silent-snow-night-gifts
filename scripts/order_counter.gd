extends Node2D
## Экран заказа: мы смотрим из-за прилавка глазами маленького эльфа. Прилавок крупным планом на первом плане,
## на нём касса, банка чаевых, календарь, полка «в наличии», кот, кружка и рамка. Над прилавком клиент,
## сверху четыре вывески-счётчика, внизу две плашки. Здесь же облачка речи и мыслей и подарок при выдаче.

signal item_given
signal gift_clicked
signal offer_pressed(item_id: String)
signal shelf_toggled(open: bool)

const Data = preload("res://scripts/data.gd")
const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")

const T_COUNTER := preload("res://art/shop/order_counter.png")
## Копилка: 16 картинок от пустой до переполненной, кадр выбирается по сумме денег (JAR_LEVELS).
const T_JARS: Array[Texture2D] = [
	preload("res://art/shop/jar_0.png"), preload("res://art/shop/jar_1.png"), preload("res://art/shop/jar_2.png"),
	preload("res://art/shop/jar_3.png"), preload("res://art/shop/jar_4.png"), preload("res://art/shop/jar_5.png"),
	preload("res://art/shop/jar_6.png"), preload("res://art/shop/jar_7.png"), preload("res://art/shop/jar_8.png"),
	preload("res://art/shop/jar_9.png"), preload("res://art/shop/jar_10.png"), preload("res://art/shop/jar_11.png"),
	preload("res://art/shop/jar_12.png"), preload("res://art/shop/jar_13.png"), preload("res://art/shop/jar_14.png"),
	preload("res://art/shop/jar_15.png"),
]
const T_SHELF_VIEW := preload("res://art/shop/shelf_closeup.jpg")
const T_MUG := preload("res://art/shop/mug.png")
const T_FRAME := preload("res://art/shop/frame.png")
const T_ITEMS := {
	"bear": preload("res://art/shop/item_bear.png"),
	"ornament": preload("res://art/shop/item_ornament.png"),
	"ball": preload("res://art/shop/item_ball.png"),
	"train": preload("res://art/shop/item_train.png"),
	"bear_mid": preload("res://art/shop/item_bear_mid.png"),
	"ornament_mid": preload("res://art/shop/item_ornament_mid.png"),
	"ball_mid": preload("res://art/shop/item_ball_mid.png"),
	"train_mid": preload("res://art/shop/item_train_mid.png"),
}

# Прилавок: плита начинается на этой высоте, всё что выше (клиент, комната) рисуется раньше
const COUNTER_TEX_Y := 482.7
const COUNTER_TEX_H := 237.3

# Вещи на прилавке: точка на столешнице (низ спрайта по центру) и высота в игровых px
const JAR_POS := Vector2(300, 580)
const JAR_H := 160.0
const JAR_SLOT := Vector2(300, 432)
const JAR_W := JAR_H * 235.0 / 333.0   # ширина копилки; высота по картинке (у переполненной монеты торчат выше горлышка)
## Сколько денег нужно для кадра копилки i (значения по умолчанию).
const JAR_LEVELS := [0, 1, 10, 25, 45, 70, 100, 135, 175, 220, 270, 330, 400, 480, 570, 680]
const CAT_POS := Vector2(122, 592)
const CAT_SCALE := 1.0 / 1.5   # кадры кота хранятся в полуторном размере
const MUG_POS := Vector2(1075, 565)
const MUG_H := 82.0
const FRAME_POS := Vector2(1160, 590)
const FRAME_H := 190.0

# Размер спрайта товара на прилавке (для подарка, который летит к клиенту)
const SHELF_SIZE := {"bear": Vector2(70, 84), "ornament": Vector2(54, 73), "ball": Vector2(74, 76), "train": Vector2(118, 40)}

# Полка на правой стене комнаты (на плите комнаты): клик открывает полку крупным планом
const WALL_SHELF := Rect2(1092, 78, 188, 392)
# Полка крупным планом: картинка под вывесками и место каждой игрушки. Простые игрушки (Data.STOCK) стоят
# на верхней доске, дорогие (Data.STOCK_MID) на нижней, один вид в одной колонке; точка — низ спрайта по центру
const SHELF_VIEW := Rect2(0, 86, 1280, 634)
const SHELF_SLOTS := {
	"bear": Vector2(170, 388), "ornament": Vector2(400, 388), "ball": Vector2(620, 388), "train": Vector2(950, 388),
	"bear_mid": Vector2(190, 611), "ornament_mid": Vector2(440, 611), "ball_mid": Vector2(700, 611), "train_mid": Vector2(990, 611),
}
const SHELF_BUBBLE_X := 790.0   # пока полка открыта, мысли клиента сдвигаются вправо и ничего не закрывают
const SHELF_VIEW_SCALE := 1.6
const BACK_BTN := Rect2(34, 650, 170, 48)
const CUSTOMER_HAND := Vector2(520, 470)
const GIFT_POS := Vector2(565, 548)
const KEEP_POS := Vector2(930, 556)   # подарки, которые подарили нам самим, остаются на прилавке
const KEEP_STEP := 92.0               # следующий такой подарок встаёт левее
const KEEP_SCALE := 0.36
const TABLE_ITEM_SCALE := 1.5   # игрушка на столе крупнее, чем на полке: её нужно нажать
const MOUTH := Vector2(555, 300)

# Вывески сверху и две плашки внизу (вставки для текста)
const TOP_PLAQUES := [Rect2(112, 12, 246, 64), Rect2(386, 12, 248, 64), Rect2(660, 12, 246, 64), Rect2(932, 12, 248, 64)]
const INSET_DAYS := Rect2(403, 642, 203, 54)
const INSET_MONEY := Rect2(735, 642, 204, 55)

const BUBBLE_X := 640.0
const BUBBLE_PAD := 40.0   # поля текста внутри облачка
const BUBBLE_W := 480.0
const BUBBLE_FONT := 25
const BUBBLE_TOP := 92.0
const BUBBLE_COLOR := Color(0.99, 0.96, 0.9)
const TEXT_LIGHT := Color("#f7e6b5")

var time := 0.0
var font: Font
var bubble_style: StyleBoxFlat
var thought_style: StyleBoxFlat
var water_style: StyleBoxFlat
var thought_fill := 0.0       # 0..1: облачко мыслей как сосуд, серая «вода» поднимается снизу вверх (время мыслей)
var bubble_text := ""
var bubble_kind := "speech"   # speech или thought (мысли клиента)
var bubble_name := ""
var bubble_t := 1.0
var offer_enabled := false
var shelf_hover_id := ""      # какая игрушка под мышью на полке крупным планом
var stock_counts: Dictionary = {}   # {item_id: сколько штук}; пока set_stock не вызывали, запас не ограничен
var stock_set := false
var shelf_open := false       # открыта полка крупным планом
var shelf_t := 0.0            # 0..1, плавное открытие
var wall_hover := false       # мышь над полкой на стене
var back_hover := false
var glow_style: StyleBoxFlat
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
var pending_money := 0.0      # деньги, которые ещё летят в копилку (в кассе уже есть, в банке ещё нет)
var jar_money := -1.0         # сколько денег сейчас показано в банке (плавно догоняет кассу)
var pay_floats: Array = []    # всплывающие «+N» над копилкой
var give: Dictionary = {}
var table_item := ""          # игрушка, которую клиент выбрал: просто лежит на столе
var table_t := 1.0
var gift_clickable := false
var gift_look: Dictionary = {}
var gift_poly := PackedVector2Array()
var gift_t := 0.0
var keepsakes: Array = []      # {look, poly, t}: подарки нам самим, стоят на прилавке до конца игры
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
	water_style = StyleBoxFlat.new()
	water_style.bg_color = Color(0.40, 0.44, 0.54, 0.52)
	water_style.corner_radius_bottom_left = 40
	water_style.corner_radius_bottom_right = 40
	glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.9, 0.5, 0.12)
	glow_style.border_color = Color(1.0, 0.9, 0.5, 0.9)
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(14)


# --- Публичное API -----------------------------------------------------------

## Мысли клиента: мы читаем их и подбираем подарок с полки.
func show_thought(person: String, text: String) -> void:
	bubble_kind = "thought"
	bubble_name = "Thoughts: " + person
	bubble_text = text
	bubble_t = 0.0


func set_thought_fill(f: float) -> void:
	thought_fill = clampf(f, 0.0, 1.0)


func set_offer(on: bool) -> void:
	offer_enabled = on
	shelf_hover_id = ""
	wall_hover = false
	if not on:
		shelf_open = false


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
		fly_coins.append({"t": -0.22 * float(i), "from": CUSTOMER_HAND + Vector2(20, -20), "to": JAR_SLOT,
			"kind": "tip", "carry": 1.0, "float": n if i == 0 else 0})


## Клиент кладёт деньги в копилку: монетки летят в банку, над ней загорается «+N» и растворяется вверх.
func pay_pop(amount: int) -> void:
	var n := clampi(ceili(float(amount) / 9.0), 1, 7)
	pending_money += float(amount)
	for i in n:
		fly_coins.append({"t": -0.13 * float(i), "from": CUSTOMER_HAND + Vector2(24, -14), "to": JAR_SLOT,
			"kind": "pay", "carry": float(amount) / float(n), "float": amount if i == 0 else 0})
	AudioSynth.play_sfx("coin", 0.0, 0.9)


## Возврат денег недовольному клиенту: монетки вылетают из копилки к клиенту, над копилкой «-N».
func refund_pop(amount: int) -> void:
	var n := clampi(ceili(float(amount) / 9.0), 1, 7)
	for i in n:
		fly_coins.append({"t": -0.13 * float(i), "from": JAR_SLOT, "to": CUSTOMER_HAND + Vector2(24, -14),
			"kind": "refund", "carry": 0.0, "float": 0})
	pay_floats.append({"t": 0.0, "text": "-%d" % amount, "tip": false, "neg": true})
	jar_bump = 1.0
	AudioSynth.play_sfx("coin", 0.0, 0.8)


## Выбранный подарок едет на прилавок.
func give_item(item_id: String) -> void:
	table_item = item_id
	table_t = 0.0
	gift_clickable = false
	AudioSynth.play_sfx("pop_in")


## Подарок на столе можно нажать, чтобы начать упаковку.
func set_gift_clickable(on: bool) -> void:
	gift_clickable = on and table_item != ""


## Подарок забрали со стола (мы идём упаковывать).
func take_item() -> void:
	table_item = ""
	gift_clickable = false


func _gift_rect() -> Rect2:
	if table_item == "":
		return Rect2()
	var sz := _item_size(table_item) * TABLE_ITEM_SCALE
	return Rect2(GIFT_POS - sz * 0.5, sz).grow(16.0)


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


## Подарок подарили нам: он уезжает со стола на прилавок и остаётся там до конца игры.
func keep_gift() -> void:
	if gift_look.is_empty():
		return
	keepsakes.append({"look": gift_look, "poly": gift_poly, "t": 0.0})
	gift_look = {}
	AudioSynth.play_sfx("pop_in")


func clear_keepsakes() -> void:
	keepsakes.clear()


func reset() -> void:
	bubble_text = ""
	offer_enabled = false
	shelf_open = false
	give = {}
	gift_look = {}
	table_item = ""
	gift_clickable = false
	pending_money = 0.0
	pay_floats.clear()
	jar_money = -1.0
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
		if shelf_open:
			shelf_hover_id = _shelf_view_at(p)
			back_hover = BACK_BTN.has_point(p)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (shelf_hover_id != "" or back_hover) else Input.CURSOR_ARROW)
			return
		var over_cat := _cat_rect().has_point(p)
		var over_gift := gift_clickable and _gift_rect().has_point(p)
		wall_hover = offer_enabled and WALL_SHELF.has_point(p)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (over_cat or wall_hover or over_gift) else Input.CURSOR_ARROW)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE and shelf_open:
			_close_shelf()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var p2 := get_global_mouse_position()
		if shelf_open:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_close_shelf()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var picked := _shelf_view_at(p2)
				if picked != "":
					AudioSynth.play_sfx("click")
					shelf_open = false
					shelf_hover_id = ""
					offer_pressed.emit(picked)
				elif BACK_BTN.has_point(p2):
					_close_shelf()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if gift_clickable and _gift_rect().has_point(p2):
				AudioSynth.play_sfx("click")
				gift_clicked.emit()
			elif offer_enabled and WALL_SHELF.has_point(p2):
				_open_shelf()
			elif _cat_rect().has_point(p2):
				_pet_cat()


func _open_shelf() -> void:
	shelf_open = true
	shelf_hover_id = ""
	back_hover = false
	AudioSynth.play_sfx("click")
	shelf_toggled.emit(true)


func _close_shelf() -> void:
	shelf_open = false
	shelf_hover_id = ""
	back_hover = false
	AudioSynth.play_sfx("click")
	shelf_toggled.emit(false)


## Какая рука-курсор нужна над точкой p (см. hand_cursor.gd).
func cursor_pose(p: Vector2) -> String:
	if not input_enabled:
		return "point"
	if shelf_open:
		return "hover" if (_shelf_view_at(p) != "" or BACK_BTN.has_point(p)) else "point"
	if gift_clickable and _gift_rect().has_point(p):
		return "hover"
	if _cat_rect().has_point(p):
		return "pet"
	if offer_enabled and WALL_SHELF.has_point(p):
		return "hover"
	return "point"


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
	for k in keepsakes:
		k["t"] = minf(float(k["t"]) + delta / 0.9, 1.0)
	purr_cd = maxf(purr_cd - delta, 0.0)
	jar_bump = maxf(jar_bump - delta * 2.5, 0.0)
	shelf_t = move_toward(shelf_t, 1.0 if shelf_open else 0.0, delta / 0.22)
	_update_cat(delta)
	for i in range(hearts.size() - 1, -1, -1):
		hearts[i]["t"] += delta / 1.2
		hearts[i]["pos"] += Vector2(0.0, -28.0 * delta)
		if hearts[i]["t"] >= 1.0:
			hearts.remove_at(i)
	for i in range(fly_coins.size() - 1, -1, -1):
		fly_coins[i]["t"] += delta / 0.75
		if fly_coins[i]["t"] >= 1.0:
			var fc: Dictionary = fly_coins[i]
			fly_coins.remove_at(i)
			var fkind := str(fc.get("kind", "tip"))
			if fkind == "refund":
				AudioSynth.play_sfx("coin", 0.0, randf_range(0.8, 0.9))
				continue
			if fkind == "pay":
				pending_money = maxf(pending_money - float(fc["carry"]), 0.0)
			else:
				tips_shown += 1
			if int(fc.get("float", 0)) > 0:
				var is_tip := str(fc.get("kind", "tip")) == "tip"
				var txt := "+%d" % int(fc["float"])
				if is_tip:
					txt += " tip"
				pay_floats.append({"t": 0.0, "text": txt, "tip": is_tip})
			jar_bump = 1.0
			AudioSynth.play_sfx("coin", 0.0, randf_range(0.95, 1.15))
	# денег в банке столько, сколько в кассе (плюс чаевые в банке), без тех, что ещё летят; уходят и приходят плавно
	var jar_target := maxf(float(info.get("cash", 0)) + float(tips_shown) - pending_money, 0.0)
	if jar_money < 0.0:
		jar_money = jar_target
	jar_money = move_toward(jar_money, jar_target, 70.0 * delta)
	for i in range(pay_floats.size() - 1, -1, -1):
		pay_floats[i]["t"] += delta / 1.9
		if pay_floats[i]["t"] >= 1.0:
			pay_floats.remove_at(i)
	if table_item != "" and table_t < 1.0:
		table_t = minf(table_t + delta / 0.25, 1.0)
		if table_t >= 1.0:
			item_given.emit()
	queue_redraw()


# --- Рисование -------------------------------------------------------------------

func _draw() -> void:
	_draw_counter()
	_draw_props()
	_draw_cat()
	_draw_wall_shelf_hint()
	_draw_plaques()
	_draw_keepsakes()
	_draw_gift()
	_draw_give()
	_draw_shelf_view()
	_draw_bubble()
	_draw_coins_and_hearts()


## Номер картинки копилки для суммы денег.
static func jar_level(money: float) -> int:
	var lvl := 0
	for i in JAR_LEVELS.size():
		if money >= float(JAR_LEVELS[i]):
			lvl = i
	return lvl


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
	# копилка: чем больше денег, тем полнее картинка; при падении монеты чуть подпрыгивает
	var bump := -absf(sin(jar_bump * PI * 3.0)) * 4.0 * jar_bump
	var jar := T_JARS[jar_level(jar_money)]
	var jh := JAR_W * float(jar.get_height()) / float(jar.get_width())
	_prop(jar, JAR_POS, jh, 1.0, -bump)
	_prop(T_MUG, MUG_POS, MUG_H)
	_prop(T_FRAME, FRAME_POS, FRAME_H)


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
	for pf in pay_floats:
		var pt: float = pf["t"]
		var alpha := 1.0 - smoothstep(0.5, 1.0, pt)
		var rise := 1.0 - (1.0 - pt) * (1.0 - pt)
		var base := JAR_SLOT + Vector2(0.0, -34.0 - 92.0 * rise)
		var big := 44 if not bool(pf["tip"]) else 30
		var col := Color(1.0, 0.92, 0.45, alpha) if not bool(pf["tip"]) else Color(1.0, 0.86, 0.6, alpha)
		var glow := Color(1.0, 0.88, 0.35, 0.16 * alpha)
		if bool(pf.get("neg", false)):
			col = Color(1.0, 0.45, 0.38, alpha)   # возврат денег: красный «-N»
			glow = Color(1.0, 0.3, 0.25, 0.14 * alpha)
		draw_circle(base + Vector2(0.0, -big * 0.3), float(big) * 1.1, glow)   # мягкое свечение
		draw_string_outline(font, base + Vector2(-110.0, 0.0), str(pf["text"]), HORIZONTAL_ALIGNMENT_CENTER, 220.0, big, 9, Color(0.32, 0.18, 0.05, 0.85 * alpha))
		draw_string(font, base + Vector2(-110.0, 0.0), str(pf["text"]), HORIZONTAL_ALIGNMENT_CENTER, 220.0, big, col)
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
	var tsize := font.get_multiline_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 2.0 * BUBBLE_PAD, BUBBLE_FONT)
	var h := tsize.y + 84.0
	var rect := Rect2(lerpf(BUBBLE_X, SHELF_BUBBLE_X, shelf_t), BUBBLE_TOP, BUBBLE_W, h)
	var s := maxf(U.ease_out_elastic(bubble_t), 0.001)
	var pivot := Vector2(rect.position.x, rect.end.y)
	draw_set_transform(pivot * (1.0 - s), 0.0, Vector2(s, s))
	if bubble_kind == "thought":
		draw_style_box(thought_style, rect)
		_draw_thought_water(rect)
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
		# хвостик: контур рисуем только снаружи облачка (от левого края к рту), иначе линии заходят на текст
		var bx := rect.position.x
		var p0 := Vector2(bx + 30.0, rect.end.y - 60.0)
		var p1 := Vector2(bx + 30.0, rect.end.y - 16.0)
		if MOUTH.x < bx - 8.0:
			var b0 := p0.lerp(MOUTH, (bx - p0.x) / (MOUTH.x - p0.x))
			var b1 := p1.lerp(MOUTH, (bx - p1.x) / (MOUTH.x - p1.x))
			draw_colored_polygon(PackedVector2Array([b0 + Vector2(5.0, 0.0), b0, MOUTH, b1, b1 + Vector2(5.0, 0.0)]), BUBBLE_COLOR)
			draw_polyline(PackedVector2Array([b0, MOUTH, b1]), U.INK, 4.0, true)
			draw_rect(Rect2(bx - 2.5, b0.y + 2.0, 9.0, b1.y - b0.y - 4.0), BUBBLE_COLOR)   # убирает край облачка между концами хвостика
	draw_string(font, Vector2(rect.position.x + BUBBLE_PAD, rect.position.y + 40.0), bubble_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.38, 0.26) if bubble_kind == "speech" else Color(0.32, 0.4, 0.62))
	draw_multiline_string(font, Vector2(rect.position.x + BUBBLE_PAD, rect.position.y + 52.0 + font.get_ascent(BUBBLE_FONT)), bubble_text,
		HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 2.0 * BUBBLE_PAD, BUBBLE_FONT, -1, U.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Серая вода в облачке мыслей: уровень растёт с таймером, у поверхности лёгкая волна и пузырьки.
func _draw_thought_water(rect: Rect2) -> void:
	if thought_fill <= 0.001:
		return
	var inner := rect.grow(-4.0)
	var f := thought_fill
	var y_w := inner.end.y - f * inner.size.y
	var h := inner.end.y - y_w
	var top_r := 40 if f > 0.88 else 0   # у самого верха вода повторяет круглые углы облачка
	water_style.corner_radius_top_left = top_r
	water_style.corner_radius_top_right = top_r
	draw_style_box(water_style, Rect2(inner.position.x, y_w, inner.size.x, h))
	if f < 0.985:
		var pts := PackedVector2Array()
		var x := inner.position.x + 36.0
		while x <= inner.end.x - 36.0:
			pts.append(Vector2(x, y_w + sin(time * 2.6 + x * 0.05) * 2.4))
			x += 10.0
		if pts.size() > 1:
			draw_polyline(pts, Color(0.88, 0.92, 0.98, 0.6), 3.0, true)
	if h > 24.0:
		for i in 6:
			var ph := fposmod(time * 0.18 + float(i) * 0.173, 1.0)
			var bx := inner.position.x + 50.0 + fposmod(float(i) * 137.0 + sin(time + float(i)) * 6.0, inner.size.x - 100.0)
			var by := inner.end.y - 8.0 - ph * (h - 12.0)
			draw_circle(Vector2(bx, by), 2.0 + float(i % 3), Color(0.9, 0.94, 1.0, 0.35 * (1.0 - ph * 0.6)))


# --- Подарок ---------------------------------------------------------------------------

func _draw_give() -> void:
	if table_item == "":
		return
	var sz := _item_size(table_item) * TABLE_ITEM_SCALE
	var a := clampf(table_t, 0.0, 1.0)
	if gift_clickable:
		var pulse := 0.5 + 0.5 * sin(time * 4.0)
		draw_circle(GIFT_POS, maxf(sz.x, sz.y) * 0.62 + 5.0 * pulse, Color(1.0, 0.93, 0.55, 0.14 + 0.14 * pulse))
	draw_colored_polygon(U.ellipse(GIFT_POS + Vector2(0.0, sz.y * 0.5), sz.x * 0.42, 7.0), Color(0, 0, 0, 0.22 * a))
	draw_texture_rect(T_ITEMS[table_item], Rect2(GIFT_POS - sz * 0.5, sz), false, Color(1, 1, 1, a))
	if gift_clickable:
		_txt(GIFT_POS + Vector2(-110.0, -sz.y * 0.5 - 16.0), U.touch_text("Click to wrap"), 22, Color(1, 0.96, 0.85), true, HORIZONTAL_ALIGNMENT_CENTER, 220.0)


func _draw_gift() -> void:
	if gift_look.is_empty():
		return
	var e := U.ease_out_back(gift_t)
	var s := 0.62 * maxf(e, 0.001)
	_draw_look(gift_look, gift_poly, GIFT_POS + Vector2(0.0, 12.0 * (1.0 - e)), s)


func _draw_keepsakes() -> void:
	for i in keepsakes.size():
		var k: Dictionary = keepsakes[i]
		var t := U.ease_in_out(float(k["t"]))
		var dst := KEEP_POS - Vector2(KEEP_STEP * float(i), 0.0)
		var pos := GIFT_POS.lerp(dst, t) + Vector2(0.0, -60.0 * sin(t * PI))
		var look: Dictionary = k["look"]
		var poly: PackedVector2Array = k["poly"]
		var h := float(look["h"]) if look["wrap_mode"] != "shape" else 200.0
		var s := lerpf(0.62, KEEP_SCALE, t)
		# низ подарка стоит на прилавке
		_draw_look(look, poly, pos - Vector2(0.0, h * 0.5 * (s - KEEP_SCALE)), s)


func _draw_look(look: Dictionary, poly: PackedVector2Array, pos: Vector2, s: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(s, s))
	var base := Color.html(look["base"])
	var acc := Color.html(look["accent"])
	var shape: bool = look["wrap_mode"] == "shape"
	var item_id: String = look["item_id"]
	var tail_data: Array = []
	if shape and Data.ITEMS[item_id].has("tail"):
		tail_data = Data.ITEMS[item_id]["tail"]
	var ribbon_col := Color.html(look["ribbon"]) if look["ribbon"] != "" else Color(0, 0, 0, 0)
	var has_ribbon: bool = look["ribbon"] != ""
	var bow: float = look["bow"]
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
	U.fill_stroke(self, poly, base, 5.0, time)
	# рисунок бумаги: мелкие акценты
	var bounds := Rect2(-130, -130, 260, 260)
	for gx in range(-4, 5):
		for gy in range(-4, 5):
			var c := Vector2(float(gx) * 30.0 + float(gy % 2) * 15.0, float(gy) * 30.0)
			if bounds.has_point(c) and Geometry2D.is_point_in_polygon(c, poly):
				draw_circle(c, 4.0, Color(acc.r, acc.g, acc.b, 0.7))
	if has_ribbon:
		if tail_data.is_empty():
			var w: float = look["w"]
			var h: float = look["h"]
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


# --- Полка «в наличии» --------------------------------------------------------------

## Подсказка на полке справа на стене, пока клиент ждёт подарок: мягкое свечение, при наведении подпись.
func _draw_wall_shelf_hint() -> void:
	if not offer_enabled or shelf_open:
		return
	var pulse := 0.5 + 0.5 * sin(time * 3.5)
	glow_style.bg_color = Color(1.0, 0.9, 0.5, (0.20 if wall_hover else 0.05 + 0.06 * pulse))
	glow_style.border_color = Color(1.0, 0.9, 0.5, (0.95 if wall_hover else 0.35 + 0.35 * pulse))
	draw_style_box(glow_style, WALL_SHELF.grow(2.0))
	if wall_hover:
		_txt(Vector2(WALL_SHELF.position.x - 150.0, WALL_SHELF.end.y + 28.0), "Open the shelf", 18, Color(1, 0.96, 0.85, 0.98), true, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	else:
		_txt(Vector2(WALL_SHELF.position.x - 150.0, WALL_SHELF.end.y + 28.0), "Gift shelf", 16, Color(1, 0.96, 0.85, 0.5 + 0.4 * pulse), true, HORIZONTAL_ALIGNMENT_CENTER, 300.0)


## Запас на полке: {item_id: сколько штук}. Игрушка с нулём стоит серой и недоступна, у остальных значок «x2»,
## а тех, кого в словаре нет, на полке нет вовсе. Пока set_stock не вызывали, видны четыре простые игрушки без счётчика.
func set_stock(counts: Dictionary) -> void:
	stock_counts = counts.duplicate()
	stock_set = true


## Какие игрушки сейчас лежат на полке, в порядке мест (простые, потом дорогие).
func _shelf_ids() -> Array:
	var out: Array = []
	if not stock_set:
		for id in Data.STOCK:
			out.append(str(id))
		return out
	for id2 in Data.STOCK + Data.STOCK_MID:
		if stock_counts.has(id2):
			out.append(str(id2))
	return out


func _stock_left(id: String) -> int:
	return 999 if not stock_set else int(stock_counts.get(id, 0))


## Размер игрушки на прилавке: высота по виду игрушки, ширина по пропорциям спрайта.
func _item_size(id: String) -> Vector2:
	var base: Vector2 = SHELF_SIZE[str(Data.ITEMS[id]["kind"])]
	var tex: Texture2D = T_ITEMS[id]
	return Vector2(base.y * float(tex.get_width()) / float(tex.get_height()), base.y)


func _shelf_view_rect(id: String) -> Rect2:
	var sz := _item_size(id) * SHELF_VIEW_SCALE
	var p: Vector2 = SHELF_SLOTS[id]
	return Rect2(p.x - sz.x * 0.5, p.y - sz.y, sz.x, sz.y).grow(10.0)


## Игрушка под точкой p на открытой полке ("" — никакой; игрушки с нулём не берутся).
func _shelf_view_at(p: Vector2) -> String:
	if shelf_t < 0.5:
		return ""
	for id in _shelf_ids():
		if _stock_left(str(id)) > 0 and _shelf_view_rect(str(id)).has_point(p):
			return str(id)
	return ""


## Полка крупным планом: две доски, на них весь наш запас. Клик по игрушке — предложить её клиенту.
func _draw_shelf_view() -> void:
	if shelf_t <= 0.0:
		return
	var e := U.ease_out_back(shelf_t)
	draw_texture_rect(T_SHELF_VIEW, SHELF_VIEW, false, Color(1, 1, 1, clampf(shelf_t * 1.6, 0.0, 1.0)))
	draw_rect(Rect2(SHELF_VIEW.position, Vector2(SHELF_VIEW.size.x, 4.0)), Color(0, 0, 0, 0.35 * shelf_t))
	var sign_c := Vector2(640.0, 180.0)
	_txt(sign_c + Vector2(-150.0, 10.0), "Pick a gift", 30, Color("#3a2418"), false, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	var n := 0
	for id in _shelf_ids():
		n += 1
		var sid := str(id)
		var sz := _item_size(sid) * SHELF_VIEW_SCALE
		var p: Vector2 = SHELF_SLOTS[sid]
		var left := _stock_left(sid)
		var out := left <= 0
		var hov := (sid == shelf_hover_id)
		var k := (1.08 if hov else 1.0 + 0.012 * sin(time * 2.4 + float(n))) * maxf(e, 0.001)
		var s2 := sz * k
		draw_colored_polygon(U.ellipse(p + Vector2(0, 4), sz.x * 0.42, 9.0), Color(0, 0, 0, (0.15 if out else 0.28) * shelf_t))
		if hov:
			draw_circle(p + Vector2(0.0, -sz.y * 0.5), maxf(sz.x, sz.y) * 0.62, Color(1.0, 0.92, 0.55, 0.22))
		draw_texture_rect(T_ITEMS[sid], Rect2(p.x - s2.x * 0.5, p.y - s2.y, s2.x, s2.y), false, Color(0.42, 0.42, 0.46, 0.6) if out else Color.WHITE)
		if stock_set:
			if out:
				_txt(Vector2(p.x - 100.0, p.y + 32.0), "Out of stock", 17, Color(1, 0.9, 0.8, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
			else:
				var bc := Vector2(p.x + sz.x * 0.5 - 4.0, p.y - sz.y + 6.0)
				draw_circle(bc, 17.0, Color("#d8343a"))
				draw_arc(bc, 17.0, 0.0, TAU, 24, U.INK, 3.0)
				_txt(Vector2(bc.x - 30.0, bc.y + 7.0), "x%d" % left, 19, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
		if hov:
			var it: Dictionary = Data.ITEMS[sid]
			_txt(Vector2(p.x - 150.0, p.y + 34.0), str(it["name"]), 22, Color(1, 0.96, 0.85, 0.98), true, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	# кнопка «назад»
	var br := BACK_BTN
	draw_rect(Rect2(br.position + Vector2(3, 4), br.size), Color(0, 0, 0, 0.3))
	U.fill_stroke(self, U.rect_pts(br), Color("#f0c05a") if back_hover else Color("#d9cdb2"), 3.5, time)
	_txt(Vector2(br.position.x, br.position.y + 32.0), U.touch_text("< Back (Esc)"), 20, U.INK, false, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
