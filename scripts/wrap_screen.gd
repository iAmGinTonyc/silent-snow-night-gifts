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
const Fold = preload("res://scripts/paper_fold.gd")
const PaperMesh = preload("res://scripts/paper_mesh.gd")

# --- Раскладка (пиксели при окне 1280x720) ---
const CENTER := Vector2(640, 393)
const MAT_RECT := Rect2(286, 154, 708, 478)
const TICKET_RECT := Rect2(405, 10, 500, 130)

const T_BACK := preload("res://art/wrap/wrap_back.jpg")
const T_SCISSORS := preload("res://art/wrap/scissors.png")
const T_TAPE := preload("res://art/wrap/tape.png")
const T_RULER := preload("res://art/wrap/ruler.png")
const T_BIN := preload("res://art/wrap/bin.png")
const T_BELL := preload("res://art/wrap/bell.png")
const T_SPOOLS := {
	"red": preload("res://art/wrap/spool_red.png"), "green": preload("res://art/wrap/spool_green.png"),
	"gold": preload("res://art/wrap/spool_gold.png"), "blue": preload("res://art/wrap/spool_blue.png"),
	"pink": preload("res://art/wrap/spool_pink.png"), "silver": preload("res://art/wrap/spool_silver.png"),
	"purple": preload("res://art/wrap/spool_purple.png"),
}
# подарки сверху (ёлочная игрушка стоит шапочкой вверх, как на силуэте)
const T_TOP := {
	"bear": preload("res://art/wrap/top_bear.png"), "ornament": preload("res://art/shop/item_ornament.png"),
	"ball": preload("res://art/wrap/top_ball.png"), "train": preload("res://art/wrap/top_train.png"),
	"bear_mid": preload("res://art/wrap/top_bear_mid.png"), "ornament_mid": preload("res://art/wrap/top_ornament_mid.png"),
	"ball_mid": preload("res://art/wrap/top_ball_mid.png"), "train_mid": preload("res://art/wrap/top_train_mid.png"),
}
# нарисованные рулоны базовых бумаг; для узорчатых берём серый рулон и красим его цветом бумаги
const T_ROLLS := {
	"kraft": preload("res://art/wrap/roll_kraft.png"), "red_plain": preload("res://art/wrap/roll_red_plain.png"),
	"green_plain": preload("res://art/wrap/roll_green_plain.png"), "blue_plain": preload("res://art/wrap/roll_blue_plain.png"),
}
const T_ROLL_NEUTRAL := preload("res://art/wrap/roll_neutral.png")
# текстуры полосок: каждая лента и скотч — полоска с контуром, тянется вдоль пути
const T_BANDS := {
	"tape": preload("res://art/wrap/band_tape.png"), "red": preload("res://art/wrap/band_red.png"),
	"green": preload("res://art/wrap/band_green.png"), "gold": preload("res://art/wrap/band_gold.png"),
	"blue": preload("res://art/wrap/band_blue.png"), "pink": preload("res://art/wrap/band_pink.png"),
	"silver": preload("res://art/wrap/band_silver.png"), "purple": preload("res://art/wrap/band_purple.png"),
}
const ROLL_BODY_W := 53.0     # толщина рулона в спрайте (px)
const ROLL_BODY_TOP := 24.0   # строка спрайта, где начинается тело рулона (выше — торчит гильза)
const ROLL_BODY_BOT := 158.0  # строка, где тело заканчивается
const ROLL_SLICE_TOP := 32.0  # верхний «колпак»: строки 0..32 не тянутся
const ROLL_SLICE_BOT := 150.0 # нижний «колпак»: строки от 150 не тянутся
const ROLL_LEN := 170.0       # длина рулона в левой панели
const ROLL_THICK := 50.0
const SPOOL_R := 26.0
const SPOOL_SIZE := 56.0
# правая панель (деревянная плашка 1060..1224 x 175..620): две колонки, ничего не наезжает друг на друга
const COL_L := 1104.0
const COL_R := 1190.0
const TAPE_POS := Vector2(COL_L, 436)
const BIN_POS := Vector2(COL_R, 438)
const SCISSORS_POS := Vector2(COL_L, 502)
const RULER_POS := Vector2(COL_R, 506)
const BELL_POS := Vector2(1147, 578)
const BELL_R := 31.0
const AXIS_POS := Vector2(333, 192)   # левый верхний угол кнопки Horizontal (внутри контура мата)
const PX_PER_CM := 6.0      # масштаб линейки: 1 см = 6 px
const CARD_SIZE := Vector2(200, 240)

# --- Механика упаковки ---
const STROKE_TOL := 5.0    # допуск у края бумаги при рисовании скотча и ленты
const MARGIN := 36.0        # поле листа сверху и снизу (загибается руками)
const MIN_OVERLAP := 16.0   # нахлёст клапанов для «хорошей» длины
const GOOD_RANGE := 90.0    # «хорошая» длина: Lmin .. Lmin + GOOD_RANGE
const EXTRA_LEN := 160.0    # Lmax = 2*w + EXTRA_LEN
const MIN_SHEET := 60.0     # самый короткий лист, который можно отрезать
const PREVIEW_EXTRA := 30.0
const TAPE_W := 18.0
const TAPE_COST_PER := 120.0  # пикселей скотча на 1 монету
const RIBBON_W := 20.0
const RIBBON_MIN_LEN := 80.0  # меньше этого ленты не видно как ленту
const STROKE_MAX := 8
const REACH := 12.0           # насколько за край бумаги можно вести скотч и ленту
const RIBBON_PICK := 34.0     # на каком расстоянии от края можно «взять» начало ленты
const RIBBON_MIN_PIECE := 36.0  # самый короткий кусок ленты от края до края
const FOLD_MIN_DRAG := 12.0   # меньше этого рука просто лежит на бумаге
const FOLD_COMMIT_PHI := 1.22 # около 70 градусов: дальше сгиб довершается сам, меньше — пружинит назад
const FOLD_SNAP_DEG := 5.0    # линия сгиба в пределах этого угла от оси или диагонали становится ровной
const FOLD_SNAP_EDGE := 10.0  # сгиб ближе этого к ребру вещи ложится точно на ребро
const CURL_R := 18.0          # радиус изгиба бумаги у сгиба, пока клапан в движении
const MESH_STIFF := 40.0      # пружина частиц бумаги
const MESH_DAMP := 8.0
const MESH_SETTLE := 0.2      # сколько частицы «усаживаются» после доводки сгиба
const TUCK_COVER := 0.95      # какая доля вещи закрыта сложенной бумагой, чтобы подарок считался завёрнутым
const CUT_EDGE_TOL := 18.0    # насколько можно не дотянуть разрез до длинного края листа
const CUT_MIN_PATH := 28.0    # короче этого путь ножниц — просто клик, не разрез
const CUT_RESUME_R := 34.0    # на каком расстоянии от кончика щели можно продолжить разрез
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
var fold = null                       # модель складывания (scripts/paper_fold.gd)
var gift_hull := PackedVector2Array() # вещь F в координатах бумаги: коробка или выпуклая оболочка силуэта
var fold_ref := PackedVector2Array()  # прямоугольник вокруг вещи: бумага вне него должна быть сложена
var fold_drag := false                # рука держит бумагу
var fold_grab_idx := -1
var fold_grab_layer := 0
var fold_P := Vector2.ZERO            # где схватили (координаты бумаги)
var fold_cur: Dictionary = {}         # параметры сгиба под рукой: {valid, n, c, phi, err, on_edge}
var fold_anim: Dictionary = {}        # сгиб, который доводится сам: {n, c, phi, target, kind}
var fold_snd_phi := 0.0
var pmesh = PaperMesh.new()           # сетка частиц для куска, который сейчас гнётся
var mesh_enabled := true
var mesh_ms := 0.0                    # среднее время на частицы за кадр (мс), для замеров
var mesh_particles := 0
var last_delta := 0.016               # при каком угле играл последний шорох
var crumples := 0                     # сколько раз сгиб откатывали
var pkg_dirty := true
var pkg_loose0 := 1.0                 # торчащая бумага до первого сгиба
var tucked := false                   # вещь закрыта сложенной бумагой
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
var ribbon_anchored := false          # лента закреплена на одном краю и тянется за курсором
var ribbon_anchor := Vector2.ZERO     # точка на краю подарка (локальные координаты)
var ribbon_end_vis := Vector2.ZERO    # где сейчас кончик натягивающейся ленты (плавно догоняет цель)
var cut_skew := 0.0                   # на сколько линия реза уходит вдоль листа сверху вниз (px), 0 — ровный срез
var cut_wobble := 0.0                 # на сколько рука увела ножницы от прямой (px)
var cut_mark_err := 0.0               # на сколько срез ушёл от линии, размеченной линейкой (px)
var cut_mark := PackedVector2Array()  # карандашная линия, размеченная линейкой (координаты бумаги)
var cutting := false                  # ножницы зажаты и ведут разрез
var cut_pts := PackedVector2Array()   # путь ножниц (координаты бумаги)
var cut_snd := 0.0
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
	cut_mark = PackedVector2Array()
	cut_pts = PackedVector2Array()
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


## Шаг и толщина рулонов в левой панели сжимаются, если купили много бумаги.
func _roll_step() -> float:
	return minf(76.0, 560.0 / maxf(float(inv_papers.size()), 1.0))


func _roll_thick() -> float:
	return minf(ROLL_THICK, _roll_step() - 4.0)


func _roll_pos(slot: int) -> Vector2:
	return Vector2(144.0, 112.0 + _roll_thick() * 0.5 + float(slot) * _roll_step())


func _roll_rect(slot: int) -> Rect2:
	var sz := Vector2(ROLL_LEN, _roll_thick())
	return Rect2(_roll_pos(slot) - sz * 0.5, sz)


func _spool_pos(slot: int) -> Vector2:
	return Vector2(COL_L + float(slot % 2) * (COL_R - COL_L), 206.0 + float(slot / 2) * 56.0)


func _roll_tex(p: Dictionary) -> Texture2D:
	return T_ROLLS.get(str(p["id"]), T_ROLL_NEUTRAL)


func _roll_tint(p: Dictionary) -> Color:
	if T_ROLLS.has(str(p["id"])):
		return Color.WHITE
	return Color.html(str(p["base"])).lerp(Color.WHITE, 0.2)


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
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if ribbon_anchored:
				_cancel_ribbon()
			else:
				fold_undo()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if step == Step.WRAP and not ribbon_strokes.is_empty():
				var d := 0.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1
				bow_size = clampf(bow_size + d, 0.6, 1.8)
	elif event is InputEventMouseMotion:
		_on_motion(get_global_mouse_position())
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_cancel_ribbon()
		elif ke.pressed and ke.keycode == KEY_Z and (ke.ctrl_pressed or ke.meta_pressed):
			fold_undo()


func _card_rect(i: int) -> Rect2:
	var n := cards.size()
	var c := CENTER + Vector2((float(i) - float(n - 1) * 0.5) * 230.0, 10.0)
	return Rect2(c - CARD_SIZE * 0.5, CARD_SIZE)


func _hit_test(pos: Vector2) -> String:
	if pos.distance_to(BELL_POS) < BELL_R + 6.0:
		return "bell"
	if pos.distance_to(BIN_POS) < 32.0:
		return "bin"
	if Rect2(TAPE_POS - Vector2(46, 25), Vector2(92, 50)).has_point(pos):
		return "tape"
	if pos.distance_to(SCISSORS_POS) < 36.0:
		return "scissors"
	if pos.distance_to(RULER_POS) < 34.0:
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
		if _roll_rect(s).grow(3.0).has_point(pos):
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
	_draw_tooltip()
	_draw_popups()


func _draw_table() -> void:
	draw_texture_rect(T_BACK, Rect2(0, 0, 1280, 720), false)


func _draw_panels() -> void:
	pass   # деревянные панели и коврик нарисованы на столе


func _draw_mat() -> void:
	pass


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
		var th := _roll_thick()
		var k := th / ROLL_BODY_W
		var tex := _roll_tex(p)
		var len_px := float(tex.get_height()) * k
		draw_colored_polygon(U.ellipse(c + Vector2(dx + 4.0, th * 0.5 + 3.0), len_px * 0.46, 5.0), Color(0, 0, 0, 0.24))
		# спрайт рулона лежит вдоль панели: поворот на 90 градусов, свет остаётся сверху
		draw_set_transform(c + Vector2(dx, 0.0), PI * 0.5, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-float(tex.get_width()) * k * 0.5, -len_px * 0.5, float(tex.get_width()) * k, len_px), false, _roll_tint(p))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if selected:
			draw_rect(Rect2(c.x + dx - len_px * 0.5 - 4.0, c.y - th * 0.5 - 4.0, len_px + 8.0, th + 8.0), Color(1.0, 0.9, 0.5, 0.9), false, 3.0)


func _draw_spools() -> void:
	for s in inv_ribbons.size():
		var gi: int = inv_ribbons[s]
		var rb: Dictionary = Data.RIBBONS[gi]
		var c := _spool_pos(s)
		var selected := (gi == ribbon_idx and active_tool == "ribbon")
		var hovered := (hover == "spool:%d" % s)
		var tex: Texture2D = T_SPOOLS[str(rb["id"])]
		var sz := SPOOL_SIZE + (5.0 if hovered else 0.0)
		var w := sz * float(tex.get_width()) / float(tex.get_height())
		draw_colored_polygon(U.ellipse(c + Vector2(3, sz * 0.42), sz * 0.42, sz * 0.12), Color(0, 0, 0, 0.25))
		draw_texture_rect(tex, Rect2(c.x - w * 0.5, c.y - sz * 0.5, w, sz), false, Color(1, 1, 1, 0.4 if selected else 1.0))
		if selected:
			draw_arc(c, sz * 0.62, 0.0, TAU, 40, Color(1.0, 0.9, 0.5), 3.0)


## Спрайт инструмента по центру c, шириной w (высота по пропорциям), alpha ниже, когда он «в руке».
func _tool_sprite(tex: Texture2D, c: Vector2, w: float, rot: float = 0.0, alpha: float = 1.0) -> void:
	var h := w * float(tex.get_height()) / float(tex.get_width())
	draw_set_transform(c, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Подпись с тёмной обводкой, по центру x, базовая линия y.
func _label(at: Vector2, text: String, size: int = 14) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(at.x - w * 0.5, at.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.1, 0.06, 0.05, 0.95))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.96, 0.85))


## Подсказка над предметом под мышью: название на тёмной плашке, всегда поверх соседей.
func _draw_tooltip() -> void:
	if hover == "" or stroking or pulling or fold_drag:
		return
	var text := ""
	var at := Vector2.ZERO
	if hover == "tape":
		text = "Tape"
		at = TAPE_POS + Vector2(0, -34)
	elif hover == "bin":
		text = "Trash"
		at = BIN_POS + Vector2(0, -42)
	elif hover == "scissors":
		text = "Scissors"
		at = SCISSORS_POS + Vector2(0, -50)
	elif hover == "ruler":
		text = "Ruler"
		at = RULER_POS + Vector2(0, -50)
	elif hover.begins_with("spool:"):
		var si := int(hover.get_slice(":", 1))
		if si >= 0 and si < inv_ribbons.size():
			text = str(Data.RIBBONS[inv_ribbons[si]]["name"])
			at = _spool_pos(si) + Vector2(0, -SPOOL_SIZE * 0.5 - 8.0)
	elif hover.begins_with("roll:"):
		var ri := int(hover.get_slice(":", 1))
		if ri >= 0 and ri < inv_papers.size():
			text = str(Data.PAPERS[inv_papers[ri]]["name"])
			at = _roll_pos(ri) + Vector2(0, -_roll_thick() * 0.5 - 10.0)
	if text == "":
		return
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	var plate := Rect2(at.x - sz.x * 0.5 - 8.0, at.y - 19.0, sz.x + 16.0, 27.0)
	plate.position.x = clampf(plate.position.x, 4.0, 1276.0 - plate.size.x)
	draw_rect(plate, Color(0.12, 0.08, 0.07, 0.9))
	draw_rect(plate, Color(1.0, 0.9, 0.55, 0.5), false, 1.5)
	draw_string(font, Vector2(plate.position.x + 8.0, plate.position.y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.96, 0.85))


func _draw_tape_dispenser() -> void:
	var c := TAPE_POS
	var glow := 0.0
	if active_tool == "tape":
		glow = 1.0
	elif step == Step.WRAP and tape_strokes.is_empty():
		glow = 0.5 + 0.5 * sin(time * 5.0)
	var k := 1.06 if hover == "tape" else 1.0
	_tool_sprite(T_TAPE, c, 88.0 * k, 0.0, 0.4 if active_tool == "tape" else 1.0)
	if glow > 0.0:
		draw_arc(c, 44.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.3 + 0.5 * glow), 3.0)


func _draw_bin() -> void:
	var c := BIN_POS + Vector2(sin(time * 55.0) * 4.0 * bin_shake, 0.0)
	var k := 1.06 if hover == "bin" else 1.0
	draw_colored_polygon(U.ellipse(c + Vector2(0, 28), 28.0, 6.0), Color(0, 0, 0, 0.22))
	_tool_sprite(T_BIN, c, 62.0 * k)


func _draw_bell() -> void:
	var pulse := 0.0
	if step == Step.WRAP and tucked and not tape_strokes.is_empty():
		pulse = 0.5 + 0.5 * sin(time * 4.0)
	var rot := sin(time * 40.0) * 0.14 * bell_shake
	var k := 1.06 if hover == "bell" else 1.0
	draw_colored_polygon(U.ellipse(BELL_POS + Vector2(0, 28), 30.0, 7.0), Color(0, 0, 0, 0.25))
	_tool_sprite(T_BELL, BELL_POS, 60.0 * k, rot)
	if pulse > 0.0:
		draw_arc(BELL_POS, 42.0, 0.0, TAU, 40, Color(1, 0.9, 0.5, 0.25 + 0.5 * pulse), 3.0)
	_label(BELL_POS + Vector2(0, 48), "Hand over")


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
		"plain":
			# матовая бумага: едва заметные волокна, без рисунка
			var fs := 46.0
			for iy in range(int(floor(r.position.y / fs)), int(ceil(r.end.y / fs)) + 1):
				for ix in range(int(floor(u0 / fs)) - 1, int(ceil(u1 / fs)) + 2):
					var cp := Vector2(anchor_x + dir * ((float(ix) + U.hash2(ix, iy)) * fs), (float(iy) + U.hash2(iy, ix)) * fs)
					if inner.has_point(cp) and _in_clip(cp, clip):
						draw_line(cp, cp + Vector2(11.0 * dir, 2.0), Color(acc.r, acc.g, acc.b, 0.16), 1.5)
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
			var ttex := _top_tex()
			if ttex != null:
				# настоящая картинка вещи сверху, как коробка на соседней карточке
				var box := Vector2(124.0, 104.0)
				var sc := minf(box.x / float(ttex.get_width()), box.y / float(ttex.get_height()))
				var tsz := Vector2(ttex.get_width(), ttex.get_height()) * sc
				var tc := center + Vector2(0, -22)
				draw_colored_polygon(U.ellipse(tc + Vector2(0, tsz.y * 0.5 - 2.0), tsz.x * 0.4, 6.0), Color(0, 0, 0, 0.16))
				draw_texture_rect(ttex, Rect2(tc - tsz * 0.5, tsz), false)
			else:
				var sil := Shapes.silhouette(item_kind)
				var k := 120.0 / maxf(raw_w, raw_h)
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


## Картинка вещи сверху: сначала по id вещи (bear_mid), потом по виду (bear); null, если картинки нет.
func _top_tex() -> Texture2D:
	if T_TOP.has(item_id):
		return T_TOP[item_id]
	if T_TOP.has(item_kind):
		return T_TOP[item_kind]
	return null


func _draw_item_art(ir: Rect2) -> void:
	if item_kind == "box":
		var col := Color.html(item["color"])
		_draw_box_art(ir, col, col.darkened(0.08), true)
	elif T_TOP.has(item_id) or T_TOP.has(item_kind):
		# сначала вид по id вещи (например bear_mid), потом по её виду (bear)
		var tex: Texture2D = T_TOP[item_id] if T_TOP.has(item_id) else T_TOP[item_kind]
		var sc := minf(ir.size.x / float(tex.get_width()), ir.size.y / float(tex.get_height()))
		var sz := Vector2(tex.get_width(), tex.get_height()) * sc
		draw_texture_rect(tex, Rect2(ir.get_center() - sz * 0.5, sz), false)
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
	fold = null
	gift_hull = PackedVector2Array()
	fold_drag = false
	fold_anim = {}
	fold_cur = {}
	crumples = 0
	pkg_dirty = true
	tucked = false
	tuck_t = 0.0
	tape_strokes = []
	ribbon_strokes = []
	stroking = false
	stroke_kind = ""
	stroke_pts = PackedVector2Array()
	active_tool = ""
	ribbon_idx = -1
	ribbon_anchored = false
	cut_skew = 0.0
	cut_wobble = 0.0
	cut_mark_err = 0.0
	cut_mark = PackedVector2Array()
	cutting = false
	cut_pts = PackedVector2Array()
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
	last_delta = delta
	bell_shake = maxf(bell_shake - delta, 0.0)
	bin_shake = maxf(bin_shake - delta, 0.0)
	bow_pop = minf(bow_pop + delta / 0.5, 1.0)
	box_t = minf(box_t + delta / 0.45, 1.0)
	if ribbon_anchored:
		ribbon_end_vis = ribbon_end_vis.lerp(_ribbon_target(mouse_pos), 1.0 - exp(-24.0 * delta))
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
	elif step == Step.WRAP:
		_update_fold_anim(delta)
		_update_package(delta)
		if not fold_drag and fold_anim.is_empty():
			pmesh.clear_states()
	queue_redraw()


func _update_clip() -> void:
	if wrap_mode != "shape" or sil_poly.size() < 3 or not tucked:
		clip_cur = PackedVector2Array()
		return
	var d := SHAPE_PAD + (1.0 - U.ease_in_out(tuck_t)) * 46.0
	var offs := Geometry2D.offset_polygon(sil_poly, d, Geometry2D.JOIN_ROUND)
	if offs.size() > 0:
		clip_cur = offs[0]


## Какая рука-курсор нужна над точкой p (см. hand_cursor.gd).
func cursor_pose(p: Vector2) -> String:
	if pulling:
		return "pinch"
	if fold_drag:
		return "grab"
	if active_tool == "scissors" or active_tool == "tape" or active_tool == "ribbon" or active_tool == "ruler":
		return active_tool
	if hover == "bell":
		return "bell"
	if hover != "":
		return "hover"
	if step == Step.PULL and p.distance_to(_paper_pt(pull_len * 0.5 + 26.0, 0.0)) < 28.0:
		return "pinch"
	if step == Step.WRAP and MAT_RECT.has_point(p) and absf(paper_shift) < 2.0:
		return "hover"
	return "point"


func _on_motion(pos: Vector2) -> void:
	hover = _hit_test(pos)
	mouse_pos = pos
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
	if measuring:
		ruler_b = pos
	if stroking:
		_move_stroke(pos)
	if cutting:
		_cut_move(pos)
	if pulling:
		_update_pull(pos)
	if fold_drag:
		_fold_move(pos)
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
				_cut_begin(pos)
			else:
				pulling = true
				cut_pts = PackedVector2Array()
				pull_moved = false
				pull_press = pos
				last_pull_len = sheet_len
	elif step == Step.WRAP:
		if active_tool == "" and not ribbon_strokes.is_empty() and _has_ribbon() and _bow_hit(pos):
			bow_drag = true
			bow_drag_y = pos.y
			bow_drag_start = bow_size
			return
		if active_tool == "ribbon":
			_ribbon_press(pos)
		elif active_tool != "":
			_begin_stroke(pos)
		elif MAT_RECT.has_point(pos) and absf(paper_shift) < 2.0:
			_fold_begin(pos)


func _on_release() -> void:
	if measuring and step == Step.PULL and ruler_b.distance_to(ruler_a) >= 40.0:
		_set_cut_mark()
	measuring = false
	_cut_end()
	if pulling:
		pulling = false
		_finish_pull()
	if fold_drag:
		_fold_end()
	_end_stroke()
	bow_drag = false


func _select_paper(slot: int) -> void:
	paper_idx = int(inv_papers[slot])
	cut_mark = PackedVector2Array()
	cut_skew = 0.0
	pull_len = _pull_min()
	sheet_len = pull_len
	pulling = false
	pull_moved = false
	paper_shift = 0.0
	step = Step.PULL
	AudioSynth.play_sfx("roll")
	_hint("Choose the direction, then drag the loose end: the gift stays in the middle and the roll rolls away. Then cut with the scissors")


## Тянем свободный конец вправо: лист остаётся по центру подарка, рулон отъезжает влево.
func _update_pull(pos: Vector2) -> void:
	if not pull_moved and pos.distance_to(pull_press) < 6.0:
		return
	if not pull_moved:
		AudioSynth.play_sfx("paper_pull", 0.0, randf_range(0.95, 1.1))
	pull_moved = true
	var lp := _to_paper(pos - CENTER)
	pull_len = clampf(2.0 * lp.x, _pull_min(), _pull_max())
	sheet_len = pull_len
	if absf(pull_len - last_pull_len) > 34.0:
		last_pull_len = pull_len
		AudioSynth.play_sfx("paper_rustle", -3.0, randf_range(0.85, 1.25))


## Отпустили конец: лист вытянут, но ещё не отрезан. Дальше нужны ножницы.
func _finish_pull() -> void:
	if not pull_moved:
		return
	_hint("Mark a line with the ruler if you like, then take the scissors: hold and drag across the paper from one long edge to the other")


## Линейка в режиме вытяжки оставляет на листе карандашную линию: по ней потом ведут ножницы.
func _set_cut_mark() -> void:
	cut_mark = PackedVector2Array([_to_paper(ruler_a - CENTER), _to_paper(ruler_b - CENTER)])
	AudioSynth.play_sfx("click")
	toast.emit("Line marked. Take the scissors and cut along it")


## Ножницы зажаты: разрез растёт за ними. Начать можно у длинного края листа, а если отпустили раньше времени,
## щель остаётся и её можно продолжить, нажав у её кончика.
func _cut_begin(pos: Vector2) -> void:
	var lp := _to_paper(pos - CENTER)
	var y_edge := _across() * 0.5 + MARGIN
	if cut_pts.size() >= 2 and lp.distance_to(cut_pts[cut_pts.size() - 1]) <= CUT_RESUME_R:
		cutting = true
		cut_snd = 0.0
		AudioSynth.play_sfx("snip", -8.0, randf_range(0.95, 1.1))
		return
	cut_pts = PackedVector2Array()
	if absf(lp.y) < y_edge - CUT_EDGE_TOL:
		AudioSynth.play_sfx("dull")
		toast.emit("Start the cut at a long edge of the paper")
		return
	cutting = true
	cut_snd = 0.0
	cut_pts = PackedVector2Array([lp])
	AudioSynth.play_sfx("snip", -8.0, randf_range(0.95, 1.1))


func _cut_move(pos: Vector2) -> void:
	if not cutting or cut_pts.is_empty():
		return
	var lp := _to_paper(pos - CENTER)
	var last := cut_pts[cut_pts.size() - 1]
	var d := lp.distance_to(last)
	if d < 3.0:
		return
	var n := maxi(int(d / 4.0), 1)
	for k in range(1, n + 1):
		cut_pts.append(last.lerp(lp, float(k) / float(n)))
	cut_snd += d
	if cut_snd > 28.0:
		cut_snd = 0.0
		AudioSynth.play_sfx("snip", -9.0, randf_range(0.9, 1.25))
	# щель дошла до противоположного длинного края: лист разрезан
	var y_edge := _across() * 0.5 + MARGIN
	var a := cut_pts[0]
	if absf(lp.y) >= y_edge - CUT_EDGE_TOL and lp.y * a.y < 0.0:
		_finish_slit()


## Отпустили ножницы. Если щель не дошла до края, она остаётся на листе; совсем короткую (просто клик) убираем.
func _cut_end() -> void:
	if not cutting:
		return
	cutting = false
	var total := 0.0
	for i in range(1, cut_pts.size()):
		total += cut_pts[i - 1].distance_to(cut_pts[i])
	if total < CUT_MIN_PATH:
		cut_pts = PackedVector2Array()
		AudioSynth.play_sfx("dull")
		toast.emit("Hold the scissors and drag across the paper to cut it")
		return
	toast.emit("Press at the tip of the cut and keep going to the other edge")


## Щель дошла до другого края: геометрия среза берётся из пути, который прошли ножницы.
func _finish_slit() -> void:
	cutting = false
	var pts := cut_pts
	cut_pts = PackedVector2Array()
	if pts.size() < 2:
		return
	var y_edge := _across() * 0.5 + MARGIN
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var ab := b - a
	if absf(ab.y) < 1.0:
		return
	# прямая реза через начало и конец пути; рука могла вилять, это идёт в штраф
	var wob := 0.0
	for q in pts:
		wob = maxf(wob, absf(ab.cross(q - a)) / maxf(ab.length(), 1.0))
	var ut := a.x + ab.x * (-y_edge - a.y) / ab.y
	var ub := a.x + ab.x * (y_edge - a.y) / ab.y
	_do_cut_line(ut, ub, wob)


## Ровный срез в точке pos (используется тестами и как запасной вариант).
func _do_cut(pos: Vector2) -> void:
	var u := _to_paper(pos - CENTER).x
	_do_cut_line(u, u, 0.0)


## Срез по линии от (u_top, верхний край) до (u_bot, нижний край). Отрезается кусок от линии реза до свободного конца.
func _do_cut_line(u_top: float, u_bot: float, wobble: float) -> void:
	var u1 := pull_len * 0.5
	var lo := -u1 + 6.0
	var hi := u1 - MIN_SHEET
	u_top = clampf(u_top, lo, hi)
	u_bot = clampf(u_bot, lo, hi)
	var u_c := (u_top + u_bot) * 0.5
	var y_edge := _across() * 0.5 + MARGIN
	cut_skew = u_bot - u_top
	cut_wobble = wobble
	cut_mark_err = 0.0
	if cut_mark.size() == 2:
		var m0 := cut_mark[0]
		var m1 := cut_mark[1]
		var md := m1 - m0
		if md.length() > 1.0:
			var e1 := absf(md.cross(Vector2(u_top, -y_edge) - m0)) / md.length()
			var e2 := absf(md.cross(Vector2(u_bot, y_edge) - m0)) / md.length()
			cut_mark_err = (e1 + e2) * 0.5
	cut_mark = PackedVector2Array()
	cut_pts = PackedVector2Array()
	cutting = false
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
	_init_fold()
	if length_class == "short":
		toast.emit("Not enough paper: the gift may come out crooked")
	elif absf(cut_skew) > 24.0:
		toast.emit("The cut came out slanted: the flaps will be uneven")
	_hint("Fold the paper: grab it and drag it over the gift. A fold in the middle is stopped by the gift. Right click undoes")


## --- Складывание: геометрия лежит в scripts/paper_fold.gd -------------------------------------

func _init_fold() -> void:
	fold = Fold.new()
	fold.reset(_sheet_poly())
	gift_hull = _compute_hull()
	var hb := _poly_bounds(gift_hull)
	fold_ref = U.rect_pts(hb)
	fold_drag = false
	fold_anim = {}
	fold_cur = {}
	crumples = 0
	pkg_loose0 = maxf(fold.loose_area(fold_ref), 1.0)
	pkg_dirty = true
	tucked = false
	tuck_t = 0.0
	tail_t = 0.0
	clip_cur = PackedVector2Array()


## Вещь F: прямоугольник коробки или выпуклая оболочка силуэта (с запасом) в координатах бумаги.
func _compute_hull() -> PackedVector2Array:
	if wrap_mode == "shape" and sil_poly.size() >= 3:
		var h := Geometry2D.convex_hull(sil_poly)
		if h.size() > 3 and h[0].is_equal_approx(h[h.size() - 1]):
			h.remove_at(h.size() - 1)
		var offs := Geometry2D.offset_polygon(h, SHAPE_PAD, Geometry2D.JOIN_ROUND)
		return _clip_to_paper(offs[0] if offs.size() > 0 else h)
	return U.rect_pts(Rect2(-_along() * 0.5, -_across() * 0.5, _along(), _across()))


func fold_busy() -> bool:
	return fold_drag or not fold_anim.is_empty()


func fold_drag_begin(pos: Vector2) -> void:
	_fold_begin(pos)


func fold_drag_move(pos: Vector2) -> void:
	_fold_move(pos)


func fold_drag_end() -> void:
	_fold_end()


## Ближайшее из восьми направлений (оси и диагонали): [направление, ошибка в радианах]. Ошибка до 5 градусов выпрямляется.
func _snap_dir(n: Vector2) -> Array:
	var dirs: Array = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	var best: Vector2 = dirs[0]
	var bd := -2.0
	for d in dirs:
		var dv: Vector2 = d
		var dd := n.dot(dv)
		if dd > bd:
			bd = dd
			best = dv
	var ang := acos(clampf(bd, -1.0, 1.0))
	if ang <= deg_to_rad(FOLD_SNAP_DEG):
		return [best, 0.0]
	return [n, ang]


## Линия сгиба по двум точкам: серединный перпендикуляр между местом, где взяли бумагу (p), и рукой (q).
## Бумага не может двигать вещь: сгиб, двигающий слой 0, упирается в опорную прямую вещи.
func _fold_params(p: Vector2, q: Vector2) -> Dictionary:
	var d := p - q
	if d.length() < FOLD_MIN_DRAG:
		return {"valid": false}
	var sn := _snap_dir(d.normalized())
	var n: Vector2 = sn[0]
	var c := n.dot((p + q) * 0.5)
	var h := -INF
	for v in gift_hull:
		h = maxf(h, n.dot(v))
	if absf(c - h) <= FOLD_SNAP_EDGE:
		c = h
	elif fold_grab_layer == 0 and c > h:
		c = h   # свободный край листа переворачивается через ребро вещи целиком, а не загибается кончиком
	c = fold.clamp_crease(n, c, gift_hull)
	var np := n.dot(p) - c
	if np < 0.5:
		return {"valid": false, "blocked": true}
	var cosp := clampf((n.dot(q) - c) / np, -1.0, 1.0)
	return {"valid": true, "n": n, "c": c, "phi": acos(cosp), "err": float(sn[1]), "on_edge": absf(c - h) < 0.5}


func _fold_begin(pos: Vector2) -> void:
	if fold == null or fold.is_empty() or not fold_anim.is_empty():
		return
	if not tape_strokes.is_empty():
		AudioSynth.play_sfx("dull")
		toast.emit("The paper is taped: no more folding")
		return
	var tp := _to_paper(pos - CENTER)
	var hit: Dictionary = fold.topmost_at(tp)
	if hit.is_empty():
		return
	if int(hit["layer"]) == 0 and Geometry2D.is_point_in_polygon(tp, gift_hull):
		return   # голая вещь, не бумага
	fold_drag = true
	fold_grab_idx = int(hit["idx"])
	fold_grab_layer = int(hit["layer"])
	fold_P = tp
	fold_cur = {}
	fold_snd_phi = 0.0
	AudioSynth.play_sfx("paper_rustle", -5.0, randf_range(0.9, 1.15))


func _fold_move(pos: Vector2) -> void:
	if not fold_drag:
		return
	fold_cur = _fold_params(fold_P, _to_paper(pos - CENTER))
	if fold_cur.get("valid", false):
		var ph := float(fold_cur["phi"])
		if absf(ph - fold_snd_phi) > 0.3:
			fold_snd_phi = ph
			AudioSynth.play_sfx("paper_rustle", -4.0, randf_range(0.8, 1.3))


func _fold_end() -> void:
	if not fold_drag:
		return
	fold_drag = false
	var cur := fold_cur
	fold_cur = {}
	if cur.get("blocked", false):
		AudioSynth.play_sfx("dull")
		toast.emit("The gift is in the way: the paper cannot bend there")
		return
	if not cur.get("valid", false):
		return
	var phi := float(cur["phi"])
	var commit := phi > FOLD_COMMIT_PHI
	fold_anim = {"n": cur["n"], "c": cur["c"], "phi": phi, "target": PI if commit else 0.0,
		"kind": "commit" if commit else "spring", "err": cur["err"], "on_edge": cur["on_edge"]}


## Правая кнопка или Ctrl+Z: последний сгиб раскладывается обратно, бумага при этом мнётся (штраф к аккуратности).
func fold_undo() -> void:
	if step != Step.WRAP or fold == null or fold_drag or not fold_anim.is_empty() or fold.fold_count() == 0:
		return
	var e: Dictionary = fold.undo()
	if e.is_empty():
		return
	crumples += 1
	fold_anim = {"n": e["n"], "c": e["c"], "phi": PI, "target": 0.0, "kind": "undo", "err": 0.0, "on_edge": false}
	pkg_dirty = true
	AudioSynth.play_sfx("paper_rustle", -2.0, 0.8)
	toast.emit("Folded back: the paper is a bit crumpled now")


func _update_fold_anim(delta: float) -> void:
	if fold_anim.is_empty():
		return
	var target := float(fold_anim["target"])
	var phi := move_toward(float(fold_anim["phi"]), target, delta * 8.0)
	fold_anim["phi"] = phi
	if absf(phi - target) > 0.001:
		return
	# частицы усаживаются на место, потом сгиб фиксируется в модели
	fold_anim["settle"] = float(fold_anim.get("settle", 0.0)) + delta
	if float(fold_anim["settle"]) < MESH_SETTLE and mesh_enabled:
		return
	if fold_anim["kind"] == "commit":
		var info := {"err": fold_anim["err"], "on_edge": fold_anim["on_edge"]}
		if fold.fold(fold_anim["n"], float(fold_anim["c"]), info):
			AudioSynth.play_sfx("fold", 0.0, randf_range(0.92, 1.08))
	else:
		AudioSynth.play_sfx("paper_rustle", -3.0, 0.9)
	fold_anim = {}
	pkg_dirty = true


## Подарок считается завёрнутым, когда вещь почти целиком закрыта сложенной бумагой и снаружи не торчит лишняя не сложенная бумага.
func _update_package(delta: float) -> void:
	if pkg_dirty and not fold_drag and fold_anim.is_empty() and fold != null:
		pkg_dirty = false
		var cover: float = fold.coverage(gift_hull)
		var loose: float = fold.loose_area(fold_ref)
		var want := cover >= TUCK_COVER and loose <= maxf(150.0, 0.03 * Fold.area(fold_ref))
		if want and not tucked:
			tucked = true
			tuck_t = 0.0
			tail_t = 0.001
			AudioSynth.play_sfx("fold", -3.0, 0.8)
			_hint("Wrapped. Tape it where you like, lay the ribbon around the gift, or hand it over")
		elif not want and tucked:
			tucked = false
			tuck_t = 0.0
			tail_t = 0.0
			clip_cur = PackedVector2Array()
	if tucked:
		if tuck_t < 1.0 or clip_cur.size() < 3:
			tuck_t = move_toward(tuck_t, 1.0, delta / 0.45)
			_update_clip()
		if wrap_mode == "shape" and tail_t > 0.0:
			tail_t = minf(tail_t + delta / 0.7, 1.0)


func _select_tool(tool_name: String) -> void:
	if tool_name == "tape" and active_tool != "tape" and step == Step.WRAP and (fold == null or fold.fold_count() < 1):
		AudioSynth.play_sfx("dull")
		toast.emit("Fold the paper first, then tape it")
		return
	active_tool = "" if active_tool == tool_name else tool_name
	ribbon_anchored = false
	measuring = false
	ruler_has = false
	match tool_name:
		"scissors":
			AudioSynth.play_sfx("snip", -5.0)
		"tape":
			AudioSynth.play_sfx("tape_stick")
		"ruler":
			AudioSynth.play_sfx("ruler")
		_:
			AudioSynth.play_sfx("click")
	if active_tool == "ruler":
		_hint("Ruler in hand: the size of the gift and of the paper is shown in cm. Press and drag to measure anything")
	elif active_tool == "tape":
		_hint("Tape in hand: press and drag anywhere on the gift, as much as you need")
	elif active_tool == "scissors":
		_hint("Scissors in hand: press at a long edge and drag across along your pencil line. The paper parts when the cut reaches the other edge")
	elif step == Step.WRAP:
		_hint("Fold the edges, tape, draw the ribbon, or hand over the gift")


## Катушку ленты берут в руку и сами обводят ленту вокруг подарка.
func _select_ribbon_tool(slot: int) -> void:
	if step == Step.WRAP and tape_strokes.is_empty() and active_tool != "ribbon":
		AudioSynth.play_sfx("dull")
		toast.emit("Tape the paper before you tie the ribbon")
		return
	var gi := int(inv_ribbons[slot])
	ribbon_anchored = false
	if active_tool == "ribbon" and ribbon_idx == gi:
		active_tool = ""
	else:
		active_tool = "ribbon"
		ribbon_idx = gi
	AudioSynth.play_sfx("ribbon")
	if active_tool == "ribbon":
		_hint("Ribbon in hand: click an edge of the gift, the ribbon unrolls along it. Click the other edge to lay it down")


## Где вообще есть бумага: скотч и лента ложатся только на неё (допуск на пару px у края).
func _stroke_region() -> PackedVector2Array:
	if tucked and wrap_mode == "shape" and clip_cur.size() >= 3:
		var offs := Geometry2D.offset_polygon(clip_cur, STROKE_TOL, Geometry2D.JOIN_ROUND)
		return offs[0] if offs.size() > 0 else clip_cur
	return _paper_footprint()


func _begin_stroke(pos: Vector2) -> void:
	if active_tool == "" or paper_idx < 0:
		return
	var lp := pos - CENTER
	if not Geometry2D.is_point_in_polygon(lp, _stroke_region()):
		toast.emit("Only on the paper")
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
		AudioSynth.play_sfx("tape_stick")
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


## Ближайшая к lp точка на границе бумаги: {pt, dist, inside}. Границу задаёт та же область, что и для скотча.
func _edge_snap(lp: Vector2) -> Dictionary:
	var poly := _stroke_region()
	var n := poly.size()
	var best := lp
	var bd := INF
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(lp, poly[i], poly[(i + 1) % n])
		var d := lp.distance_to(q)
		if d < bd:
			bd = d
			best = q
	return {"pt": best, "dist": bd, "inside": Geometry2D.is_point_in_polygon(lp, poly)}


## Кусок ленты от края до края годится, если он не короткий и весь лежит на бумаге.
func _ribbon_piece_ok(a: Vector2, b: Vector2) -> bool:
	if a.distance_to(b) < RIBBON_MIN_PIECE:
		return false
	var poly := _stroke_region()
	var n := maxi(int(a.distance_to(b) / 6.0), 2)
	for i in range(1, n):
		if not Geometry2D.is_point_in_polygon(a.lerp(b, float(i) / float(n)), poly):
			return false
	return true


## Куда тянется лента: на ближайший к курсору край бумаги.
func _ribbon_target(pos: Vector2) -> Vector2:
	return _edge_snap(pos - CENTER)["pt"]


func _cancel_ribbon() -> void:
	if ribbon_anchored:
		ribbon_anchored = false
		AudioSynth.play_sfx("click")
		if step == Step.WRAP and active_tool == "ribbon":
			_hint("Ribbon in hand: click an edge of the gift, the ribbon unrolls along it. Click the other edge to lay it down")


## Лента кладётся двумя щелчками: первый берёт её на краю подарка, она тянется за курсором
## вдоль подарка к ближайшему к нему краю, второй щелчок кладёт её.
func _ribbon_press(pos: Vector2) -> void:
	if active_tool != "ribbon" or paper_idx < 0 or ribbon_idx < 0:
		return
	if ribbon_strokes.size() >= STROKE_MAX:
		toast.emit("Out of ribbon")
		return
	var lp := pos - CENTER
	var sn := _edge_snap(lp)
	if not ribbon_anchored:
		if float(sn["dist"]) > RIBBON_PICK:
			AudioSynth.play_sfx("dull")
			toast.emit("Start the ribbon at an edge of the gift")
			return
		ribbon_anchor = sn["pt"]
		ribbon_end_vis = ribbon_anchor
		ribbon_anchored = true
		AudioSynth.play_sfx("ribbon")
		_hint("Now the ribbon follows you. Click the other edge to lay it down (right click cancels)")
		return
	var e: Vector2 = sn["pt"]
	if not _ribbon_piece_ok(ribbon_anchor, e):
		AudioSynth.play_sfx("dull")
		toast.emit("Take the ribbon across the gift to another edge")
		return
	_place_ribbon(ribbon_anchor, e)
	ribbon_anchored = false
	_hint("Ribbon laid. Lay another one, or hand over the gift")


func _place_ribbon(a: Vector2, b: Vector2) -> void:
	var d := a.distance_to(b)
	var pts := PackedVector2Array()
	var n := maxi(int(d / 6.0), 2)
	for i in n + 1:
		pts.append(a.lerp(b, float(i) / float(n)))
	var had := _has_ribbon()
	ribbon_strokes.append({"pts": pts, "len": d, "age": 0.0, "ribbon": ribbon_idx})
	var rb: Dictionary = Data.RIBBONS[ribbon_idx]
	_spend("ribbon", maxi(roundi(d / 100.0 * float(rb["cost"])), 1), CENTER + b + Vector2(0, -34))
	AudioSynth.play_sfx("tape_stick")
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
	return (pos - CENTER - _bow_pos()).length() < 40.0 * bow_size + 8.0


func _neatness() -> Dictionary:
	var fa := maxf(Fold.area(gift_hull), 1.0)
	var cover := 0.0
	var loose := 0.0
	var hang := 0.0
	if fold != null:
		cover = fold.coverage(gift_hull)
		loose = fold.loose_area(fold_ref)
		hang = fold.hanging_area(fold_ref)
	var ends_score := 1.0 - clampf(loose / maxf(pkg_loose0, 1.0), 0.0, 1.0)
	var tape_len := 0.0
	for st in tape_strokes:
		tape_len += float(st["len"])
	var tape_ok := tape_len >= 0.6 * _across()
	var neat := 0.55 * cover + 0.20 * ends_score + (0.25 if tape_ok else 0.0)
	# торчащие сложенные куски, кривые сгибы по ребру вещи, откаты и лишние сгибы, кривой срез, виляние ножниц
	var pen := clampf(hang / fa * 0.4, 0.0, 0.15)
	var folds_n := 0
	if fold != null:
		folds_n = fold.fold_count()
		for e in fold.history:
			var info: Dictionary = e["info"]
			pen += clampf(float(info.get("err", 0.0)) * 0.25, 0.0, 0.08)
	pen += clampf(float(crumples) * 0.05, 0.0, 0.15) + clampf(float(folds_n - 6) * 0.03, 0.0, 0.09)
	var y_edge := _across() * 0.5 + MARGIN
	pen += clampf(absf(cut_skew) / (2.0 * y_edge) * 0.6, 0.0, 0.25)
	pen += clampf(cut_wobble / 60.0, 0.0, 0.1) + clampf(cut_mark_err / 80.0, 0.0, 0.15)
	neat -= pen
	return {"neat": clampf(neat, 0.0, 1.0), "cover": cover, "ends": int(round(ends_score * 2.0)), "tape_len": tape_len, "tape_ok": tape_ok}


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
	if step != Step.WRAP or fold == null or fold.fold_count() < 1:
		bell_shake = 0.4
		AudioSynth.play_sfx("dull")
		toast.emit("The gift is not wrapped yet: fold the paper over it")
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


## Оставляет точки не чаще чем через step px (последняя точка всегда остаётся).
func _thin(pts: PackedVector2Array, step_px: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	for i in range(1, pts.size()):
		if i == pts.size() - 1 or out[out.size() - 1].distance_to(pts[i]) >= step_px:
			out.append(pts[i])
	return out


func _mirror_u(u: float) -> float:
	var f := fposmod(u, 2.0)
	return f if f <= 1.0 else 2.0 - f


## Полоска из текстуры по пути: четырёхугольники с общими боковыми вершинами. Текстура идёт вдоль пути
## и зеркально повторяется, если путь длиннее неё; u0 сдвигает начало, чтобы куски выглядели по-разному.
func _draw_band(pts: PackedVector2Array, width: float, tex: Texture2D, u0: float, tint: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var nat := float(tex.get_width()) / float(tex.get_height()) * width
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var us := PackedFloat32Array()
	var dist := 0.0
	for i in n:
		var d0 := (pts[i] - pts[i - 1]).normalized() if i > 0 else Vector2.ZERO
		var d1 := (pts[i + 1] - pts[i]).normalized() if i < n - 1 else Vector2.ZERO
		var nm := Vector2.ZERO
		var sc := 1.0
		if d0 == Vector2.ZERO:
			nm = Vector2(-d1.y, d1.x)
		elif d1 == Vector2.ZERO:
			nm = Vector2(-d0.y, d0.x)
		else:
			var n0 := Vector2(-d0.y, d0.x)
			var n1 := Vector2(-d1.y, d1.x)
			nm = (n0 + n1).normalized() if (n0 + n1).length() > 0.01 else n0
			sc = 1.0 / maxf(nm.dot(n0), 0.5)
		var off := nm * width * 0.5 * sc
		left.append(pts[i] + off)
		right.append(pts[i] - off)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		us.append(dist)
	var cols := PackedColorArray([tint, tint, tint, tint])
	for i in n - 1:
		var ua := _mirror_u(u0 + us[i] / nat)
		var ub := _mirror_u(u0 + us[i + 1] / nat)
		draw_primitive(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]), cols,
			PackedVector2Array([Vector2(ua, 0.0), Vector2(ub, 0.0), Vector2(ub, 1.0), Vector2(ua, 1.0)]), tex)


## Полоска скотча по пути (в локальных координатах подарка): полупрозрачная, бумага видна сквозь неё.
func _draw_tape_path(pts: PackedVector2Array, age: float) -> void:
	if pts.size() < 2:
		return
	var w := TAPE_W * (1.0 + 0.35 * exp(-age * 12.0))
	var sp := _thin(pts, 6.0)
	var sh := PackedVector2Array()
	for q in sp:
		sh.append(q + Vector2(1.5, 2.5))
	draw_polyline(sh, Color(0, 0, 0, 0.12), w, false)
	_draw_band(sp, w, T_BANDS["tape"], fposmod(pts[0].x * 0.011 + pts[0].y * 0.017, 1.0), Color(1, 1, 1, 0.62))


## Лента по пути: текстура выбранного цвета, под ней мягкая тень.
func _draw_ribbon_path(pts: PackedVector2Array, age: float, ribbon_id: String, alpha: float = 1.0) -> void:
	if pts.size() < 2:
		return
	var w := RIBBON_W * (1.0 + 0.3 * exp(-age * 12.0))
	var sp := _thin(pts, 8.0)
	var sh := PackedVector2Array()
	for q in sp:
		sh.append(q + Vector2(2.0, 3.0))
	draw_polyline(sh, Color(0, 0, 0, 0.22 * alpha), w, false)
	_draw_band(sp, w, T_BANDS[ribbon_id], fposmod(pts[0].x * 0.013 + pts[0].y * 0.009, 1.0), Color(1, 1, 1, alpha))


func _axis_rect(a: String) -> Rect2:
	# Две кнопки друг под другом целиком на зелёном мате, в 28 px от его чёрного контура слева и сверху.
	return Rect2(AXIS_POS.x, AXIS_POS.y + (0.0 if a == "h" else 44.0), 130.0, 36.0)


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
	var glow := 0.0
	if on:
		glow = 1.0
	elif step == Step.PULL and pull_moved:
		glow = 0.5 + 0.5 * sin(time * 5.0)
	var k := 1.06 if hover == "scissors" else 1.0
	draw_colored_polygon(U.ellipse(c + Vector2(0, 30), 34.0, 6.0), Color(0, 0, 0, 0.22))
	_tool_sprite(T_SCISSORS, c, 88.0 * k, -0.35, 0.4 if on else 1.0)
	if glow > 0.0:
		draw_arc(c, 46.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.3 + 0.5 * glow), 3.0)


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
	var k := 1.06 if hover == "ruler" else 1.0
	_tool_sprite(T_RULER, RULER_POS, 84.0 * k, -PI * 0.25, 0.4 if on else 1.0)
	if on:
		draw_arc(RULER_POS, 40.0, 0.0, TAU, 40, Color(1, 0.93, 0.55, 0.85), 3.0)


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
	if (step == Step.PULL or step == Step.WRAP) and (fold == null or fold.fold_count() == 0) and not tucked:
		var plen := pull_len if step == Step.PULL else sheet_len
		var need := _l_min()
		var pcol := Color("#ffe07a") if plen >= need else Color("#ff9a7a")
		var v := -(_across() * 0.5 + MARGIN + 34.0)
		var tx := "Paper %d cm (need %d+)" % [roundi(plen / PX_PER_CM), ceili(need / PX_PER_CM)]
		_dim_line(_paper_pt(-plen * 0.5, v), _paper_pt(plen * 0.5, v), tx, pcol, Vector2(0, -24) if rot == 0.0 else Vector2(60, 0))
	if ruler_has:
		var d := ruler_b - ruler_a
		_dim_line(ruler_a, ruler_b, "%.1f cm" % (d.length() / PX_PER_CM), Color("#a8d4ff"), Vector2(0, -24))


## Карандашная линия линейки, путь ножниц и подсказка рядом с рукой.
func _draw_cut_preview() -> void:
	if step != Step.PULL or paper_idx < 0:
		return
	_set_paper_transform()
	if cut_mark.size() == 2:
		draw_line(cut_mark[0], cut_mark[1], Color(1, 1, 1, 0.45), 6.0)
		draw_dashed_line(cut_mark[0], cut_mark[1], Color(0.2, 0.18, 0.22, 0.95), 2.5, 7.0)
	if cut_pts.size() >= 2:
		_draw_slit()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if active_tool == "scissors" and MAT_RECT.has_point(mouse_pos):
		var txt := "Drag across the paper to cut"
		if cutting:
			var u1 := pull_len * 0.5
			var cu := clampf(_to_paper(mouse_pos - CENTER).x, -u1 + 6.0, u1 - MIN_SHEET)
			txt = "Piece: %d cm" % roundi((u1 - cu) / PX_PER_CM)
		_label(mouse_pos + Vector2(70, -18), txt, 16)


## Щель в бумаге: тёмная линия, за ножницами она чуть раскрыта и видно стол, у кончика смыкается.
func _draw_slit() -> void:
	var n := cut_pts.size()
	var from_tip := 0.0
	for k in range(n - 1, 0, -1):
		var a := cut_pts[k - 1]
		var b := cut_pts[k]
		from_tip += a.distance_to(b)
		var gap := clampf(0.8 + from_tip * 0.05, 0.8, 4.0)
		draw_line(a, b, Color(0.05, 0.11, 0.07, 0.95), gap + 1.6)
		draw_line(a, b, Color(0.2, 0.37, 0.24, 1.0), gap)
	var tip := cut_pts[n - 1]
	draw_circle(tip, 4.0 if cutting else 6.0 + sin(time * 6.0), Color(1.0, 0.85, 0.5, 0.9))


## --- Лист и сложенная бумага: рисование модели ------------------------------------------------

## Лист в координатах бумаги: правый конец ровный, левый (линия реза) может быть косым.
func _sheet_poly() -> PackedVector2Array:
	var sl := maxf(sheet_len, 1.0)
	var y := _across() * 0.5 + MARGIN
	return PackedVector2Array([Vector2(-sl * 0.5 - cut_skew * 0.5, -y), Vector2(sl * 0.5, -y), Vector2(sl * 0.5, y), Vector2(-sl * 0.5 + cut_skew * 0.5, y)])


func _poly_bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


func _shadow_poly(poly: PackedVector2Array, off: Vector2, alpha: float) -> void:
	var o := PackedVector2Array()
	for p in poly:
		o.append(p + off)
	draw_colored_polygon(o, Color(0, 0, 0, alpha))


## Преобразование координат бумаги в экранные.
func _paper_base_xf() -> Transform2D:
	var s := maxf(gift_scale, 0.001)
	var off := Vector2(paper_shift, 0.0).rotated(rot) * s
	return Transform2D(rot, CENTER + gift_off + off).scaled_local(Vector2(s, s))


## Куски бумаги, как они выглядят сейчас: под рукой, в доводке или уже лежащие.
func _current_pieces() -> Array:
	if fold_drag and fold_cur.get("valid", false):
		return fold.preview(fold_cur["n"], float(fold_cur["c"]), float(fold_cur["phi"]))
	if not fold_anim.is_empty():
		return fold.preview(fold_anim["n"], float(fold_anim["c"]), float(fold_anim["phi"]))
	return fold.pieces()


func _back_color(paper: Dictionary) -> Color:
	return Color.html(str(paper["base"])).lerp(Color(0.97, 0.95, 0.9), 0.72)


## Куски слоя 0 рисуются под вещью, все сложенные (слой 1 и выше) над ней по возрастанию слоя.
func _draw_pieces(paper: Dictionary, pieces: Array, upper: bool) -> void:
	var list: Array = []
	for pc in pieces:
		if (int(pc["layer"]) >= 1) == upper:
			list.append(pc)
	list.sort_custom(func(a, b): return int(a["layer"]) < int(b["layer"]))
	for pc in list:
		_draw_piece(paper, pc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_piece(paper: Dictionary, pc: Dictionary) -> void:
	var xf: Transform2D = pc["xf"]
	var flat: PackedVector2Array = pc["flat"]
	var det := xf.determinant()
	if absf(det) < 0.03:
		return   # бумага стоит ребром
	var layer := int(pc["layer"])
	var moving: bool = pc.get("moving", false)
	var phi := float(pc.get("phi", 0.0))
	if moving and mesh_enabled and pc.has("xf0"):
		_draw_piece_mesh(paper, pc)
		return
	var cur := xf * flat
	var base_xf := _paper_base_xf()
	draw_set_transform_matrix(base_xf)
	if moving:
		_shadow_poly(cur, Vector2(3, 5) * (1.0 + 1.8 * sin(phi)), 0.14 + 0.12 * sin(phi))
	elif layer >= 1:
		_shadow_poly(cur, Vector2(3, 5), 0.16)
	else:
		_shadow_poly(cur, Vector2(5, 7), 0.22)
	draw_set_transform_matrix(base_xf * xf)
	var r := _poly_bounds(flat)
	if r.size.x >= 0.5 and r.size.y >= 0.5:
		_draw_print(r, paper, r.position.x, 1.0, flat)
	if det < 0.0:
		draw_colored_polygon(flat, Color(1, 1, 1, 0.13))   # обратная сторона листа чуть светлее
	if moving:
		draw_colored_polygon(flat, Color(0, 0, 0, 0.10 * sin(phi)))
	# faint crease lines stay on folded pieces
	var grown := Geometry2D.offset_polygon(flat, 1.5, Geometry2D.JOIN_MITER)
	if grown.size() > 0:
		for cr in pc["creases"]:
			var seg: Array = cr
			for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([seg[0], seg[1]]), grown[0]):
				if part.size() >= 2:
					draw_line(part[0], part[part.size() - 1], Color(1, 1, 1, 0.22), 2.0)
	draw_set_transform_matrix(base_xf)
	if moving:
		_crease_band(cur, pc["n"], float(pc["c"]), phi)
	U.stroke(self, cur, U.INK, 3.0, time, 0.0)


## Кусок в движении как сетка частиц: бумага изгибается по дуге у сгиба (радиус CURL_R, у ровного и сложенного положения
## радиус нулевой), частицы тянутся к цели пружиной, свет и затемнение у сгиба считаются по высоте.
func _draw_piece_mesh(paper: Dictionary, pc: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var flat: PackedVector2Array = pc["flat"]
	var xf0: Transform2D = pc["xf0"]
	var xf: Transform2D = pc["xf"]
	var n: Vector2 = pc["n"]
	var c := float(pc["c"])
	var phi := float(pc["phi"])
	var m: Dictionary = pmesh.mesh_for(flat)
	var pts: PackedVector2Array = m["pts"]
	var cnt := pts.size()
	var targets := PackedVector2Array()
	var tz := PackedFloat32Array()
	var ao := PackedFloat32Array()
	targets.resize(cnt)
	tz.resize(cnt)
	ao.resize(cnt)
	var r := CURL_R * sin(phi)
	var cs := cos(phi)
	var sn := sin(phi)
	var arc := r * phi
	for i in cnt:
		var p0 := xf0 * pts[i]
		var sd := maxf(n.dot(p0) - c, 0.0)
		var pn := 0.0
		var hz := 0.0
		if r > 0.5 and sd <= arc:
			var th := sd / r
			pn = r * sin(th)
			hz = r * (1.0 - cos(th))
		else:
			pn = r * sn + (sd - arc) * cs
			hz = r * (1.0 - cs) + (sd - arc) * sn
		targets[i] = p0 - n * sd + n * pn
		tz[i] = hz
		ao[i] = 0.30 * sn * exp(-sd / 14.0)
	var stiff := MESH_STIFF * (5.0 if pc.has("xf0") and fold_anim.has("settle") else 1.0)
	var st: Dictionary = pmesh.step(hash(flat), targets, tz, last_delta, stiff, MESH_DAMP)
	var pos: PackedVector2Array = st["pos"]
	var base := Color.html(str(paper["base"]))
	if xf.determinant() < 0.0:
		base = base.lerp(Color(1, 1, 1), 0.13)
	var colors := PaperMesh.shade(pos, st["z"], m["tris"], base, ao)
	var base_xf := _paper_base_xf()
	draw_set_transform_matrix(base_xf)
	var nb := int(m["nb"])
	var bound := PackedVector2Array()
	for i in nb:
		bound.append(pos[i])
	# мягкая тень под поднятым куском: те же треугольники, сдвинутые вниз и вправо
	var soff := Vector2(3, 5) * (1.0 + 1.8 * sn)
	var spos := PackedVector2Array()
	spos.resize(cnt)
	var scol := PackedColorArray()
	scol.resize(cnt)
	var sa := 0.14 + 0.12 * sn
	for i in cnt:
		spos[i] = pos[i] + soff
		scol[i] = Color(0, 0, 0, sa)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), m["tris"], spos, scol)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), m["tris"], pos, colors)
	var ring := bound.duplicate()
	ring.append(bound[0])
	draw_polyline(ring, U.INK, 3.0, true)
	mesh_particles = pmesh.particle_count()
	mesh_ms = lerpf(mesh_ms, float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	# бюджет кадра: если частицы дороже ~3.5 мс (например, в веб-сборке), сетка становится грубее
	if mesh_ms > 3.5 and pmesh.cell < 24.0:
		pmesh.cell *= 1.25
		pmesh.meshes = {}
		pmesh.clear_states()


## Мягкая тень вдоль линии сгиба на поднятом куске, сильнее всего посередине сгибания.
func _crease_band(cur: PackedVector2Array, n: Vector2, c: float, phi: float) -> void:
	var d := Vector2(-n.y, n.x)
	var inward := 1.0 if cos(phi) >= 0.0 else -1.0
	var p0 := n * c
	for k in 2:
		var w0 := 16.0 * float(k) * inward
		var w1 := 16.0 * float(k + 1) * inward
		var strip := PackedVector2Array([p0 - d * 3000.0 + n * w0, p0 + d * 3000.0 + n * w0, p0 + d * 3000.0 + n * w1, p0 - d * 3000.0 + n * w1])
		for q in Geometry2D.intersect_polygons(cur, strip):
			if Fold.area(q) >= 2.0:
				draw_colored_polygon(q, Color(0, 0, 0, 0.22 * sin(phi) * (1.0 - 0.5 * float(k))))


## Готовый свёрток по форме вещи: бумага плотно обтягивает силуэт.
func _draw_sack(paper: Dictionary) -> void:
	var clip_p := _clip_to_paper(clip_cur)
	if clip_p.size() < 3:
		return
	_set_paper_transform()
	var r := _poly_bounds(clip_p)
	_draw_print(r, paper, r.position.x, 1.0, clip_p)
	U.stroke(self, clip_p, U.INK, 4.0, time, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Где сейчас есть бумага (скотч и лента ложатся только на неё): сложенные куски плюс не сложенная бумага вне вещи, с допуском.
func _paper_footprint() -> PackedVector2Array:
	var polys: Array = []
	if fold != null:
		for f in fold.facets:
			var p := Fold.poly(f)
			if int(f["layer"]) >= 1:
				polys.append(p)
			else:
				for q in Geometry2D.clip_polygons(p, gift_hull):
					polys.append(q)
	var parts := Fold.union_polys(polys)
	var best := PackedVector2Array()
	var best_a := -1.0
	for q2 in parts:
		var a := Fold.area(q2)
		if a > best_a:
			best_a = a
			best = q2
	if best.size() < 3:
		best = gift_hull if gift_hull.size() >= 3 else _sheet_poly()
	var offs := Geometry2D.offset_polygon(best, STROKE_TOL, Geometry2D.JOIN_ROUND)
	var src: PackedVector2Array = offs[0] if offs.size() > 0 else best
	var out := PackedVector2Array()
	for p3 in src:
		out.append(p3.rotated(rot))
	return out


## Подсказки: стрелки на не сложенных кусках бумаги, торчащих из-под вещи.
func _draw_fold_hints() -> void:
	if fold == null or fold_drag or not fold_anim.is_empty() or tucked or active_tool != "":
		return
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	var acol := Color(1, 0.95, 0.7, 0.35 + 0.4 * pulse)
	var hc := Vector2.ZERO
	for v in gift_hull:
		hc += v
	hc /= float(maxi(gift_hull.size(), 1))
	for f in fold.facets:
		if int(f["layer"]) != 0:
			continue
		var p := Fold.poly(f)
		if Fold.area(p) < 700.0:
			continue
		var c := Vector2.ZERO
		for v in p:
			c += v
		c /= float(p.size())
		if Geometry2D.is_point_in_polygon(c, gift_hull):
			continue
		var d := (hc - c).normalized()
		var perp := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 16.0, c - d * 8.0 + perp * 12.0, c - d * 8.0 - perp * 12.0]), acol)


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
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.28))
	_draw_roll_v(_roll_tex(paper), _roll_tint(paper), r.position.x, r.position.y, r.size.x, r.size.y)
	# швы слоёв бегут по поверхности, пока рулон откатывается
	var rad := maxf(rt * 0.5, 1.0)
	var cx := r.position.x + r.size.x * 0.5
	var ang0 := -pull_len * 0.5 / rad
	for k in 5:
		var a := TAU * float(k) / 5.0 + ang0
		var c := cos(a)
		if c > 0.1:
			var lx := cx + rad * 0.8 * sin(a)
			draw_line(Vector2(lx, r.position.y + 4.0), Vector2(lx, r.end.y - 4.0), Color(0, 0, 0, 0.16 * c), 1.5)


## Рулон из спрайта по трём кускам: колпак с гильзой сверху, тянущееся тело, колпак с гильзой снизу.
## Тело занимает [x0, x0 + w] x [y_top, y_top + body_h], гильзы торчат за его концы.
func _draw_roll_v(tex: Texture2D, tint: Color, x0: float, y_top: float, w: float, body_h: float) -> void:
	var k := w / ROLL_BODY_W
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var top_part := ROLL_SLICE_TOP - ROLL_BODY_TOP        # часть верхнего колпака, лежащая на теле
	var bot_part := ROLL_BODY_BOT - ROLL_SLICE_BOT
	var body := maxf(body_h, (top_part + bot_part) * k + 2.0)
	var y_a0 := y_top - ROLL_BODY_TOP * k
	var y_a1 := y_top + top_part * k
	var y_c0 := y_top + body - bot_part * k
	var y_c1 := y_top + body + (th - ROLL_BODY_BOT) * k
	draw_texture_rect_region(tex, Rect2(x0, y_a0, tw * k, y_a1 - y_a0), Rect2(0, 0, tw, ROLL_SLICE_TOP), tint)
	draw_texture_rect_region(tex, Rect2(x0, y_a1, tw * k, y_c0 - y_a1), Rect2(0, ROLL_SLICE_TOP, tw, ROLL_SLICE_BOT - ROLL_SLICE_TOP), tint)
	draw_texture_rect_region(tex, Rect2(x0, y_c0, tw * k, y_c1 - y_c0), Rect2(0, ROLL_SLICE_BOT, tw, th - ROLL_SLICE_BOT), tint)


func _draw_gift() -> void:
	if item.is_empty() or step == Step.CHOOSE:
		return
	var shape_mode := wrap_mode == "shape"
	var hh := _across() * 0.5
	var ir := Rect2(-item_w * 0.5, -item_h * 0.5, item_w, item_h)
	var fh := _flap_len()
	var paper: Dictionary = {}
	if paper_idx >= 0:
		paper = Data.PAPERS[paper_idx]

	if step == Step.PULL and not paper.is_empty():
		_draw_pull_view(paper, ir)
		_set_paper_transform()
		_draw_gift_hints(hh, fh)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var have_fold: bool = not paper.is_empty() and fold != null and not fold.is_empty()
	var sack: bool = have_fold and tucked and shape_mode and clip_cur.size() >= 3
	var pieces: Array = _current_pieces() if have_fold else []
	# 1. не сложенная бумага (слой 0) лежит под вещью
	if have_fold and not sack:
		_draw_pieces(paper, pieces, false)

	# 2. сама вещь или коробка и собранный хвост (в системе координат стола)
	_set_gift_transform()
	_draw_subject(ir)
	if shape_mode and tail_t > 0.0 and not paper.is_empty() and item.has("tail"):
		_draw_tail(paper)

	# 3. сложенная бумага всегда поверх вещи и поверх более ранних сгибов
	if have_fold:
		if sack:
			_draw_sack(paper)
		else:
			_draw_pieces(paper, pieces, true)

	# 5. скотч, лента, бант (в системе координат стола, рисует игрок)
	_set_gift_transform()
	for st in tape_strokes:
		_draw_tape_path(st["pts"], float(st["age"]))
	if stroking and stroke_kind == "tape" and stroke_pts.size() >= 2:
		_draw_tape_path(stroke_pts, 9.0)
	for st in ribbon_strokes:
		var rbs: Dictionary = Data.RIBBONS[int(st["ribbon"])]
		_draw_ribbon_path(st["pts"], float(st["age"]), str(rbs["id"]))
	if active_tool == "ribbon" and ribbon_idx >= 0 and step == Step.WRAP:
		var rbc: Dictionary = Data.RIBBONS[ribbon_idx]
		if ribbon_anchored:
			var tgt := _ribbon_target(mouse_pos)
			var ok := _ribbon_piece_ok(ribbon_anchor, tgt)
			var pv := PackedVector2Array([ribbon_anchor, ribbon_end_vis])
			if ribbon_anchor.distance_to(ribbon_end_vis) > 2.0:
				_draw_ribbon_path(pv, 9.0, str(rbc["id"]), 1.0 if ok else 0.45)
			draw_circle(ribbon_anchor, 7.0, Color(1, 0.93, 0.55, 0.95))
			draw_arc(ribbon_end_vis, 9.0 + 2.0 * sin(time * 8.0), 0.0, TAU, 20, Color(1, 0.93, 0.55) if ok else Color(1, 0.55, 0.5), 2.5)
		else:
			var sn := _edge_snap(mouse_pos - CENTER)
			if float(sn["dist"]) <= RIBBON_PICK:
				var gp: Vector2 = sn["pt"]
				draw_circle(gp, 7.0 + 1.5 * sin(time * 6.0), Color(1, 0.93, 0.55, 0.9))
				draw_arc(gp, 13.0, 0.0, TAU, 20, Color(1, 0.93, 0.55, 0.8), 2.0)
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
	elif step == Step.WRAP:
		_draw_fold_hints()
