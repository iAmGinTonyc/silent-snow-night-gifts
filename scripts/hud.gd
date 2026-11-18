extends CanvasLayer

const UI = preload("res://scripts/ui_kit.gd")
const Story = preload("res://scripts/story.gd")
## Интерфейс: подсказки, баннер вечера, стартовый экран, итоги вечера с расходами,
## лавка поставщика (магазин) и финал.

signal start_pressed
signal next_pressed
signal shop_pressed
signal shop_back_pressed
signal buy_pressed(idx: int)
signal restart_pressed

var hint_label: Label
var toast_label: Label
var title_label: Label
var sub_label: Label
var start_root: Control
var summary_root: Control
var shop_root: Control
var final_root: Control
var summary_title: Label
var summary_text: Label
var summary_next: Button
var shop_balance: Label
var shop_note: Label
var final_text: Label
var shop_cards: Array = []
var _hint_tween: Tween
var _toast_tween: Tween
var _title_tween: Tween
var _note_tween: Tween


func _ready() -> void:
	layer = 10
	hint_label = _make_label("", 17, Color(1.0, 0.95, 0.82, 0.85), Vector2(262, 684), Vector2(760, 26))
	add_child(hint_label)
	toast_label = _make_label("", 22, Color(1.0, 0.9, 0.55), Vector2(262, 112), Vector2(760, 30))
	toast_label.modulate.a = 0.0
	add_child(toast_label)
	title_label = _make_label("", 64, Color(1, 0.96, 0.86), Vector2(240, 246), Vector2(800, 76), HORIZONTAL_ALIGNMENT_CENTER, true)
	title_label.modulate.a = 0.0
	add_child(title_label)
	sub_label = _make_label("", 26, Color(1.0, 0.88, 0.6), Vector2(240, 322), Vector2(800, 36))
	sub_label.modulate.a = 0.0
	add_child(sub_label)
	_build_start()
	_build_summary()
	_build_shop()
	_build_final()


# --- Публичное API -----------------------------------------------------------

func set_hint(text: String) -> void:
	hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	hint_label.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.3)


func show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.9)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func show_title(title: String, sub: String) -> void:
	title_label.text = title
	sub_label.text = sub
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.set_parallel(true)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
	_title_tween.tween_property(sub_label, "modulate:a", 1.0, 0.6)
	_title_tween.chain().tween_interval(1.2)
	_title_tween.chain().set_parallel(true)
	_title_tween.tween_property(title_label, "modulate:a", 0.0, 0.7)
	_title_tween.tween_property(sub_label, "modulate:a", 0.0, 0.7)


func show_summary(l: Dictionary, balance: int, n: int, total: int) -> void:
	summary_title.text = "Night %d of %d is over" % [n, total]
	summary_next.text = "Finish" if n >= total else "Next"
	var net: int = l["net"]
	var sign_net := "+" if net >= 0 else "-"
	summary_text.text = "Gift sales: +%d\nExpenses: -%d\n   paper %d · wasted %d · tape %d · ribbon %d · boxes %d · stock %d\nTips from the jar: +%d\nTonight: %s%d\nIn the till: %d" % [
		int(l["revenue"]), int(l["expenses"]), int(l["paper"]), int(l["waste"]), int(l["tape"]),
		int(l["ribbon"]), int(l["box"]), int(l["stock"]), int(l["tips"]), sign_net, absi(net), balance]
	summary_root.visible = true


func show_shop(items: Array, balance: int) -> void:
	summary_root.visible = false
	shop_root.visible = true
	refresh_shop(items, balance)


func back_to_summary() -> void:
	shop_root.visible = false
	summary_root.visible = true


func refresh_shop(items: Array, balance: int) -> void:
	shop_balance.text = "In the till: %d" % balance
	for c in shop_cards:
		c.queue_free()
	shop_cards = []
	for i in items.size():
		var it: Dictionary = items[i]
		var col := i % 2
		var row := floori(float(i) / 2.0)
		var card := _make_panel(Vector2(150.0 + float(col) * 495.0, 122.0 + float(row) * 80.0), Vector2(470, 72), Color(0.17, 0.12, 0.14, 0.95), 2, 12)
		var nm: String = it["name"]
		card.add_child(_make_label(nm, 21, Color(1.0, 0.93, 0.75), Vector2(14, 6), Vector2(330, 28), HORIZONTAL_ALIGNMENT_LEFT))
		var tag := "Price: %d" % int(it["price"])
		if bool(it["premium"]):
			tag += "  ·  premium"
		card.add_child(_make_label(tag, 14, Color(0.95, 0.8, 0.5), Vector2(14, 38), Vector2(340, 24), HORIZONTAL_ALIGNMENT_LEFT))
		var owned: bool = it["owned"]
		var btn := _make_button("Bought" if owned else "Buy", Vector2(350, 12), Vector2(106, 46))
		btn.add_theme_font_size_override("font_size", 20)
		if owned or int(it["price"]) > balance:
			btn.disabled = true
		btn.pressed.connect(_on_buy_btn.bind(i))
		card.add_child(btn)
		shop_root.add_child(card)
		shop_cards.append(card)


func show_shop_note(text: String) -> void:
	shop_note.text = text
	if _note_tween:
		_note_tween.kill()
	shop_note.modulate.a = 1.0
	_note_tween = create_tween()
	_note_tween.tween_interval(1.8)
	_note_tween.tween_property(shop_note, "modulate:a", 0.0, 0.6)


func show_final(balance: int, tips_total: int) -> void:
	final_text.text = "In the till: %d\nTotal tips: %d\n%s" % [balance, tips_total, Story.DEMO_END_TEXT]
	final_root.visible = true


func hide_all() -> void:
	summary_root.visible = false
	shop_root.visible = false
	final_root.visible = false
	set_hint("")


# --- Построение -------------------------------------------------------------

func _make_label(text: String, font_size: int, color: Color, pos: Vector2, sz: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, heading: bool = false) -> Label:
	var l := Label.new()
	if heading and UI.black_font() != null:
		l.add_theme_font_override("font", UI.black_font())
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_panel(pos: Vector2, sz: Vector2, bg: Color = Color(0.10, 0.07, 0.11, 0.96), border: int = 3, radius: int = 20) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.93, 0.82, 0.58, 0.9)
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, Color(0.22, 0.12, 0.08))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.42, 0.38))
	var colors := {
		"normal": Color(0.96, 0.8, 0.45), "hover": Color(1.0, 0.88, 0.58),
		"pressed": Color(0.86, 0.68, 0.36), "disabled": Color(0.35, 0.3, 0.3),
	}
	for key in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[key]
		sb.border_color = Color(0.165, 0.102, 0.078)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override(key, sb)
	return b


func _make_overlay_root(dim_alpha: float) -> Control:
	var r := Control.new()
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, dim_alpha)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(dim)
	return r


func _build_start() -> void:
	start_root = Control.new()
	start_root.size = Vector2(1280, 720)
	start_root.gui_input.connect(_on_start_input)
	add_child(start_root)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture = load("res://art/ui/menu.jpg")
	pic.size = Vector2(1280, 720)
	pic.pivot_offset = Vector2(640, 430)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_root.add_child(pic)
	var zoom := create_tween().set_loops()
	zoom.tween_property(pic, "scale", Vector2(1.045, 1.045), 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(pic, "scale", Vector2.ONE, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# тёмная полоса сверху под заголовок и лёгкое затемнение снизу
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.75, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.07, 0.9), Color(0.02, 0.02, 0.07, 0.0), Color(0.02, 0.02, 0.07, 0.0), Color(0.02, 0.02, 0.07, 0.6)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.size = Vector2(1280, 720)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_root.add_child(shade)
	start_root.add_child(_make_snow())
	var title := _make_label("Silent Snow Night Gifts", 92, Color(1.0, 0.92, 0.72), Vector2(0, 8), Vector2(1280, 100), HORIZONTAL_ALIGNMENT_CENTER, true)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.07, 0.05, 0.95))
	title.add_theme_constant_override("outline_size", 10)
	start_root.add_child(title)
	var tag := _make_label("Gifts when you need them, where you need them.", 34, Color(1.0, 0.86, 0.5), Vector2(0, 106), Vector2(1280, 44))
	tag.add_theme_color_override("font_outline_color", Color(0.18, 0.05, 0.04, 0.95))
	tag.add_theme_constant_override("outline_size", 8)
	start_root.add_child(tag)
	var prompt := _make_label("Click to start", 40, Color(1.0, 0.9, 0.62), Vector2(0, 626), Vector2(1280, 50), HORIZONTAL_ALIGNMENT_CENTER, true)
	prompt.add_theme_color_override("font_outline_color", Color(0.18, 0.05, 0.04, 0.95))
	prompt.add_theme_constant_override("outline_size", 8)
	start_root.add_child(prompt)
	var tw := create_tween().set_loops()
	tw.tween_property(prompt, "modulate:a", 0.35, 0.9)
	tw.tween_property(prompt, "modulate:a", 1.0, 0.9)


## Мягкий снегопад поверх картинки меню.
func _make_snow() -> CPUParticles2D:
	var sn := CPUParticles2D.new()
	sn.position = Vector2(640, -12)
	sn.amount = 90
	sn.lifetime = 9.0
	sn.preprocess = 9.0
	sn.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sn.emission_rect_extents = Vector2(660, 4)
	sn.direction = Vector2(0.12, 1.0)
	sn.spread = 14.0
	sn.gravity = Vector2.ZERO
	sn.initial_velocity_min = 36.0
	sn.initial_velocity_max = 84.0
	sn.scale_amount_min = 0.5
	sn.scale_amount_max = 1.3
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 1.0])
	rg.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)])
	var rt := GradientTexture2D.new()
	rt.gradient = rg
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(1.0, 0.5)
	rt.width = 14
	rt.height = 14
	sn.texture = rt
	return sn


func _on_start_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		start_root.visible = false
		start_pressed.emit()


func _build_summary() -> void:
	summary_root = _make_overlay_root(0.55)
	summary_root.visible = false
	add_child(summary_root)
	summary_root.add_child(_make_panel(Vector2(300, 90), Vector2(680, 540)))
	summary_title = _make_label("", 36, Color(1.0, 0.93, 0.75), Vector2(320, 118), Vector2(640, 50))
	summary_root.add_child(summary_title)
	summary_text = _make_label("", 24, Color(1.0, 0.88, 0.6), Vector2(340, 190), Vector2(600, 300), HORIZONTAL_ALIGNMENT_LEFT)
	summary_root.add_child(summary_text)
	var shop_btn := _make_button("Grow the shop", Vector2(330, 540), Vector2(290, 54))
	shop_btn.pressed.connect(_on_shop_open)
	summary_root.add_child(shop_btn)
	summary_next = _make_button("Next", Vector2(680, 540), Vector2(240, 54))
	summary_next.pressed.connect(_on_next)
	summary_root.add_child(summary_next)


func _on_shop_open() -> void:
	AudioSynth.play_sfx("click")
	shop_pressed.emit()


func _on_next() -> void:
	summary_root.visible = false
	next_pressed.emit()


func _build_shop() -> void:
	shop_root = _make_overlay_root(0.7)
	shop_root.visible = false
	add_child(shop_root)
	var panel := _make_panel(Vector2(120, 30), Vector2(1040, 660))
	shop_root.add_child(panel)
	# все дочерние элементы лавки кладём в shop_root, поэтому координаты — от его угла
	shop_root.add_child(_make_label("Grow the shop", 36, Color(1.0, 0.93, 0.75), Vector2(160, 40), Vector2(500, 50), HORIZONTAL_ALIGNMENT_LEFT))
	shop_root.add_child(_make_label("Elf entrepreneurs invest the night's earnings in the shop.", 16, Color(0.85, 0.75, 0.6), Vector2(160, 88), Vector2(600, 24), HORIZONTAL_ALIGNMENT_LEFT))
	shop_balance = _make_label("", 28, Color(1.0, 0.88, 0.5), Vector2(780, 50), Vector2(340, 40), HORIZONTAL_ALIGNMENT_RIGHT)
	shop_root.add_child(shop_balance)
	shop_root.add_child(_make_label("Premium materials cost more per use but raise the gift's rating.", 16, Color(0.85, 0.75, 0.6), Vector2(150, 596), Vector2(700, 24), HORIZONTAL_ALIGNMENT_LEFT))
	shop_note = _make_label("", 20, Color(1.0, 0.7, 0.55), Vector2(160, 640), Vector2(400, 30), HORIZONTAL_ALIGNMENT_LEFT)
	shop_note.modulate.a = 0.0
	shop_root.add_child(shop_note)
	var back := _make_button("Back", Vector2(540, 632), Vector2(200, 48))
	back.pressed.connect(_on_shop_back)
	shop_root.add_child(back)


func _on_shop_back() -> void:
	AudioSynth.play_sfx("click")
	shop_back_pressed.emit()


func _on_buy_btn(idx: int) -> void:
	buy_pressed.emit(idx)


func _build_final() -> void:
	final_root = _make_overlay_root(0.15)
	final_root.visible = false
	add_child(final_root)
	final_root.add_child(_make_panel(Vector2(360, 280), Vector2(560, 340)))
	final_root.add_child(_make_label(Story.DEMO_END_TITLE, 60, Color(1.0, 0.93, 0.75), Vector2(380, 300), Vector2(520, 76), HORIZONTAL_ALIGNMENT_CENTER, true))
	final_text = _make_label("", 24, Color(1.0, 0.88, 0.6), Vector2(380, 396), Vector2(520, 110))
	final_root.add_child(final_text)
	var btn := _make_button("Play again", Vector2(500, 530), Vector2(280, 54))
	btn.pressed.connect(_on_restart)
	final_root.add_child(btn)


func _on_restart() -> void:
	final_root.visible = false
	restart_pressed.emit()
