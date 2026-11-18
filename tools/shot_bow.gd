extends SceneTree
## Снимки банта и жалобы после смены (нужно окно, не headless):
##   godot --path . --script res://tools/shot_bow.gd -- /папка
## Кадры: подарок с лентой и бантом на экране упаковки, он же на прилавке, клиент ругается, деньги уходят из копилки.

var main
var out_dir := "/tmp"


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)   # иначе macOS замораживает кадры, если окно закрыто другим
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
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
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)


func fold(w, a: Vector2, b: Vector2) -> void:
	w.fold_drag_begin(w.CENTER + a.rotated(w.rot))
	for k in range(1, 9):
		w.fold_drag_move(w.CENTER + a.lerp(b, float(k) / 8.0).rotated(w.rot))
		await process_frame
	w.fold_drag_end()
	await wait_until(func(): return not w.fold_busy(), 8.0)


func run() -> void:
	await process_frame
	main.auto_play = true
	main.think_time = 1.0
	main.hud.start_root.visible = false
	main._start_game()
	await wait_until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 90.0)
	main._on_offer(str(main.current["ideal"]))
	var w = main.wrap
	await wait_until(func(): return main.screen == "wrap" and (w.step == w.Step.CHOOSE or w.step == w.Step.PAPER), 30.0)
	if w.step == w.Step.CHOOSE:
		w._choose_card(0)
	w._select_paper(1)
	w.pull_len = clampf(w._l_min() + 70.0, w._pull_min(), w._pull_max())
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w._do_cut(w.CENTER + Vector2(-w.pull_len * 0.5 + 1.0, 0.0).rotated(w.rot))
	await create_timer(1.2).timeout
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	var fh: float = w._flap_len()
	await fold(w, Vector2(-hw - fh * 0.8, 0.0), Vector2(10.0, 0.0))
	await fold(w, Vector2(hw + fh * 0.8, 0.0), Vector2(-10.0, 0.0))
	await fold(w, Vector2(0.0, -hh - 22.0), Vector2(0.0, 10.0))
	await fold(w, Vector2(0.0, hh + 22.0), Vector2(0.0, -10.0))
	await create_timer(1.0).timeout
	w._select_tool("tape")
	var x0: float = -w.item_w * 0.4
	w._begin_stroke(w.CENTER + Vector2(x0, 0.0))
	var xx: float = x0
	while xx < w.item_w * 0.4:
		xx += 10.0
		w._move_stroke(w.CENTER + Vector2(xx, 0.0))
	w._end_stroke()
	w._select_tool("tape")
	w._select_ribbon_tool(1)
	w._ribbon_press(w.CENTER + Vector2(-w.item_w * 0.5 - 2.0, 4.0))
	w._ribbon_press(w.CENTER + Vector2(w.item_w * 0.5 + 2.0, 4.0))
	w._ribbon_press(w.CENTER + Vector2(4.0, -w.item_h * 0.5 - 2.0))
	w._ribbon_press(w.CENTER + Vector2(4.0, w.item_h * 0.5 + 2.0))
	await create_timer(1.0).timeout
	await shot("b1_wrap_bow")
	w._try_deliver()
	await wait_until(func(): return main.screen == "order" and main.order.gift_look.size() > 0, 20.0)
	await create_timer(1.0).timeout
	await shot("b2_counter_bow")
	# жалоба после смены
	await wait_until(func(): return main.customer.state == "none", 20.0)
	main.auto_play = false
	main.complaint_list = [{"who": main.Data.EVENINGS[0]["customers"][1], "item": "bear", "pay": 30, "defect": "bad"}]
	main._complaint_scene(main.epoch)
	await create_timer(4.6).timeout
	await shot("b3_complaint")
	main._click_flag = true
	await create_timer(0.9).timeout
	await shot("b4_refund")
	quit()
