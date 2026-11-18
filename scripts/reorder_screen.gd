extends CanvasLayer
## Экран заказа игрушек в конце ночи 1 и 2: что осталось на полке, что уже в пути и сколько заказать
## у каждого из двух поставщиков. Ночь, после которой заказ приедет, зависит от поставщика.
##   reorder.open(stock, night, last_night, cash, tutorial); var spent: int = await reorder.finished

const UI = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/data.gd")
const Stock = preload("res://scripts/stock.gd")

signal finished(spent: int)

const ROW_Y := 244.0
const ROW_H := 47.0
const COL_X := [690.0, 940.0]      # левые края колонок поставщиков
const COL_W := 235.0

var root: Control
var stock
var night := 0
var last_night := 2
var cash := 0
var qty := {}              # sid -> {item_id: qty}
var cash_label: Label
var note_label: Label
var total_label: Label
var reason_label: Label
var place_btn: Button
var row_refs: Array = []   # {id, vals: {sid: Label}, plus: {sid: Button}, minus: {sid: Button}}
var col_open := {}         # sid -> bool: успевает ли заказ до конца демки
var preorders: Array = []  # предзаказы на следующую ночь: {who, item, ...}; напоминание в подписи
var _tex_cache := {}


func _ready() -> void:
	layer = 25
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.visible = false
	add_child(root)


func _sprite(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var it: Dictionary = Data.ITEMS[id]
	var path := "res://art/shop/item_%s%s.png" % [it["kind"], "_mid" if it["tier"] == "mid" else ""]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[id] = tex
	return tex


func open(stock_ref, night_idx: int, last_night_idx: int, cash_now: int, tutorial: bool, preorders_next: Array = []) -> void:
	stock = stock_ref
	preorders = preorders_next
	night = night_idx
	last_night = last_night_idx
	cash = cash_now
	qty = {}
	for s in Stock.SUPPLIERS:
		qty[s["id"]] = {}
		col_open[s["id"]] = night + int(s["nights"]) <= last_night
	_build(tutorial)
	root.visible = true
	_refresh()


func _clear() -> void:
	for c in root.get_children():
		c.queue_free()
	row_refs = []


func _build(tutorial: bool) -> void:
	_clear()
	root.add_child(UI.overlay(0.82))
	root.add_child(UI.panel(Vector2(50, 22), Vector2(1180, 676), Color(0.12, 0.085, 0.10, 0.97), 4, 26))
	root.add_child(UI.label("Order toys", 52, UI.CREAM, Vector2(80, 28), Vector2(500, 60), HORIZONTAL_ALIGNMENT_LEFT, true))
	cash_label = UI.label("", 34, UI.GOLD, Vector2(820, 36), Vector2(380, 44), HORIZONTAL_ALIGNMENT_RIGHT, true)
	root.add_child(cash_label)
	var note := "Night %d is over. Orders arrive before the night shown on each supplier." % (night + 1)
	if tutorial:
		note = "Night one is over. From now on the shelf holds only what we have: 2 of each toy. Order more before the next night!"
	if not preorders.is_empty():
		var asks: Array = []
		for po in preorders:
			asks.append("%s: %s" % [str(po["who"]["name"]), str(Data.ITEMS[str(po["item"])]["name"]).to_lower()])
		note = "Pre-orders, they come back tomorrow: %s. Only Jolly Jingle delivers in one night!" % ", ".join(asks)
	note_label = UI.label(note, 20, Color(1.0, 0.86, 0.55) if not preorders.is_empty() else Color(0.92, 0.84, 0.7), Vector2(80, 92), Vector2(1120, 56), HORIZONTAL_ALIGNMENT_LEFT)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note_label)

	# карточки поставщиков
	for si in Stock.SUPPLIERS.size():
		var s: Dictionary = Stock.SUPPLIERS[si]
		var x: float = COL_X[si]
		var card := UI.panel(Vector2(x, 150), Vector2(COL_W, 86), Color(0.2, 0.14, 0.15, 0.95), 2, 12)
		root.add_child(card)
		card.add_child(UI.label(str(s["short"]), 22, UI.GOLD, Vector2(0, 2), Vector2(COL_W, 28), HORIZONTAL_ALIGNMENT_CENTER, true))
		var arrive_txt := "Arrives before night %d" % (night + int(s["nights"]) + 1)
		if not col_open[s["id"]]:
			arrive_txt = "Arrives after the demo"
		card.add_child(UI.label(arrive_txt, 15, Color(0.95, 0.9, 0.78), Vector2(8, 30), Vector2(COL_W - 16, 20)))
		var fee_txt := "~%d%% broken · fee %d" % [roundi(float(s["defect"]) * 100.0), int(s["fee"])]
		card.add_child(UI.label(fee_txt, 15, Color(0.95, 0.9, 0.78), Vector2(8, 48), Vector2(COL_W - 16, 20)))
		var ret_txt := "Min %d · refund %s" % [int(s["min_order"]), "full" if float(s["refund"]) >= 1.0 else "half"]
		if int(s["min_order"]) == 0:
			ret_txt = "No minimum · refund %s" % ("full" if float(s["refund"]) >= 1.0 else "half")
		card.add_child(UI.label(ret_txt, 15, Color(0.95, 0.9, 0.78), Vector2(8, 64), Vector2(COL_W - 16, 20)))

	# заголовки колонок слева
	root.add_child(UI.label("Toy", 17, Color(0.8, 0.7, 0.55), Vector2(150, 218), Vector2(200, 22), HORIZONTAL_ALIGNMENT_LEFT))
	root.add_child(UI.label("On the shelf", 17, Color(0.8, 0.7, 0.55), Vector2(470, 218), Vector2(200, 22), HORIZONTAL_ALIGNMENT_LEFT))

	var ids: Array = stock.all_ids()
	for i in ids.size():
		var id: String = ids[i]
		var it: Dictionary = Data.ITEMS[id]
		var y := ROW_Y + float(i) * ROW_H
		var ref := {"id": id, "vals": {}, "plus": {}, "minus": {}}
		if i % 2 == 1:
			var band := ColorRect.new()
			band.color = Color(1, 1, 1, 0.035)
			band.position = Vector2(70, y)
			band.size = Vector2(1140, ROW_H)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(band)
		var tex := _sprite(id)
		if tex != null:
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = tex
			tr.position = Vector2(86, y + 3)
			tr.size = Vector2(58, ROW_H - 6)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
		root.add_child(UI.label(str(it["name"]), 22, UI.CREAM, Vector2(152, y + 1), Vector2(300, 26), HORIZONTAL_ALIGNMENT_LEFT))
		var tier := "cheap" if it["tier"] == "cheap" else "mid-price"
		root.add_child(UI.label("%s · sells for %d" % [tier, int(it["sell"])], 15, Color(0.85, 0.75, 0.55), Vector2(152, y + 24), Vector2(300, 20), HORIZONTAL_ALIGNMENT_LEFT))
		var have_lbl := UI.label("", 22, UI.CREAM, Vector2(470, y + 8), Vector2(200, 28), HORIZONTAL_ALIGNMENT_LEFT)
		root.add_child(have_lbl)
		ref["have"] = have_lbl
		for si in Stock.SUPPLIERS.size():
			var sid: String = Stock.SUPPLIERS[si]["id"]
			var x: float = COL_X[si]
			var minus := UI.button("-", Vector2(x + 6, y + 5), Vector2(34, 36), 24)
			var val := UI.label("0", 24, UI.CREAM, Vector2(x + 42, y + 8), Vector2(38, 28))
			var plus := UI.button("+", Vector2(x + 82, y + 5), Vector2(34, 36), 24)
			var price := UI.label("%d each" % stock.buy_price(sid, id), 17, Color(0.95, 0.8, 0.5), Vector2(x + 122, y + 12), Vector2(COL_W - 126, 22), HORIZONTAL_ALIGNMENT_LEFT)
			minus.pressed.connect(_step.bind(sid, id, -1))
			plus.pressed.connect(_step.bind(sid, id, 1))
			if not col_open[sid]:
				minus.disabled = true
				plus.disabled = true
			root.add_child(minus)
			root.add_child(val)
			root.add_child(plus)
			root.add_child(price)
			ref["vals"][sid] = val
			ref["plus"][sid] = plus
			ref["minus"][sid] = minus
		row_refs.append(ref)

	total_label = UI.label("", 22, UI.GOLD, Vector2(80, 646), Vector2(640, 28), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(total_label)
	reason_label = UI.label("", 17, Color(1.0, 0.65, 0.55), Vector2(80, 672), Vector2(640, 22), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(reason_label)
	var skip := UI.button("Skip", Vector2(790, 642), Vector2(150, 46), 24)
	skip.pressed.connect(_on_skip)
	root.add_child(skip)
	place_btn = UI.button("Place order", Vector2(960, 642), Vector2(230, 46), 26)
	place_btn.pressed.connect(_on_place)
	root.add_child(place_btn)


func _step(sid: String, id: String, d: int) -> void:
	var lines: Dictionary = qty[sid]
	var q := clampi(int(lines.get(id, 0)) + d, 0, Stock.MAX_PER_ORDER)
	lines[id] = q
	AudioSynth.play_sfx("click")
	_refresh()


func _refresh() -> void:
	cash_label.text = "In the till: %d" % cash
	var total := 0
	var ok := true
	var reason := ""
	var summary: PackedStringArray = []
	for s in Stock.SUPPLIERS:
		var sid: String = s["id"]
		var q: Dictionary = stock.quote(sid, qty[sid])
		total += int(q["total"])
		if int(q["qty"]) > 0:
			summary.append("%s: %d toys, %d" % [s["short"], int(q["qty"]), int(q["total"])])
			if not bool(q["ok"]):
				ok = false
				reason = "%s: %s" % [s["short"], q["reason"]]
	for ref in row_refs:
		var id: String = ref["id"]
		var have: int = stock.count(id)
		var way: int = stock.on_the_way(id)
		(ref["have"] as Label).text = "%d" % have + ("  (+%d on the way)" % way if way > 0 else "")
		for s in Stock.SUPPLIERS:
			var sid: String = s["id"]
			(ref["vals"][sid] as Label).text = str(int((qty[sid] as Dictionary).get(id, 0)))
	if total > cash:
		ok = false
		reason = "Not enough coins"
	var fee_note := ""
	total_label.text = ("Order: %s  ·  left in the till: %d" % [" + ".join(summary), cash - total]) if not summary.is_empty() else "Nothing in the basket yet"
	reason_label.text = reason + fee_note
	place_btn.disabled = summary.is_empty() or not ok


func _on_place() -> void:
	var spent := 0
	for s in Stock.SUPPLIERS:
		var sid: String = s["id"]
		var o: Dictionary = stock.place_order(sid, qty[sid], night)
		if not o.is_empty():
			spent += int(o["paid"])
	AudioSynth.play_sfx("buy")
	root.visible = false
	finished.emit(spent)


func _on_skip() -> void:
	AudioSynth.play_sfx("click")
	root.visible = false
	finished.emit(0)
