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


func wait_idle(w) -> void:
	var t0 := Time.get_ticks_msec()
	while w.fold_busy() and float(Time.get_ticks_msec() - t0) < 8000.0:
		await process_frame


## Один сгиб рукой: схватить бумагу в точке a и довести до b (координаты бумаги), дождаться доводки.
func fold_by(w, a: Vector2, b: Vector2) -> void:
	w.fold_drag_begin(w.CENTER + a.rotated(w.rot))
	if not w.fold_drag:
		print("   paper was not grabbed at ", a)
		failed = true
		return
	for k in range(1, 7):
		w.fold_drag_move(w.CENTER + a.lerp(b, float(k) / 6.0).rotated(w.rot))
		await process_frame
	w.fold_drag_end()
	await wait_idle(w)


## Заворачивает подарок на столе: идеально или криво.
func wrap_gift(perfect: bool, vertical: bool, skew: bool = false) -> bool:
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
	# линейка: размеры подарка и листа рисуются, замер тоже
	w._select_tool("ruler")
	w.ruler_has = true
	w.ruler_a = w.CENTER
	w.ruler_b = w.CENTER + Vector2(60.0, 40.0)
	await process_frame
	await process_frame
	w._select_tool("ruler")
	w._select_tool("scissors")
	if skew:
		# разметка линейкой и косой разрез рукой: от верхнего края листа к нижнему со сдвигом вдоль листа
		var y_edge: float = w._across() * 0.5 + w.MARGIN
		var u_cut: float = -w.pull_len * 0.5 + 40.0
		w.ruler_a = w.CENTER + Vector2(u_cut - 18.0, -y_edge).rotated(w.rot)
		w.ruler_b = w.CENTER + Vector2(u_cut + 18.0, y_edge).rotated(w.rot)
		w._set_cut_mark()
		var pa := Vector2(u_cut - 18.0, -y_edge - 4.0)
		var pb := Vector2(u_cut + 18.0, y_edge + 4.0)
		w._cut_begin(w.CENTER + pa.rotated(w.rot))
		for k in range(1, 11):
			w._cut_move(w.CENTER + pa.lerp(pb, float(k) / 10.0).rotated(w.rot))
		w._cut_end()
		if absf(w.cut_skew) < 5.0:
			print("   skewed cut did not register, skew=", w.cut_skew)
			failed = true
	else:
		w._do_cut(w.CENTER + Vector2(-w.pull_len * 0.5 + 30.0, 0.0).rotated(w.rot))
	await create_timer(0.6).timeout
	if w.step != w.Step.WRAP:
		print("   cut failed, step=", w.step)
		failed = true
	var fh: float = w._flap_len()
	var hw: float = w._along() * 0.5
	var hh: float = w._across() * 0.5
	if skew:
		# угол листа загибаем по диагонали через вещь, потом откатываем: бумага мнётся, всё возвращается
		var ys: float = hh + w.MARGIN
		var corner := Vector2(w._sheet_poly()[0].x + 14.0, -ys + 14.0)
		await fold_by(w, corner, Vector2(-hw * 0.2, -hh * 0.2))
		if w.fold.fold_count() != 1:
			print("   diagonal corner fold was not applied, folds=", w.fold.fold_count())
			failed = true
		if w._hit_test(w.UNDO_RECT.get_center()) != "undo":
			print("   undo button is not hit while a fold can be undone")
			failed = true
		w.undo_action()
		await wait_idle(w)
		if w.fold.fold_count() != 0 or w.crumples != 1:
			print("   undo failed, folds=", w.fold.fold_count(), " crumples=", w.crumples)
			failed = true
	var starts: Array = [Vector2(-hw - fh * 0.8, 0.0), Vector2(hw + fh * 0.8, 0.0), Vector2(0.0, -hh - 22.0), Vector2(0.0, hh + 22.0)]
	var ends: Array = [Vector2(10.0, 0.0), Vector2(-10.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, -10.0)]
	var count := 4 if perfect else 1
	var tops: Array = []
	for i in count:
		if perfect and not skew and i == 0 and main.customer_idx % 2 == 0:
			# касание клапана: он сам переваливается через ребро вещи
			w.fold_drag_begin(w.CENTER + (starts[0] as Vector2).rotated(w.rot))
			w.fold_drag_end()
			await wait_idle(w)
			if w.fold.fold_count() != 1:
				print("   tap did not fold the flap, folds=", w.fold.fold_count())
				failed = true
		else:
			await fold_by(w, starts[i], ends[i])
		tops.append(w.fold.top_layer())
	if w.fold.fold_count() != count + 0:
		print("   expected ", count, " folds, got ", w.fold.fold_count())
		failed = true
	if perfect and not skew and w.length_class != "short":
		# бумага всегда сверху: слои растут по порядку сгибов, а вещь закрыта целиком
		for k in range(1, tops.size()):
			if int(tops[k]) <= int(tops[k - 1]):
				print("   layer order broken: ", tops)
				failed = true
		var cov: float = w.fold.coverage(w.gift_hull)
		if cov < 0.97:
			print("   four straight folds do not cover the gift, coverage=", cov)
			failed = true
	if perfect:
		await create_timer(0.8).timeout
		var cov_now: float = w.fold.coverage(w.gift_hull)
		ok = true
		if cov_now >= 0.96:
			ok = await wait_until(func(): return w.tucked, 10.0, "tucked")
		if not ok:
			print("   folds=", w.fold.fold_count(), " cover=", w.fold.coverage(w.gift_hull), " loose=", w.fold.loose_area(w.fold_ref), " hang=", w.fold.hanging_area(w.fold_ref), " skew=", w.cut_skew, " mode=", w.wrap_mode, " axis=", w.axis)
			return false
		await create_timer(1.0).timeout
		w._select_tool("tape")
		# касание у края или шва клеит полоску скотча вдоль него
		var edges: Array = w._tape_edges()
		if not edges.is_empty() and w.active_tool == "tape":
			var longest: Array = edges[0]
			for e in edges:
				var ea: Array = e
				if (ea[0] as Vector2).distance_to(ea[1]) > (longest[0] as Vector2).distance_to(longest[1]):
					longest = ea
			var mid: Vector2 = ((longest[0] as Vector2) + (longest[1] as Vector2)) * 0.5
			var before: int = w.tape_strokes.size()
			w._begin_stroke(w.CENTER + mid)
			w._end_stroke()
			if w.tape_strokes.size() != before + 1:
				print("   tap at an edge did not place tape")
				failed = true
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
			# лента кладётся двумя щелчками: край подарка, потом противоположный край
			w._ribbon_press(w.CENTER + Vector2(-w.item_w * 0.5 - 2.0, 4.0))
			if w.ribbon_anchored:
				w.undo_action()   # кнопка отката снимает закреплённую ленту, как правая кнопка
				if w.ribbon_anchored:
					print("   undo button did not release the ribbon")
					failed = true
				w._ribbon_press(w.CENTER + Vector2(-w.item_w * 0.5 - 2.0, 4.0))
			if not w.ribbon_anchored:
				var reg: PackedVector2Array = w._stroke_region()
				var bb := Rect2(reg[0], Vector2.ZERO)
				for q in reg:
					bb = bb.expand(q)
				print("   ribbon did not anchor at the edge: region ", bb, " item ", w.item_w, "x", w.item_h, " axis=", w.axis, " skew=", w.cut_skew, " folds=", w.fold.fold_count(), " tucked=", w.tucked, " tape=", w.tape_strokes.size(), " tool=", w.active_tool, " step=", w.step)
				failed = true
			w._ribbon_press(w.CENTER + Vector2(w.item_w * 0.5 + 2.0, 4.0))
			w._ribbon_press(w.CENTER + Vector2(4.0, -w.item_h * 0.5 - 2.0))
			w._ribbon_press(w.CENTER + Vector2(4.0, w.item_h * 0.5 + 2.0))
			if not w._has_ribbon():
				print("   ribbon not drawn")
				failed = true
	await create_timer(0.8).timeout
	var nt: Dictionary = w._neatness()
	if absf(w.meter_neat - float(nt["neat"])) > 0.001:
		print("   quality meter shows ", w.meter_neat, " but the gift scores ", nt["neat"])
		failed = true
	print("   neat=%.2f cover=%.2f ends=%d" % [nt["neat"], nt["cover"], nt["ends"]])
	w._try_deliver()
	return true


var complaint_forced := false
var preorder_forced := false     # ночь 2: поезда убраны с полки, клиент оставляет задаток
var preorder_back_seen := false  # ночь 3: он вернулся первым и получил свой поезд


func run() -> void:
	await process_frame
	Engine.time_scale = 3.0
	main.auto_play = true
	main.think_time = 1.0   # мысли клиента наполняются секунду, а не двадцать   # без диалогов и экранов выбора: история и поставки проверяет tools/smoke.gd
	main._start_game()
	var served := 0
	var crooked_done := false
	while served < 30:
		var ok := await wait_until(func(): return (main.customer.state == "idle" and main.order.offer_enabled) or ((str(main.current.get("scene", "")) == "santa" or main.current.has("preorder")) and main.screen == "wrap" and main.wrap.input_enabled) or main.hud.summary_root.visible or main.hud.final_root.visible, 60.0, "next customer")
		if not ok:
			break
		if main.hud.final_root.visible:
			print("FINAL panel shown. balance=", main.econ.balance, " tips=", main.tips_total)
			break
		if main.hud.summary_root.visible:
			print("EVENING END. balance=", main.econ.balance, " ledger=", main.econ.ledger)
			if main.evening_idx == 1 and preorder_forced and int(main.econ.ledger.get("deposits", 0)) <= 0:
				print("   pre-order deposit was not taken")
				failed = true
			if main.evening_idx == 2 and preorder_forced and not preorder_back_seen:
				print("   pre-order customer did not come back")
				failed = true
			if main.evening_idx == 1 and complaint_forced and (int(main.econ.ledger.get("complaint_n", 0)) < 1 or int(main.econ.ledger.get("complaint", 0)) <= 0):
				print("   after-hours complaint was not charged")
				failed = true
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
		if main.current.has("preorder"):
			print("--- ", cname, " came back for the pre-order, place in line ", main.customer_idx)
			ok = await wrap_gift(true, false)
			await wait_until(func(): return main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible, 60.0, "pre-order served")
			preorder_back_seen = preorder_back_seen or main.evening_idx == 2
			served += 1
			continue
		if main.evening_idx == 1 and not preorder_forced and main.Data.ITEMS[str(main.current["ideal"])]["kind"] == "train":
			# нужной игрушки нет: все поезда с полки убираем, клиент должен оставить задаток
			main.stock.units["train"] = []
			main.stock.units["train_mid"] = []
			main._sync_shelf()
			preorder_forced = true
			var npo: int = main.preorders.size()
			main._on_offer(main.stock.available_ids()[0])
			await wait_until(func(): return main.customer_idx > before, 30.0, "pre-order customer leaves")
			if main.preorders.size() != npo + 1:
				print("   no pre-order was taken")
				failed = true
			print("--- ", cname, " left a pre-order deposit: ", main.preorders)
			served += 1
			continue
		var ideal: String = main.current["ideal"]
		var guessed := served % 3 != 1
		print("--- ", cname, " ideal=", ideal, " guess=", guessed)
		if served % 4 == 3 and str(main.current.get("scene", "")) != "santa":
			await wait_until(func(): return main.patience_on, 30.0, "thoughts spoken")   # путь «клиент сам сказал мысли»
		var pick: String = ideal
		if not main.stock.infinite:
			# после ночи 1 на полке только то, что заказали: берём игрушку нужного вида, иначе любую
			var avail: Array = main.stock.available_ids()
			var same := ""
			for id in avail:
				if main.Data.ITEMS[id]["kind"] == main.Data.ITEMS[ideal]["kind"]:
					same = id
			if same != "":
				pick = same
			elif avail.size() > 0:
				pick = avail[0]
		if not guessed:
			pick = "bear" if ideal != "bear" else "ornament"
			if not main.stock.infinite and not main.stock.available_ids().has(pick):
				pick = main.stock.available_ids()[0] if main.stock.available_ids().size() > 0 else pick
		if str(main.current.get("scene", "")) != "santa":
			var npo2: int = main.preorders.size()
			main._on_offer(pick)
			await process_frame
			if main.preorders.size() > npo2:
				print("--- ", cname, " left a pre-order deposit too")
				await wait_until(func(): return main.customer_idx > before, 30.0, "pre-order customer leaves")
				served += 1
				continue
			if main.evening_idx == 1 and not complaint_forced:
				# проданный брак: после смены клиент вернётся ругаться, деньги уйдут из копилки
				main.current_bad = "bad"
				complaint_forced = true
		var perfect := crooked_done or served != 2
		crooked_done = crooked_done or not perfect
		var attempts := 0
		while true:
			attempts += 1
			ok = await wrap_gift(perfect or attempts > 1, served % 2 == 1, served % 4 == 3 and (perfect or attempts > 1))
			if not ok:
				break
			served += 0
			var r := await wait_until(func(): return main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible or (main.screen == "wrap" and (main.wrap.step == main.wrap.Step.CHOOSE or main.wrap.step == main.wrap.Step.PAPER)), 60.0, "served or redo")
			if not r or main.customer_idx > before or main.hud.summary_root.visible or main.hud.final_root.visible:
				break
			print("   клиент просит переделать, попытка ", attempts + 1)
		served += 1
		print("   balance=", main.econ.balance, " tips_total=", main.tips_total, " stock=", main._stock_counts())
	print("DONE served=", served, " failed=", failed)
	quit()
