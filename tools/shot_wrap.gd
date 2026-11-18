extends SceneTree
## Скриншоты экрана упаковки по шагам (в окне, не headless): godot --path . --script res://tools/shot_wrap.gd
## Кадры падают в build/shots/. Нужен, потому что превью в панели иногда тормозит до одного кадра в секунду.

var main
var OUT := ProjectSettings.globalize_path("res://build/shots/")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	run()


func wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
	return true


func shot(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func run() -> void:
	await process_frame
	main.auto_play = true
	main.hud.start_root.visible = false
	main._start_game()
	await wait_until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 90.0)
	await shot("w0_order")
	main._on_offer(str(main.current["ideal"]))
	var w = main.wrap
	await wait_until(func(): return w.step == w.Step.CHOOSE or w.step == w.Step.PAPER, 60.0)
	if w.step == w.Step.CHOOSE:
		w._choose_card(w.cards.size() - 1)
	await create_timer(0.8).timeout
	w._select_paper(1)
	w.pull_len = w._pull_min() + 150.0
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w.hover = "spool:1"
	w.mouse_pos = w._spool_pos(1)
	await shot("w1_pull_tooltip")
	w.hover = "ruler"
	await shot("w1b_ruler_tooltip")
	w.hover = ""
	w._select_tool("ruler")
	w.ruler_a = w.CENTER + Vector2(-110, -80)
	w.ruler_b = w.CENTER + Vector2(-70, 80)
	w._set_cut_mark()
	w._select_tool("scissors")
	await shot("w2_mark")
	w._do_cut_line(-w.pull_len * 0.5 + 30.0, -w.pull_len * 0.5 + 80.0, 4.0)
	await create_timer(1.0).timeout
	await shot("w3_cut")
	var hw: float = w._along() * 0.5
	var fh: float = w._flap_len()
	w._begin_flap_drag(w.CENTER + Vector2(-hw - fh * 0.7, 0.0))
	w._update_flap_drag(w.CENTER + Vector2(-hw + fh * 0.4, 46.0))
	await shot("w4_tilt_drag")
	w._end_flap_drag()
	var hh: float = w._across() * 0.5
	var starts: Array = [Vector2(hw + fh * 0.8, 0.0), Vector2(0.0, -hh - 22.0), Vector2(0.0, hh + 22.0)]
	var ends: Array = [Vector2(-10.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, -10.0)]
	for i in 3:
		w._begin_flap_drag(w.CENTER + starts[i])
		w._update_flap_drag(w.CENTER + ends[i])
		w._end_flap_drag()
	await wait_until(func(): return w.tucked, 10.0)
	await create_timer(1.2).timeout
	await shot("w5_tucked")
	w._select_tool("tape")
	w._begin_stroke(w.CENTER + Vector2(-30.0, -10.0))
	for k in 8:
		w._move_stroke(w.CENTER + Vector2(-30.0 + float(k) * 8.0, -10.0 + float(k) * 3.0))
	w._end_stroke()
	w._select_tool("tape")
	w._select_ribbon_tool(2)
	w._ribbon_press(w.CENTER + Vector2(-hw - 2.0, 4.0))
	w.mouse_pos = w.CENTER + Vector2(hw + 2.0, 4.0)
	await create_timer(0.5).timeout
	await shot("w6_ribbon_preview")
	w._ribbon_press(w.CENTER + Vector2(hw + 2.0, 4.0))
	w._ribbon_press(w.CENTER + Vector2(4.0, -hh - 2.0))
	w.mouse_pos = w.CENTER + Vector2(4.0, hh + 2.0)
	w.ribbon_end_vis = w.CENTER + Vector2(4.0, hh) - w.CENTER
	await shot("w7_ribbon_anchored")
	w._ribbon_press(w.CENTER + Vector2(4.0, hh + 2.0))
	w.active_tool = ""
	await create_timer(0.8).timeout
	await shot("w8_done")
	quit()
