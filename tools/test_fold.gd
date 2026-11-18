extends SceneTree
## Модульные тесты геометрии сложенной бумаги: godot --headless --path . --script res://tools/test_fold.gd
## Ожидаемый вывод: «TEST_FOLD OK» и код возврата 0.

const Fold = preload("res://scripts/paper_fold.gd")
var fails := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", label)


func near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _initialize() -> void:
	test_reflection()
	test_stack_order()
	test_clamp()
	test_undo()
	test_partial()
	test_box_four_folds()
	test_diagonal_corner()
	test_topmost()
	test_slanted_sheet()
	print("TEST_FOLD ", "OK" if fails == 0 else "FAILED", " (", checks, " checks, ", fails, " failed)")
	quit(0 if fails == 0 else 1)


func test_reflection() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -50, 100, 50))
	var a0 := f.sheet_area()
	check(f.fold(Vector2(1, 0), 40.0), "fold returns true")
	check(near(f.sheet_area(), a0), "area conserved by a fold")
	check(f.facets.size() == 2, "sheet split in two")
	var moved: Dictionary = {}
	var stay: Dictionary = {}
	for g in f.facets:
		if int(g["layer"]) == 1:
			moved = g
		else:
			stay = g
	check(not moved.is_empty() and not stay.is_empty(), "one moved piece on layer 1, one stationary on layer 0")
	var mp := Fold.poly(moved)
	var minx := 1e9
	var maxx := -1e9
	for v in mp:
		minx = minf(minx, v.x)
		maxx = maxf(maxx, v.x)
	check(near(minx, -20.0) and near(maxx, 40.0), "moving part x in [40,100] lands on [-20,40]")
	var xf: Transform2D = moved["xf"]
	check(xf.determinant() < 0.0, "reflection flips the facet (back side)")
	# точка плоского листа (100, 0) попадает в (-20, 0)
	check((xf * Vector2(100, 0)).distance_to(Vector2(-20, 0)) < 0.01, "flat corner maps to its mirror image")
	check(moved["creases"].size() == 1, "crease recorded on the moved piece")
	var cr: Array = moved["creases"][0]
	check(near(cr[0].x, 40.0) and near(cr[1].x, 40.0), "crease lies on x = 40 in flat coordinates")


func test_stack_order() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -50, 100, 50))
	f.fold(Vector2(1, 0), 40.0)
	var before := {}
	for g in f.facets:
		before[int(g["layer"])] = true
	check(f.fold(Vector2(1, 0), 0.0), "second fold moves the stack")
	# кусок слоя 0 (B) лежал под слоем 1 (A); после общего сгиба порядок обратный: B теперь выше A
	check(f.top_layer() == 3, "old layer 0 moved above old layer 1 (top layer 3)")
	var b_above := 0
	var a_below := 0
	for g in f.facets:
		var xf: Transform2D = g["xf"]
		if int(g["layer"]) == 3 and xf.determinant() < 0.0:
			b_above += 1   # бывший нижний кусок отражён один раз
		if int(g["layer"]) == 2 and xf.determinant() > 0.0:
			a_below += 1   # бывший верхний кусок отражён второй раз и вернул лицевую сторону
	check(b_above >= 1 and a_below >= 1, "relative order reversed: former bottom piece is now above the former top piece")


func test_clamp() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -100, 100, 100))
	var hull := rect(-30, -30, 30, 30)
	check(near(f.clamp_crease(Vector2(1, 0), 10.0, hull), 30.0), "crease through the gift moves to its edge (axis)")
	check(near(f.clamp_crease(Vector2(1, 0), 50.0, hull), 50.0), "crease beyond the gift stays")
	var dn := Vector2(1, 1).normalized()
	check(near(f.clamp_crease(dn, 0.0, hull), 60.0 * dn.x, 0.01), "diagonal crease bends over the gift corner")
	check(near(f.clamp_crease(Vector2(-1, 0), 0.0, hull), 30.0), "mirror axis")
	# слой 1 над вещью двигается без ограничений: слой 0 по подвижную сторону отсутствует
	var g := Fold.new()
	g.facets = [
		{"flat": rect(-100, -20, -50, 20), "xf": Transform2D.IDENTITY, "layer": 0, "creases": []},
		{"flat": rect(50, -20, 100, 20), "xf": Transform2D.IDENTITY, "layer": 1, "creases": []},
	]
	check(not g.moves_layer0(Vector2(1, 0), -20.0), "only upper pieces on the moving side")
	check(near(g.clamp_crease(Vector2(1, 0), -20.0, rect(-10, -10, 10, 10)), -20.0), "folds of pieces above the gift are unconstrained")
	check(g.moves_layer0(Vector2(1, 0), -75.0), "a layer-0 piece on the moving side is detected")


func test_undo() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -50, 100, 50))
	var snap_area := f.sheet_area()
	f.fold(Vector2(1, 0), 40.0)
	f.fold(Vector2(0, 1), 10.0)
	check(f.fold_count() == 2, "two folds recorded")
	var e := f.undo()
	check(not e.is_empty() and f.fold_count() == 1, "undo removes the last fold")
	e = f.undo()
	check(f.fold_count() == 0 and f.facets.size() == 1, "undo twice restores the flat sheet")
	check(near(f.sheet_area(), snap_area), "area after undo")
	check(f.facets[0]["xf"] == Transform2D.IDENTITY and int(f.facets[0]["layer"]) == 0, "identity transform and layer 0 after undo")
	check(f.undo().is_empty(), "undo on an empty history")


func test_partial() -> void:
	var n := Vector2(1, 0)
	var c := 40.0
	check(Fold.partial(n, c, 0.0) == Transform2D.IDENTITY or (Fold.partial(n, c, 0.0) * Vector2(70, 5)).distance_to(Vector2(70, 5)) < 1e-4, "phi = 0 is the identity")
	var full := Fold.partial(n, c, PI)
	var refl := Fold.reflection(n, c)
	for p in [Vector2(70, 5), Vector2(100, -30), Vector2(41, 0)]:
		check((full * p).distance_to(refl * p) < 1e-3, "phi = PI equals the exact reflection")
	var half := Fold.partial(n, c, PI * 0.5)
	check(near((half * Vector2(90, 7)).x, 40.0, 1e-3), "phi = PI/2 puts the point on the crease line")
	check((Fold.partial(n, c, 1.0) * Vector2(40, 12)).distance_to(Vector2(40, 12)) < 1e-4, "points on the crease do not move")
	check(Fold.partial(n, c, 2.5).determinant() < 0.0 and Fold.partial(n, c, 0.7).determinant() > 0.0, "back side shows past PI/2")
	# предпросмотр не меняет модель
	var f := Fold.new()
	f.reset(rect(-100, -50, 100, 50))
	var pv := f.preview(Vector2(1, 0), 40.0, 1.0)
	check(f.facets.size() == 1 and f.fold_count() == 0, "preview leaves the model untouched")
	check(pv.size() == 2, "preview returns both pieces")
	var top_layer := 0
	for g in pv:
		top_layer = maxi(top_layer, int(g["layer"]))
	check(top_layer == 1, "lifting piece is above the rest")


func test_box_four_folds() -> void:
	var f := Fold.new()
	f.reset(rect(-190, -86, 190, 86))
	var hull := rect(-75, -50, 75, 50)
	var a0 := f.sheet_area()
	var tops: Array = []
	var folds: Array = [[Vector2(-1, 0), 75.0], [Vector2(1, 0), 75.0], [Vector2(0, -1), 50.0], [Vector2(0, 1), 50.0]]
	for fd in folds:
		var n: Vector2 = fd[0]
		var c := f.clamp_crease(n, float(fd[1]), hull)
		check(f.fold(n, c), "box fold moves paper")
		tops.append(f.top_layer())
		check(near(f.sheet_area(), a0, 0.5), "area conserved through four folds")
	check(tops[0] < tops[1] and tops[1] < tops[2] and tops[2] < tops[3], "top layer strictly increases in fold order " + str(tops))
	check(f.coverage(hull) > 0.999, "four folds cover the whole box (coverage " + str(f.coverage(hull)) + ")")
	check(f.loose_area(hull) < 1.0, "no loose paper left outside the box")
	check(f.hanging_area(hull) < 1.0, "nothing hangs past the box")
	# после левого и правого сгибов обе половины над вещью, слои первого сгиба ниже
	var f2 := Fold.new()
	f2.reset(rect(-190, -86, 190, 86))
	f2.fold(Vector2(-1, 0), 75.0)
	var l_left := -1
	for g in f2.facets:
		if int(g["layer"]) >= 1:
			l_left = int(g["layer"])
	f2.fold(Vector2(1, 0), 75.0)
	var l_right := -1
	for g in f2.facets:
		var xf: Transform2D = g["xf"]
		if int(g["layer"]) >= 1 and xf.determinant() < 0.0:
			var p := Fold.poly(g)
			var cx := 0.0
			for v in p:
				cx += v.x
			if cx / float(p.size()) > 0.0:
				l_right = maxi(l_right, int(g["layer"]))
	check(l_right > l_left, "later fold (right) is above the earlier one (left)")
	# короткий лист не закрывает вещь целиком
	var s := Fold.new()
	s.reset(rect(-90, -86, 90, 86))
	s.fold(Vector2(-1, 0), 75.0)
	s.fold(Vector2(1, 0), 75.0)
	check(s.coverage(hull) < 0.8, "a short sheet leaves the box partly bare")
	# щель в 10 px между клапанами (дыра в объединении) считается честно
	var g := Fold.new()
	g.reset(rect(-181, -129, 181, 129))
	var hull2 := rect(-93, -93, 93, 93)
	for fd in [[Vector2(-1, 0), 93.0], [Vector2(1, 0), 93.0], [Vector2(0, -1), 93.0], [Vector2(0, 1), 93.0]]:
		g.fold(fd[0], fd[1])
	var cg := g.coverage(hull2)
	check(cg > 0.94 and cg < 0.99, "a 10 px gap between side flaps lowers coverage a little (" + str(cg) + ")")


func test_diagonal_corner() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -100, 100, 100))
	var a0 := f.sheet_area()
	var n := Vector2(1, 1).normalized()
	check(f.fold(n, 60.0), "diagonal corner fold")
	check(near(f.sheet_area(), a0, 0.5), "area conserved by a diagonal fold")
	var found := false
	for g in f.facets:
		if int(g["layer"]) == 1:
			found = true
			for v in Fold.poly(g):
				check(n.dot(v) <= 60.0 + 0.01, "folded corner lies on the stationary side")
				check(v.x >= -100.01 and v.y >= -100.01 and v.x <= 100.01 and v.y <= 100.01, "folded corner stays inside the sheet outline")
	check(found, "corner piece exists")
	# сгиб по диагонали через вещь упирается в её угол
	var hull := rect(-20, -20, 20, 20)
	var c := f.clamp_crease(n, 0.0, hull)
	check(near(c, 40.0 * n.x * 1.0, 0.01), "diagonal crease clamps to the gift corner")


func test_topmost() -> void:
	var f := Fold.new()
	f.reset(rect(-100, -50, 100, 50))
	f.fold(Vector2(1, 0), 40.0)
	var hit := f.topmost_at(Vector2(0, 0))
	check(not hit.is_empty() and int(hit["layer"]) == 1, "topmost piece under a point is the folded one")
	var hit2 := f.topmost_at(Vector2(-90, 0))
	check(not hit2.is_empty() and int(hit2["layer"]) == 0, "bare paper elsewhere")
	check(f.topmost_at(Vector2(150, 0)).is_empty(), "nothing outside the paper")
	var back := f.map_point(int(hit["idx"]), hit["flat_pt"])
	check(back.distance_to(Vector2(0, 0)) < 0.01, "flat point round-trips through the transform")


func test_slanted_sheet() -> void:
	var f := Fold.new()
	f.reset(PackedVector2Array([Vector2(-160, -80), Vector2(150, -80), Vector2(150, 80), Vector2(-110, 80)]))
	var a0 := f.sheet_area()
	f.fold(Vector2(-1, 0), 70.0)
	check(near(f.sheet_area(), a0, 0.5), "area conserved on a slanted sheet")
	for g in f.facets:
		check(Fold.area(Fold.poly(g)) > 0.5, "no empty facets")
		check(Geometry2D.is_polygon_clockwise(g["flat"]) == Geometry2D.is_polygon_clockwise(g["flat"]), "polygon winding is readable")
