extends CanvasLayer
## Приёмка ящика с игрушками перед ночью: все игрушки лежат на столе, среди них бывает брак
## (явный и почти незаметный). Кликаем по тем, что хотим отправить обратно. Хорошую игрушку
## поставщик назад не принимает, а пропущенный брак попадёт на полку.
##   inspect.open(stock, order, units, tutorial); var res: Dictionary = await inspect.finished

const UI = preload("res://scripts/ui_kit.gd")
const Data = preload("res://scripts/data.gd")
const Stock = preload("res://scripts/stock.gd")

signal finished(result: Dictionary)

const CARD := Vector2(200, 196)
const GAP := 14.0

var root: Control
var stock
var order: Dictionary = {}
var units_in: Array = []
var flagged: Array = []        # индексы штук, которые отправляем назад
var cards: Array = []
var count_label: Label
var done_btn: Button
var phase := "table"
var _tex_cache := {}


func _ready() -> void:
	layer = 25
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.visible = false
	add_child(root)


func sprite_path(id: String, defect: String) -> String:
	var it: Dictionary = Data.ITEMS[id]
	var mid := "_mid" if it["tier"] == "mid" else ""
	var suffix := ""
	if defect == "bad":
		suffix = "_bad"
	elif defect == "sub":
		suffix = "_sub"
	return "res://art/shop/item_%s%s%s.png" % [it["kind"], mid, suffix]


func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t


func open(stock_ref, order_ref: Dictionary, units: Array, tutorial: bool) -> void:
	stock = stock_ref
	order = order_ref
	units_in = units
	flagged = []
	phase = "table"
	_build(tutorial)
	root.visible = true


func _clear() -> void:
	for c in root.get_children():
		c.queue_free()
	cards = []


func _build(tutorial: bool) -> void:
	_clear()
	root.add_child(UI.overlay(0.8))
	root.add_child(UI.panel(Vector2(60, 24), Vector2(1160, 672), Color(0.16, 0.11, 0.09, 0.97), 4, 26))
	var s: Dictionary = stock.supplier(str(order["supplier"]))
	root.add_child(UI.label("A crate from %s" % s["short"], 46, UI.CREAM, Vector2(90, 30), Vector2(1100, 56), HORIZONTAL_ALIGNMENT_LEFT, true))
	var tip := "Look closely. Click a broken toy to send it back. A good toy can't be returned, so be sure."
	if tutorial:
		tip = "Our first delivery! Suppliers sometimes pack in a hurry. Look closely and click every broken toy to send it back. A good toy can't be returned."
	var t := UI.label(tip, 21, Color(0.92, 0.84, 0.7), Vector2(90, 88), Vector2(1100, 56), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(t)
	var n := units_in.size()
	var cols := mini(n, 5)
	var rows := ceili(float(n) / float(maxi(cols, 1)))
	var total_w := float(cols) * CARD.x + float(cols - 1) * GAP
	var x0 := (1280.0 - total_w) * 0.5
	var y0 := 156.0 + (3.0 - float(rows)) * 38.0
	for i in n:
		var u: Dictionary = units_in[i]
		var col := i % cols
		var row := i / cols
		var pos := Vector2(x0 + float(col) * (CARD.x + GAP), y0 + float(row) * (CARD.y + GAP))
		var card := UI.panel(pos, CARD, Color(0.42, 0.29, 0.2, 0.96), 3, 14)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
		root.add_child(card)
		var tex := _tex(sprite_path(str(u["id"]), str(u["defect"])))
		if tex != null:
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = tex
			tr.position = Vector2(10, 8)
			tr.size = Vector2(CARD.x - 20, CARD.y - 44)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(tr)
		card.add_child(UI.label(str(Data.ITEMS[str(u["id"])]["name"]), 17, Color(1.0, 0.93, 0.75), Vector2(4, CARD.y - 32), Vector2(CARD.x - 8, 24)))
		var stamp := UI.label("SEND BACK", 30, Color(1, 0.96, 0.9), Vector2(0, 66), Vector2(CARD.x, 44), HORIZONTAL_ALIGNMENT_CENTER, true)
		stamp.rotation = -0.18
		stamp.pivot_offset = Vector2(CARD.x * 0.5, 22)
		stamp.visible = false
		var shade := ColorRect.new()
		shade.color = Color(0.7, 0.12, 0.12, 0.55)
		shade.position = Vector2(4, 4)
		shade.size = CARD - Vector2(8, 8)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.visible = false
		card.add_child(shade)
		card.add_child(stamp)
		cards.append({"card": card, "shade": shade, "stamp": stamp})
	count_label = UI.label("", 24, UI.GOLD, Vector2(90, 646), Vector2(640, 32), HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(count_label)
	done_btn = UI.button("Done", Vector2(980, 636), Vector2(210, 50), 28)
	done_btn.pressed.connect(_on_done)
	root.add_child(done_btn)
	_refresh()


func _on_card_input(ev: InputEvent, i: int) -> void:
	if phase != "table":
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if flagged.has(i):
			flagged.erase(i)
			AudioSynth.play_sfx("click")
		else:
			flagged.append(i)
			AudioSynth.play_sfx("dull")
		_refresh()


func _refresh() -> void:
	for i in cards.size():
		var on := flagged.has(i)
		(cards[i]["shade"] as ColorRect).visible = on
		(cards[i]["stamp"] as Label).visible = on
	count_label.text = "Sending back: %d of %d" % [flagged.size(), units_in.size()]


func _on_done() -> void:
	if phase != "table":
		return
	phase = "result"
	AudioSynth.play_sfx("click")
	var res: Dictionary = stock.finish_inspection(order, units_in, flagged)
	_show_result(res)


func _show_result(res: Dictionary) -> void:
	_clear()
	root.add_child(UI.overlay(0.8))
	root.add_child(UI.panel(Vector2(300, 150), Vector2(680, 420), Color(0.16, 0.11, 0.09, 0.97), 4, 26))
	root.add_child(UI.label("Crate checked", 46, UI.CREAM, Vector2(320, 164), Vector2(640, 56), HORIZONTAL_ALIGNMENT_CENTER, true))
	var lines: PackedStringArray = []
	if int(res["back_bad"]) > 0:
		lines.append("Sent back %d broken: +%d coins" % [int(res["back_bad"]), int(res["refund"])])
	if int(res["back_good"]) > 0:
		lines.append("Sent back %d good: not accepted, no refund" % int(res["back_good"]))
	if int(res["back_bad"]) == 0 and int(res["back_good"]) == 0:
		lines.append("Nothing sent back")
	lines.append("On the shelf now: %d toys" % int(res["kept"]))
	if int(res["slipped"]) > 0:
		lines.append("%d broken slipped through. Hope nobody notices." % int(res["slipped"]))
	else:
		lines.append("The whole shelf is in good shape.")
	var text := UI.label("\n".join(lines), 26, UI.GOLD, Vector2(330, 238), Vector2(620, 230), HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(text)
	var ok := UI.button("Open the shop", Vector2(500, 492), Vector2(280, 54), 28)
	ok.pressed.connect(func():
		AudioSynth.play_sfx("click")
		root.visible = false
		finished.emit(res))
	root.add_child(ok)
