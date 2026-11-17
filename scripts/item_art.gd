extends RefCounted
## Рисунки вещей-подарков (вид сверху), общие для стола, полки и выдачи.
## Рисуются в локальных координатах вокруг (0, 0) в «родном» размере вещи.

const U = preload("res://scripts/util.gd")
const Shapes = preload("res://scripts/shapes.gd")


static func draw(ci: CanvasItem, kind: String, item: Dictionary, t: float) -> void:
	var col := Color.html(item["color"])
	var sil := Shapes.silhouette(kind)
	match kind:
		"bottle":
			ci.draw_colored_polygon(U.ellipse(Vector2(0, 40), 104.0, 8.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(ci, sil, col, 4.0, t)
			ci.draw_rect(Rect2(-75.0, -17.0, 70.0, 34.0), Color("#efe3c8"))
			ci.draw_rect(Rect2(-69.0, -2.0, 58.0, 4.0), Color("#d9b13f"))
			ci.draw_rect(Rect2(100.0, -15.0, 15.0, 30.0), Color("#d9b13f"))
			ci.draw_rect(Rect2(-80.0, -30.0, 100.0, 6.0), Color(1, 1, 1, 0.18))
		"ball":
			_football(ci, sil, col, t)
		"bear":
			ci.draw_colored_polygon(U.ellipse(Vector2(4, 96), 70.0, 9.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(ci, sil, col, 4.0, t)
			ci.draw_colored_polygon(U.ellipse(Vector2(0, 30), 30.0, 36.0), col.lightened(0.25))
			ci.draw_colored_polygon(U.ellipse(Vector2(-27, -74), 7.0, 7.0), col.darkened(0.2))
			ci.draw_colored_polygon(U.ellipse(Vector2(27, -74), 7.0, 7.0), col.darkened(0.2))
			ci.draw_colored_polygon(U.ellipse(Vector2(0, -38), 16.0, 12.0), col.lightened(0.3))
			ci.draw_colored_polygon(U.ellipse(Vector2(0, -42), 6.0, 4.0), U.INK)
			ci.draw_circle(Vector2(-13, -56), 4.0, U.INK)
			ci.draw_circle(Vector2(13, -56), 4.0, U.INK)
			U.stroke(ci, sil, U.INK, 4.0, t)
		"mug":
			ci.draw_colored_polygon(U.ellipse(Vector2(0, 54), 60.0, 8.0), Color(0, 0, 0, 0.25))
			U.fill_stroke(ci, sil, col, 4.0, t)
			ci.draw_colored_polygon(U.ellipse(Vector2(-10, 0), 40.0, 40.0), Color("#5a3a26"))
			ci.draw_arc(Vector2(-10, 0), 41.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 3.0)
			ci.draw_colored_polygon(U.ellipse(Vector2(56, 0), 9.0, 13.0), Color(0.2, 0.15, 0.12, 0.35))
			ci.draw_colored_polygon(U.ellipse(Vector2(-22, -14), 9.0, 5.0), Color(1, 1, 1, 0.3))
		"ornament":
			_ornament(ci, sil, col, t)
		"train":
			_train(ci, sil, col, t)


## Футбольный мяч: белый круг, чёрные пятиугольники.
static func _football(ci: CanvasItem, sil: PackedVector2Array, col: Color, t: float) -> void:
	ci.draw_colored_polygon(U.ellipse(Vector2(4, 6), 75.0, 75.0), Color(0, 0, 0, 0.25))
	U.fill_stroke(ci, sil, col, 4.0, t)
	var black := Color(0.13, 0.12, 0.14)
	ci.draw_colored_polygon(_pentagon(Vector2.ZERO, 22.0, -PI * 0.5), black)
	for k in 5:
		var a := -PI * 0.5 + TAU * float(k) / 5.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(dir * 22.0, dir * 42.0, black, 3.0)
		ci.draw_colored_polygon(_pentagon(dir * 58.0, 15.0, a + PI), black)
	ci.draw_circle(Vector2(-26, -30), 11.0, Color(1, 1, 1, 0.35))
	U.stroke(ci, sil, U.INK, 4.0, t)


static func _pentagon(center: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 5:
		var a := rot + TAU * float(i) / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Ёлочная игрушка: блестящий шар с золотой шапочкой и петелькой.
static func _ornament(ci: CanvasItem, sil: PackedVector2Array, col: Color, t: float) -> void:
	ci.draw_colored_polygon(U.ellipse(Vector2(3, 66), 48.0, 7.0), Color(0, 0, 0, 0.25))
	U.fill_stroke(ci, sil, col, 4.0, t)
	ci.draw_colored_polygon(U.ellipse(Vector2(0, 6), 46.0, 46.0, 0.0, 32), col.lightened(0.08))
	for k in 5:
		var y := -30.0 + float(k) * 17.0
		ci.draw_line(Vector2(-40.0, y), Vector2(40.0, y), Color(1, 1, 1, 0.28), 3.0)
	ci.draw_colored_polygon(U.ellipse(Vector2(-18, -16), 13.0, 8.0, -0.6, 14), Color(1, 1, 1, 0.45))
	U.fill_stroke(ci, U.rect_pts(Rect2(-13.0, -62.0, 26.0, 20.0)), Color("#e3b84b"), 3.5, t)
	ci.draw_arc(Vector2(0, -68), 7.0, 0.0, TAU, 14, Color("#e3b84b"), 3.0)
	U.stroke(ci, sil, U.INK, 4.0, t)


## Игрушечный поезд: паровозик и вагон, вид сверху.
static func _train(ci: CanvasItem, sil: PackedVector2Array, col: Color, t: float) -> void:
	ci.draw_colored_polygon(U.ellipse(Vector2(0, 40), 116.0, 8.0), Color(0, 0, 0, 0.25))
	U.fill_stroke(ci, sil, Color("#2b2b33"), 4.0, t)
	U.fill_stroke(ci, U.rect_pts(Rect2(-115.0, -26.0, 100.0, 52.0)), Color("#3a6fd1"), 3.5, t)
	ci.draw_rect(Rect2(-102.0, -16.0, 40.0, 32.0), Color("#e3b84b"))
	ci.draw_rect(Rect2(-56.0, -16.0, 30.0, 32.0), Color("#d9d2c0"))
	ci.draw_rect(Rect2(-16.0, -5.0, 26.0, 10.0), Color("#8a8f99"))
	U.fill_stroke(ci, U.rect_pts(Rect2(8.0, -27.0, 100.0, 54.0)), col, 3.5, t)
	U.fill_stroke(ci, U.ellipse(Vector2(108, 0), 10.0, 27.0, 0.0, 16), col, 3.5, t)
	ci.draw_rect(Rect2(14.0, -20.0, 34.0, 40.0), col.darkened(0.25))
	U.fill_stroke(ci, U.ellipse(Vector2(82, 0), 12.0, 12.0, 0.0, 16), Color("#2b2b33"), 3.0, t)
	ci.draw_circle(Vector2(82, 0), 5.0, Color("#8a8f99"))
	ci.draw_rect(Rect2(58.0, -4.0, 14.0, 8.0), Color(1, 1, 1, 0.3))
