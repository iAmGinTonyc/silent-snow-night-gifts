extends RefCounted
## Геометрия сложенной бумаги, без рисования. Лист состоит из граней (фасетов): у каждой выпуклый многоугольник
## на плоском листе (`flat`, по нему печатается рисунок бумаги), преобразование плоского листа в стол (`xf`, при
## зеркальном отражении определитель -1, видна обратная сторона), слой (`layer`, 0 — бумага, лежащая под вещью)
## и линии сгибов (`creases`, в координатах плоского листа). Все грани остаются выпуклыми: выпуклый многоугольник,
## разрезанный прямой, даёт два выпуклых, а отражение выпуклость сохраняет.
##
## Сгиб: прямая n.x = c (n единичный, двигается сторона n.x > c). Все куски на подвижной стороне отражаются
## относительно прямой, их порядок в стопке меняется на обратный, и все они ложатся выше всего остального.
## Неподвижность вещи: она лежит на слое 0 и не может двигаться, поэтому сгиб, двигающий слой 0, обязан
## оставить вещь целиком на неподвижной стороне (`clamp_crease`).

const EPS_AREA := 1.0      # куски меньше этой площади отбрасываются
const BIG := 5000.0

var facets: Array = []     # {flat, xf, layer, creases}
var history: Array = []    # перед каждым сгибом: {facets, n, c, info}


## Начать с плоского листа (выпуклый многоугольник в координатах стола).
func reset(sheet: PackedVector2Array) -> void:
	facets = [{"flat": sheet.duplicate(), "xf": Transform2D.IDENTITY, "layer": 0, "creases": []}]
	history = []


func is_empty() -> bool:
	return facets.is_empty()


func fold_count() -> int:
	return history.size()


## Текущий многоугольник грани на столе.
static func poly(f: Dictionary) -> PackedVector2Array:
	var xf: Transform2D = f["xf"]
	return xf * (f["flat"] as PackedVector2Array)


static func area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[i]
		var r := p[(i + 1) % p.size()]
		a += q.x * r.y - r.x * q.y
	return absf(a) * 0.5


func top_layer() -> int:
	var t := 0
	for f in facets:
		t = maxi(t, int(f["layer"]))
	return t


## Отражение относительно прямой n.x = c.
static func reflection(n: Vector2, c: float) -> Transform2D:
	return Transform2D(Vector2(1.0 - 2.0 * n.x * n.x, -2.0 * n.x * n.y), Vector2(-2.0 * n.x * n.y, 1.0 - 2.0 * n.y * n.y), 2.0 * c * n)


## Частичный сгиб на угол phi (0 — лежит, PI — сложен точно): p' = p - s (1 - cos phi) n, s = n.p - c.
## При phi > PI/2 определитель становится отрицательным и грань показывает обратную сторону.
static func partial(n: Vector2, c: float, phi: float) -> Transform2D:
	var k := 1.0 - cos(phi)
	return Transform2D(Vector2(1.0 - k * n.x * n.x, -k * n.x * n.y), Vector2(-k * n.x * n.y, 1.0 - k * n.y * n.y), k * c * n)


static func _half_plane(p0: Vector2, d: Vector2, nn: Vector2) -> PackedVector2Array:
	return PackedVector2Array([p0 - d * BIG, p0 + d * BIG, p0 + d * BIG + nn * BIG, p0 - d * BIG + nn * BIG])


## Режет грань прямой n.x = c. Режет плоский многоугольник той же прямой, перенесённой обратно через xf,
## поэтому рисунок и текущая форма остаются согласованными. Возвращает {moving: [...], stay: [...], crease: [a, b] или []}.
static func split_facet(f: Dictionary, n: Vector2, c: float) -> Dictionary:
	var xf: Transform2D = f["xf"]
	var xinv := xf.affine_inverse()
	var p0 := n * c
	var d := Vector2(-n.y, n.x)
	var y0 := xinv * p0
	var ny := (xinv * (p0 + n)) - y0
	var dy := xinv.basis_xform(d)
	var out := {"moving": [], "stay": [], "crease": []}
	for side in 2:
		var sign_n := ny if side == 0 else -ny
		var hp := _half_plane(y0, dy, sign_n)
		for pp in Geometry2D.intersect_polygons(f["flat"], hp):
			if area(pp) < EPS_AREA:
				continue
			var nf := {"flat": pp, "xf": xf, "layer": f["layer"], "creases": (f["creases"] as Array).duplicate()}
			(out["moving"] if side == 0 else out["stay"]).append(nf)
	# отрезок сгиба внутри исходной грани (в координатах плоского листа)
	var cur := poly(f)
	var ts: Array = []
	for i in cur.size():
		var a := cur[i]
		var b := cur[(i + 1) % cur.size()]
		var da := n.dot(a) - c
		var db := n.dot(b) - c
		if da * db < 0.0 or absf(da) < 1e-6:
			var t := 0.0 if absf(da - db) < 1e-9 else da / (da - db)
			ts.append(a.lerp(b, clampf(t, 0.0, 1.0)))
	if ts.size() >= 2 and not (out["moving"].is_empty() or out["stay"].is_empty()):
		var lo: Vector2 = ts[0]
		var hi: Vector2 = ts[0]
		for q in ts:
			if q.dot(d) < lo.dot(d):
				lo = q
			if q.dot(d) > hi.dot(d):
				hi = q
		out["crease"] = [xinv * lo, xinv * hi]
	return out


## Двигает ли сгиб кусок слоя 0 (его вершины по подвижную сторону прямой).
func moves_layer0(n: Vector2, c: float) -> bool:
	for f in facets:
		if int(f["layer"]) != 0:
			continue
		for v in poly(f):
			if n.dot(v) > c + 0.5:
				return true
	return false


## Опорная прямая вещи: если сгиб двигает слой 0, прямая не может пересекать вещь F (выпуклый многоугольник).
## Бумага перегибается ровно по ребру вещи (n вдоль оси) или по её углу (n по диагонали).
func clamp_crease(n: Vector2, c: float, hull: PackedVector2Array) -> float:
	if hull.size() < 3:
		return c
	var h := -INF
	for v in hull:
		h = maxf(h, n.dot(v))
	return maxf(c, h) if moves_layer0(n, c) else c


## Сгиб целиком. Возвращает false, если двигать нечего.
func fold(n: Vector2, c: float, info: Dictionary = {}) -> bool:
	var snap := _copy(facets)
	var stay: Array = []
	var mov: Array = []
	var top := top_layer()
	for f in facets:
		var s := split_facet(f, n, c)
		var cr: Array = s["crease"]
		for g in s["stay"]:
			if cr.size() == 2:
				g["creases"].append(cr)
			stay.append(g)
		for g2 in s["moving"]:
			if cr.size() == 2:
				g2["creases"].append(cr)
			mov.append(g2)
	var moved_area := 0.0
	var max_old := 0
	for m in mov:
		moved_area += area(poly(m))
		max_old = maxi(max_old, int(m["layer"]))
	if mov.is_empty() or moved_area < 20.0:
		return false
	var r := reflection(n, c)
	for m2 in mov:
		var old := int(m2["layer"])
		m2["xf"] = r * (m2["xf"] as Transform2D)
		m2["layer"] = top + 1 + (max_old - old)
	history.append({"facets": snap, "n": n, "c": c, "info": info})
	facets = stay + mov
	return true


## Откатить последний сгиб. Возвращает {n, c, info} этого сгиба или пустой словарь.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var e: Dictionary = history.pop_back()
	facets = e["facets"]
	return {"n": e["n"], "c": e["c"], "info": e["info"]}


## Куски для рисования при сгибе на угол phi, без изменения модели: {flat, xf, layer, creases, moving, phi}.
func preview(n: Vector2, c: float, phi: float) -> Array:
	var stay: Array = []
	var mov: Array = []
	var top := top_layer()
	var max_old := 0
	for f in facets:
		var s := split_facet(f, n, c)
		for g in s["stay"]:
			g["moving"] = false
			stay.append(g)
		for g2 in s["moving"]:
			max_old = maxi(max_old, int(g2["layer"]))
			mov.append(g2)
	var pm := partial(n, c, phi)
	for m in mov:
		var old := int(m["layer"])
		m["xf0"] = m["xf"]
		m["xf"] = pm * (m["xf"] as Transform2D)
		m["layer"] = top + 1 + (max_old - old)
		m["moving"] = true
		m["phi"] = phi
		m["n"] = n
		m["c"] = c
	return stay + mov


## Куски без сгиба в процессе (как лежат сейчас).
func pieces() -> Array:
	var out: Array = []
	for f in facets:
		var g: Dictionary = (f as Dictionary).duplicate()
		g["moving"] = false
		out.append(g)
	return out


## Самая верхняя грань под точкой p (координаты стола): {idx, layer, flat_pt} или пустой словарь.
func topmost_at(p: Vector2) -> Dictionary:
	var best := -1
	for i in facets.size():
		var f: Dictionary = facets[i]
		if Geometry2D.is_point_in_polygon(p, poly(f)):
			if best < 0 or int(f["layer"]) >= int(facets[best]["layer"]):
				best = i
	if best < 0:
		return {}
	var xf: Transform2D = facets[best]["xf"]
	return {"idx": best, "layer": int(facets[best]["layer"]), "flat_pt": xf.affine_inverse() * p}


## Куда сейчас попала точка плоского листа.
func map_point(idx: int, flat_pt: Vector2) -> Vector2:
	var xf: Transform2D = facets[idx]["xf"]
	return xf * flat_pt


# --- Измерения ---------------------------------------------------------------------------

## Объединение многоугольников: список внешних контуров. Дыры (многоугольники по часовой стрелке) отбрасываются.
static func union_polys(polys: Array) -> Array:
	var parts: Array = []
	for p in polys:
		if area(p) < EPS_AREA:
			continue
		var cur: PackedVector2Array = p
		var rest: Array = []
		for q in parts:
			var outers: Array = []
			for m in Geometry2D.merge_polygons(cur, q):
				if not Geometry2D.is_polygon_clockwise(m):
					outers.append(m)
			if outers.size() == 1:
				cur = outers[0]
			else:
				rest.append(q)
		rest.append(cur)
		parts = rest
	return parts


static func total_area(polys: Array) -> float:
	var a := 0.0
	for p in polys:
		a += area(p)
	return a


## Какая доля площади вещи F закрыта кусками выше вещи (слой 1 и выше). Считается по сетке точек внутри F,
## поэтому дыры и наложения кусков друг на друга считаются верно.
func coverage(hull: PackedVector2Array, n: int = 48) -> float:
	if hull.size() < 3 or area(hull) < 1.0:
		return 0.0
	var upper: Array = []
	for f in facets:
		if int(f["layer"]) >= 1:
			upper.append(poly(f))
	var lo := hull[0]
	var hi := hull[0]
	for v in hull:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	var inside := 0
	var covered := 0
	for iy in n:
		for ix in n:
			var pt := Vector2(lerpf(lo.x, hi.x, (float(ix) + 0.5) / float(n)), lerpf(lo.y, hi.y, (float(iy) + 0.5) / float(n)))
			if not Geometry2D.is_point_in_polygon(pt, hull):
				continue
			inside += 1
			for up in upper:
				if Geometry2D.is_point_in_polygon(pt, up):
					covered += 1
					break
	return float(covered) / float(maxi(inside, 1))


## Площадь не сложенной бумаги слоя 0 вне вещи (торчит по краям).
func loose_area(hull: PackedVector2Array) -> float:
	var a := 0.0
	for f in facets:
		if int(f["layer"]) != 0:
			continue
		var p := poly(f)
		a += area(p)
		for q in Geometry2D.intersect_polygons(p, hull):
			a -= area(q)
	return maxf(a, 0.0)


## Площадь сложенных кусков, торчащих за вещь.
func hanging_area(hull: PackedVector2Array) -> float:
	var outside: Array = []
	for f in facets:
		if int(f["layer"]) < 1:
			continue
		for q in Geometry2D.clip_polygons(poly(f), hull):
			if not Geometry2D.is_polygon_clockwise(q):
				outside.append(q)
	return total_area(union_polys(outside))


## Общая площадь всех кусков (при сгибах сохраняется: сумма площадей граней равна площади листа).
func sheet_area() -> float:
	var a := 0.0
	for f in facets:
		a += area(poly(f))
	return a


static func _copy(src: Array) -> Array:
	var out: Array = []
	for f in src:
		out.append({"flat": (f["flat"] as PackedVector2Array).duplicate(), "xf": f["xf"], "layer": f["layer"], "creases": (f["creases"] as Array).duplicate(true)})
	return out
