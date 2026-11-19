extends RefCounted
## Силуэты предметов для упаковки «по форме». Координаты локальные, центр в (0, 0).

const U = preload("res://scripts/util.gd")

static var _cache := {}

## Нарисованная упаковка по контуру: art/wrap/shape_<вид>_<бумага>.png (свёрток с хвостом в цвете и узоре бумаги)
## и где картинка лежит в координатах вещи. Нет картинки — свёрток рисуется кодом, как раньше.
const ART_RECT := {
	"ball": [-82.83, -82.39, 198.91, 165.65], "bear": [-80.0, -131.05, 159.74, 226.58],
	"ornament": [-61.3, -96.09, 121.96, 163.04], "train": [-120.6, -39.2, 279.0, 78.0],
}
static var _art := {}


static func wrap_art(kind: String, paper_id: String) -> Texture2D:
	var key := kind + ":" + paper_id
	if not _art.has(key):
		var path := "res://art/wrap/shape_%s_%s.png" % [kind, paper_id]
		_art[key] = load(path) if (ART_RECT.has(kind) and ResourceLoader.exists(path)) else null
	return _art[key]


static func art_rect(kind: String) -> Rect2:
	var r: Array = ART_RECT.get(kind, [0, 0, 0, 0])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func silhouette(kind: String) -> PackedVector2Array:
	if _cache.has(kind):
		return _cache[kind]
	var pts := _build(kind)
	_cache[kind] = pts
	return pts


static func _union(parts: Array) -> PackedVector2Array:
	var acc: PackedVector2Array = parts[0]
	for i in range(1, parts.size()):
		var merged := Geometry2D.merge_polygons(acc, parts[i])
		var best := PackedVector2Array()
		var best_area := -1.0
		for m in merged:
			var a := U.poly_area(m)
			if a > best_area:
				best_area = a
				best = m
		if best.size() >= 3:
			acc = best
	return acc


static func _build(kind: String) -> PackedVector2Array:
	match kind:
		"ball":
			return U.ellipse(Vector2.ZERO, 75.0, 75.0, 0.0, 48)
		"bottle":
			var pts := PackedVector2Array()
			for p in [Vector2(-80, -35), Vector2(30, -35), Vector2(46, -31), Vector2(58, -20), Vector2(64, -13),
					Vector2(100, -13), Vector2(100, -15), Vector2(115, -15), Vector2(115, 15), Vector2(100, 15),
					Vector2(100, 13), Vector2(64, 13), Vector2(58, 20), Vector2(46, 31), Vector2(30, 35), Vector2(-80, 35)]:
				pts.append(p)
			for k in range(1, 12):
				var a := PI * 0.5 + PI * float(k) / 12.0
				pts.append(Vector2(-80.0 + cos(a) * 35.0, sin(a) * 35.0))
			return pts
		"bear":
			return _union([
				U.ellipse(Vector2(0, 26), 50.0, 54.0, 0.0, 36),
				U.ellipse(Vector2(0, -46), 36.0, 34.0, 0.0, 32),
				U.ellipse(Vector2(-27, -74), 13.0, 13.0, 0.0, 20),
				U.ellipse(Vector2(27, -74), 13.0, 13.0, 0.0, 20),
				U.ellipse(Vector2(-58, 12), 16.0, 30.0, 0.35, 24),
				U.ellipse(Vector2(58, 12), 16.0, 30.0, -0.35, 24),
				U.ellipse(Vector2(-28, 72), 22.0, 19.0, 0.0, 24),
				U.ellipse(Vector2(28, 72), 22.0, 19.0, 0.0, 24),
			])
		"mug":
			return _union([
				U.ellipse(Vector2(-10, 0), 52.0, 52.0, 0.0, 40),
				U.ellipse(Vector2(52, 0), 22.0, 26.0, 0.0, 24),
			])
		"ornament":
			return _union([
				U.ellipse(Vector2(0, 6), 55.0, 55.0, 0.0, 40),
				U.rect_pts(Rect2(-13.0, -62.0, 26.0, 20.0)),
			])
		"train":
			var parts: Array = [
				U.rect_pts(Rect2(-115.0, -26.0, 100.0, 52.0)),
				U.rect_pts(Rect2(-16.0, -5.0, 26.0, 10.0)),
				U.rect_pts(Rect2(8.0, -27.0, 100.0, 54.0)),
				U.ellipse(Vector2(108, 0), 10.0, 27.0, 0.0, 16),
			]
			for wx in [-100.0, -52.0, 20.0, 70.0]:
				var x: float = wx
				parts.append(U.rect_pts(Rect2(x, -32.0, 18.0, 8.0)))
				parts.append(U.rect_pts(Rect2(x, 24.0, 18.0, 8.0)))
			return _union(parts)
	return PackedVector2Array()
