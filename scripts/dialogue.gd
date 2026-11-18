extends CanvasLayer
## Окно диалога внизу экрана: плашка с именем, печатающийся текст, ответы на выбор.
##   var pick: int = await dialogue.play(lines, on_line)
## Строка: {"who": "Santa", "text": "...", "choices": ["...", "..."], "face": 2}
## Пустое "who" значит внутренний голос героя (без плашки, мягкий цвет текста).
## После выбора ответа он показывается отдельной строкой от имени героя.

const UI = preload("res://scripts/ui_kit.gd")
const U = preload("res://scripts/util.gd")

const CHARS_PER_SEC := 48.0
const WHO_COLORS := {
	"Santa": Color(0.78, 0.2, 0.2),
	"Elf": Color(0.25, 0.55, 0.32),
}

var root: Control
var box: Panel
var plate: Panel
var plate_label: Label
var text_label: Label
var more_label: Label
var choice_box: Control
var typing := false
var shown_chars := 0.0
var total_chars := 0
var active := false
var _picked := -1
var _buttons: Array = []

signal advanced
signal picked(idx: int)


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	root.gui_input.connect(_on_gui_input)
	add_child(root)
	# реплику листает нажатие в любом месте экрана, и на краях за рамкой 1280x720
	var catcher := Control.new()
	catcher.position = U.COVER.position
	catcher.size = U.COVER.size
	catcher.gui_input.connect(_on_gui_input)
	root.add_child(catcher)
	box = UI.panel(Vector2(110, 520), Vector2(1060, 172), Color(0.10, 0.07, 0.11, 0.95), 4, 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # клики должны доходить до root, а не гаснуть на панели
	root.add_child(box)
	plate = UI.panel(Vector2(146, 488), Vector2(250, 50), Color(0.25, 0.55, 0.32), 3, 14)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	plate_label = UI.label("", 30, Color(1, 0.96, 0.85), Vector2(0, 2), Vector2(250, 44), HORIZONTAL_ALIGNMENT_CENTER, true)
	plate.add_child(plate_label)
	text_label = UI.label("", 32, Color(1.0, 0.95, 0.82), Vector2(150, 548), Vector2(980, 120), HORIZONTAL_ALIGNMENT_LEFT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(text_label)
	more_label = UI.label(U.touch_text("click"), 18, Color(1.0, 0.85, 0.5, 0.9), Vector2(1020, 660), Vector2(130, 24), HORIZONTAL_ALIGNMENT_RIGHT)
	root.add_child(more_label)
	choice_box = Control.new()
	choice_box.size = Vector2(1280, 720)
	choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(choice_box)


func _process(delta: float) -> void:
	if not active:
		return
	if typing:
		shown_chars += delta * CHARS_PER_SEC
		text_label.visible_characters = int(shown_chars)
		if int(shown_chars) >= total_chars:
			typing = false
			text_label.visible_characters = -1
	more_label.visible = not typing and _buttons.is_empty()
	more_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)


func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance_request()


func _unhandled_key_input(ev: InputEvent) -> void:
	if active and ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		_advance_request()


func _advance_request() -> void:
	if not active or not _buttons.is_empty():
		return
	if typing:
		typing = false
		text_label.visible_characters = -1
		return
	AudioSynth.play_sfx("click")
	advanced.emit()


func play(lines: Array, on_line: Callable = Callable()) -> int:
	active = true
	root.visible = true
	var last_pick := -1
	for ln in lines:
		var d: Dictionary = ln
		if on_line.is_valid():
			on_line.call(d)
		if d.has("choices"):
			_present(str(d.get("who", "")), str(d["text"]))
			while typing:
				await get_tree().process_frame
			var idx: int = await _choose(d["choices"])
			last_pick = idx
			var chosen: Array = d["choices"]
			await _say("Elf", str(chosen[idx]))
		else:
			await _say(str(d.get("who", "")), str(d["text"]))
	root.visible = false
	active = false
	return last_pick


func _say(who: String, text: String) -> void:
	_present(who, text)
	await advanced


func _present(who: String, text: String) -> void:
	plate.visible = who != ""
	if who != "":
		plate_label.text = who
		var col: Color = WHO_COLORS.get(who, Color(0.4, 0.35, 0.55))
		var sb := plate.get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = col
		text_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	else:
		text_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.95))
	text_label.text = text
	total_chars = text.length()
	shown_chars = 0.0
	text_label.visible_characters = 0
	typing = true


func _choose(options: Array) -> int:
	_picked = -1
	text_label.visible_characters = -1
	var n := options.size()
	for i in n:
		var b := UI.button(str(options[i]), Vector2(300, 330 + float(i) * 66.0), Vector2(680, 56), 26)
		b.pressed.connect(func(): picked.emit(i))
		choice_box.add_child(b)
		_buttons.append(b)
	var idx: int = await picked
	AudioSynth.play_sfx("click")
	for b in _buttons:
		b.queue_free()
	_buttons = []
	return idx
