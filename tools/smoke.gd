extends SceneTree
## Дымовой тест без окна: godot --headless --path . --script res://tools/smoke.gd
## Проходит клиентов подряд и печатает состояние. Ошибки скриптов и рисования попадают в вывод.

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


func run() -> void:
	await process_frame
	Engine.time_scale = 3.0
	main._start_game()
	var served := 0
	while served < 20:
		# конец вечера: если открыта панель итогов, идём дальше; на финале выходим
		var ok := await wait_until(func(): return (main.customer.state == "idle" and main.order.accept_enabled) or main.hud.summary_root.visible or main.hud.final_root.visible, 60.0, "next customer")
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
			print("shop items: ", items.size())
			if items.size() > 0:
				main._on_buy(0)
				main._on_buy(items.size() - 1)
			main.hud.shop_root.visible = false
			main._on_next_evening()
			continue
		var cname: String = main.current["name"]
		var item_id: String = main.current["item"]
		var wrap_pref: String = main.current["wrap"]
		print("--- ", cname, " item=", item_id, " wants wrap=", wrap_pref)
		main._on_accept()
		ok = await wait_until(func(): return main.wrap.step == main.wrap.Step.CHOOSE or main.wrap.step == main.wrap.Step.PAPER, 30.0, "wrap ready")
		if not ok:
			break
		var w = main.wrap
		if w.step == w.Step.CHOOSE:
			var idx := 0
			if wrap_pref == "shape":
				idx = w.cards.size() - 1
			w._choose_card(idx)
			print("   chose: ", w.wrap_mode, " box_idx=", w.box_idx)
		var paper_slot := 0
		if main.current["paper"] != "any":
			for s in w.inv_papers.size():
				var pp: Dictionary = main.Data.PAPERS[int(w.inv_papers[s])]
				if pp["tag"] == main.current["paper"]:
					paper_slot = s
		w._select_paper(paper_slot)
		w.sheet_len = w._l_min() + 40.0
		w._finish_cut()
		for side in [0, 1]:
			w.flap_drag = side
			w.theta[side] = 0.0
			w._end_flap_drag()
		ok = await wait_until(func(): return w.step == w.Step.TAPE, 10.0, "tuck")
		if not ok:
			break
		await create_timer(1.2).timeout
		w._try_tape(w.CENTER + Vector2(w.seam_x, 0.0))
		if w.step != w.Step.DONE:
			print("   tape failed, step=", w.step)
			failed = true
		if main.current["ribbon"] != "none":
			w._select_ribbon(0)
		await create_timer(0.8).timeout
		var before: int = main.customer_idx
		w._try_deliver()
		served += 1
		await wait_until(func(): return main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible, 40.0, "customer served")
		print("   balance=", main.econ.balance, " tips_total=", main.tips_total)
	print("DONE served=", served, " failed=", failed)
	quit()
