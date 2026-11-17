extends RefCounted
## Общие помощники: easing, формы и «кипящий» контур в стиле старых мультфильмов.

const INK := Color(0.165, 0.102, 0.078)


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
static func draw_bow(ci: CanvasItem, pos: Vector2, s: float, col: Color, t: float) -> void:
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
