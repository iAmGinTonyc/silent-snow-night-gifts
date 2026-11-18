extends RefCounted
## Мелкие помощники для интерфейса из кода: подписи, панели, кнопки в стиле игры.
## Заголовки рисуются шрифтом Londrina Solid Black, остальной текст берёт шрифт проекта.

const INK := Color(0.165, 0.102, 0.078)
const CREAM := Color(1.0, 0.93, 0.75)
const GOLD := Color(1.0, 0.82, 0.45)
const WARM := Color(0.95, 0.8, 0.5)

static var _black: Font


static func black_font() -> Font:
	if _black == null and ResourceLoader.exists("res://fonts/LondrinaSolid-Black.ttf"):
		_black = load("res://fonts/LondrinaSolid-Black.ttf")
	return _black


static func label(text: String, font_size: int, color: Color, pos: Vector2, sz: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	if heading and black_font() != null:
		l.add_theme_font_override("font", black_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(pos: Vector2, sz: Vector2, bg: Color = Color(0.10, 0.07, 0.11, 0.96), border: int = 3, radius: int = 20) -> Panel:
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


static func button(text: String, pos: Vector2, sz: Vector2, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
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
		sb.border_color = INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override(key, sb)
	return b


static func small_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := button(text, pos, sz, 22)
	return b


static func overlay(dim_alpha: float) -> Control:
	var r := Control.new()
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, dim_alpha)
	dim.position = Vector2(-640, -400)   # с запасом: экран бывает шире или выше рамки 1280x720
	dim.size = Vector2(2560, 1520)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(dim)
	return r
