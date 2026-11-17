extends Node2D
## Экран упаковки (вид сверху). Всё делается руками: отрез бумаги, четыре загиба, скотч в любом
## месте, лента, которую нужно самому обвести вокруг подарка. Можно упаковать криво, клиент это заметит.
## Геометрия подарка в локальных координатах: (0, 0) — центр подарка.

signal gift_ready(result: Dictionary)
signal hint_changed(text: String)
signal toast(text: String)
signal cost(category: String, amount: int)

const Data = preload("res://scripts/data.gd")
const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")
const ItemArt = preload("res://scripts/item_art.gd")

# --- Раскладка (пиксели при окне 1280x720) ---
const CENTER := Vector2(642, 410)
const MAT_RECT := Rect2(262, 150, 760, 520)
const LEFT_PANEL := Rect2(14, 40, 224, 640)
const RIGHT_PANEL := Rect2(1050, 104, 216, 576)
const TICKET_RECT := Rect2(262, 10, 500, 130)
const ROLL_SIZE := Vector2(170, 50)
const SPOOL_R := 28.0
const TAPE_POS := Vector2(1110, 446)
const BIN_POS := Vector2(1196, 446)
const BELL_POS := Vector2(1150, 590)
const BELL_R := 38.0
const SCISSORS_POS := Vector2(1108, 522)
const RULER_POS := Vector2(1218, 556)
const PX_PER_CM := 6.0      # масштаб линейки: 1 см = 6 px
const CARD_SIZE := Vector2(200, 240)

# --- Механика упаковки ---
const MARGIN := 36.0        # поле листа сверху и снизу (загибается руками)
const MIN_OVERLAP := 16.0   # нахлёст клапанов для «хорошей» длины
const GOOD_RANGE := 90.0    # «хорошая» длина: Lmin .. Lmin + GOOD_RANGE
const EXTRA_LEN := 160.0    # Lmax = 2*w + EXTRA_LEN
const MIN_SHEET := 60.0     # самый короткий лист, который можно отрезать
const PREVIEW_EXTRA := 30.0
const TAPE_W := 18.0
const TAPE_COST_PER := 120.0  # пикселей скотча на 1 монету
const RIBBON_W := 14.0
const RIBBON_MIN_LEN := 80.0  # меньше этого ленты не видно как ленту
const STROKE_MAX := 8
const REACH := 12.0           # насколько за край бумаги можно вести скотч и ленту
const FOLD_SNAP_ANGLE := 1.05
const BOX_PAD := 36.0         # запас коробки вокруг вещи
const SHAPE_PAD := 6.0        # бумага чуть шире силуэта

enum Step { IDLE, ARRIVING, CHOOSE, PAPER, PULL, WRAP, DELIVER }

var step: int = Step.IDLE
var input_enabled := false
var time := 0.0

var inv_papers: Array = []
var inv_ribbons: Array = []
var inv_boxes: Array = []
var ticket_name := ""
var ticket_lines: Array = []

var item_id := ""
var item: Dictionary = {}
var item_kind := ""
var raw_w := 0.0
var raw_h := 0.0
var item_w := 0.0     # размеры того, что заворачиваем (коробка или сама вещь)
var item_h := 0.0
var wrap_mode := "rect"   # "rect" или "shape"
var box_idx := -1
var sil_poly := PackedVector2Array()
var clip_cur := PackedVector2Array()
var cards: Array = []

var paper_idx := -1
var sheet_len := 0.0
var pulling := false
var pull_moved := false
var pull_press := Vector2.ZERO
var pull_len := 0.0     # сколько бумаги вытянуто с рулона
var paper_shift := 0.0  # смещение отрезанного куска к центру (скользит под подарок)
var axis := "h"         # вдоль какой оси тянут бумагу: h — горизонтально, v — вертикально
var rot := 0.0          # поворот бумаги относительно стола (0 или PI/2)
var last_pull_len := 0.0
## Четыре клапана: 0 — левый, 1 — правый, 2 — верхний, 3 — нижний.
var theta: Array[float] = [PI, PI, PI, PI]
var theta_target: Array[float] = [PI, PI, PI, PI]
var folded: Array[bool] = [false, false, false, false]
var fold_order: Array[int] = []
var flap_drag := -1
var tucked := false      # все четыре края загнуты
var tuck_t := 0.0

var tape_strokes: Array = []     # {pts, len, age}
var ribbon_strokes: Array = []   # {pts, len, age, ribbon}
var stroking := false
var stroke_kind := ""
var stroke_pts := PackedVector2Array()
var active_tool := ""            # "", "scissors", "tape", "ribbon" или "ruler"
var measuring := false           # линейка: тянем замер
var ruler_has := false
var ruler_a := Vector2.ZERO
var ruler_b := Vector2.ZERO
var ribbon_idx := -1
var bow_size := 1.0
var bow_drag := false
var bow_drag_y := 0.0
var bow_drag_start := 1.0
var bow_pop := 1.0
var length_class := ""
var arrive_t := 0.0
var box_t := 1.0
var tail_t := 0.0
var gift_off := Vector2.ZERO
var gift_scale := 1.0
var result: Dictionary = {}

var hover := ""
var mouse_pos := Vector2.ZERO
var popups: Array = []
var bell_shake := 0.0
var bin_shake := 0.0

var font: Font
var mat_style: StyleBoxFlat
var panel_style: StyleBoxFlat
var card_style: StyleBoxFlat


func _ready() -> void:
	font = ThemeDB.fallback_font
	mat_style = StyleBoxFlat.new()
	mat_style.bg_color = Color(0.17, 0.29, 0.27)
	mat_style.border_color = U.INK
	mat_style.set_border_width_all(4)
	mat_style.set_corner_radius_all(18)
	mat_style.shadow_color = Color(0, 0, 0, 0.35)
	mat_style.shadow_size = 10
	mat_style.shadow_offset = Vector2(0, 5)
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#4a3020")
	panel_style.border_color = U.INK
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	panel_style.shadow_size = 8
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#f3e8cf")
	card_style.border_color = U.INK
	card_style.set_border_width_all(4)
	card_style.set_corner_radius_all(18)
	card_style.shadow_color = Color(0, 0, 0, 0.3)
	card_style.shadow_size = 8


func set_inventory(papers: Array, ribbons: Array, boxes: Array) -> void:
	inv_papers = papers
	inv_ribbons = ribbons
	inv_boxes = boxes


func set_ticket(person: String, lines: Array) -> void:
	ticket_name = person
	ticket_lines = lines


func place_item(id: String) -> void:
	item_id = id
	item = Data.ITEMS[id]
	item_kind = item["kind"]
	raw_w = float(item["w"])
	raw_h = float(item["h"])
	_reset_gift_state()
	sil_poly = Shapes.silhouette(item_kind) if item_kind != "box" else PackedVector2Array()
	item_w = raw_w
	item_h = raw_h
	arrive_t = 0.0
	step = Step.ARRIVING
	hint_changed.emit("")


func clear_gift() -> void:
	item = {}
	item_id = ""
	_reset_gift_state()
	step = Step.IDLE
	hint_changed.emit("")


func _l_min() -> float:
	return 2.0 * _along() + MIN_OVERLAP


func _l_max() -> float:
	return 2.0 * _along() + EXTRA_LEN


func _flap_len() -> float:
	return maxf((sheet_len - _along()) * 0.5, 0.0)


## Размер вещи вдоль оси, по которой тянут бумагу, и поперёк неё.
func _along() -> float:
	return item_w if axis == "h" else item_h


func _across() -> float:
	return item_h if axis == "h" else item_w


func _to_paper(world: Vector2) -> Vector2:
	return world.rotated(-rot)


func _clip_to_paper(poly: PackedVector2Array) -> PackedVector2Array:
	if rot == 0.0 or poly.size() < 3:
		return poly
	var out := PackedVector2Array()
	for p in poly:
		out.append(p.rotated(-rot))
	return out


func _set_axis(a: String) -> void:
	if step != Step.PULL or a == axis:
		return
	axis = a
	rot = 0.0 if a == "h" else PI * 0.5
	pull_len = _pull_min()
	sheet_len = pull_len
	pull_moved = false
	AudioSynth.play_sfx("click")
	_hint("Drag the loose end: the gift stays in the middle of the sheet and the roll rolls away. Then cut with the scissors")


func _set_paper_transform() -> void:
	var s := maxf(gift_scale, 0.001)
	var off := Vector2(paper_shift, 0.0).rotated(rot) * s
	draw_set_transform(CENTER + gift_off + off, rot, Vector2(s, s))


## Самый короткий лист при вытяжке: чуть шире подарка, чтобы был виден свободный конец.
func _pull_min() -> float:
	return _along() + 56.0


## Сколько бумаги можно вытянуть: лист всегда по центру подарка, рулон отъезжает к краю стола,
## поэтому длина ограничена шириной (или высотой) стола минус место под рулон.
func _pull_max() -> float:
	var half := (MAT_RECT.size.x if axis == "h" else MAT_RECT.size.y) * 0.5
	return maxf(_pull_min(), 2.0 * (half - 58.0))


func _hint(text: String) -> void:
	hint_changed.emit(text)


func _paper_cost(length: float) -> int:
	var p: Dictionary = Data.PAPERS[paper_idx]
	return maxi(roundi(length / 100.0 * float(p["cpp"])), 1)


func _roll_pos(slot: int) -> Vector2:
	return Vector2(123.0, 86.0 + float(slot) * 76.0)


func _spool_pos(slot: int) -> Vector2:
	return Vector2(1108.0 + float(slot % 2) * 88.0, 170.0 + float(slot / 2) * 88.0)


func _popup(pos: Vector2, text: String, col: Color) -> void:
	popups.append({"pos": pos, "text": text, "t": 0.0, "col": col})


func _spend(category: String, amount: int, at: Vector2) -> void:
	cost.emit(category, amount)
	_popup(at, "-%d" % amount, Color(1.0, 0.62, 0.5))
	AudioSynth.play_sfx("spend")


func _after_arrival() -> void:
	if item_kind == "box":
		wrap_mode = "rect"
		item_w = raw_w
		item_h = raw_h
		step = Step.PAPER
		_hint("Choose the wrapping paper")
		return
	cards = []
	for bi in inv_boxes:
		cards.append({"type": "box", "idx": bi})
	cards.append({"type": "shape"})
	step = Step.CHOOSE
	_hint("Put it in a box or wrap it by its shape?")


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(get_global_mouse_position())
			else:
				_on_release()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if step == Step.WRAP and not ribbon_strokes.is_empty():
				var d := 0.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1
				bow_size = clampf(bow_size + d, 0.6, 1.8)
	elif event is InputEventMouseMotion:
		_on_motion(get_global_mouse_position())


func _card_rect(i: int) -> Rect2:
	var n := cards.size()
	var c := CENTER + Vector2((float(i) - float(n - 1) * 0.5) * 230.0, 10.0)
	return Rect2(c - CARD_SIZE * 0.5, CARD_SIZE)


func _hit_test(pos: Vector2) -> String:
	if pos.distance_to(BELL_POS) < BELL_R + 6.0:
		return "bell"
	if pos.distance_to(BIN_POS) < 36.0:
		return "bin"
	if pos.distance_to(TAPE_POS + Vector2(-6, -4)) < 36.0:
		return "tape"
	if pos.distance_to(SCISSORS_POS) < 36.0:
		return "scissors"
	if pos.distance_to(RULER_POS) < 36.0:
		return "ruler"
	if step == Step.PULL:
		if _axis_rect("h").has_point(pos):
			return "axis:h"
		if _axis_rect("v").has_point(pos):
			return "axis:v"
	if step == Step.CHOOSE:
		for i in cards.size():
			if _card_rect(i).has_point(pos):
				return "card:%d" % i
	for s in inv_papers.size():
		var rp := _roll_pos(s)
		if Rect2(rp - ROLL_SIZE * 0.5, ROLL_SIZE).grow(4.0).has_point(pos):
			return "roll:%d" % s
	for s in inv_ribbons.size():
		if pos.distance_to(_spool_pos(s)) < SPOOL_R + 4.0:
			return "spool:%d" % s
	return ""


func _choose_card(i: int) -> void:
	var c: Dictionary = cards[i]
	if c["type"] == "box":
		box_idx = int(c["idx"])
		var bx: Dictionary = Data.BOXES[box_idx]
		wrap_mode = "rect"
		item_w = raw_w + BOX_PAD
		item_h = raw_h + BOX_PAD
		box_t = 0.0
		_spend("box", int(bx["cost"]), CENTER + Vector2(0, -110))
		AudioSynth.play_sfx("fold")
	else:
		wrap_mode = "shape"
		item_w = raw_w
		item_h = raw_h
		AudioSynth.play_sfx("stick")
	step = Step.PAPER
	_hint("Choose the wrapping paper")


func _draw() -> void:
	_draw_table()
	_draw_panels()
	_draw_mat()
	_draw_axis_buttons()
	_draw_ticket()
	_draw_rolls()
	_draw_spools()
	_draw_tape_dispenser()
	_draw_scissors()
	_draw_ruler_button()
	_draw_bin()
	_draw_bell()
	_draw_choose_cards()
	_draw_gift()
	_draw_cut_preview()
	_draw_ruler_overlay()
	_draw_tool_cursor()
	_draw_popups()


func _draw_table() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#6a4630"))
	for i in 12:
		var y := float(i) * 60.0
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0, 0, 0, 0.16), 2.0)
		var x := 0.0 if i % 2 == 0 else 150.0
		while x < 1280.0:
			draw_line(Vector2(x, y), Vector2(x, y + 60.0), Color(0, 0, 0, 0.1), 2.0)
			x += 300.0
	for i in 50:
		var fy := U.hash2(i, 5) * 720.0
		var fx := U.hash2(i, 9) * 1280.0
		draw_line(Vector2(fx, fy), Vector2(fx + 40.0 + U.hash2(i, 3) * 80.0, fy), Color(1, 1, 1, 0.04), 2.0)


func _draw_panels() -> void:
	draw_style_box(panel_style, LEFT_PANEL)
	draw_style_box(panel_style, RIGHT_PANEL)
	draw_string(font, Vector2(LEFT_PANEL.position.x, LEFT_PANEL.position.y + 24.0), "Paper", HORIZONTAL_ALIGNMENT_CENTER, LEFT_PANEL.size.x, 16, Color(1, 0.93, 0.75, 0.8))
	draw_string(font, Vector2(RIGHT_PANEL.position.x, RIGHT_PANEL.position.y + 24.0), "Ribbons", HORIZONTAL_ALIGNMENT_CENTER, RIGHT_PANEL.size.x, 16, Color(1, 0.93, 0.75, 0.8))


func _draw_mat() -> void:
	draw_style_box(mat_style, MAT_RECT)
	for gx in range(1, 22):
		var x := MAT_RECT.position.x + float(gx) * 35.0
		draw_line(Vector2(x, MAT_RECT.position.y + 5.0), Vector2(x, MAT_RECT.end.y - 5.0), Color(1, 1, 1, 0.035), 1.0)
	for gy in range(1, 15):
		var y := MAT_RECT.position.y + float(gy) * 35.0
		draw_line(Vector2(MAT_RECT.position.x + 5.0, y), Vector2(MAT_RECT.end.x - 5.0, y), Color(1, 1, 1, 0.035), 1.0)
	for k in range(0, 76):
		var tx := MAT_RECT.position.x + 12.0 + float(k) * 9.8
		var tl := 10.0 if k % 5 == 0 else 5.0
		draw_line(Vector2(tx, MAT_RECT.position.y + 8.0), Vector2(tx, MAT_RECT.position.y + 8.0 + tl), Color(1, 1, 1, 0.14), 1.0)


func _draw_ticket() -> void:
	if ticket_name == "":
		return
	var r := TICKET_RECT
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.25))
	U.fill_stroke(self, U.rect_pts(r), Color("#f3e8cf"), 4.0, time)
	draw_rect(Rect2(r.position.x + 30.0, r.position.y - 6.0, 60.0, 16.0), Color(0.95, 0.9, 0.6, 0.75))
	draw_rect(Rect2(r.end.x - 90.0, r.position.y - 6.0, 60.0, 16.0), Color(0.95, 0.9, 0.6, 0.75))
	draw_string(font, Vector2(r.position.x + 20.0, r.position.y + 36.0), "Order: " + ticket_name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 22, Color(0.62, 0.38, 0.26))
	for i in ticket_lines.size():
		var col := i % 2
		var row := floori(float(i) / 2.0)
		draw_string(font, Vector2(r.position.x + 22.0 + float(col) * 240.0, r.position.y + 70.0 + float(row) * 26.0), "• " + str(ticket_lines[i]), HORIZONTAL_ALIGNMENT_LEFT, 230.0, 18, U.INK)


func _rect_stroke(r: Rect2, w: float = 3.0) -> void:
	U.stroke(self, U.rect_pts(r), U.INK, w, time, 1.0)


func _draw_rolls() -> void:
	for s in inv_papers.size():
		var gi: int = inv_papers[s]
		var p: Dictionary = Data.PAPERS[gi]
		var c := _roll_pos(s)
		var selected := (gi == paper_idx)
		var hovered := (hover == "roll:%d" % s)
		var dx := 10.0 if selected else (4.0 if hovered else 0.0)
		var body := Rect2(c.x - 85.0 + 14.0 + dx, c.y - 25.0, 170.0 - 14.0, 50.0)
		draw_rect(Rect2(body.position + Vector2(4, 6), body.size), Color(0, 0, 0, 0.28))
		_draw_print(body, p, body.position.x, 1.0, PackedVector2Array())
		draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 11.0), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(body.position.x, body.end.y - 13.0, body.size.x, 13.0), Color(0, 0, 0, 0.22))
		_rect_stroke(body)
		var end_c := Vector2(body.position.x, c.y)
		U.fill_stroke(self, U.ellipse(end_c, 13.0, 25.0), Color("#d9c7a0"), 3.0, time)
		draw_colored_polygon(U.ellipse(end_c, 6.0, 12.0), Color("#6b5640"))
		if selected:
			draw_rect(body.grow(5.0), Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		if selected or hovered:
			var nm: String = p["name"]
			draw_string(font, Vector2(c.x - 80.0 + dx, c.y + 42.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.96, 0.85, 0.95))


func _draw_spools() -> void:
	for s in inv_ribbons.size():
		var gi: int = inv_ribbons[s]
		var rb: Dictionary = Data.RIBBONS[gi]
		var c := _spool_pos(s)
		var col := Color.html(rb["color"])
		var selected := (gi == ribbon_idx and active_tool == "ribbon")
		var hovered := (hover == "spool:%d" % s)
		var r := SPOOL_R + (3.0 if hovered else 0.0)
		draw_circle(c + Vector2(3, 5), r, Color(0, 0, 0, 0.28))
		U.fill_stroke(self, U.ellipse(c, r, r, 0.0, 28), col.darkened(0.2), 3.5, time)
		draw_circle(c, r - 4.0, col)
		for k in 3:
			draw_arc(c, r - 9.0 - float(k) * 5.0, 0.0, TAU, 28, col.darkened(0.15), 1.5)
		draw_circle(c, 8.0, Color("#3b2a22"))
		draw_circle(c, 4.0, Color("#6a4630"))
		draw_line(c + Vector2(-r + 2.0, r - 6.0), c + Vector2(-r - 12.0, r + 8.0), col, 6.0)
		if selected:
			draw_arc(c, r + 6.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.5), 3.0)


func _draw_tape_dispenser() -> void:
	var c := TAPE_POS
	var glow := 0.0
	if active_tool == "tape":
		glow = 1.0
	elif step == Step.WRAP and tape_strokes.is_empty():
		glow = 0.5 + 0.5 * sin(time * 5.0)
	draw_colored_polygon(U.ellipse(c + Vector2(0, 10), 44.0, 14.0), Color(0, 0, 0, 0.25))
	U.fill_stroke(self, U.rect_pts(Rect2(c.x - 34.0, c.y - 4.0, 68.0, 22.0)), Color("#3a3a46"), 3.5, time)
	U.fill_stroke(self, U.ellipse(c + Vector2(-6, -4), 26.0, 26.0), Color("#efe2b8"), 3.5, time)
	draw_colored_polygon(U.ellipse(c + Vector2(-6, -4), 13.0, 13.0), Color("#3a3a46"))
	draw_rect(Rect2(c.x + 12.0, c.y + 6.0, 24.0, 6.0), Color("#bfc3cc"))
	if glow > 0.0:
		draw_arc(c + Vector2(-6, -4), 34.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.3 + 0.5 * glow), 3.0)


func _draw_bin() -> void:
	var c := BIN_POS + Vector2(sin(time * 55.0) * 4.0 * bin_shake, 0.0)
	var hov := hover == "bin"
	draw_colored_polygon(U.ellipse(c + Vector2(0, 30), 34.0, 9.0), Color(0, 0, 0, 0.25))
	var body := PackedVector2Array([c + Vector2(-26, -14), c + Vector2(26, -14), c + Vector2(20, 30), c + Vector2(-20, 30)])
	U.fill_stroke(self, body, Color("#6b7686") if not hov else Color("#7f8b9c"), 3.5, time)
	for k in 3:
		draw_line(c + Vector2(-10.0 + float(k) * 10.0, -8), c + Vector2(-8.0 + float(k) * 8.0, 24), Color(0, 0, 0, 0.3), 2.0)
	U.fill_stroke(self, U.rect_pts(Rect2(c.x - 30.0, c.y - 24.0, 60.0, 10.0)), Color("#8a95a6"), 3.0, time)
	draw_string(font, c + Vector2(-40, 52), "Trash", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(1, 0.96, 0.85, 0.8))


func _draw_bell() -> void:
	var pulse := 0.0
	if step == Step.WRAP and tucked and not tape_strokes.is_empty():
		pulse = 0.5 + 0.5 * sin(time * 4.0)
	var rot := sin(time * 40.0) * 0.14 * bell_shake
	var base := BELL_POS + Vector2(0, 22)
	draw_colored_polygon(U.ellipse(base + Vector2(0, 8), 42.0, 10.0), Color(0, 0, 0, 0.3))
	draw_set_transform(base, rot, Vector2.ONE)
	U.fill_stroke(self, U.ellipse(Vector2(0, 0), 40.0, 11.0), Color("#8a6b2a"), 3.5, time)
	var dome := PackedVector2Array()
	for k in 21:
		var a := PI + PI * float(k) / 20.0
		dome.append(Vector2(cos(a) * 32.0, sin(a) * 36.0))
	U.fill_stroke(self, dome, Color("#e3b84b"), 3.5, time)
	draw_arc(Vector2(-8, -6), 20.0, PI * 1.1, PI * 1.5, 10, Color(1, 1, 0.8, 0.6), 3.0)
	draw_circle(Vector2(0, -38), 5.0, Color("#c99a2e"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if pulse > 0.0:
		draw_arc(BELL_POS + Vector2(0, 6), 50.0, 0.0, TAU, 40, Color(1, 0.9, 0.5, 0.25 + 0.5 * pulse), 3.0)
	draw_string(font, BELL_POS + Vector2(-50, 62), "Hand over", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, Color(1, 0.96, 0.85, 0.9))


func _draw_popups() -> void:
	for pu in popups:
		var t: float = pu["t"]
		var pos: Vector2 = pu["pos"]
		var col: Color = pu["col"]
		var a := 1.0 - t * t
		var txt: String = pu["text"]
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 30, Color(0, 0, 0, 0.5 * a))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 30, Color(col.r, col.g, col.b, a))


func _fill_rect(r: Rect2, col: Color, clip: PackedVector2Array) -> void:
	if clip.size() < 3:
		draw_rect(r, col)
		return
	var res := Geometry2D.intersect_polygons(U.rect_pts(r), clip)
	for poly in res:
		if poly.size() >= 3:
			draw_colored_polygon(poly, col)


func _in_clip(c: Vector2, clip: PackedVector2Array) -> bool:
	return clip.size() < 3 or Geometry2D.is_point_in_polygon(c, clip)


func _draw_print(r: Rect2, paper: Dictionary, anchor_x: float, dir: float, clip: PackedVector2Array) -> void:
	var base := Color.html(paper["base"])
	var acc := Color.html(paper["accent"])
	_fill_rect(r, base, clip)
	var u0 := 0.0
	var u1 := 0.0
	if dir > 0.0:
		u0 = r.position.x - anchor_x
		u1 = r.end.x - anchor_x
	else:
		u0 = anchor_x - r.end.x
		u1 = anchor_x - r.position.x
	var pat: String = paper["pattern"]
	var inner := r.grow(-6.0)
	if inner.size.x < 0.0 or inner.size.y < 0.0:
		inner = Rect2(r.get_center(), Vector2.ZERO)  # узкая полоса (клапан почти сложен): узор не рисуем
	match pat:
		"stars":
			var st := 38.0
			for iy in range(int(floor(r.position.y / st)), int(ceil(r.end.y / st)) + 1):
				for ix in range(int(floor(u0 / st)) - 1, int(ceil(u1 / st)) + 2):
					var u := (float(ix) + (0.5 if iy % 2 == 0 else 0.0)) * st + 19.0
					var c := Vector2(anchor_x + dir * u, float(iy) * st + 19.0)
					if inner.has_point(c) and _in_clip(c, clip):
						draw_colored_polygon(U.star(c, 6.0, 2.4, 4, 0.0), acc)
		"lines":
			var y := floorf(r.position.y / 14.0) * 14.0
			while y < r.end.y:
				if y > r.position.y + 2.0:
					_fill_rect(Rect2(r.position.x, y, r.size.x, 1.8), Color(acc.r, acc.g, acc.b, 0.45), clip)
				y += 14.0
		"stripes":
			for k in range(int(floor(u0 / 26.0)) - 1, int(ceil(u1 / 26.0)) + 2):
				var su0 := float(k) * 26.0
				var a := maxf(su0, u0)
				var b := minf(su0 + 9.0, u1)
				if b > a:
					var xa := anchor_x + dir * a
					var xb := anchor_x + dir * b
					_fill_rect(Rect2(minf(xa, xb), r.position.y, absf(xb - xa), r.size.y), Color(acc.r, acc.g, acc.b, 0.55), clip)
		"dots":
			var sd := 17.0
			for jy in range(int(floor(r.position.y / sd)), int(ceil(r.end.y / sd)) + 1):
				for jx in range(int(floor(u0 / sd)) - 1, int(ceil(u1 / sd)) + 2):
					var hh := U.hash2(jx, jy)
					var cc := Vector2(anchor_x + dir * (float(jx) * sd + hh * 9.0), float(jy) * sd + U.hash2(jy, jx) * 9.0)
					if inner.has_point(cc) and _in_clip(cc, clip):
						draw_circle(cc, 1.4 + hh, Color(acc.r, acc.g, acc.b, 0.5))
		"polka":
			var sp := 34.0
			for jy in range(int(floor(r.position.y / sp)), int(ceil(r.end.y / sp)) + 1):
				for jx in range(int(floor(u0 / sp)) - 1, int(ceil(u1 / sp)) + 2):
					var u2 := (float(jx) + (0.5 if jy % 2 == 0 else 0.0)) * sp + 17.0
					var c2 := Vector2(anchor_x + dir * u2, float(jy) * sp + 17.0)
					if inner.has_point(c2) and _in_clip(c2, clip):
						draw_circle(c2, 6.5, Color(acc.r, acc.g, acc.b, 0.9))
		"snow":
			var ss := 26.0
			for jy in range(int(floor(r.position.y / ss)), int(ceil(r.end.y / ss)) + 1):
				for jx in range(int(floor(u0 / ss)) - 1, int(ceil(u1 / ss)) + 2):
					var h2 := U.hash2(jx + 5, jy + 9)
					var c3 := Vector2(anchor_x + dir * (float(jx) * ss + h2 * 18.0), float(jy) * ss + U.hash2(jy + 3, jx) * 18.0)
					if inner.has_point(c3) and _in_clip(c3, clip):
						if h2 > 0.6:
							draw_colored_polygon(U.star(c3, 6.0, 1.6, 6, 0.0), Color(acc.r, acc.g, acc.b, 0.9))
						else:
							draw_circle(c3, 2.0 + h2 * 2.5, Color(acc.r, acc.g, acc.b, 0.75))
		"check":
			var cs := 24.0
			for ky in range(int(floor(r.position.y / cs)), int(ceil(r.end.y / cs)) + 1):
				for kx in range(int(floor(u0 / cs)) - 1, int(ceil(u1 / cs)) + 2):
					if (kx + ky) % 2 != 0:
						continue
					var xa2 := anchor_x + dir * float(kx) * cs
					var xb2 := anchor_x + dir * float(kx + 1) * cs
					var cell := Rect2(minf(xa2, xb2), float(ky) * cs, absf(xb2 - xa2), cs)
					var cr := r.intersection(cell)
					if cr.size.x > 0.5 and cr.size.y > 0.5:
						_fill_rect(cr, Color(acc.r, acc.g, acc.b, 0.55), clip)


func _draw_choose_cards() -> void:
	if step != Step.CHOOSE:
		return
	var pop := 1.0
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := _card_rect(i)
		var hovered := hover == "card:%d" % i
		var s := pop * (1.05 if hovered else 1.0) * (1.0 + 0.012 * sin(time * 3.0 + float(i)))
		var center := r.get_center()
		draw_set_transform(center * (1.0 - s), 0.0, Vector2(s, s))
		draw_style_box(card_style, r)
		if c["type"] == "box":
			var bx: Dictionary = Data.BOXES[int(c["idx"])]
			var br := Rect2(center.x - 56.0, center.y - 62.0, 112.0, 84.0)
			_draw_box_art(br, Color.html(bx["color"]), Color.html(bx["lid"]), false)
			draw_string(font, Vector2(r.position.x, r.end.y - 52.0), str(bx["name"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, U.INK)
			draw_string(font, Vector2(r.position.x, r.end.y - 24.0), "Cost: %d" % int(bx["cost"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.7, 0.32, 0.25))
		else:
			var kind := item_kind
			var sil := Shapes.silhouette(kind)
			var bound := maxf(raw_w, raw_h)
			var k := 120.0 / bound
			var scaled := PackedVector2Array()
			for p in sil:
				scaled.append(center + Vector2(0, -26) + p * k)
			U.fill_stroke(self, scaled, Color.html(item["color"]), 4.0, time)
			draw_string(font, Vector2(r.position.x, r.end.y - 52.0), "By shape", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, U.INK)
			draw_string(font, Vector2(r.position.x, r.end.y - 24.0), "no box", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.45, 0.35, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _set_gift_transform(extra: float = 1.0) -> void:
	var s := maxf(gift_scale * extra, 0.001)
	draw_set_transform(CENTER + gift_off, 0.0, Vector2(s, s))


func _draw_tail(paper: Dictionary) -> void:
	var tl: Array = item["tail"]
	var b := Vector2(float(tl[0]), float(tl[1]))
	var d := Vector2(float(tl[2]), float(tl[3]))
	var ln: float = float(tl[4])
	var pp := d.rotated(PI * 0.5)
	var e := U.ease_out_elastic(tail_t)
	var L := ln * e
	var spread := 36.0 * clampf(e, 0.0, 1.3)
	var fan := PackedVector2Array([
		b - d * 10.0 + pp * -13.0, b + d * L + pp * -spread, b + d * (L * 0.88) + pp * (-spread * 0.45),
		b + d * (L * 1.06), b + d * (L * 0.88) + pp * (spread * 0.45), b + d * L + pp * spread, b - d * 10.0 + pp * 13.0])
	var base := Color.html(paper["base"])
	U.fill_stroke(self, fan, base, 4.0, time)
	var acc := Color.html(paper["accent"])
	for k in 3:
		var sgn := float(k - 1)
		draw_line(b, b + d * (L * 0.95) + pp * (sgn * spread * 0.7), Color(acc.r, acc.g, acc.b, 0.45), 2.0)


func _draw_subject(ir: Rect2) -> void:
	var boxed := box_idx >= 0
	if boxed:
		var raw := Rect2(-raw_w * 0.5, -raw_h * 0.5, raw_w, raw_h)
		if box_t < 0.5:
			_draw_item_art(raw)
		var bx: Dictionary = Data.BOXES[box_idx]
		var s := maxf(U.ease_out_back(box_t), 0.05)
		_set_gift_transform(s)
		_draw_box_art(ir, Color.html(bx["color"]), Color.html(bx["lid"]), false)
		_set_gift_transform()
	else:
		_draw_item_art(ir)


## Коробка, вид строго сверху: стенки чуть шире крышки, на крышке шов, где сходятся клапаны,
## и блик по краю. tape: поперёк шва клеится полоска скотча.
func _draw_box_art(r: Rect2, col: Color, lid: Color, tape: bool) -> void:
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.25))
	U.fill_stroke(self, U.rect_pts(r), col.darkened(0.14), 4.0, time)
	var lr := r.grow(-7.0)
	if lr.size.x < 10.0 or lr.size.y < 10.0:
		return
	U.fill_stroke(self, U.rect_pts(lr), lid, 3.0, time)
	draw_rect(Rect2(lr.position + Vector2(3, 3), Vector2(lr.size.x - 6.0, 5.0)), lid.lightened(0.16))
	var mid := lr.get_center()
	if lr.size.x >= lr.size.y:
		draw_line(Vector2(lr.position.x + 2.0, mid.y), Vector2(lr.end.x - 2.0, mid.y), U.INK, 2.5)
		if tape:
			draw_rect(Rect2(mid.x - 9.0, lr.position.y, 18.0, lr.size.y), Color("#dccfab"))
	else:
		draw_line(Vector2(mid.x, lr.position.y + 2.0), Vector2(mid.x, lr.end.y - 2.0), U.INK, 2.5)
		if tape:
			draw_rect(Rect2(lr.position.x, mid.y - 9.0, lr.size.x, 18.0), Color("#dccfab"))


func _draw_item_art(ir: Rect2) -> void:
	if item_kind == "box":
		var col := Color.html(item["color"])
		_draw_box_art(ir, col, col.darkened(0.08), true)
	else:
		ItemArt.draw(self, item_kind, item, time)


func _reset_gift_state() -> void:
	measuring = false
	ruler_has = false
	paper_idx = -1
	sheet_len = 0.0
	pulling = false
	pull_moved = false
	pull_len = 0.0
	paper_shift = 0.0
	axis = "h"
	rot = 0.0
	theta = [PI, PI, PI, PI]
	theta_target = [PI, PI, PI, PI]
	folded = [false, false, false, false]
	fold_order = []
	flap_drag = -1
	tucked = false
	tuck_t = 0.0
	tape_strokes = []
	ribbon_strokes = []
	stroking = false
	stroke_kind = ""
	stroke_pts = PackedVector2Array()
	active_tool = ""
	ribbon_idx = -1
	bow_size = 1.0
	bow_drag = false
	bow_pop = 1.0
	length_class = ""
	box_idx = -1
	box_t = 1.0
	tail_t = 0.0
	wrap_mode = "rect"
	clip_cur = PackedVector2Array()
	cards = []
	gift_off = Vector2.ZERO
	gift_scale = 1.0
	result = {}
	if not item.is_empty():
		item_w = raw_w
		item_h = raw_h


func _process(delta: float) -> void:
	time += delta
	bell_shake = maxf(bell_shake - delta, 0.0)
	bin_shake = maxf(bin_shake - delta, 0.0)
	bow_pop = minf(bow_pop + delta / 0.5, 1.0)
	box_t = minf(box_t + delta / 0.45, 1.0)
	if paper_shift != 0.0:
		paper_shift = lerpf(paper_shift, 0.0, 1.0 - exp(-9.0 * delta))
		if absf(paper_shift) < 0.5:
			paper_shift = 0.0
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] += delta / 1.2
		popups[i]["pos"] += Vector2(0.0, -34.0 * delta)
		if popups[i]["t"] >= 1.0:
			popups.remove_at(i)
	for st in tape_strokes:
		st["age"] += delta
	for st in ribbon_strokes:
		st["age"] += delta

	if step == Step.ARRIVING:
		arrive_t += delta / 0.7
		var e := U.ease_out_back(arrive_t)
		gift_off = Vector2(0.0, -170.0 * (1.0 - U.ease_out(arrive_t)))
		gift_scale = maxf(lerpf(0.2, 1.0, e), 0.05)
		if arrive_t >= 1.0:
			gift_off = Vector2.ZERO
			gift_scale = 1.0
			_after_arrival()
	elif step == Step.WRAP or step == Step.PULL or step == Step.PAPER:
		var k := 1.0 - exp(-14.0 * delta)
		for i in 4:
			if flap_drag != i:
				theta[i] = lerpf(theta[i], theta_target[i], k)
				if absf(theta[i] - theta_target[i]) < 0.004:
					theta[i] = theta_target[i]
		if step == Step.WRAP:
			if not tucked and folded[0] and folded[1] and folded[2] and folded[3]:
				var settled := true
				for i in 4:
					if theta[i] > 0.004:
						settled = false
				if settled:
					tucked = true
					tuck_t = 0.0
					tail_t = 0.001
					AudioSynth.play_sfx("fold", -3.0, 0.8)
					_hint("Edges are folded. Tape it where you like, draw the ribbon around the gift, or hand it over")
			if tucked:
				if tuck_t < 1.0 or clip_cur.size() < 3:
					tuck_t = move_toward(tuck_t, 1.0, delta / 0.45)
					_update_clip()
				if wrap_mode == "shape" and tail_t > 0.0:
					tail_t = minf(tail_t + delta / 0.7, 1.0)
	queue_redraw()


func _update_clip() -> void:
	if wrap_mode != "shape" or sil_poly.size() < 3 or not tucked:
		clip_cur = PackedVector2Array()
		return
	var d := SHAPE_PAD + (1.0 - U.ease_in_out(tuck_t)) * 46.0
	var offs := Geometry2D.offset_polygon(sil_poly, d, Geometry2D.JOIN_ROUND)
	if offs.size() > 0:
		clip_cur = offs[0]


func _on_motion(pos: Vector2) -> void:
	hover = _hit_test(pos)
	mouse_pos = pos
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
	if measuring:
		ruler_b = pos
	if stroking:
		_move_stroke(pos)
	if pulling:
		_update_pull(pos)
	if flap_drag >= 0:
		_update_flap_drag(pos)
	if bow_drag:
		bow_size = clampf(bow_drag_start + (bow_drag_y - pos.y) / 120.0, 0.6, 1.8)


func _on_press(pos: Vector2) -> void:
	var hit := _hit_test(pos)
	if hit == "bell":
		_try_deliver()
		return
	if hit == "bin":
		_discard()
		return
	if hit == "tape":
		if step == Step.WRAP:
			_select_tool("tape")
		else:
			toast.emit("You will need tape once the paper is cut")
		return
	if hit == "scissors":
		if step == Step.PULL:
			_select_tool("scissors")
		else:
			toast.emit("Scissors are for cutting the paper after you pull it out")
		return
	if hit == "ruler":
		if step == Step.PAPER or step == Step.PULL or step == Step.WRAP:
			_select_tool("ruler")
		else:
			toast.emit("The ruler is for measuring a gift that is on the table")
		return
	if hit.begins_with("spool:"):
		if step == Step.WRAP:
			_select_ribbon_tool(int(hit.substr(6)))
		else:
			toast.emit("Ribbon goes around a gift that is already wrapped")
		return
	if step == Step.CHOOSE:
		if hit.begins_with("card:"):
			_choose_card(int(hit.substr(5)))
		return
	if active_tool == "ruler" and MAT_RECT.has_point(pos):
		measuring = true
		ruler_has = true
		ruler_a = pos
		ruler_b = pos
		AudioSynth.play_sfx("click")
		return
	if step == Step.PAPER or step == Step.PULL:
		if hit.begins_with("roll:"):
			_select_paper(int(hit.substr(5)))
			return
		if hit.begins_with("axis:") and step == Step.PULL:
			_set_axis(hit.substr(5))
			return
		if step == Step.PULL and MAT_RECT.has_point(pos):
			if active_tool == "scissors":
				_do_cut(pos)
			else:
				pulling = true
				pull_moved = false
				pull_press = pos
				last_pull_len = sheet_len
	elif step == Step.WRAP:
		if not ribbon_strokes.is_empty() and _has_ribbon() and _bow_hit(pos):
			bow_drag = true
			bow_drag_y = pos.y
			bow_drag_start = bow_size
			return
		if active_tool != "":
			_begin_stroke(pos)
		elif MAT_RECT.has_point(pos) and absf(paper_shift) < 2.0:
			_begin_flap_drag(pos)


func _on_release() -> void:
	measuring = false
	if pulling:
		pulling = false
		_finish_pull()
	if flap_drag >= 0:
		_end_flap_drag()
	_end_stroke()
	bow_drag = false


func _select_paper(slot: int) -> void:
	paper_idx = int(inv_papers[slot])
	pull_len = _pull_min()
	sheet_len = pull_len
	pulling = false
	pull_moved = false
	paper_shift = 0.0
	step = Step.PULL
	AudioSynth.play_sfx("paper_pull")
	_hint("Choose the direction, then drag the loose end: the gift stays in the middle and the roll rolls away. Then cut with the scissors")


## Тянем свободный конец вправо: лист остаётся по центру подарка, рулон отъезжает влево.
func _update_pull(pos: Vector2) -> void:
	if not pull_moved and pos.distance_to(pull_press) < 6.0:
		return
	pull_moved = true
	var lp := _to_paper(pos - CENTER)
	pull_len = clampf(2.0 * lp.x, _pull_min(), _pull_max())
	sheet_len = pull_len
	if absf(pull_len - last_pull_len) > 60.0:
		last_pull_len = pull_len
		AudioSynth.play_sfx("paper_pull", -4.0, randf_range(0.9, 1.2))


## Отпустили конец: лист вытянут, но ещё не отрезан. Дальше нужны ножницы.
func _finish_pull() -> void:
	if not pull_moved:
		return
	_hint("Now take the scissors (right panel) and click where to cut. The piece slides under the gift")


## Ножницы отрезают кусок от свободного конца. Длина куска = от линии реза до конца листа.
func _do_cut(pos: Vector2) -> void:
	var lp := _to_paper(pos - CENTER)
	var u1 := pull_len * 0.5
	var u_c := clampf(lp.x, -u1 + 6.0, u1 - MIN_SHEET)
	var cut_len := u1 - u_c
	sheet_len = cut_len
	paper_shift = (u_c + u1) * 0.5
	if sheet_len < _l_min():
		length_class = "short"
	elif sheet_len <= _l_min() + GOOD_RANGE:
		length_class = "good"
	else:
		length_class = "long"
	AudioSynth.play_sfx("cut")
	_spend("paper", _paper_cost(cut_len), CENTER + Vector2(0, -60))
	active_tool = ""
	step = Step.WRAP
	theta = [PI, PI, PI, PI]
	theta_target = [PI, PI, PI, PI]
	folded = [false, false, false, false]
	fold_order = []
	if length_class == "short":
		toast.emit("Not enough paper: the gift may come out crooked")
	_hint("Fold the edges by hand: both ends, then both sides. Tape and ribbon are on the right")


func _begin_flap_drag(pos: Vector2) -> void:
	var lp := _to_paper(pos - CENTER)
	var fh := _flap_len()
	var nx := absf(lp.x) / (_along() * 0.5 + maxf(fh, 20.0))
	var ny := absf(lp.y) / (_across() * 0.5 + MARGIN)
	var side := 0 if lp.x < 0.0 else 1
	var end := 2 if lp.y < 0.0 else 3
	var order: Array = [side, end, 1 - side, 5 - end] if nx >= ny else [end, side, 5 - end, 1 - side]
	for cand in order:
		var c: int = cand
		if folded[c]:
			continue
		if c < 2 and fh < 1.0:
			continue
		flap_drag = c
		_update_flap_drag(pos)
		return


func _update_flap_drag(pos: Vector2) -> void:
	var lp := _to_paper(pos - CENTER)
	var f := _flap_len() if flap_drag < 2 else MARGIN
	if f < 1.0:
		return
	var c := 0.0
	match flap_drag:
		0:
			c = (lp.x + _along() * 0.5) / f
		1:
			c = (_along() * 0.5 - lp.x) / f
		2:
			c = (lp.y + _across() * 0.5) / f
		_:
			c = (_across() * 0.5 - lp.y) / f
	theta[flap_drag] = acos(clampf(c, -1.0, 1.0))
	theta_target[flap_drag] = theta[flap_drag]


func _end_flap_drag() -> void:
	var i := flap_drag
	flap_drag = -1
	if theta[i] < FOLD_SNAP_ANGLE:
		theta_target[i] = 0.0
		folded[i] = true
		fold_order.append(i)
		AudioSynth.play_sfx("fold", 0.0, randf_range(0.92, 1.08))
	else:
		theta_target[i] = PI
		AudioSynth.play_sfx("paper_pull", -6.0, 1.3)


func _select_tool(tool_name: String) -> void:
	active_tool = "" if active_tool == tool_name else tool_name
	measuring = false
	ruler_has = false
	AudioSynth.play_sfx("click")
	if active_tool == "ruler":
		_hint("Ruler in hand: the size of the gift and of the paper is shown in cm. Press and drag to measure anything")
	elif active_tool == "tape":
		_hint("Tape in hand: press and drag anywhere on the gift, as much as you need")
	elif active_tool == "scissors":
		_hint("Scissors in hand: click on the paper where to cut. The piece from the cut to the loose end slides under the gift")
	elif step == Step.WRAP:
		_hint("Fold the edges, tape, draw the ribbon, or hand over the gift")


## Катушку ленты берут в руку и сами обводят ленту вокруг подарка.
func _select_ribbon_tool(slot: int) -> void:
	var gi := int(inv_ribbons[slot])
	if active_tool == "ribbon" and ribbon_idx == gi:
		active_tool = ""
	else:
		active_tool = "ribbon"
		ribbon_idx = gi
	AudioSynth.play_sfx("ribbon")
	if active_tool == "ribbon":
		_hint("Ribbon in hand: press and draw it around the gift. Cross it however you like")


func _stroke_region() -> PackedVector2Array:
	if tucked and wrap_mode == "shape" and clip_cur.size() >= 3:
		var offs := Geometry2D.offset_polygon(clip_cur, REACH, Geometry2D.JOIN_ROUND)
		return offs[0] if offs.size() > 0 else clip_cur
	var half := maxf(sheet_len * 0.5, _along() * 0.5)
	var xl := -_along() * 0.5 if folded[0] else -half
	var xr := _along() * 0.5 if folded[1] else half
	var mt := 0.0 if folded[2] else MARGIN
	var mb := 0.0 if folded[3] else MARGIN
	var pts := U.rect_pts(Rect2(xl - REACH, -_across() * 0.5 - mt - REACH, xr - xl + 2.0 * REACH, _across() + mt + mb + 2.0 * REACH))
	var out := PackedVector2Array()
	for p in pts:
		out.append(p.rotated(rot))
	return out


func _begin_stroke(pos: Vector2) -> void:
	if active_tool == "" or paper_idx < 0:
		return
	var lp := pos - CENTER
	if not Geometry2D.is_point_in_polygon(lp, _stroke_region()):
		return
	var count := tape_strokes.size() if active_tool == "tape" else ribbon_strokes.size()
	if count >= STROKE_MAX:
		toast.emit("Out of tape" if active_tool == "tape" else "Out of ribbon")
		return
	stroking = true
	stroke_kind = active_tool
	stroke_pts = PackedVector2Array([lp])
	AudioSynth.play_sfx("tape" if stroke_kind == "tape" else "ribbon")


func _move_stroke(pos: Vector2) -> void:
	if not stroking:
		return
	var lp := pos - CENTER
	if not Geometry2D.is_point_in_polygon(lp, _stroke_region()):
		_end_stroke()
		return
	var last := stroke_pts[stroke_pts.size() - 1]
	var d := last.distance_to(lp)
	if d < 4.0:
		return
	var n := maxi(int(d / 4.0), 1)
	for i in range(1, n + 1):
		stroke_pts.append(last.lerp(lp, float(i) / float(n)))


## Полоска отпущена: считаем длину и списываем расход по длине.
func _end_stroke() -> void:
	if not stroking:
		return
	stroking = false
	var total := 0.0
	for i in range(1, stroke_pts.size()):
		total += stroke_pts[i - 1].distance_to(stroke_pts[i])
	if total < 20.0:
		stroke_pts = PackedVector2Array()
		return
	var last := stroke_pts[stroke_pts.size() - 1]
	var pts := stroke_pts.duplicate()
	stroke_pts = PackedVector2Array()
	if stroke_kind == "tape":
		tape_strokes.append({"pts": pts, "len": total, "age": 0.0})
		_spend("tape", maxi(roundi(total / TAPE_COST_PER), 1), CENTER + last + Vector2(0, -34))
	else:
		var had := _has_ribbon()
		ribbon_strokes.append({"pts": pts, "len": total, "age": 0.0, "ribbon": ribbon_idx})
		var rb: Dictionary = Data.RIBBONS[ribbon_idx]
		_spend("ribbon", maxi(roundi(total / 100.0 * float(rb["cost"])), 1), CENTER + last + Vector2(0, -34))
		if not had and _has_ribbon():
			bow_pop = 0.0
			AudioSynth.play_sfx("pop_in")


func _ribbon_len() -> float:
	var s := 0.0
	for st in ribbon_strokes:
		s += float(st["len"])
	return s


func _has_ribbon() -> bool:
	return _ribbon_len() >= RIBBON_MIN_LEN


## Бант сам завязывается там, где лежит основная масса ленты.
func _bow_pos() -> Vector2:
	if ribbon_strokes.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for st in ribbon_strokes:
		var pts: PackedVector2Array = st["pts"]
		sum += pts[pts.size() / 2]
	return sum / float(ribbon_strokes.size())


func _bow_hit(pos: Vector2) -> bool:
	return (pos - CENTER - _bow_pos()).length() < 46.0 * bow_size + 10.0


func _neatness() -> Dictionary:
	var w := _along()
	var f := _flap_len()
	var spans: Array = []
	if folded[0]:
		spans.append(Vector2(-w * 0.5, -w * 0.5 + minf(f, w)))
	if folded[1]:
		spans.append(Vector2(w * 0.5 - minf(f, w), w * 0.5))
	var covered := 0.0
	if spans.size() == 1:
		var a1: Vector2 = spans[0]
		covered = a1.y - a1.x
	elif spans.size() == 2:
		var a: Vector2 = spans[0]
		var b: Vector2 = spans[1]
		covered = (a.y - a.x) + (b.y - b.x) - maxf(0.0, minf(a.y, b.y) - maxf(a.x, b.x))
	var cover := clampf(covered / w, 0.0, 1.0)
	var ends := (1 if folded[2] else 0) + (1 if folded[3] else 0)
	var tape_len := 0.0
	for st in tape_strokes:
		tape_len += float(st["len"])
	var tape_ok := tape_len >= 0.6 * _across()
	var neat := 0.55 * cover + 0.10 * float(ends) + (0.25 if tape_ok else 0.0)
	return {"neat": clampf(neat, 0.0, 1.0), "cover": cover, "ends": ends, "tape_len": tape_len, "tape_ok": tape_ok}


## Выбросить текущий подарок и начать заново (потраченные материалы не возвращаются).
func _discard() -> void:
	if item.is_empty() or step < Step.PAPER or step > Step.WRAP:
		return
	if paper_idx < 0 and box_idx < 0:
		return
	bin_shake = 0.5
	AudioSynth.play_sfx("crumple")
	toast.emit("Thrown away. The materials are spent, starting over")
	var keep_id := item_id
	_reset_gift_state()
	item_id = keep_id
	_after_arrival()


func _try_deliver() -> void:
	if step == Step.IDLE or step == Step.ARRIVING or step == Step.DELIVER:
		return
	if step != Step.WRAP or not (folded[0] or folded[1] or folded[2] or folded[3]):
		bell_shake = 0.4
		AudioSynth.play_sfx("dull")
		toast.emit("The gift is not wrapped yet: fold at least one edge")
		return
	var nt := _neatness()
	var rid := ""
	var rcol := ""
	var bonus := 0.0
	var pp: Dictionary = Data.PAPERS[paper_idx]
	bonus += float(pp["bonus"])
	if _has_ribbon():
		var last_idx := int(ribbon_strokes[ribbon_strokes.size() - 1]["ribbon"])
		var rb: Dictionary = Data.RIBBONS[last_idx]
		rid = rb["id"]
		rcol = rb["color"]
		bonus += float(rb["bonus"])
	if box_idx >= 0:
		var bx: Dictionary = Data.BOXES[box_idx]
		bonus += float(bx["bonus"])
	var choice := "native"
	if item_kind != "box":
		choice = "box" if box_idx >= 0 else "shape"
	var look_mode := "shape" if (tucked and wrap_mode == "shape") else "rect"
	result = {
		"paper_tag": pp["tag"],
		"length_class": length_class,
		"crumpled": 0,
		"tape_count": tape_strokes.size(),
		"ribbon": rid,
		"bow_size": bow_size,
		"wrap_choice": choice,
		"bonus": minf(bonus, 0.2),
		"neat": nt["neat"],
		"cover": nt["cover"],
		"look": {
			"kind": item_kind, "item_id": item_id, "w": item_w, "h": item_h, "wrap_mode": look_mode,
			"base": pp["base"], "accent": pp["accent"], "ribbon": rcol, "bow": bow_size,
		},
	}
	bell_shake = 0.5
	AudioSynth.play_sfx("bell")
	step = Step.DELIVER
	_hint("")
	gift_ready.emit(result)


## Полоска скотча по пути (в локальных координатах подарка).
func _draw_tape_path(pts: PackedVector2Array, age: float) -> void:
	if pts.size() < 2:
		return
	var w := TAPE_W * (1.0 + 0.35 * exp(-age * 12.0))
	var col := Color(0.97, 0.95, 0.82, 0.62)
	draw_polyline(pts, col, w, true)
	draw_polyline(pts, Color(1, 1, 1, 0.35), w * 0.3, true)
	draw_circle(pts[0], w * 0.5, col)
	draw_circle(pts[pts.size() - 1], w * 0.5, col)


## Лента по пути, обведённому игроком.
func _draw_ribbon_path(pts: PackedVector2Array, age: float, rc: Color) -> void:
	if pts.size() < 2:
		return
	var w := RIBBON_W * (1.0 + 0.3 * exp(-age * 12.0))
	draw_polyline(pts, U.INK, w + 5.0, true)
	draw_polyline(pts, rc, w, true)
	draw_polyline(pts, rc.lightened(0.3), w * 0.28, true)


## Инструмент «в руке»: ножницы, скотч или катушка ленты рядом с курсором.
func _draw_tool_cursor() -> void:
	if active_tool == "" or not MAT_RECT.grow(60.0).has_point(mouse_pos):
		return
	var c := mouse_pos + Vector2(20, 22)
	if active_tool == "tape":
		U.fill_stroke(self, U.ellipse(c, 14.0, 14.0, 0.0, 20), Color("#efe2b8"), 3.0, time)
		draw_colored_polygon(U.ellipse(c, 6.0, 6.0, 0.0, 14), Color("#3a3a46"))
	elif active_tool == "ruler":
		_draw_ruler_icon(c + Vector2(4, 2), 0.7, -0.6, false)
	elif active_tool == "scissors":
		for sg in [-1.0, 1.0]:
			var s: float = sg
			draw_line(c + Vector2(s * 7.0, 12.0), c + Vector2(-s * 9.0, -14.0), U.INK, 6.0)
			draw_line(c + Vector2(s * 7.0, 12.0), c + Vector2(-s * 9.0, -14.0), Color("#d7dce4"), 3.0)
			draw_circle(c + Vector2(s * 8.0, 15.0), 5.0, Color("#d8343a"))
	elif ribbon_idx >= 0:
		var rb: Dictionary = Data.RIBBONS[ribbon_idx]
		var rc := Color.html(rb["color"])
		U.fill_stroke(self, U.ellipse(c, 15.0, 15.0, 0.0, 20), rc, 3.0, time)
		draw_colored_polygon(U.ellipse(c, 6.0, 6.0, 0.0, 14), Color("#3b2a22"))


func _axis_rect(a: String) -> Rect2:
	# Две кнопки друг под другом в левом верхнем углу: рулон (слева или сверху) их не задевает.
	return Rect2(MAT_RECT.position.x + 14.0, MAT_RECT.position.y + 12.0 + (0.0 if a == "h" else 46.0), 130.0, 38.0)


## Кнопки выбора направления, в котором тянут бумагу.
func _draw_axis_buttons() -> void:
	if step != Step.PULL:
		return
	for a in ["h", "v"]:
		var key: String = a
		var r := _axis_rect(key)
		var on := axis == key
		var hov := hover == "axis:" + key
		var col := Color("#f0c05a") if on else (Color("#d9cdb2") if hov else Color("#b8ac92"))
		U.fill_stroke(self, U.rect_pts(r), col, 3.5, time)
		var c := Vector2(r.position.x + 20.0, r.get_center().y)
		var dir := Vector2(1, 0) if key == "h" else Vector2(0, 1)
		draw_line(c - dir * 10.0, c + dir * 10.0, U.INK, 3.0)
		for sg in [-1.0, 1.0]:
			var s: float = sg
			var tip := c + dir * 12.0 * s
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 8.0 * s + perp * 6.0, tip - dir * 8.0 * s - perp * 6.0]), U.INK)
		draw_string(font, Vector2(r.position.x + 40.0, r.position.y + 26.0), "Horizontal" if key == "h" else "Vertical", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, U.INK)


func _draw_scissors() -> void:
	var c := SCISSORS_POS
	var on := active_tool == "scissors"
	var hov := hover == "scissors"
	var glow := 0.0
	if on:
		glow = 1.0
	elif step == Step.PULL and pull_moved:
		glow = 0.5 + 0.5 * sin(time * 5.0)
	var open := 0.4 if (on or hov) else 0.16
	draw_colored_polygon(U.ellipse(c + Vector2(0, 30), 40.0, 9.0), Color(0, 0, 0, 0.25))
	for sg in [-1.0, 1.0]:
		var s: float = sg
		var handle := c + Vector2(s * 15.0, 24.0)
		var tip := c + Vector2(-s * open * 46.0, -40.0)
		draw_line(handle, tip, U.INK, 9.0)
		draw_line(handle, tip, Color("#d7dce4"), 5.0)
		U.fill_stroke(self, U.ellipse(handle, 10.0, 12.0, 0.0, 16), Color("#d8343a"), 3.0, time)
		draw_colored_polygon(U.ellipse(handle, 4.0, 5.0, 0.0, 10), Color("#6a1d20"))
	draw_circle(c, 4.0, U.INK)
	if glow > 0.0:
		draw_arc(c + Vector2(0, -6), 44.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.3 + 0.5 * glow), 3.0)
	draw_string(font, c + Vector2(-40, 56), "Scissors", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(1, 0.96, 0.85, 0.9))


## Деревянная линейка с делениями (иконка и курсор).
func _draw_ruler_icon(c: Vector2, k: float, ang: float, shadow: bool) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	var hl := 38.0 * k
	var hw := 11.0 * k
	if shadow:
		draw_colored_polygon(U.ellipse(c + Vector2(0, 26.0 * k), 40.0 * k, 8.0 * k), Color(0, 0, 0, 0.25))
	var pts := PackedVector2Array([c - dir * hl - perp * hw, c + dir * hl - perp * hw, c + dir * hl + perp * hw, c - dir * hl + perp * hw])
	U.fill_stroke(self, pts, Color("#d9b46a"), 3.0, time)
	for i in range(-6, 7):
		var p := c + dir * float(i) * 5.6 * k - perp * hw
		var ln := (hw * 0.9) if i % 2 == 0 else (hw * 0.55)
		draw_line(p, p + perp * ln, U.INK, 1.6)


func _draw_ruler_button() -> void:
	var on := active_tool == "ruler"
	var hov := hover == "ruler"
	_draw_ruler_icon(RULER_POS + Vector2(0, -4), 1.0, -0.6 if not (on or hov) else -0.75, true)
	if on:
		draw_arc(RULER_POS + Vector2(0, -4), 44.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.85), 3.0)
	draw_string(font, RULER_POS + Vector2(-40, 46), "Ruler", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(1, 0.96, 0.85, 0.9))


## Размерная линия с засечками каждый сантиметр и подписью.
func _dim_line(a: Vector2, b: Vector2, text: String, col: Color, label_off: Vector2) -> void:
	var d := b - a
	if d.length() < 2.0:
		return
	var n := d.normalized()
	var perp := Vector2(-n.y, n.x)
	draw_line(a, b, U.INK, 5.0)
	draw_line(a, b, col, 2.5)
	for pe in [a, b]:
		var q: Vector2 = pe
		draw_line(q - perp * 10.0, q + perp * 10.0, U.INK, 5.0)
		draw_line(q - perp * 9.0, q + perp * 9.0, col, 2.5)
	var cm := int(d.length() / PX_PER_CM)
	for k in range(1, cm):
		var q2 := a + n * PX_PER_CM * float(k)
		var ln := 7.0 if k % 5 == 0 else 4.0
		draw_line(q2, q2 + perp * ln, col, 1.5)
	var mid := (a + b) * 0.5 + label_off
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(Rect2(mid - Vector2(sz.x * 0.5 + 8.0, 17.0), Vector2(sz.x + 16.0, 26.0)), Color(0.12, 0.08, 0.07, 0.88))
	draw_string(font, mid + Vector2(-sz.x * 0.5, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.8))


## Точка в системе координат бумаги (u вдоль вытяжки, v поперёк) в координатах экрана.
func _paper_pt(u: float, v: float) -> Vector2:
	var s := maxf(gift_scale, 0.001)
	return CENTER + gift_off + (Vector2(paper_shift + u, v) * s).rotated(rot)


## Линейка в руке: размеры подарка и листа в сантиметрах, плюс свободный замер перетаскиванием.
func _draw_ruler_overlay() -> void:
	if active_tool != "ruler" or item.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s := maxf(gift_scale, 0.001)
	var half := Vector2(item_w, item_h) * 0.5 * s
	var c := CENTER + gift_off
	var gcol := Color("#8fe0c0")
	_dim_line(c + Vector2(-half.x, half.y + 20.0), c + Vector2(half.x, half.y + 20.0), "%d cm" % roundi(item_w / PX_PER_CM), gcol, Vector2(0, 22))
	_dim_line(c + Vector2(half.x + 20.0, -half.y), c + Vector2(half.x + 20.0, half.y), "%d cm" % roundi(item_h / PX_PER_CM), gcol, Vector2(40, 0))
	if (step == Step.PULL or step == Step.WRAP) and not folded.has(true) and not tucked:
		var plen := pull_len if step == Step.PULL else sheet_len
		var need := _l_min()
		var pcol := Color("#ffe07a") if plen >= need else Color("#ff9a7a")
		var v := -(_across() * 0.5 + MARGIN + 34.0)
		var tx := "Paper %d cm (need %d+)" % [roundi(plen / PX_PER_CM), ceili(need / PX_PER_CM)]
		_dim_line(_paper_pt(-plen * 0.5, v), _paper_pt(plen * 0.5, v), tx, pcol, Vector2(0, -24) if rot == 0.0 else Vector2(60, 0))
	if ruler_has:
		var d := ruler_b - ruler_a
		_dim_line(ruler_a, ruler_b, "%.1f cm" % (d.length() / PX_PER_CM), Color("#a8d4ff"), Vector2(0, -24))


## Где ножницы отрежут: линия реза вдоль листа и длина куска.
func _draw_cut_preview() -> void:
	if step != Step.PULL or active_tool != "scissors" or not MAT_RECT.has_point(mouse_pos):
		return
	var lp := _to_paper(mouse_pos - CENTER)
	var u1 := pull_len * 0.5
	var u_c := clampf(lp.x, -u1 + 6.0, u1 - MIN_SHEET)
	var hh := _across() * 0.5 + MARGIN + 12.0
	_set_paper_transform()
	draw_dashed_line(Vector2(u_c, -hh), Vector2(u_c, hh), Color(1.0, 0.45, 0.4, 0.95), 3.0, 8.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(font, mouse_pos + Vector2(18, -14), "Cut length: %d" % int(u1 - u_c), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.8, 0.75))


## Вид во время вытяжки: лист по центру подарка, свободный конец идёт за курсором,
## рулон откатывается в другую сторону и становится тоньше.
func _draw_pull_view(paper: Dictionary, ir: Rect2) -> void:
	var u0 := -pull_len * 0.5
	var u1 := pull_len * 0.5
	var half_v := _across() * 0.5 + MARGIN
	_set_paper_transform()
	var sr := Rect2(u0, -half_v, pull_len, half_v * 2.0)
	draw_rect(Rect2(sr.position + Vector2(5, 7), sr.size), Color(0, 0, 0, 0.22))
	_draw_print(sr, paper, u0, 1.0, PackedVector2Array())
	draw_rect(Rect2(u1 - 9.0, -half_v, 9.0, half_v * 2.0), Color(0, 0, 0, 0.12))
	_rect_stroke(sr, 3.0)
	var prog := clampf(inverse_lerp(_pull_min(), _pull_max(), pull_len), 0.0, 1.0)
	_draw_roll_on_table(paper, u0, half_v, lerpf(52.0, 36.0, prog))   # рулон очень большой: при максимальной раскатке худеет лишь на ~30%
	_set_gift_transform()
	_draw_subject(ir)


## Рулон лежит на столе, вид строго сверху: сбоку виден цилиндр (прямоугольник с цилиндрической светотенью),
## концы картонной гильзы торчат с двух сторон. rt: толщина рулона вдоль вытяжки, он худеет по мере разворота;
## швы слоёв бегут по поверхности, пока рулон откатывается.
func _draw_roll_on_table(paper: Dictionary, u0: float, half_v: float, rt: float) -> void:
	var r := Rect2(u0 - rt, -half_v, rt + 2.0, half_v * 2.0)
	var cx := r.position.x + r.size.x * 0.5
	var rad := maxf(rt * 0.5, 1.0)
	var tube := Rect2(cx - rt * 0.24, r.position.y - 10.0, rt * 0.48, r.size.y + 20.0)
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.28))
	draw_rect(tube, Color("#d9c7a0"))
	_rect_stroke(tube, 2.5)
	_draw_print(r, paper, r.position.x, 1.0, PackedVector2Array())
	draw_rect(Rect2(r.position.x, r.position.y, rt * 0.24, r.size.y), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(r.position.x + rt * 0.30, r.position.y, rt * 0.14, r.size.y), Color(1, 1, 1, 0.20))
	draw_rect(Rect2(r.end.x - rt * 0.30, r.position.y, rt * 0.30, r.size.y), Color(0, 0, 0, 0.30))
	var ang0 := -pull_len * 0.5 / rad
	for k in 5:
		var a := TAU * float(k) / 5.0 + ang0
		var c := cos(a)
		if c > 0.1:
			var lx := cx + rad * sin(a)
			draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), Color(0, 0, 0, 0.18 * c), 1.5)
	_rect_stroke(r, 3.5)
	for sv in [-1.0, 1.0]:
		var ey: float = r.position.y if sv < 0.0 else r.end.y
		draw_line(Vector2(r.position.x, ey), Vector2(r.end.x, ey), U.INK, 3.0)


func _draw_gift() -> void:
	if item.is_empty() or step == Step.CHOOSE:
		return
	var shape_mode := wrap_mode == "shape"
	var iw := _along()
	var ih := _across()
	var hw := iw * 0.5
	var hh := ih * 0.5
	var ir := Rect2(-item_w * 0.5, -item_h * 0.5, item_w, item_h)
	var fh := _flap_len()
	var fv := MARGIN
	var paper: Dictionary = {}
	if paper_idx >= 0:
		paper = Data.PAPERS[paper_idx]
	var pbase := Color.html(paper["base"]) if not paper.is_empty() else Color.WHITE
	var clip := clip_cur
	var clip_p := _clip_to_paper(clip_cur)
	var lean: Array[float] = []
	for i in 4:
		lean.append(maxf(-cos(theta[i]), 0.0))
	var mt := fv * lean[2]
	var mb := fv * lean[3]
	var bw := minf(sheet_len, iw)

	if step == Step.PULL and not paper.is_empty():
		_draw_pull_view(paper, ir)
		_set_paper_transform()
		_draw_gift_hints(hh, fh)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# 1. основа листа и клапаны, ещё лежащие вбок (всё в системе координат бумаги)
	_set_paper_transform()
	if not paper.is_empty():
		var base_r := Rect2(-bw * 0.5, -hh, bw, ih)
		if clip_p.size() < 3:
			draw_rect(Rect2(base_r.position + Vector2(5, 7), base_r.size), Color(0, 0, 0, 0.22))
		_draw_print(base_r, paper, base_r.position.x, 1.0, clip_p)
		for i in 2:
			var sgn := -1.0 if i == 0 else 1.0
			var hinge := sgn * hw
			var ct := cos(theta[i])
			if fh > 0.0 and ct < 0.0:
				var xe := hinge - sgn * fh * ct
				var xa := minf(hinge, xe)
				var xb := maxf(hinge, xe)
				var shade := lerpf(0.78, 1.0, clampf((theta[i] - PI * 0.5) / (PI * 0.5), 0.0, 1.0))
				var lr := Rect2(xa, -hh - mt, xb - xa, ih + mt + mb)
				draw_rect(Rect2(lr.position + Vector2(4, 6), lr.size), Color(0, 0, 0, 0.18))
				_draw_print(lr, paper, -bw * 0.5, 1.0, PackedVector2Array())
				draw_rect(lr, Color(0, 0, 0, 1.0 - shade))
				_rect_stroke(lr, 3.0)
		for i in range(2, 4):
			var sgv := -1.0 if i == 2 else 1.0
			var hinge_y := sgv * hh
			var ctv := cos(theta[i])
			if ctv < 0.0:
				var ye := hinge_y - sgv * fv * ctv
				var ya := minf(hinge_y, ye)
				var yb := maxf(hinge_y, ye)
				var half := bw * 0.5
				var xl := -half - fh * lean[0]
				var xr := half + fh * lean[1]
				var shade_v := lerpf(0.78, 1.0, clampf((theta[i] - PI * 0.5) / (PI * 0.5), 0.0, 1.0))
				var vr := Rect2(xl, ya, xr - xl, yb - ya)
				_draw_print(vr, paper, xl, 1.0, PackedVector2Array())
				draw_rect(vr, Color(0, 0, 0, 1.0 - shade_v))
				_rect_stroke(vr, 3.0)

	# 2. сама вещь или коробка и собранный хвост (в системе координат стола)
	_set_gift_transform()
	_draw_subject(ir)
	if shape_mode and tail_t > 0.0 and not paper.is_empty() and item.has("tail"):
		_draw_tail(paper)

	# 3. клапаны поверх вещи (виден рисунок бумаги)
	_set_paper_transform()
	if not paper.is_empty():
		if fh > 0.0:
			var order: Array = fold_order.duplicate()
			for i in 2:
				if not order.has(i):
					order.append(i)
			for idx in order:
				var i2: int = idx
				if i2 > 1:
					continue
				var sgn2 := -1.0 if i2 == 0 else 1.0
				var hinge2 := sgn2 * hw
				var ct2 := cos(theta[i2])
				if ct2 < 0.0:
					continue
				var xe2 := hinge2 - sgn2 * fh * ct2
				var xa2 := minf(hinge2, xe2)
				var xb2 := maxf(hinge2, xe2)
				if xb2 - xa2 < 0.5:
					continue
				var cr := Rect2(xa2, -hh - mt, xb2 - xa2, ih + mt + mb)
				if clip_p.size() < 3:
					var shx := xe2 if sgn2 < 0.0 else xe2 - 6.0
					draw_rect(Rect2(shx, cr.position.y + 4.0, 6.0, cr.size.y), Color(0, 0, 0, 0.2))
				_draw_print(cr, paper, hinge2, -sgn2, clip_p)
				if clip_p.size() < 3:
					draw_rect(cr, Color(0, 0, 0, 0.22 * (1.0 - ct2)))
					draw_line(Vector2(xe2, cr.position.y), Vector2(xe2, cr.end.y), Color(1, 1, 1, 0.35), 2.0)
					_rect_stroke(cr, 3.0)
		for i in range(2, 4):
			var sgv2 := -1.0 if i == 2 else 1.0
			var hinge_y2 := sgv2 * hh
			var ctv2 := cos(theta[i])
			if ctv2 < 0.0 or fv * ctv2 < 0.5:
				continue
			var ye2 := hinge_y2 - sgv2 * fv * ctv2
			var ya2 := minf(hinge_y2, ye2)
			var yb2 := maxf(hinge_y2, ye2)
			var er := Rect2(-bw * 0.5, ya2, bw, yb2 - ya2)   # длина как у листа: короткий лист короче подарка
			_draw_print(er, paper, er.position.x, 1.0, clip_p)
			if clip_p.size() < 3:
				draw_rect(er, Color(0, 0, 0, 0.16 + 0.16 * (1.0 - ctv2)))
				draw_line(Vector2(er.position.x, ye2), Vector2(er.end.x, ye2), Color(1, 1, 1, 0.3), 2.0)
				_rect_stroke(er, 3.0)

	# 4. общий контур готового свёртка
	if tucked and not paper.is_empty():
		if shape_mode and clip.size() >= 3:
			_set_gift_transform()
			U.stroke(self, clip, U.INK, 4.0, time, 1.2)
		elif not shape_mode:
			_rect_stroke(Rect2(-hw, -hh, iw, ih), 4.0)

	# 5. скотч, лента, бант (в системе координат стола, рисует игрок)
	_set_gift_transform()
	for st in tape_strokes:
		_draw_tape_path(st["pts"], float(st["age"]))
	if stroking and stroke_kind == "tape" and stroke_pts.size() >= 2:
		_draw_tape_path(stroke_pts, 9.0)
	for st in ribbon_strokes:
		var rbs: Dictionary = Data.RIBBONS[int(st["ribbon"])]
		_draw_ribbon_path(st["pts"], float(st["age"]), Color.html(rbs["color"]))
	if stroking and stroke_kind == "ribbon" and stroke_pts.size() >= 2 and ribbon_idx >= 0:
		var rbc: Dictionary = Data.RIBBONS[ribbon_idx]
		_draw_ribbon_path(stroke_pts, 9.0, Color.html(rbc["color"]))
	if _has_ribbon():
		var last: Dictionary = Data.RIBBONS[int(ribbon_strokes[ribbon_strokes.size() - 1]["ribbon"])]
		var bs := bow_size * maxf(U.ease_out_back(bow_pop), 0.01)
		U.draw_bow(self, _bow_pos(), bs, Color.html(last["color"]), time)
	elif shape_mode and tucked and tail_t > 0.0 and item.has("tail"):
		var tl2: Array = item["tail"]
		var b2 := Vector2(float(tl2[0]), float(tl2[1]))
		var pp2 := Vector2(float(tl2[2]), float(tl2[3])).rotated(PI * 0.5)
		draw_line(b2 + pp2 * -18.0, b2 + pp2 * 18.0, Color("#6b4a2a"), 4.0)
		draw_circle(b2, 5.0, Color("#6b4a2a"))

	_set_paper_transform()
	_draw_gift_hints(hh, fh)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gift_hints(hh: float, f: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	if step == Step.PULL and paper_idx >= 0:
		var u1 := pull_len * 0.5
		var col := Color(1, 0.92, 0.6, 0.85)
		var top := -hh - MARGIN - 10.0
		var bot := hh + MARGIN + 10.0
		draw_dashed_line(Vector2(u1, top), Vector2(u1, bot), col, 2.0, 7.0)
		var hp := Vector2(u1 + 26.0, 0.0)
		draw_circle(hp, 15.0, Color(0.15, 0.1, 0.12, 0.75))
		draw_arc(hp, 15.0, 0.0, TAU, 24, col, 2.0)
		draw_colored_polygon(PackedVector2Array([hp + Vector2(-9, 0), hp + Vector2(-3, -5), hp + Vector2(-3, 5)]), col)
		draw_colored_polygon(PackedVector2Array([hp + Vector2(9, 0), hp + Vector2(3, -5), hp + Vector2(3, 5)]), col)
	elif step == Step.WRAP and active_tool == "" and flap_drag < 0 and not tucked:
		var hw := _along() * 0.5
		var acol := Color(1, 0.95, 0.7, 0.35 + 0.4 * pulse)
		for i in 2:
			if folded[i] or f < 1.0:
				continue
			var sgn := -1.0 if i == 0 else 1.0
			var xm := sgn * hw + sgn * f * 0.5
			var d := -sgn
			var tip := xm + d * 16.0
			var bs := xm - d * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(tip, 0), Vector2(bs, -12), Vector2(bs, 12)]), acol)
		for i in range(2, 4):
			if folded[i]:
				continue
			var sgv := -1.0 if i == 2 else 1.0
			var ym := sgv * hh + sgv * MARGIN * 0.5
			var dv := -sgv
			var tipv := ym + dv * 14.0
			var bsv := ym - dv * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, tipv), Vector2(-12, bsv), Vector2(12, bsv)]), acol)
