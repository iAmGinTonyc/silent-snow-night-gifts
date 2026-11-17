extends Node2D
## Верхний правый угол: касса (заработок) и сердечко терпения клиента, как в референсе.

const U = preload("res://scripts/util.gd")

const BADGE := Rect2(1030, 10, 240, 46)
const SEGMENTS := 10

var shown := 0.0
var target := 0
var pulse := 0.0
var pulse_sign := 1
var patience := 1.0
var patience_secs := 0.0
var patience_on := false
var time := 0.0
var font: Font
var badge_style: StyleBoxFlat


func _ready() -> void:
	font = ThemeDB.fallback_font
	badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.13, 0.09, 0.11, 0.92)
	badge_style.border_color = Color(0.93, 0.82, 0.58)
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(16)
	badge_style.shadow_color = Color(0, 0, 0, 0.35)
	badge_style.shadow_size = 6


func set_money(v: int, animate: bool = true) -> void:
	if animate and v != target:
		pulse = 1.0
		pulse_sign = 1 if v > target else -1
	target = v
	if not animate:
		shown = float(v)


func show_patience(on: bool) -> void:
	patience_on = on


func set_patience(p: float, secs: float = -1.0) -> void:
	patience = clampf(p, 0.0, 1.0)
	if secs >= 0.0:
		patience_secs = secs


func _process(delta: float) -> void:
	time += delta
	shown = move_toward(shown, float(target), maxf(abs(float(target) - shown) * 6.0, 8.0) * delta)
	pulse = maxf(pulse - delta * 2.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var sc := 1.0 + 0.14 * U.ease_out_back(pulse) * pulse
	var c := BADGE.get_center()
	draw_set_transform(c * (1.0 - sc), 0.0, Vector2(sc, sc))
	draw_style_box(badge_style, BADGE)
	# монета
	var coin := Vector2(BADGE.position.x + 30.0, c.y)
	U.fill_stroke(self, U.ellipse(coin, 16.0, 16.0, 0.0, 24), Color("#e6b83a"), 3.0, time)
	draw_arc(coin, 10.0, 0.0, TAU, 20, Color("#b8891f"), 2.0)
	draw_colored_polygon(U.star(coin, 6.0, 2.4, 4, 0.0), Color("#fff0b0"))
	var val := int(round(shown))
	var col := Color(1.0, 0.93, 0.7)
	if val < 0:
		col = Color(1.0, 0.55, 0.5)
	elif pulse > 0.0 and pulse_sign > 0:
		col = Color(0.75, 1.0, 0.7)
	elif pulse > 0.0 and pulse_sign < 0:
		col = Color(1.0, 0.7, 0.6)
	draw_string(font, Vector2(BADGE.position.x + 56.0, c.y + 11.0), str(val), HORIZONTAL_ALIGNMENT_LEFT, 170.0, 30, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if patience_on:
		_draw_patience()


func _draw_patience() -> void:
	var panel := Rect2(1030, 62, 240, 42)
	var low := patience < 0.28
	var beat := 1.0
	if low:
		beat = 1.0 + 0.05 * absf(sin(time * 7.0))
	var c := panel.get_center()
	draw_set_transform(c * (1.0 - beat), 0.0, Vector2(beat, beat))
	draw_style_box(badge_style, panel)
	# сердце
	var hc := Vector2(panel.position.x + 26.0, c.y)
	var heart := PackedVector2Array()
	for k in 24:
		var a := TAU * float(k) / 24.0
		var x := 16.0 * pow(sin(a), 3.0)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		heart.append(hc + Vector2(x, y) * 0.85)
	U.fill_stroke(self, heart, Color("#e04a4a") if not low else Color("#ff3a3a"), 3.0, time)
	# полоса из делений
	var frame := Rect2(panel.position.x + 52.0, panel.position.y + 9.0, 118.0, 24.0)
	draw_rect(frame, Color(0.2, 0.15, 0.17))
	var filled := ceili(patience * float(SEGMENTS))
	var seg_w := (frame.size.x - 8.0) / float(SEGMENTS)
	for i in SEGMENTS:
		if i < filled:
			var col := Color("#6bd36b")
			if patience < 0.5:
				col = Color("#f2c14e")
			if patience < 0.28:
				col = Color("#ef5a4a")
			draw_rect(Rect2(frame.position.x + 4.0 + float(i) * seg_w, frame.position.y + 4.0, seg_w - 2.0, frame.size.y - 8.0), col)
	# время до ухода клиента
	var secs := maxi(int(ceil(patience_secs)), 0)
	var txt := "%d:%02d" % [secs / 60, secs % 60]
	var tcol := Color(1.0, 0.93, 0.7) if not low else Color(1.0, 0.55, 0.5)
	draw_string(font, Vector2(panel.position.x + 176.0, c.y + 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, 60.0, 22, tcol)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
