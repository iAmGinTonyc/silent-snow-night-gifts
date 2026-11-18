extends RefCounted
## Общие помощники: easing, формы и «кипящий» контур в стиле старых мультфильмов.

const INK := Color(0.165, 0.102, 0.078)


## Подсказки для телефона и планшета: «Click» становится «Tap», упоминания клавиш и правой кнопки убираются.
static func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


static func touch_text(text: String) -> String:
	if not is_touch():
		return text
	var t := text
	for pair in [[" (Esc goes back)", ""], [" (Esc)", ""], ["(Esc)", ""], [" or press Esc", ""], ["Esc or ", ""],
			[" (or right click)", ""], ["(or right click)", ""], ["Click", "Tap"], ["click", "tap"]]:
		t = t.replace(str(pair[0]), str(pair[1]))
	return t


static func ease_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


static func ease_in(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u


static func ease_in_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Выход с «перелётом» и возвратом: резиновый характер старых мультфильмов.
static func ease_out_back(t: float) -> float:
	var s := 1.70158
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


static func ease_out_elastic(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	if u <= 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * (TAU / 3.0)) + 1.0


static func ellipse(center: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(center + p)
	return pts


static func star(center: Vector2, r_out: float, r_in: float, points: int = 4, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(points) - PI * 0.5
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Детерминированный «шум» 0..1 по двум целым.
static func hash2(ix: int, iy: int) -> float:
	var h: int = (ix * 73856093) ^ (iy * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0


static func boil_frame(t: float) -> int:
	return int(floor(t * 12.0))


## Контур, который «кипит»: вершины чуть дрожат 12 раз в секунду.
static func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, t: float, amp: float = 1.1, closed: bool = true) -> void:
	if pts.size() < 2:
		return
	var f := boil_frame(t)
	var base := int(pts[0].x * 7.0 + pts[0].y * 13.0)
	var out := PackedVector2Array()
	for i in pts.size():
		var j := Vector2(hash2(base + i, f) - 0.5, hash2(f, base + i + 91) - 0.5) * 2.0 * amp
		out.append(pts[i] + j)
	if closed:
		out.append(out[0])
	ci.draw_polyline(out, col, w, true)


static func fill_stroke(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float, t: float, amp: float = 1.1) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	stroke(ci, pts, INK, w, t, amp)


## Бант: хвосты, две петли и узел, всё с «кипящим» контуром.
## Нарисованные банты (art/wrap/bow_<id>.png) по цвету ленты; узел банта на 29% высоты картинки.
static var _bow_tex := {}
static var _bow_ids: Array = []
const BOW_W := 118.0          # ширина нарисованного банта при размере 1
const BOW_KNOT_Y := 0.29


static func bow_texture(col: Color) -> Texture2D:
	if _bow_ids.is_empty():
		var data = load("res://scripts/data.gd")
		for r in data.RIBBONS:
			_bow_ids.append([Color.html(str(r["color"])), str(r["id"])])
	var best := ""
	var best_d := 0.15
	for e in _bow_ids:
		var c: Color = e[0]
		var d := absf(c.r - col.r) + absf(c.g - col.g) + absf(c.b - col.b)
		if d < best_d:
			best_d = d
			best = str(e[1])
	if best == "":
		return null
	if not _bow_tex.has(best):
		var path := "res://art/wrap/bow_%s.png" % best
		_bow_tex[best] = load(path) if ResourceLoader.exists(path) else null
	return _bow_tex[best]


static func draw_bow(ci: CanvasItem, pos: Vector2, s: float, col: Color, t: float) -> void:
	var tex := bow_texture(col)
	if tex != null:
		var w := BOW_W * s
		var h := w * float(tex.get_height()) / float(tex.get_width())
		ci.draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - h * BOW_KNOT_Y, w, h), false)
		return
	# запасной бант кодом (цвет без картинки)
	var dark := col.darkened(0.3)
	var light := col.lightened(0.2)
	fill_stroke(ci, PackedVector2Array([pos + Vector2(-4, 2) * s, pos + Vector2(-34, 50) * s, pos + Vector2(-18, 56) * s, pos + Vector2(2, 10) * s]), dark, 3.0, t)
	fill_stroke(ci, PackedVector2Array([pos + Vector2(4, 2) * s, pos + Vector2(34, 50) * s, pos + Vector2(18, 56) * s, pos + Vector2(-2, 10) * s]), dark, 3.0, t)
	for sg in [-1.0, 1.0]:
		var sgn: float = sg
		var c := pos + Vector2(sgn * 28.0 * s, -4.0 * s)
		fill_stroke(ci, ellipse(c, 27.0 * s, 17.0 * s, sgn * -0.28), col, 3.0, t)
		ci.draw_colored_polygon(ellipse(c, 15.0 * s, 7.0 * s, sgn * -0.28), dark)
	fill_stroke(ci, ellipse(pos, 10.0 * s, 10.0 * s), col, 3.0, t)
	ci.draw_circle(pos + Vector2(-2, -2) * s, 4.0 * s, light)


static func poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5
