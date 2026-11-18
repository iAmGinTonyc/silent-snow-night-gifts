extends SceneTree
## Замер частиц бумаги без окна: godot --headless --path . --script res://tools/bench_mesh.gd
const PaperMesh = preload("res://scripts/paper_mesh.gd")


func _initialize() -> void:
	var pm := PaperMesh.new()
	for size in [Vector2(120, 200), Vector2(190, 260), Vector2(370, 232)]:
		var flat := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)])
		var t0 := Time.get_ticks_usec()
		var m := pm.mesh_for(flat)
		var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var pts: PackedVector2Array = m["pts"]
		var n := pts.size()
		var targets := PackedVector2Array()
		var tz := PackedFloat32Array()
		var ao := PackedFloat32Array()
		targets.resize(n)
		tz.resize(n)
		ao.resize(n)
		var iters := 600
		var t1 := Time.get_ticks_usec()
		for it in iters:
			for i in n:
				var s := pts[i].x * 0.8
				targets[i] = pts[i] + Vector2(sin(it * 0.05) * s * 0.1, 0.0)
				tz[i] = s * 0.1
				ao[i] = 0.2 * exp(-s / 14.0)
			var st := pm.step(hash(flat), targets, tz, 0.016, 40.0, 8.0)
			PaperMesh.shade(st["pos"], st["z"], m["tris"], Color(0.7, 0.2, 0.2), ao)
		var per := float(Time.get_ticks_usec() - t1) / 1000.0 / float(iters)
		print("piece ", size, " particles=", n, " triangles=", (m["tris"] as PackedInt32Array).size() / 3, " build=", snappedf(build_ms, 0.01), " ms, update+shade per frame=", snappedf(per, 0.001), " ms")
	quit()
