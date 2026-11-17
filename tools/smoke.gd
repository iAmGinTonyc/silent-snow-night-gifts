extends SceneTree
## Дымовой тест без окна: godot --headless --path . --script res://tools/smoke.gd
## Проходит всех клиентов подряд (покупатели и обычные), один раз заворачивает криво и печатает состояние.
## Ошибки скриптов и рисования попадают в вывод.

var main
var failed := false


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	run()


func wait_until(cond: Callable, timeout_s: float, label: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			print("TIMEOUT: ", label)
			failed = true
			return false
	return true


## Заворачивает подарок на столе: идеально или криво.
func wrap_gift(perfect: bool, vertical: bool) -> bool:
	var w = main.wrap
	var ok := await wait_until(func(): return w.step == w.Step.CHOOSE or w.step == w.Step.PAPER, 30.0, "wrap ready")
	if not ok:
		return false
	if w.step == w.Step.CHOOSE:
		var idx := 0
		if main.current.get("wrap", "free") == "shape":
			idx = w.cards.size() - 1
		w._choose_card(idx)
		print("   chose: ", w.wrap_mode, " box_idx=", w.box_idx)
	var paper_slot := 0
	var want: String = main.current.get("paper", "any")
	if want != "any":
		for s in w.inv_papers.size():
			var pp: Dictionary = main.Data.PAPERS[int(w.inv_papers[s])]
			if pp["tag"] == want:
				paper_slot = s
	w._select_paper(paper_slot)
	if vertical:
		w._set_axis("v")
	var along: float = w._along()
	w.pull_len = clampf((w._l_min() + 60.0) if perfect else (along + 40.0), w._pull_min(), w._pull_max())
	w.sheet_len = w.pull_len
	w.pull_moved = true
	w._finish_pull()
	w._select_tool("scissors")
	w._do_cut(w.CENTER + Vector2(-w.pull_len * 0.5 + 30.0, 0.0).rotated(w.rot))
	await create_timer(0.6).timeout
	if w.step != w.Step.WRAP:
		print("   cut failed, step=", w.step)
		failed = true
	var fh: float = w._flap_len()
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	var starts: Array = [Vector2(-hw - fh * 0.8, 0.0), Vector2(hw + fh * 0.8, 0.0), Vector2(0.0, -hh - 22.0), Vector2(0.0, hh + 22.0)]
	var ends: Array = [Vector2(10.0, 0.0), Vector2(-10.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, -10.0)]
	var count := 4 if perfect else 1
	for i in count:
		var a: Vector2 = starts[i]
		var b: Vector2 = ends[i]
		w._begin_flap_drag(w.CENTER + a.rotated(w.rot))
		w._update_flap_drag(w.CENTER + b.rotated(w.rot))
		if w.flap_drag < 0:
			print("   flap ", i, " was not picked")
			failed = true
		w._end_flap_drag()
	if perfect:
		ok = await wait_until(func(): return w.tucked, 10.0, "tucked")
		if not ok:
			return false
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
		if w.active_tool != "":
			print("   tool not released")
			failed = true
		if main.current.get("ribbon", "any") != "none":
			w._select_ribbon_tool(0)
			w._begin_stroke(w.CENTER + Vector2(-w.item_w * 0.45, 4.0))
			xx = -w.item_w * 0.45
			while xx < w.item_w * 0.45:
				xx += 10.0
				w._move_stroke(w.CENTER + Vector2(xx, 4.0))
			w._end_stroke()
			w._begin_stroke(w.CENTER + Vector2(4.0, -w.item_h * 0.45))
			var yy: float = -w.item_h * 0.45
			while yy < w.item_h * 0.45:
				yy += 10.0
				w._move_stroke(w.CENTER + Vector2(4.0, yy))
			w._end_stroke()
			if not w._has_ribbon():
				print("   ribbon not drawn")
				failed = true
	await create_timer(0.8).timeout
	var nt: Dictionary = w._neatness()
	print("   neat=%.2f cover=%.2f ends=%d" % [nt["neat"], nt["cover"], nt["ends"]])
	w._try_deliver()
	return true


func run() -> void:
	await process_frame
	Engine.time_scale = 3.0
	main._start_game()
	var served := 0
	var crooked_done := false
	while served < 30:
		var ok := await wait_until(func(): return (main.customer.state == "idle" and main.order.offer_enabled) or main.hud.summary_root.visible or main.hud.final_root.visible, 60.0, "next customer")
		if not ok:
			break
		if main.hud.final_root.visible:
			print("FINAL panel shown. balance=", main.econ.balance, " tips=", main.tips_total)
			break
		if main.hud.summary_root.visible:
			print("EVENING END. balance=", main.econ.balance, " ledger=", main.econ.ledger)
			main.hud.summary_root.visible = false
			main._on_shop_open()
			var items: Array = main.shop_list
			if items.size() > 0:
				main._on_buy(0)
				main._on_buy(items.size() - 1)
			main.hud.shop_root.visible = false
			main._on_next_evening()
			continue
		var cname: String = main.current["name"]
		var before: int = main.customer_idx
		var ideal: String = main.current["ideal"]
		var guessed := served % 3 != 1
		print("--- ", cname, " ideal=", ideal, " guess=", guessed)
		var pick := ideal
		if not guessed:
			pick = "bear" if ideal != "bear" else "ornament"
		main._on_offer(pick)
		var perfect := crooked_done or served != 2
		crooked_done = crooked_done or not perfect
		var attempts := 0
		while true:
			attempts += 1
			ok = await wrap_gift(perfect or attempts > 1, served % 2 == 1)
			if not ok:
				break
			served += 0
			var r := await wait_until(func(): return main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible or (main.screen == "wrap" and (main.wrap.step == main.wrap.Step.CHOOSE or main.wrap.step == main.wrap.Step.PAPER)), 60.0, "served or redo")
			if not r or main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible:
				break
			print("   клиент просит переделать, попытка ", attempts + 1)
		served += 1
		print("   balance=", main.econ.balance, " tips_total=", main.tips_total)
	print("DONE served=", served, " failed=", failed)
	quit()
