extends SceneTree
## Карта захвата бумаги без окна: godot --headless --path . --script res://tools/grab_map.gd -- <box|shape> <h|v>
## Для каждой точки мата (шаг 6 px) печатает, что произойдёт при нажатии: g — бумага схвачена, . — ничего,
## U — перехватила кнопка, x — вне мата. Карты строятся для листа после реза, после левого+правого сгибов и после ещё верхнего.

var main


func _initialize() -> void:
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


func idle(w) -> void:
	await wait_until(func(): return not w.fold_busy(), 8.0)
	for i in 6:
		await process_frame


func fold_by(w, a: Vector2, b: Vector2) -> void:
	w.fold_drag_begin(w.CENTER + a.rotated(w.rot))
	for k in range(1, 7):
		w.fold_drag_move(w.CENTER + a.lerp(b, float(k) / 6.0).rotated(w.rot))
		await process_frame
	w.fold_drag_end()
	await idle(w)


## Что происходит при нажатии в точке p: символ карты и сколько пикселей поддаётся.
func probe(w, p: Vector2) -> String:
	var hit: String = w._hit_test(p)
	if hit != "":
		return "U"
	if not w.MAT_RECT.has_point(p):
		return "x"
	w.fold_drag_begin(p)
	var ok: bool = w.fold_drag
	w.fold_drag = false
	w.fold_cur = {}
	return "g" if ok else "."


func print_map(w, title: String) -> void:
	print("--- ", title, "  (sheet ", snappedf(w.sheet_len, 1.0), " x ", snappedf(w._across() + 2.0 * w.MARGIN, 1.0), ", rot=", snappedf(w.rot, 0.01), ", folds=", w.fold.fold_count(), ")")
	var step_px := 6
	var y0 := 156
	var y1 := 636
	var x0 := 290
	var x1 := 990
	# рамка листа: где он на экране (для сверки)
	var sp: PackedVector2Array = w._sheet_poly()
	var bb := Rect2(w.CENTER + sp[0].rotated(w.rot), Vector2.ZERO)
	for v in sp:
		bb = bb.expand(w.CENTER + v.rotated(w.rot))
	print("    sheet screen bbox: x ", snappedf(bb.position.x, 1.0), "..", snappedf(bb.end.x, 1.0), "  y ", snappedf(bb.position.y, 1.0), "..", snappedf(bb.end.y, 1.0))
	var y := y0
	while y <= y1:
		var line := ""
		var x := x0
		while x <= x1:
			line += probe(w, Vector2(x, y))
			x += step_px
		print("%3d %s" % [y, line])
		y += step_px


func run() -> void:
	await process_frame
	main.auto_play = true
	main.hud.start_root.visible = false
	main._start_game()
	var args := OS.get_cmdline_user_args()
	var use_box := (str(args[0]) if args.size() > 0 else "box") == "box"
	var vertical := (str(args[1]) if args.size() > 1 else "h") == "v"
	var w = main.wrap
	await wait_until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 90.0)
	main._on_offer(str(main.current["ideal"]))
	await wait_until(func(): return w.step == w.Step.CHOOSE and main.screen == "wrap", 60.0)
	await create_timer(1.0).timeout
	w._choose_card(0 if use_box else w.cards.size() - 1)
	await create_timer(0.5).timeout
	w._select_paper(1)
	if vertical:
		w._set_axis("v")
	w.pull_len = clampf(w._l_min() + 70.0, w._pull_min(), w._pull_max())
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w._do_cut(w.CENTER + Vector2(-w.pull_len * 0.5 + 1.0, 0.0).rotated(w.rot))
	await create_timer(1.5).timeout
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	var fh: float = w._flap_len()
	print("item ", w.item_w, "x", w.item_h, " axis=", w.axis, " flap=", snappedf(fh, 1.0))
	print_map(w, "fresh sheet")
	await fold_by(w, Vector2(-hw - fh * 0.8, 0.0), Vector2(10.0, 0.0))
	await fold_by(w, Vector2(hw + fh * 0.8, 0.0), Vector2(-10.0, 0.0))
	print_map(w, "left + right folded")
	await fold_by(w, Vector2(0.0, -hh - 22.0), Vector2(0.0, 10.0))
	print_map(w, "left + right + top folded")
	quit()
