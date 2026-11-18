extends Node
## Замер упаковки в веб-сборке: откройте игру с ?bench=wrap. Игра сама дойдёт до экрана упаковки,
## сделает четыре сгиба и напишет в консоль браузера (и в window.__bench) время кадра и частиц бумаги.
## В обычной игре этот узел не создаётся.

var main
var proc_ms: Array = []
var mesh_ms: Array = []
var deltas: Array = []
var measuring := false


func run(m) -> void:
	main = m
	await get_tree().process_frame
	main.hud.start_root.visible = false
	main.auto_play = true
	main.think_time = 1.0
	main._start_game()
	await _until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 40.0)
	main._on_offer(str(main.current["ideal"]))
	var w = main.wrap
	await _until(func(): return main.screen == "wrap" and (w.step == w.Step.CHOOSE or w.step == w.Step.PAPER), 30.0)
	if w.step == w.Step.CHOOSE:
		w._choose_card(0)
	w._select_paper(0)
	w.pull_len = clampf(w._l_min() + 60.0, w._pull_min(), w._pull_max())
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w._finish_pull()
	w._select_tool("scissors")
	w._do_cut(w.CENTER + Vector2(-w.pull_len * 0.5 + 30.0, 0.0).rotated(w.rot))
	await get_tree().create_timer(0.8).timeout
	var fh: float = w._flap_len()
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	var starts: Array = [Vector2(-hw - fh * 0.8, 0.0), Vector2(hw + fh * 0.8, 0.0), Vector2(0.0, -hh - 22.0), Vector2(0.0, hh + 22.0)]
	var ends: Array = [Vector2(10.0, 0.0), Vector2(-10.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, -10.0)]
	measuring = true
	for i in 4:
		w.fold_drag_begin(w.CENTER + (starts[i] as Vector2).rotated(w.rot))
		for k in range(1, 25):
			w.fold_drag_move(w.CENTER + (starts[i] as Vector2).lerp(ends[i], float(k) / 24.0).rotated(w.rot))
			await get_tree().process_frame
		w.fold_drag_end()
		await _until(func(): return not w.fold_busy(), 8.0)
	measuring = false
	var res := "BENCH wrap: frames=%d process avg=%.2f ms max=%.2f ms | paper mesh avg=%.2f ms max=%.2f ms | fps avg=%.1f | grid cell=%.0f px | folds=%d" % [
		proc_ms.size(), _avg(proc_ms), _max(proc_ms), _avg(mesh_ms), _max(mesh_ms),
		1.0 / maxf(_avg(deltas), 0.0001), float(w.pmesh.cell), w.fold.fold_count()]
	print(res)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__bench = %s" % JSON.stringify(res))


func _process(delta: float) -> void:
	if not measuring:
		return
	proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	mesh_ms.append(float(main.wrap.mesh_ms))
	deltas.append(delta)


func _until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
	return true


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _max(a: Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, float(v))
	return m
