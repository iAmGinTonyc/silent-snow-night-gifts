extends SceneTree
## Скриншоты экрана упаковки по шагам (в окне, не headless): godot --path . --script res://tools/shot_wrap.gd -- <сценарий>
## Сценарии: box_h, shape_h, box_v, shape_v (четыре прямых сгиба, потом откат), diag_box_h, diag_shape_h (угол по диагонали).
## Кадры падают в build/shots/. Каждый сценарий запускайте отдельным процессом: окно за другими перестаёт перерисовываться.

var main
var OUT := ProjectSettings.globalize_path("res://build/shots/")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
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


func pt(w, p: Vector2) -> Vector2:
	return w.CENTER + p.rotated(w.rot)


func idle(w) -> void:
	await wait_until(func(): return not w.fold_busy(), 8.0)
	await create_timer(0.3).timeout


## Рука берёт бумагу в a и ведёт к b (координаты бумаги); на половине пути, если задан tag, снимается кадр.
func drag(w, a: Vector2, b: Vector2, tag: String = "") -> void:
	w.fold_drag_begin(pt(w, a))
	if not w.fold_drag:
		print("not grabbed at ", a)
	for k in range(1, 9):
		w.fold_drag_move(pt(w, a.lerp(b, float(k) / 8.0)))
		await process_frame
		if tag != "" and (k == 3 or k == 5):
			await shot(tag + "_k" + str(k))
		if tag != "" and k == 4:
			await shot(tag)
			print("   mesh: particles=", w.mesh_particles, " ms/frame=", snappedf(w.mesh_ms, 0.001))
	w.fold_drag_end()
	await idle(w)


func scenario(which: String) -> void:
	var w = main.wrap
	var use_box := which.contains("box")
	var vertical := which.ends_with("_v")
	await wait_until(func(): return w.step == w.Step.CHOOSE and main.screen == "wrap", 60.0)
	await create_timer(2.0).timeout
	w._choose_card(0 if use_box else w.cards.size() - 1)
	await create_timer(0.6).timeout
	w._select_paper(1)
	if vertical:
		w._set_axis("v")
	w.pull_len = clampf(w._l_min() + 70.0, w._pull_min(), w._pull_max())
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w._do_cut(pt(w, Vector2(-w.pull_len * 0.5 + 1.0, 0.0)))
	await create_timer(1.5).timeout
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	var fh: float = w._flap_len()
	await shot(which + "_0_cut")
	if which.begins_with("diag"):
		var ys: float = hh + w.MARGIN
		var corner: Vector2 = w._sheet_poly()[0] + Vector2(16.0, 16.0)
		await drag(w, corner, Vector2(-hw * 0.2, -hh * 0.2), which + "_1_diag_partial")
		await shot(which + "_2_diag_done")
	await drag(w, Vector2(-hw - fh * 0.8, 0.0), Vector2(10.0, 0.0), which + "_3_left_partial")
	await shot(which + "_4_left")
	await drag(w, Vector2(hw + fh * 0.8, 0.0), Vector2(-10.0, 0.0))
	await shot(which + "_5_right")
	await drag(w, Vector2(0.0, -hh - 22.0), Vector2(0.0, 10.0))
	await shot(which + "_6_top")
	await drag(w, Vector2(0.0, hh + 22.0), Vector2(0.0, -10.0))
	await create_timer(1.3).timeout
	await shot(which + "_7_done")
	print(which, " folds=", w.fold.fold_count(), " cover=", w.fold.coverage(w.gift_hull), " tucked=", w.tucked)
	w.fold_undo()
	await idle(w)
	await shot(which + "_8_undo")


func run() -> void:
	await process_frame
	main.auto_play = true
	main.hud.start_root.visible = false
	main._start_game()
	await wait_until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 90.0)
	main._on_offer(str(main.current["ideal"]))
	var args := OS.get_cmdline_user_args()
	await scenario(str(args[0]) if args.size() > 0 else "box_h")
	quit()
