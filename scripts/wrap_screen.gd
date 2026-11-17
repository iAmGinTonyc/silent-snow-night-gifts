extends Node2D
## Экран упаковки (вид сверху): выбор «коробка или по форме», бумага, отрез, клапаны,
## скотч, лента и бант, выдача. Геометрия подарка в локальных координатах: (0, 0) — центр подарка.

signal gift_ready(result: Dictionary)
signal hint_changed(text: String)
signal toast(text: String)
signal cost(category: String, amount: int)

const Data = preload("res://scripts/data.gd")
const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")

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
const CARD_SIZE := Vector2(200, 240)

# --- Механика упаковки ---
const MARGIN := 36.0        # поле листа сверху и снизу
const MIN_OVERLAP := 16.0   # минимальный нахлёст клапанов
const GOOD_RANGE := 90.0    # «хорошая» длина: Lmin .. Lmin + GOOD_RANGE
const EXTRA_LEN := 160.0    # Lmax = 2*w + EXTRA_LEN
const PREVIEW_EXTRA := 30.0
const TAPE_W := 22.0
const TAPE_H := 70.0
const TAPE_MAX := 4
const SEAM_HALF := 18.0
const FOLD_SNAP_ANGLE := 1.05
const BOX_PAD := 36.0       # запас коробки вокруг вещи
const SHAPE_PAD := 6.0      # бумага чуть шире силуэта

enum Step { IDLE, ARRIVING, CHOOSE, PAPER, PULL, FOLD, TUCK, TAPE, DONE, DELIVER }

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
var last_pull_len := 0.0
var theta: Array[float] = [PI, PI]
var theta_target: Array[float] = [PI, PI]
var folded: Array[bool] = [false, false]
var fold_order: Array[int] = []
var flap_drag := -1
var ends_t := 0.0
var seam_x := 0.0
var tape_strips: Array = []
var ribbon_idx := -1
var bow_size := 1.0
var bow_drag := false
var bow_drag_y := 0.0
var bow_drag_start := 1.0
var bow_pop := 1.0
var crumpled := 0
var length_class := ""
var arrive_t := 0.0
var box_t := 1.0
var tail_t := 0.0
var gift_off := Vector2.ZERO
var gift_scale := 1.0
var result: Dictionary = {}

var hover := ""
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


# --- Публичное API -----------------------------------------------------------

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


func _reset_gift_state() -> void:
	paper_idx = -1
	sheet_len = 0.0
	pulling = false
	theta = [PI, PI]
	theta_target = [PI, PI]
	folded = [false, false]
	fold_order = []
	flap_drag = -1
	ends_t = 0.0
	seam_x = 0.0
	tape_strips = []
	ribbon_idx = -1
	bow_size = 1.0
	bow_drag = false
	bow_pop = 1.0
	crumpled = 0
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


# --- Геометрия ------------------------------------------------------------------

func _l_min() -> float:
	return 2.0 * item_w + MIN_OVERLAP


func _l_max() -> float:
	return 2.0 * item_w + EXTRA_LEN


func _flap_len() -> float:
	return maxf((sheet_len - item_w) * 0.5, 0.0)


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


# --- Обновление -----------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	bell_shake = maxf(bell_shake - delta, 0.0)
	bin_shake = maxf(bin_shake - delta, 0.0)
	bow_pop = minf(bow_pop + delta / 0.5, 1.0)
	box_t = minf(box_t + delta / 0.45, 1.0)
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] += delta / 1.2
		popups[i]["pos"] += Vector2(0.0, -34.0 * delta)
		if popups[i]["t"] >= 1.0:
			popups.remove_at(i)
	for ts in tape_strips:
		ts["age"] += delta

	if step == Step.ARRIVING:
		arrive_t += delta / 0.7
		var e := U.ease_out_back(arrive_t)
		gift_off = Vector2(0.0, -170.0 * (1.0 - U.ease_out(arrive_t)))
		gift_scale = maxf(lerpf(0.2, 1.0, e), 0.05)
		if arrive_t >= 1.0:
			gift_off = Vector2.ZERO
			gift_scale = 1.0
			_after_arrival()
	elif step != Step.DELIVER and step != Step.IDLE:
		var k := 1.0 - exp(-14.0 * delta)
		for i in 2:
			if flap_drag != i:
				theta[i] = lerpf(theta[i], theta_target[i], k)
				if absf(theta[i] - theta_target[i]) < 0.004:
					theta[i] = theta_target[i]
		if step == Step.FOLD and folded[0] and folded[1] and theta[0] <= 0.004 and theta[1] <= 0.004:
			step = Step.TUCK
			AudioSynth.play_sfx("fold", -3.0)
		elif step == Step.TUCK:
			ends_t = move_toward(ends_t, 1.0, delta / 0.45)
			_update_clip()
			if ends_t >= 1.0:
				var top: int = fold_order.back()
				var f := _flap_len()
				seam_x = (-item_w * 0.5 + f) if top == 0 else (item_w * 0.5 - f)
				step = Step.TAPE
				tail_t = 0.001
				_hint("Заклей шов")
		if step >= Step.TAPE and wrap_mode == "shape" and tail_t > 0.0:
			tail_t = minf(tail_t + delta / 0.7, 1.0)
	queue_redraw()


func _after_arrival() -> void:
	if item_kind == "box":
		wrap_mode = "rect"
		item_w = raw_w
		item_h = raw_h
		step = Step.PAPER
		_hint("Выбери бумагу")
		return
	cards = []
	for bi in inv_boxes:
		cards.append({"type": "box", "idx": bi})
	cards.append({"type": "shape"})
	step = Step.CHOOSE
	_hint("Положить в коробку или завернуть по форме?")


func _update_clip() -> void:
	if wrap_mode != "shape" or sil_poly.size() < 3:
		clip_cur = PackedVector2Array()
		return
	var d := SHAPE_PAD + (1.0 - U.ease_in_out(ends_t)) * 46.0
	var offs := Geometry2D.offset_polygon(sil_poly, d, Geometry2D.JOIN_ROUND)
	if offs.size() > 0:
		clip_cur = offs[0]


## Вертикальный диапазон, доступный для скотча по линии шва.
func _seam_range() -> Vector2:
	var half := item_h * 0.5 + 4.0
	if wrap_mode == "shape" and clip_cur.size() >= 3:
		var segs := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(seam_x, -400.0), Vector2(seam_x, 400.0)]), clip_cur)
		var best := Vector2(-half, half)
		var best_len := -1.0
		for sg in segs:
			var seg: PackedVector2Array = sg
			if seg.size() >= 2:
				var lo := minf(seg[0].y, seg[seg.size() - 1].y)
				var hi := maxf(seg[0].y, seg[seg.size() - 1].y)
				if hi - lo > best_len:
					best_len = hi - lo
					best = Vector2(lo, hi)
		return best
	return Vector2(-half, half)


# --- Ввод ------------------------------------------------------------------------

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
			if step == Step.DONE and ribbon_idx >= 0:
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


func _on_motion(pos: Vector2) -> void:
	hover = _hit_test(pos)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)
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
	if step == Step.CHOOSE:
		if hit.begins_with("card:"):
			_choose_card(int(hit.substr(5)))
		return
	if step == Step.PAPER or step == Step.PULL:
		if hit.begins_with("roll:"):
			_select_paper(int(hit.substr(5)))
			return
		if step == Step.PULL and MAT_RECT.has_point(pos):
			pulling = true
			last_pull_len = sheet_len
			_update_pull(pos)
	elif step == Step.FOLD:
		if MAT_RECT.has_point(pos):
			_begin_flap_drag(pos)
	elif step == Step.TAPE or step == Step.DONE:
		if hit.begins_with("spool:"):
			if step == Step.DONE:
				_select_ribbon(int(hit.substr(6)))
			else:
				toast.emit("Сначала заклей шов")
			return
		if step == Step.DONE and ribbon_idx >= 0 and _bow_hit(pos):
			bow_drag = true
			bow_drag_y = pos.y
			bow_drag_start = bow_size
			return
		_try_tape(pos)


func _bow_hit(pos: Vector2) -> bool:
	var c := CENTER
	var r := 56.0 * bow_size + 10.0
	if wrap_mode == "shape" and item.has("tail"):
		var tl: Array = item["tail"]
		c = CENTER + Vector2(float(tl[0]), float(tl[1])) + Vector2(float(tl[2]), float(tl[3])) * 6.0
		r = 46.0 * bow_size + 10.0
	return (pos - c).length() < r


func _on_release() -> void:
	if pulling:
		pulling = false
		_finish_cut()
	if flap_drag >= 0:
		_end_flap_drag()
	bow_drag = false


# --- Шаги ----------------------------------------------------------------------

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
	_hint("Выбери бумагу")


func _select_paper(slot: int) -> void:
	paper_idx = int(inv_papers[slot])
	sheet_len = item_w + PREVIEW_EXTRA
	pulling = false
	step = Step.PULL
	AudioSynth.play_sfx("paper_pull")
	_hint("Тяни край бумаги и отпусти, чтобы отрезать")


func _update_pull(pos: Vector2) -> void:
	var lp := pos - CENTER
	sheet_len = clampf(2.0 * absf(lp.x), 60.0, _l_max())
	if absf(sheet_len - last_pull_len) > 60.0:
		last_pull_len = sheet_len
		AudioSynth.play_sfx("paper_pull", -4.0, randf_range(0.9, 1.2))


func _finish_cut() -> void:
	if sheet_len < item_w + 20.0:
		sheet_len = item_w + PREVIEW_EXTRA
		return
	if sheet_len < _l_min():
		crumpled += 1
		AudioSynth.play_sfx("crumple")
		_spend("waste", _paper_cost(sheet_len), CENTER + Vector2(0, -60))
		toast.emit("Не хватило бумаги: лист пропал")
		sheet_len = item_w + PREVIEW_EXTRA
		return
	length_class = "good" if sheet_len <= _l_min() + GOOD_RANGE else "long"
	AudioSynth.play_sfx("cut")
	_spend("paper", _paper_cost(sheet_len), CENTER + Vector2(0, -60))
	step = Step.FOLD
	theta = [PI, PI]
	theta_target = [PI, PI]
	folded = [false, false]
	fold_order = []
	_hint("Заверни края: тяни их к центру")


func _begin_flap_drag(pos: Vector2) -> void:
	var lp := pos - CENTER
	var side := 0 if lp.x < 0.0 else 1
	if folded[side]:
		side = 1 - side
		if folded[side]:
			return
	flap_drag = side
	_update_flap_drag(pos)


func _update_flap_drag(pos: Vector2) -> void:
	var f := _flap_len()
	if f < 1.0:
		return
	var lp := pos - CENTER
	var c := 0.0
	if flap_drag == 0:
		c = (lp.x + item_w * 0.5) / f
	else:
		c = (item_w * 0.5 - lp.x) / f
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


func _try_tape(pos: Vector2) -> void:
	var lp := pos - CENTER
	var rng := _seam_range()
	var band := Rect2(seam_x - SEAM_HALF, rng.x, SEAM_HALF * 2.0, rng.y - rng.x)
	if not band.has_point(lp):
		if step == Step.TAPE and Rect2(-item_w * 0.5 - 10.0, -item_h * 0.5 - 10.0, item_w + 20.0, item_h + 20.0).has_point(lp):
			AudioSynth.play_sfx("dull")
		return
	if tape_strips.size() >= TAPE_MAX:
		toast.emit("Скотч закончился")
		return
	var lo := rng.x + TAPE_H * 0.5 - 6.0
	var hi := rng.y - TAPE_H * 0.5 + 6.0
	var sy := clampf(lp.y, lo, hi) if lo <= hi else (rng.x + rng.y) * 0.5
	tape_strips.append({"y": sy, "rot": randf_range(-0.05, 0.05), "age": 0.0})
	AudioSynth.play_sfx("tape")
	_spend("tape", 1, TAPE_POS + Vector2(0, -50))
	if step == Step.TAPE:
		step = Step.DONE
		_hint("Добавь ленту и бант или отдавай подарок (колокольчик)")


func _select_ribbon(slot: int) -> void:
	var gi := int(inv_ribbons[slot])
	if ribbon_idx == gi:
		ribbon_idx = -1
	else:
		ribbon_idx = gi
		bow_pop = 0.0
	AudioSynth.play_sfx("ribbon")


## Выбросить текущий подарок и начать заново (потраченные материалы не возвращаются).
func _discard() -> void:
	if item.is_empty() or step < Step.PAPER or step > Step.DONE:
		return
	if paper_idx < 0 and box_idx < 0:
		return
	bin_shake = 0.5
	AudioSynth.play_sfx("crumple")
	toast.emit("Выброшено. Материалы потрачены, начинаем заново")
	var keep_id := item_id
	_reset_gift_state()
	item_id = keep_id
	_after_arrival()


func _try_deliver() -> void:
	if step == Step.IDLE or step == Step.ARRIVING or step == Step.DELIVER:
		return
	if step != Step.DONE:
		bell_shake = 0.4
		AudioSynth.play_sfx("dull")
		toast.emit("Шов не заклеен" if step == Step.TAPE else "Подарок ещё не готов")
		return
	var rid := ""
	var rcol := ""
	var bonus := 0.0
	var pp: Dictionary = Data.PAPERS[paper_idx]
	bonus += float(pp["bonus"])
	if ribbon_idx >= 0:
		var rb: Dictionary = Data.RIBBONS[ribbon_idx]
		rid = rb["id"]
		rcol = rb["color"]
		bonus += float(rb["bonus"])
		_spend("ribbon", int(rb["cost"]), CENTER + Vector2(0, -100))
	if box_idx >= 0:
		var bx: Dictionary = Data.BOXES[box_idx]
		bonus += float(bx["bonus"])
	var choice := "native"
	if item_kind != "box":
		choice = "box" if box_idx >= 0 else "shape"
	result = {
		"paper_tag": pp["tag"],
		"length_class": length_class,
		"crumpled": crumpled,
		"tape_count": tape_strips.size(),
		"ribbon": rid,
		"bow_size": bow_size,
		"wrap_choice": choice,
		"bonus": minf(bonus, 0.2),
		"look": {
			"kind": item_kind, "item_id": item_id, "w": item_w, "h": item_h, "wrap_mode": wrap_mode,
			"base": pp["base"], "accent": pp["accent"], "ribbon": rcol, "bow": bow_size,
		},
	}
	bell_shake = 0.5
	AudioSynth.play_sfx("bell")
	step = Step.DELIVER
	_hint("")
	gift_ready.emit(result)


# --- Рисование: стол, панели, инструменты -------------------------------------

func _draw() -> void:
	_draw_table()
	_draw_panels()
	_draw_mat()
	_draw_ticket()
	_draw_rolls()
	_draw_spools()
	_draw_tape_dispenser()
	_draw_bin()
	_draw_bell()
	_draw_choose_cards()
	_draw_gift()
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
	draw_string(font, Vector2(LEFT_PANEL.position.x, LEFT_PANEL.position.y + 24.0), "Бумага", HORIZONTAL_ALIGNMENT_CENTER, LEFT_PANEL.size.x, 16, Color(1, 0.93, 0.75, 0.8))
	draw_string(font, Vector2(RIGHT_PANEL.position.x, RIGHT_PANEL.position.y + 24.0), "Ленты", HORIZONTAL_ALIGNMENT_CENTER, RIGHT_PANEL.size.x, 16, Color(1, 0.93, 0.75, 0.8))


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
	draw_string(font, Vector2(r.position.x + 20.0, r.position.y + 36.0), "Заказ: " + ticket_name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 22, Color(0.62, 0.38, 0.26))
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
		var selected := (gi == ribbon_idx)
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
	if step == Step.TAPE:
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
	draw_string(font, c + Vector2(-40, 52), "Выбросить", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(1, 0.96, 0.85, 0.8))


func _draw_bell() -> void:
	var pulse := 0.0
	if step == Step.DONE:
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
	draw_string(font, BELL_POS + Vector2(-50, 62), "Отдать клиенту", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, Color(1, 0.96, 0.85, 0.9))


func _draw_popups() -> void:
	for pu in popups:
		var t: float = pu["t"]
		var pos: Vector2 = pu["pos"]
		var col: Color = pu["col"]
		var a := 1.0 - t * t
		var txt: String = pu["text"]
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 30, Color(0, 0, 0, 0.5 * a))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 30, Color(col.r, col.g, col.b, a))


# --- Рисунок бумаги ---------------------------------------------------------------

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


# --- Рисование: выбор упаковки ------------------------------------------------------

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
			var br := Rect2(center.x - 56.0, center.y - 60.0, 112.0, 84.0)
			U.fill_stroke(self, U.rect_pts(br), Color.html(bx["color"]), 4.0, time)
			U.fill_stroke(self, U.rect_pts(Rect2(br.position.x - 6.0, br.position.y - 14.0, br.size.x + 12.0, 22.0)), Color.html(bx["lid"]), 4.0, time)
			draw_string(font, Vector2(r.position.x, r.end.y - 52.0), str(bx["name"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, U.INK)
			draw_string(font, Vector2(r.position.x, r.end.y - 24.0), "Расход: %d" % int(bx["cost"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.7, 0.32, 0.25))
		else:
			var kind := item_kind
			var sil := Shapes.silhouette(kind)
			var bound := maxf(raw_w, raw_h)
			var k := 120.0 / bound
			var scaled := PackedVector2Array()
			for p in sil:
				scaled.append(center + Vector2(0, -26) + p * k)
			U.fill_stroke(self, scaled, Color.html(item["color"]), 4.0, time)
			draw_string(font, Vector2(r.position.x, r.end.y - 52.0), "По форме", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, U.INK)
			draw_string(font, Vector2(r.position.x, r.end.y - 24.0), "без коробки", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color(0.45, 0.35, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Рисование: подарок ---------------------------------------------------------------

func _set_gift_transform(extra: float = 1.0) -> void:
	var s := maxf(gift_scale * extra, 0.001)
	draw_set_transform(CENTER + gift_off, 0.0, Vector2(s, s))


func _draw_gift() -> void:
	if item.is_empty() or step == Step.CHOOSE:
		return
	_set_gift_transform()
	var shape_mode := wrap_mode == "shape"
	var ends_e := U.ease_in_out(ends_t)
	var hs := item_h + 2.0 * MARGIN * (1.0 - ends_e)
	var hh := hs * 0.5
	var ir := Rect2(-item_w * 0.5, -item_h * 0.5, item_w, item_h)
	var f := _flap_len()
	var paper: Dictionary = {}
	if paper_idx >= 0:
		paper = Data.PAPERS[paper_idx]
	var pbase := Color.html(paper["base"]) if not paper.is_empty() else Color.WHITE
	var back := Color("#efe3c8").lerp(pbase, 0.16)
	var clip := clip_cur

	# 1. основа листа и клапаны, ещё лежащие вбок (виден изнаночный бок)
	if not paper.is_empty():
		var bw := minf(sheet_len, item_w)
		var base_r := Rect2(-bw * 0.5, -hh, bw, hs)
		if clip.size() < 3:
			draw_rect(Rect2(base_r.position + Vector2(5, 7), base_r.size), Color(0, 0, 0, 0.22))
		_fill_rect(base_r, back, clip)
		if clip.size() < 3:
			draw_rect(Rect2(base_r.position.x, -hh, base_r.size.x, 5.0), pbase)
			draw_rect(Rect2(base_r.position.x, hh - 5.0, base_r.size.x, 5.0), pbase)
		for i in 2:
			var sgn := -1.0 if i == 0 else 1.0
			var hinge := sgn * item_w * 0.5
			var ct := cos(theta[i])
			if f > 0.0 and ct < 0.0:
				var xe := hinge - sgn * f * ct
				var xa := minf(hinge, xe)
				var xb := maxf(hinge, xe)
				var shade := lerpf(0.78, 1.0, clampf((theta[i] - PI * 0.5) / (PI * 0.5), 0.0, 1.0))
				draw_rect(Rect2(xa + 4.0, -hh + 6.0, xb - xa, hs), Color(0, 0, 0, 0.18))
				draw_rect(Rect2(xa, -hh, xb - xa, hs), back.darkened(1.0 - shade))
				draw_rect(Rect2(xa, -hh, xb - xa, 5.0), pbase)
				draw_rect(Rect2(xa, hh - 5.0, xb - xa, 5.0), pbase)
				_rect_stroke(Rect2(xa, -hh, xb - xa, hs), 3.0)

	# 2. сама вещь или коробка
	_draw_subject(ir)

	# 3. собранный хвост бумаги (только «по форме»)
	if shape_mode and tail_t > 0.0 and not paper.is_empty() and item.has("tail"):
		_draw_tail(paper)

	# 4. клапаны поверх вещи (виден рисунок бумаги)
	if not paper.is_empty() and f > 0.0:
		var order: Array = fold_order.duplicate()
		for i in 2:
			if not order.has(i):
				order.append(i)
		for idx in order:
			var i2: int = idx
			var sgn2 := -1.0 if i2 == 0 else 1.0
			var hinge2 := sgn2 * item_w * 0.5
			var ct2 := cos(theta[i2])
			if ct2 < 0.0:
				continue
			var xe2 := hinge2 - sgn2 * f * ct2
			var xa2 := minf(hinge2, xe2)
			var xb2 := maxf(hinge2, xe2)
			if xb2 - xa2 < 0.5:
				continue
			var cr := Rect2(xa2, -hh, xb2 - xa2, hs)
			if clip.size() < 3:
				var shx := xe2 if sgn2 < 0.0 else xe2 - 6.0
				draw_rect(Rect2(shx, -hh + 4.0, 6.0, hs), Color(0, 0, 0, 0.2))
			_draw_print(cr, paper, hinge2, -sgn2, clip)
			if clip.size() < 3:
				draw_rect(cr, Color(0, 0, 0, 0.22 * (1.0 - ct2)))
				draw_line(Vector2(xe2, -hh), Vector2(xe2, hh), Color(1, 1, 1, 0.35), 2.0)
				_rect_stroke(cr, 3.0)

	# 5. общий контур готового свёртка
	if step >= Step.TUCK and not paper.is_empty():
		if shape_mode and clip.size() >= 3:
			U.stroke(self, clip, U.INK, 4.0, time, 1.2)
		elif not shape_mode:
			_rect_stroke(Rect2(-item_w * 0.5, -hh, item_w, hs), 4.0)

	# 6. скотч
	for ts in tape_strips:
		var sy: float = ts["y"]
		var rot: float = ts["rot"]
		var age: float = ts["age"]
		var pop := 1.0 + 0.4 * exp(-age * 12.0)
		var tc := Vector2(seam_x, sy)
		var hw := TAPE_W * 0.5 * pop
		var th := TAPE_H * 0.5 * pop
		var pts := PackedVector2Array()
		for corner in [Vector2(-hw, -th), Vector2(hw, -th), Vector2(hw, th), Vector2(-hw, th)]:
			var cv: Vector2 = corner
			pts.append(tc + cv.rotated(rot))
		draw_colored_polygon(pts, Color(0.97, 0.95, 0.82, 0.58))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(1, 1, 1, 0.55), 1.5)
		draw_line(tc + Vector2(-hw * 0.4, -th * 0.8).rotated(rot), tc + Vector2(-hw * 0.4, th * 0.2).rotated(rot), Color(1, 1, 1, 0.45), 2.0)

	# 7. лента и бант
	if ribbon_idx >= 0 and step >= Step.DONE:
		var rbn: Dictionary = Data.RIBBONS[ribbon_idx]
		var rc := Color.html(rbn["color"])
		var bs := bow_size * maxf(U.ease_out_back(bow_pop), 0.01)
		if shape_mode and item.has("tail"):
			var tl: Array = item["tail"]
			var b := Vector2(float(tl[0]), float(tl[1]))
			var d := Vector2(float(tl[2]), float(tl[3]))
			var pp := d.rotated(PI * 0.5)
			draw_line(b + pp * -22.0, b + pp * 22.0, U.INK, 14.0)
			draw_line(b + pp * -22.0, b + pp * 22.0, rc, 9.0)
			U.draw_bow(self, b + d * 6.0, bs * 0.8, rc, time)
		else:
			var gr := ir.grow(2.0)
			for bnd in [Rect2(gr.position.x, -9.0, gr.size.x, 18.0), Rect2(-9.0, gr.position.y, 18.0, gr.size.y)]:
				var br: Rect2 = bnd
				draw_rect(Rect2(br.position + Vector2(2, 3), br.size), Color(0, 0, 0, 0.2))
				draw_rect(br, rc)
				if br.size.x > br.size.y:
					draw_rect(Rect2(br.position.x, br.position.y + 2.0, br.size.x, 3.0), rc.lightened(0.3))
				else:
					draw_rect(Rect2(br.position.x + 2.0, br.position.y, 3.0, br.size.y), rc.lightened(0.3))
				_rect_stroke(br, 2.5)
			U.draw_bow(self, Vector2.ZERO, bs, rc, time)
	elif shape_mode and step >= Step.TAPE and tail_t > 0.0 and item.has("tail"):
		# без ленты хвост просто перевязан бечёвкой
		var tl2: Array = item["tail"]
		var b2 := Vector2(float(tl2[0]), float(tl2[1]))
		var pp2 := Vector2(float(tl2[2]), float(tl2[3])).rotated(PI * 0.5)
		draw_line(b2 + pp2 * -18.0, b2 + pp2 * 18.0, Color("#6b4a2a"), 4.0)
		draw_circle(b2, 5.0, Color("#6b4a2a"))

	_draw_gift_hints(hh, f)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _draw_box_art(r: Rect2, col: Color, lid: Color, tape: bool) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.25))
	U.fill_stroke(self, U.rect_pts(r), col, 4.0, time)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 9.0), col.lightened(0.14))
	var lid_r := Rect2(r.position.x - 4.0, r.position.y - 2.0, r.size.x + 8.0, r.size.y * 0.22)
	U.fill_stroke(self, U.rect_pts(lid_r), lid, 3.5, time)
	if tape:
		draw_rect(Rect2(-9.0, r.position.y, 18.0, r.size.y), Color("#dccfab"))
		draw_rect(Rect2(r.position.x + 12.0, r.end.y - 30.0, 38.0, 18.0), Color("#efe7d4"))


func _draw_item_art(ir: Rect2) -> void:
	var col := Color.html(item["color"])
	match item_kind:
		"box":
			_draw_box_art(ir, col, col.darkened(0.08), true)
		"bottle":
			draw_colored_polygon(U.ellipse(Vector2(0, 40), ir.size.x * 0.45, 8.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(self, sil_poly, col, 4.0, time)
			draw_rect(Rect2(-75.0, -17.0, 70.0, 34.0), Color("#efe3c8"))
			draw_rect(Rect2(-69.0, -2.0, 58.0, 4.0), Color("#d9b13f"))
			draw_rect(Rect2(100.0, -15.0, 15.0, 30.0), Color("#d9b13f"))
			draw_rect(Rect2(-80.0, -30.0, 100.0, 6.0), Color(1, 1, 1, 0.18))
		"ball":
			draw_colored_polygon(U.ellipse(Vector2(4, 6), 75.0, 75.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(self, sil_poly, col, 4.0, time)
			for k in 3:
				var a0 := float(k) * TAU / 3.0
				var pts := PackedVector2Array([Vector2.ZERO])
				for j in 9:
					var a := a0 + (float(j) / 8.0) * (TAU / 6.0)
					pts.append(Vector2(cos(a), sin(a)) * 73.0)
				draw_colored_polygon(pts, Color("#f4ead4"))
			draw_circle(Vector2(-26, -30), 12.0, Color(1, 1, 1, 0.3))
			U.stroke(self, sil_poly, U.INK, 4.0, time)
		"bear":
			draw_colored_polygon(U.ellipse(Vector2(4, 96), 70.0, 9.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(self, sil_poly, col, 4.0, time)
			draw_colored_polygon(U.ellipse(Vector2(0, 30), 30.0, 36.0), col.lightened(0.25))
			draw_colored_polygon(U.ellipse(Vector2(-27, -74), 7.0, 7.0), col.darkened(0.2))
			draw_colored_polygon(U.ellipse(Vector2(27, -74), 7.0, 7.0), col.darkened(0.2))
			draw_colored_polygon(U.ellipse(Vector2(0, -38), 16.0, 12.0), col.lightened(0.3))
			draw_colored_polygon(U.ellipse(Vector2(0, -42), 6.0, 4.0), U.INK)
			draw_circle(Vector2(-13, -56), 4.0, U.INK)
			draw_circle(Vector2(13, -56), 4.0, U.INK)
			U.stroke(self, sil_poly, U.INK, 4.0, time)
		"mug":
			draw_colored_polygon(U.ellipse(Vector2(0, 54), 60.0, 8.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(self, sil_poly, col, 4.0, time)
			draw_colored_polygon(U.ellipse(Vector2(-10, 0), 40.0, 40.0), Color("#5a3a26"))
			draw_arc(Vector2(-10, 0), 41.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 3.0)
			draw_colored_polygon(U.ellipse(Vector2(56, 0), 9.0, 13.0), Color(0.2, 0.15, 0.12, 0.35))
			draw_colored_polygon(U.ellipse(Vector2(-22, -14), 9.0, 5.0), Color(1, 1, 1, 0.3))


func _draw_gift_hints(hh: float, f: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	if step == Step.PULL and paper_idx >= 0:
		var ex := sheet_len * 0.5
		var col := Color(1, 0.92, 0.6, 0.85)
		draw_dashed_line(Vector2(ex, -hh - 10.0), Vector2(ex, hh + 10.0), col, 2.0, 7.0)
		draw_dashed_line(Vector2(-ex, -hh - 10.0), Vector2(-ex, hh + 10.0), col, 2.0, 7.0)
		for sg in [-1.0, 1.0]:
			var s: float = sg
			var hp := Vector2(s * (ex + 24.0), 0.0)
			draw_circle(hp, 15.0, Color(0.15, 0.1, 0.12, 0.75))
			draw_arc(hp, 15.0, 0.0, TAU, 24, col, 2.0)
			draw_colored_polygon(PackedVector2Array([hp + Vector2(-9, 0), hp + Vector2(-3, -5), hp + Vector2(-3, 5)]), col)
			draw_colored_polygon(PackedVector2Array([hp + Vector2(9, 0), hp + Vector2(3, -5), hp + Vector2(3, 5)]), col)
	elif step == Step.FOLD:
		for i in 2:
			if folded[i] or flap_drag == i or f < 1.0:
				continue
			var sgn := -1.0 if i == 0 else 1.0
			var hinge := sgn * item_w * 0.5
			var xm := hinge + sgn * f * 0.5
			var d := -sgn
			var tip := xm + d * 16.0
			var bs := xm - d * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(tip, 0), Vector2(bs, -12), Vector2(bs, 12)]), Color(1, 0.95, 0.7, 0.35 + 0.4 * pulse))
	elif step == Step.TAPE:
		var rng := _seam_range()
		var band := Rect2(seam_x - SEAM_HALF, rng.x, SEAM_HALF * 2.0, rng.y - rng.x)
		_fill_rect(band, Color(1, 0.95, 0.6, 0.18 + 0.2 * pulse), clip_cur)
		draw_rect(band, Color(1, 0.95, 0.6, 0.5 + 0.4 * pulse), false, 2.0)
