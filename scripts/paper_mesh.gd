extends RefCounted
## Частицы бумаги: кусок бумаги, который сейчас гнётся, рисуется мелкой сеткой (шаг около 10 px). Каждая вершина сетки
## частица с положением и скоростью, она тянется к своей геометрической цели пружиной с затуханием, поэтому у движения
## есть запаздывание и небольшая «усадка». Освещение считается по нормалям треугольников из высоты z.
## Модуль без рисования: wrap_screen.gd берёт готовые точки, индексы и цвета.

const MAX_VERTS := 500        # на один кусок; если больше, шаг сетки увеличивается
const LIGHT := Vector3(-0.45, -0.55, 0.70)

var cell := 10.0
var meshes := {}              # хэш плоского многоугольника -> {pts, tris, nb}
var states := {}              # хэш -> {pos, vel, z, zv}


func clear_states() -> void:
	states = {}


func particle_count() -> int:
	var n := 0
	for k in states:
		n += (states[k]["pos"] as PackedVector2Array).size()
	return n


## Сетка куска: границу делим на отрезки по cell, внутри ставим узлы сетки, треугольники по Делоне (кусок выпуклый).
func mesh_for(flat: PackedVector2Array) -> Dictionary:
	var key := hash(flat)
	if meshes.has(key):
		return meshes[key]
	var step := cell
	var m := _build(flat, step)
	while (m["pts"] as PackedVector2Array).size() > MAX_VERTS and step < 80.0:
		step *= 1.4
		m = _build(flat, step)
	meshes[key] = m
	return m


static func _build(flat: PackedVector2Array, step: float) -> Dictionary:
	var pts := PackedVector2Array()
	var n := flat.size()
	for i in n:
		var a := flat[i]
		var b := flat[(i + 1) % n]
		var segs := maxi(int(ceil(a.distance_to(b) / step)), 1)
		for k in segs:
			pts.append(a.lerp(b, float(k) / float(segs)))
	var nb := pts.size()
	var lo := flat[0]
	var hi := flat[0]
	for v in flat:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	var gx := lo.x + step * 0.5
	while gx < hi.x:
		var gy := lo.y + step * 0.5
		while gy < hi.y:
			var p := Vector2(gx, gy)
			if Geometry2D.is_point_in_polygon(p, flat):
				var near := 1e9
				for i in n:
					var q := Geometry2D.get_closest_point_to_segment(p, flat[i], flat[(i + 1) % n])
					near = minf(near, p.distance_to(q))
				if near > step * 0.4:
					pts.append(p)
			gy += step
		gx += step
	var tris := Geometry2D.triangulate_delaunay(pts)
	return {"pts": pts, "tris": tris, "nb": nb}


## Одна ступень пружины для частиц куска: цель по положению (targets) и по высоте (tz).
func step(key: int, targets: PackedVector2Array, tz: PackedFloat32Array, dt: float, stiff: float, damp: float) -> Dictionary:
	var n := targets.size()
	if not states.has(key) or (states[key]["pos"] as PackedVector2Array).size() != n:
		var v0 := PackedVector2Array()
		v0.resize(n)
		var zv0 := PackedFloat32Array()
		zv0.resize(n)
		states[key] = {"pos": targets.duplicate(), "vel": v0, "z": tz.duplicate(), "zv": zv0}
	var st: Dictionary = states[key]
	var pos: PackedVector2Array = st["pos"]
	var vel: PackedVector2Array = st["vel"]
	var z: PackedFloat32Array = st["z"]
	var zv: PackedFloat32Array = st["zv"]
	var h := minf(dt, 1.0 / 30.0)
	for i in n:
		var a := (targets[i] - pos[i]) * stiff - vel[i] * damp
		vel[i] += a * h
		pos[i] += vel[i] * h
		var az := (tz[i] - z[i]) * stiff - zv[i] * damp
		zv[i] += az * h
		z[i] += zv[i] * h
	st["pos"] = pos
	st["vel"] = vel
	st["z"] = z
	st["zv"] = zv
	return st


## Цвета вершин: мягкий свет сверху-слева по нормалям из высоты, затемнение у сгиба (ao 0..1 на вершину).
static func shade(pos: PackedVector2Array, z: PackedFloat32Array, tris: PackedInt32Array, base: Color, ao: PackedFloat32Array) -> PackedColorArray:
	var n := pos.size()
	var nx := PackedFloat32Array()
	var ny := PackedFloat32Array()
	var nz := PackedFloat32Array()
	nx.resize(n)
	ny.resize(n)
	nz.resize(n)
	var t := 0
	while t + 2 < tris.size():
		var i0 := tris[t]
		var i1 := tris[t + 1]
		var i2 := tris[t + 2]
		t += 3
		var ax := pos[i1].x - pos[i0].x
		var ay := pos[i1].y - pos[i0].y
		var az := z[i1] - z[i0]
		var bx := pos[i2].x - pos[i0].x
		var by := pos[i2].y - pos[i0].y
		var bz := z[i2] - z[i0]
		var cx := ay * bz - az * by
		var cy := az * bx - ax * bz
		var cz := ax * by - ay * bx
		if cz < 0.0:
			cx = -cx
			cy = -cy
			cz = -cz
		for idx in [i0, i1, i2]:
			nx[idx] += cx
			ny[idx] += cy
			nz[idx] += cz
	var out := PackedColorArray()
	out.resize(n)
	for i in n:
		var ln := sqrt(nx[i] * nx[i] + ny[i] * ny[i] + nz[i] * nz[i])
		var d := LIGHT.z
		if ln > 1e-6:
			d = (nx[i] * LIGHT.x + ny[i] * LIGHT.y + nz[i] * LIGHT.z) / ln
		var s := clampf(1.0 + 0.6 * (d - LIGHT.z), 0.5, 1.15) * (1.0 - ao[i])
		out[i] = Color(clampf(base.r * s, 0.0, 1.0), clampf(base.g * s, 0.0, 1.0), clampf(base.b * s, 0.0, 1.0), 1.0)
	return out
