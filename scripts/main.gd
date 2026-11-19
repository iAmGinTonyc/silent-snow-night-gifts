extends Node2D
## Поток игры: два экрана (заказ и упаковка), терпение клиента, деньги и лавка, вечера и финал.

const Data = preload("res://scripts/data.gd")
const UTIL = preload("res://scripts/util.gd")
const SceneBg = preload("res://scripts/scene_bg.gd")
const CustomerView = preload("res://scripts/customer_view.gd")
const OrderCounter = preload("res://scripts/order_counter.gd")
const WrapScreen = preload("res://scripts/wrap_screen.gd")
const Hud = preload("res://scripts/hud.gd")
const StatusBar = preload("res://scripts/status_bar.gd")
const Fx = preload("res://scripts/fx.gd")
const Economy = preload("res://scripts/economy.gd")
const HandCursor = preload("res://scripts/hand_cursor.gd")
const Stock = preload("res://scripts/stock.gd")
const Story = preload("res://scripts/story.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const ReorderScreen = preload("res://scripts/reorder_screen.gd")
const InspectScreen = preload("res://scripts/inspect_screen.gd")

## Упаковка и оплата: кривее REWRAP_BELOW клиент сразу просит переупаковать; плата = цена × (PAY_BASE + PAY_NEAT × аккуратность).
const REWRAP_BELOW := 0.5
const PAY_BASE := 0.7
const PAY_NEAT := 0.5
const DEPOSIT_SHARE := 0.3   # задаток за предзаказ: доля цены игрушки

var econ
var stock
var dialogue
var reorder
var inspect
var auto_play := false      # автотест: без диалогов и экранов выбора, заказ и приёмка идут сами
var current_bad := ""       # скрытый брак у игрушки, которую выбрал клиент: "", "bad" или "sub"
var think_time := 20.0      # сколько секунд мысли клиента наполняются «водой», потом он говорит их вслух
var thinking := false
var think_t := 0.0
var read_in_time := false   # подарок предложен до конца таймера мыслей: дополнительные чаевые
var offer_made := false
var complaints_today := 0   # сколько с нас снимут вечером за проданный брак
var complaint_count := 0
var complaint_list: Array = []   # кому продали брак этой ночью: {who, item, pay, defect}; придут ругаться после смены
var complaint_mode := false      # идёт сценка жалоб после смены: обычный приход клиента не запускается
var preorders: Array = []        # {who, kind, item, deposit, night}: клиент вернётся в ночь night за заказанной игрушкой
var night_queue: Array = []      # клиенты этой ночи: сначала вернувшиеся за предзаказом, потом обычные
var free_gift := false           # этот клиент попросил подарок бесплатно, и мы согласились
var tint
var order_root
var wrap_root
var bg
var light
var customer
var order
var wrap
var hud
var status
var fx

var evening_idx := 0
var customer_idx := 0
var current: Dictionary = {}
var epoch := 0
var redo_count := 0
var current_match := ""     # угадали ли мысли клиента: perfect или miss (тогда выбрал сам)
var chosen_item := ""
var patience_paused := false
var screen := "order"
var patience_max := 150.0
var patience := 0.0
var patience_on := false
var tips_total := 0
var shop_list: Array = []


func _ready() -> void:
	randomize()
	econ = Economy.new()
	tint = CanvasModulate.new()
	tint.color = Color(1.0, 0.985, 0.95)
	add_child(tint)

	order_root = Node2D.new()
	add_child(order_root)
	bg = SceneBg.new()
	bg.mode = "back"
	order_root.add_child(bg)
	customer = CustomerView.new()
	customer.scale = Vector2(1.6, 1.6)
	order_root.add_child(customer)
	order = OrderCounter.new()
	order_root.add_child(order)
	light = SceneBg.new()
	light.mode = "front"
	order_root.add_child(light)

	wrap_root = Node2D.new()
	wrap_root.visible = false
	add_child(wrap_root)
	# стол для упаковки с запасом по краям: лежит под экраном упаковки, в рамке 1280x720 совпадает с ним
	var wrap_ext: Texture2D = UTIL.tex_or("res://art/wrap/wrap_back_ext.jpg", null)
	if wrap_ext:
		var sp := Sprite2D.new()
		sp.texture = wrap_ext
		sp.centered = false
		sp.position = UTIL.EXT.position
		sp.scale = UTIL.EXT.size / wrap_ext.get_size()
		wrap_root.add_child(sp)
	wrap = WrapScreen.new()
	wrap_root.add_child(wrap)
	var wrap_light := SceneBg.new()
	wrap_light.mode = "vignette"
	wrap_root.add_child(wrap_light)

	hud = Hud.new()
	add_child(hud)
	status = StatusBar.new()
	hud.add_child(status)
	status.visible = false   # на экране заказа деньги и терпение показывают вывески сверху
	fx = Fx.new()
	add_child(fx)
	stock = Stock.new()
	dialogue = Dialogue.new()
	add_child(dialogue)
	reorder = ReorderScreen.new()
	add_child(reorder)
	inspect = InspectScreen.new()
	add_child(inspect)
	var cursor := HandCursor.new()
	cursor.main = self
	add_child(cursor)

	order.input_enabled = false
	wrap.input_enabled = false
	wrap.hint_changed.connect(hud.set_hint)
	wrap.toast.connect(hud.show_toast)
	wrap.cost.connect(_on_cost)
	wrap.gift_ready.connect(_on_gift_ready)
	customer.arrived.connect(_on_customer_arrived)
	order.offer_pressed.connect(_on_offer)
	order.shelf_toggled.connect(func(open: bool): hud.set_hint("Click a gift to offer it (Esc goes back)" if open else "Click the shelf on the right to pick a gift"))
	hud.start_pressed.connect(_start_game)
	hud.next_pressed.connect(_on_next_evening)
	hud.shop_pressed.connect(_on_shop_open)
	hud.shop_back_pressed.connect(hud.back_to_summary)
	hud.buy_pressed.connect(_on_buy)
	hud.restart_pressed.connect(_restart)

	_apply_inventory()
	status.set_money(econ.balance, false)
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()
	var ev: Dictionary = Data.EVENINGS[0]
	bg.sky_color = Color.html(ev["sky"])
	bg.sky_target = bg.sky_color
	var clock: Array = ev["clock"]
	bg.set_clock_instant(float(clock[0]))
	# замер упаковки в браузере: index.html?bench=wrap (см. scripts/web_bench.gd)
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).contains("bench=wrap"):
		var bench: Node = load("res://scripts/web_bench.gd").new()
		add_child(bench)
		bench.run(self)


var _click_flag := false


## Экран шире или выше 16:9 (растяжение expand): рамка 1280x720 встаёт по центру, все слои сдвигаются вместе с ней,
## а расширенные фоны заполняют края. Ввод везде считается через get_global_mouse_position, поэтому сдвиг ему не мешает.
func _fit_screen() -> void:
	var vis := get_viewport().get_visible_rect().size
	var off := ((vis - UTIL.BASE) * 0.5).round()
	get_viewport().canvas_transform = Transform2D(0.0, off)
	for ch in get_children():
		if ch is CanvasLayer:
			(ch as CanvasLayer).offset = off


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_flag = true


## Ждём указанное время, но клик пропускает ожидание (чтобы не томить на длинных репликах).
func _wait_or_click(seconds: float) -> void:
	_click_flag = false
	var t := 0.0
	while t < seconds and not _click_flag:
		await get_tree().process_frame
		t += get_process_delta_time()


func _sync_counter() -> void:
	var ev: Dictionary = Data.EVENINGS[evening_idx]
	var date_parts: PackedStringArray = str(ev["date"]).split(" ")
	var clist: Array = night_queue if not night_queue.is_empty() else ev["customers"]
	order.set_info({
		"night": evening_idx + 1,
		"nights": Data.EVENINGS.size(),
		"clock": bg.clock_minutes,
		"date_short": "%s %s" % [date_parts[0], date_parts[1].substr(0, 3)],
		"day": date_parts[0],
		"month": date_parts[1].substr(0, 3).to_upper(),
		"customer": mini(customer_idx + 1, clist.size()),
		"customers": clist.size(),
		"patience": (patience / patience_max) if patience_on else -1.0,
		"secs": patience,
		"cash": econ.balance,
		"earned": int(econ.ledger["revenue"]) + int(econ.ledger["tips"]),
		"spent": econ.expenses(),
		"days": Data.DAYS_TO_NEW_YEAR - evening_idx,
	})


func _process(delta: float) -> void:
	_sync_counter()
	var mp: Vector2 = customer.mouth_point()
	order.mouth = mp if mp.is_finite() else OrderCounter.MOUTH
	if thinking and not patience_paused:
		think_t += delta
		order.set_thought_fill(think_t / think_time)
		if think_t >= think_time:
			thinking = false
			_on_thoughts_spoken()
	if not patience_on or patience_paused:
		return
	patience -= delta
	status.set_patience(patience / patience_max, patience)
	customer.set_worry(patience / patience_max)
	if patience <= 0.0:
		patience_on = false
		_on_timeout()


func _apply_inventory() -> void:
	wrap.set_inventory(econ.owned_indices("paper"), econ.owned_indices("ribbon"), econ.owned_indices("box"))


func _on_cost(category: String, amount: int) -> void:
	econ.spend(category, amount)
	status.set_money(econ.balance)


func _show_screen(which: String) -> void:
	order_root.visible = (which == "order")
	wrap_root.visible = (which == "wrap")
	screen = which
	status.visible = (which == "wrap")   # на экране заказа деньги и терпение показывают вывески сверху
	# подсказка: на экране заказа слева сверху (внизу плашки прилавка), на столе внизу
	# на телефоне подсказка крупнее и в две строки: экран там примерно вдвое меньше
	var touch := DisplayServer.is_touchscreen_available()
	hud.hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if touch else TextServer.AUTOWRAP_OFF
	hud.hint_label.add_theme_font_size_override("font_size", 23 if touch else 17)
	hud.hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if (touch and which != "order") else VERTICAL_ALIGNMENT_TOP
	if which == "order":
		hud.hint_label.position = Vector2(30, 90)
		hud.hint_label.size = Vector2(600, 64) if touch else Vector2(560, 26)
	elif touch:
		hud.hint_label.position = Vector2(150, 646)
		hud.hint_label.size = Vector2(980, 70)
	else:
		hud.hint_label.position = Vector2(262, 684)
		hud.hint_label.size = Vector2(760, 26)
	hud.hint_label.add_theme_constant_override("outline_size", 6)
	hud.hint_label.add_theme_color_override("font_outline_color", Color(0.165, 0.102, 0.078))


func _switch_to(which: String) -> void:
	var prev := patience_paused
	patience_paused = true
	AudioSynth.play_sfx("whoosh")
	await fx.iris_out(0.36)
	_show_screen(which)
	await fx.iris_in(0.36)
	patience_paused = prev


# --- Вечер и клиенты --------------------------------------------------------------

func _start_game() -> void:
	AudioSynth.start_music()
	econ.reset()
	stock.reset()
	_sync_shelf()
	_apply_inventory()
	status.set_money(econ.balance, false)
	tips_total = 0
	_begin_evening()


func _begin_evening() -> void:
	var e := epoch
	var ev: Dictionary = Data.EVENINGS[evening_idx]
	_show_screen("order")
	wrap.set_night(evening_idx)   # подробное обучение упаковки в первые ночи
	econ.new_evening()
	bg.set_sky(Color.html(ev["sky"]))
	var clock: Array = ev["clock"]
	bg.set_clock_instant(float(clock[0]))
	patience_max = float(ev["patience"])
	customer_idx = 0
	redo_count = 0
	night_queue = []
	for po in preorders:
		if int(po["night"]) == evening_idx:
			var back: Dictionary = (po["who"] as Dictionary).duplicate()
			back["preorder"] = po
			night_queue.append(back)
	preorders = preorders.filter(func(po): return int(po["night"]) != evening_idx)
	night_queue.append_array(ev["customers"])
	order.reset()
	order.input_enabled = false
	status.show_patience(false)
	hud.show_title("Night %d of %d" % [evening_idx + 1, Data.EVENINGS.size()], str(ev["date"]) + " · " + str(ev["place"]))
	await get_tree().create_timer(2.4).timeout
	if e != epoch:
		return
	if evening_idx == 0:
		if not auto_play:
			await dialogue.play(Story.INTRO)
	else:
		await _receive_deliveries(e)
	if e != epoch:
		return
	_next_customer()


func _next_customer() -> void:
	var ev: Dictionary = Data.EVENINGS[evening_idx]
	var list: Array = night_queue
	if customer_idx >= list.size():
		_end_evening()
		return
	current = list[customer_idx]
	redo_count = 0
	free_gift = false
	var clock: Array = ev["clock"]
	var frac := float(customer_idx) / float(maxi(list.size() - 1, 1))
	bg.set_clock(lerpf(float(clock[0]), float(clock[1]), frac))
	order.input_enabled = false
	AudioSynth.play_sfx("door")
	customer.arrive(current)


func _on_customer_arrived() -> void:
	if complaint_mode:
		return
	var e := epoch
	current_match = ""
	chosen_item = ""
	current_bad = ""
	# Лор по ходу диалогов: короткие приветствия до мыслей клиента (первый гость рассказывает, что лавка появилась из ниоткуда).
	if not auto_play:
		var hello: Array = Story.HELLO.get(str(current["name"]), [])
		for line in hello:
			order.show_bubble(current["name"], str(line))
			await _wait_or_click(1.0 + float(str(line).length()) * 0.05)
			if e != epoch:
				return
	if str(current.get("scene", "")) == "santa":
		await _santa_scene(e)
		return
	if current.has("preorder"):
		await _preorder_return(e)
		return
	# Клиент всегда приходит с пустыми руками: мы читаем его мысли и предлагаем подарок с полки.
	order.show_thought(current["name"], current["thought"])
	hud.set_hint("Click the shelf on the right to pick a gift")
	order.input_enabled = true
	order.set_offer(true)
	offer_made = false
	read_in_time = false
	thinking = true
	think_t = 0.0
	order.set_thought_fill(0.0)
	# отсчёт обслуживания начнётся, когда клиент выскажет мысли вслух или когда мы предложим подарок
	patience_on = false
	status.show_patience(false)


## Время мыслей вышло: клиент сам говорит их вслух (неразборчивым голосом по возрасту и полу), потом идёт отсчёт обслуживания.
func _on_thoughts_spoken() -> void:
	var e := epoch
	order.set_thought_fill(0.0)
	var text := str(current["thought"])
	order.show_bubble(current["name"], text)
	var secs: float = AudioSynth.babble_seconds(text.length())
	if auto_play:
		secs = 0.2
	else:
		AudioSynth.babble(str(Story.VOICES.get(str(current["name"]), "woman")), secs)
		customer.talk_for(secs)
	await get_tree().create_timer(secs + (0.2 if auto_play else 0.5)).timeout
	if e != epoch or offer_made:
		return
	_start_service_timer()


func _start_service_timer() -> void:
	patience = patience_max
	patience_on = true
	status.show_patience(true)
	status.set_patience(1.0, patience_max)


## Предлагаем подарок с полки. Угадали мысли: клиент радуется и охотнее даёт чаевые.
## Не угадали: клиент сам выбирает то, что ему нужно.
func _on_offer(offered: String) -> void:
	var e := epoch
	var ideal: String = current["ideal"]
	var ideal_kind: String = Data.ITEMS[ideal]["kind"]
	var guessed: bool = Data.ITEMS[offered]["kind"] == ideal_kind   # любой уровень игрушки нужного вида подходит
	order.set_offer(false)
	order.input_enabled = false
	patience_paused = true
	hud.set_hint("")
	offer_made = true
	read_in_time = thinking          # успели предложить, пока мысли ещё наполнялись
	thinking = false
	order.set_thought_fill(0.0)
	AudioSynth.stop_babble()
	customer.talk_for(0.0)
	if not patience_on:
		_start_service_timer()
		patience_paused = true
	current_match = "perfect" if guessed else "miss"
	if guessed:
		chosen_item = offered
	elif stock.infinite:
		chosen_item = ideal
	elif not stock.has_kind(ideal_kind):
		# нужной игрушки нет: клиент оставляет задаток и вернётся за ней следующей ночью
		await _take_preorder(e, ideal)
		return
	else:
		chosen_item = stock.pick_for_kind(ideal_kind)   # клиент выбирает сам: нужный вид
	if not guessed:
		order.show_bubble(current["name"], str(Data.BUYER_LINES["miss"]))
		AudioSynth.play_sfx("dull")
		await get_tree().create_timer(2.2).timeout
		if e != epoch:
			return
	if chosen_item == "":
		customer.set_mood(0)
		order.show_bubble(current["name"], "Oh... the shelf is empty. Maybe next time.")
		await get_tree().create_timer(2.8).timeout
		if e != epoch:
			return
		status.show_patience(false)
		patience_on = false
		patience_paused = false
		await _customer_leaves(e)
		return
	current_bad = stock.take(chosen_item)
	_sync_shelf()
	order.give_item(chosen_item)
	if guessed:
		customer.set_mood(2)
		order.show_bubble(current["name"], str(Data.BUYER_LINES["perfect"]))
	else:
		order.show_bubble(current["name"], str(Data.BUYER_LINES["choose"]))
	await order.item_given
	if e != epoch:
		return
	await get_tree().create_timer(1.6).timeout
	if e != epoch:
		return
	# раз за ночь кто-то просит подарок бесплатно: решаем, дарить или нет
	if current.has("ask_free"):
		if not await _ask_free(e):
			return
	await _serve_item(e)


## Игрушка на столе: клиент говорит, как упаковать, мы нажимаем на подарок и идём упаковывать.
func _serve_item(e: int) -> void:
	# после выбора подарка клиент говорит, как его упаковать (то же стоит в талоне на столе)
	var pack := str(current.get("pack", ""))
	if pack != "":
		order.show_bubble(current["name"], pack)
		await get_tree().create_timer(2.6).timeout
		if e != epoch:
			return
	order.hide_bubble()
	# подарок просто лежит на столе: упаковка начинается, когда мы на него нажмём
	if not auto_play:
		hud.set_hint("Click the gift to start wrapping")
		order.input_enabled = true
		order.set_gift_clickable(true)
		await order.gift_clicked
		if e != epoch:
			return
		hud.set_hint("")
		order.input_enabled = false
	order.take_item()
	await _switch_to("wrap")
	if e != epoch:
		return
	wrap.set_ticket(current["name"], Data.ticket_lines(current, chosen_item))
	wrap.place_item(chosen_item)
	wrap.input_enabled = true
	patience_paused = false


func _on_timeout() -> void:
	var e := epoch
	wrap.input_enabled = false
	order.set_offer(false)
	status.show_patience(false)
	hud.show_toast("The customer got tired of waiting and left")
	if screen != "order":
		await _switch_to("order")
		if e != epoch:
			return
	wrap.clear_gift()
	customer.set_mood(0)
	order.show_bubble(current["name"], "Sorry, I cannot wait this long...")
	await get_tree().create_timer(2.6).timeout
	if e != epoch:
		return
	await _customer_leaves(e)


func _customer_leaves(e: int) -> void:
	order.hide_bubble()
	customer.leave()
	await customer.left
	if e != epoch:
		return
	customer_idx += 1
	await get_tree().create_timer(0.5).timeout
	if e != epoch:
		return
	_next_customer()


## Подарок готов: возвращаемся к клиенту. Кривой подарок клиент может вернуть или не оплатить.
func _on_gift_ready(res: Dictionary) -> void:
	var e := epoch
	patience_on = false
	wrap.input_enabled = false
	var frac := clampf(patience / patience_max, 0.0, 1.0)
	status.show_patience(false)
	await _switch_to("order")
	if e != epoch:
		return
	wrap.clear_gift()
	order.show_gift(res["look"])
	await get_tree().create_timer(0.7).timeout
	if e != epoch:
		return
	var item_id: String = res["look"]["item_id"]
	var neat: float = res["neat"]

	# кривой подарок клиент сразу просит переупаковать (кроме Санты и тех, кто дарит подарок нам);
	# переупаковать можно один раз: вторая кривая упаковка — клиент уходит недовольный, не заплатив
	var outcome := "pay"
	if neat < REWRAP_BELOW and str(current.get("scene", "")) == "" and not current.get("free", false):
		outcome = "redo" if redo_count < 1 else "refuse"
	if outcome == "redo":
		redo_count += 1
		customer.set_mood(0)
		order.show_bubble(current["name"], "That came out crooked. Please wrap it again.")
		await get_tree().create_timer(2.4).timeout
		if e != epoch:
			return
		order.hide_bubble()
		order.clear_gift()
		await _switch_to("wrap")
		if e != epoch:
			return
		wrap.place_item(item_id)
		wrap.input_enabled = true
		patience = minf(patience + 25.0, patience_max)
		patience_on = true
		status.show_patience(true)
		status.set_patience(patience / patience_max, patience)
		return
	if outcome == "refuse":
		customer.set_mood(0)
		customer.face_override = customer.ANGRY_FACE
		order.show_bubble(current["name"], "Still crooked. Keep it, I am leaving.")
		await get_tree().create_timer(0.3 if auto_play else 2.8).timeout
		if e != epoch:
			return
		order.clear_gift()
		stock.put_back(item_id, current_bad)   # игрушку не забрали: возвращается на полку
		current_bad = ""
		_sync_shelf()
		await _customer_leaves(e)
		return

	var it: Dictionary = Data.ITEMS[item_id]
	# чем аккуратнее упаковка, тем больше платят; за предзаказ задаток уже у нас
	var pay: int = roundi(float(it.get("sell", it["price"])) * (PAY_BASE + PAY_NEAT * clampf(neat, 0.0, 1.0)))
	if current.has("preorder"):
		pay = maxi(pay - int(current["preorder"]["deposit"]), 0)
	if free_gift:
		pay = 0
	if pay > 0:
		econ.earn(pay)
		status.set_money(econ.balance)
		order.pay_pop(pay)
	if not free_gift and str(current.get("scene", "")) == "":
		hud.show_toast("Wrap quality %d%%: paid %d" % [roundi(neat * 100.0), pay])
	# проданный брак: клиент придёт жаловаться уже после смены, вечером с нас снимут эти деньги
	if current_bad != "" and pay > 0:
		complaints_today += pay
		complaint_count += 1
		complaint_list.append({"who": current, "item": item_id, "pay": pay, "defect": current_bad})

	var s := _evaluate(current, res)
	if neat < 0.4:
		s -= 0.30
	elif neat < 0.7:
		s -= 0.15
	s = clampf(s, 0.0, 1.0)
	var tips := 1
	var mood := 0
	var line: String = current["meh"]
	if s >= 0.75:
		tips = 3
		mood = 2
		line = current["good"]
	elif s >= 0.5:
		tips = 2
		mood = 1
		line = current["ok"]
	if frac < 0.25:
		tips = maxi(tips - 1, 1)
	var chance := 0.8
	if current_match == "perfect":
		tips = maxi(tips, 2)
		chance = 1.0
	if randf() > chance:
		tips = 0
	if neat < 0.4:
		tips = 0
	# мысли прочитаны вовремя, подарок и упаковка понравились: дополнительные чаевые
	if read_in_time and current_match == "perfect" and s >= 0.5 and neat >= 0.4:
		var bonus := 3 if s >= 0.75 else 2
		tips += bonus
		hud.show_toast("Mind read in time! Bonus tip +%d" % bonus)
	if tips == 0:
		line = current["meh"]
		mood = mini(mood, 1)
	if free_gift:
		tips = 0
		mood = 2
		line = str(Story.FREE_THANKS[randi() % Story.FREE_THANKS.size()])
	customer.set_mood(mood)
	if str(current.get("scene", "")) == "santa":
		if not auto_play:
			await dialogue.play(Story.SANTA_BYE, _santa_face)
		customer.face_override = -1
		order.clear_gift()
		await _customer_leaves(e)
		return
	order.show_bubble(current["name"], line)
	if tips > 0:
		order.add_tip_coins(tips)
		econ.add_tip(tips)
		tips_total += tips
	await get_tree().create_timer(2.9).timeout
	if e != epoch:
		return
	if current.get("free", false):
		order.keep_gift()   # этот подарок подарили нам: он остаётся на прилавке
	else:
		order.clear_gift()
	await _customer_leaves(e)


## Нужной игрушки нет на полке: клиент оставляет задаток и вернётся за ней в следующую ночь.
## В последнюю ночь возвращаться некогда: клиент уходит ни с чем.
func _take_preorder(e: int, ideal: String) -> void:
	var toy := str(Data.ITEMS[ideal]["name"]).to_lower()
	var kind := str(Data.ITEMS[ideal]["kind"])
	status.show_patience(false)
	patience_on = false
	patience_paused = false
	if evening_idx >= Data.EVENINGS.size() - 1:
		customer.set_mood(0)
		order.show_bubble(current["name"], "No %s on your shelf? Oh... then nothing tonight." % toy)
		await get_tree().create_timer(0.3 if auto_play else 2.8).timeout
		if e != epoch:
			return
		await _customer_leaves(e)
		return
	var deposit := maxi(roundi(float(Data.ITEMS[ideal].get("sell", Data.ITEMS[ideal]["price"])) * DEPOSIT_SHARE), 1)
	customer.set_mood(1)
	order.show_bubble(current["name"], "No %s on your shelf? Could you order one for me? Here is a deposit of %d. I will come back tomorrow night." % [toy, deposit])
	econ.earn_deposit(deposit)
	status.set_money(econ.balance)
	order.pay_pop(deposit)
	preorders.append({"who": current, "kind": kind, "item": ideal, "deposit": deposit, "night": evening_idx + 1})
	hud.show_toast("Pre-order: %s, %s tomorrow night. Order it from a supplier that delivers in 1 night." % [str(current["name"]), toy])
	await get_tree().create_timer(0.3 if auto_play else 4.2).timeout
	if e != epoch:
		return
	await _customer_leaves(e)


## Клиент вернулся за предзаказом: игрушка есть — упаковываем как обычно (платит остаток);
## нет — возвращаем задаток, и он злится.
func _preorder_return(e: int) -> void:
	var po: Dictionary = current["preorder"]
	var toy := str(Data.ITEMS[str(po["item"])]["name"]).to_lower()
	var deposit := int(po["deposit"])
	order.show_bubble(current["name"], "I'm back for the %s I ordered last night!" % toy)
	await get_tree().create_timer(0.3 if auto_play else 2.4).timeout
	if e != epoch:
		return
	var item: String = stock.pick_for_kind(str(po["kind"])) if stock.has_kind(str(po["kind"])) else ""
	if item == "":
		customer.face_override = customer.ANGRY_FACE
		order.show_bubble(current["name"], "You still don't have it? Then give me back my deposit!")
		await get_tree().create_timer(0.3 if auto_play else 2.4).timeout
		if e != epoch:
			return
		econ.spend("deposit_back", deposit)
		status.set_money(econ.balance)
		order.refund_pop(deposit)
		await get_tree().create_timer(0.3 if auto_play else 1.6).timeout
		if e != epoch:
			return
		customer.face_override = -1
		await _customer_leaves(e)
		return
	current_match = "perfect"
	read_in_time = false
	offer_made = true
	chosen_item = item
	_start_service_timer()
	patience_paused = true
	current_bad = stock.take(chosen_item)
	_sync_shelf()
	order.give_item(chosen_item)
	customer.set_mood(2)
	order.show_bubble(current["name"], "That's the one! Thank you for ordering it.")
	await order.item_given
	if e != epoch:
		return
	await get_tree().create_timer(0.2 if auto_play else 1.4).timeout
	if e != epoch:
		return
	await _serve_item(e)


## Клиент просит подарок бесплатно. Дарим: упаковываем как обычно, денег и чаевых нет.
## Отказываем: игрушка возвращается на полку, клиент грустно уходит. Возвращает true, если дарим.
func _ask_free(e: int) -> bool:
	order.show_bubble(current["name"], str(current["ask_free"]))
	var gift := true
	if auto_play:
		await get_tree().create_timer(0.2).timeout
	else:
		var secs: float = AudioSynth.babble_seconds(str(current["ask_free"]).length())
		AudioSynth.babble(str(Story.VOICES.get(str(current["name"]), "woman")), secs)
		await get_tree().create_timer(secs + 0.6).timeout
		AudioSynth.stop_babble()
		if e != epoch:
			return false
		order.hide_bubble()
		var pick: int = await dialogue.play([{"who": str(current["name"]), "text": str(current["ask_free"]), "choices": Story.FREE_CHOICES}])
		gift = pick == 0
	if e != epoch:
		return false
	if gift:
		free_gift = true
		customer.set_mood(2)
		return true
	customer.set_mood(0)
	order.take_item()
	stock.put_back(chosen_item, current_bad)
	current_bad = ""
	_sync_shelf()
	status.show_patience(false)
	patience_on = false
	patience_paused = false
	order.show_bubble(current["name"], str(Story.FREE_DECLINED[randi() % Story.FREE_DECLINED.size()]))
	await get_tree().create_timer(0.3 if auto_play else 2.6).timeout
	if e != epoch:
		return false
	await _customer_leaves(e)
	return false


## Оценка подарка (значения 0..1): просьбы клиента, аккуратность и дорогие материалы.
func _evaluate(c: Dictionary, r: Dictionary) -> float:
	if c.get("free", false):
		return 1.0
	var s := 0.40
	var want_paper: String = c["paper"]
	if want_paper == "any":
		s += 0.10
	elif want_paper == r["paper_tag"]:
		s += 0.25
	else:
		s -= 0.20
	if r["length_class"] == "good":
		s += 0.10
	else:
		s -= 0.05
	var crumpled: int = r["crumpled"]
	s -= 0.05 * float(mini(crumpled, 2))
	var tapes: int = r["tape_count"]
	if tapes >= 1 and tapes <= 3:
		s += 0.10
	else:
		s -= 0.05
	var want_ribbon: String = c["ribbon"]
	var got_ribbon: String = r["ribbon"]
	var has_ribbon := got_ribbon != ""
	if want_ribbon == "none":
		s += 0.20 if not has_ribbon else -0.30
	elif want_ribbon == "any":
		s += 0.15 if has_ribbon else -0.05
	else:
		if has_ribbon:
			s += 0.25 if got_ribbon == want_ribbon else 0.05
		else:
			s -= 0.10
	var want_bow: String = c["bow"]
	var bow: float = r["bow_size"]
	if want_bow == "big":
		if has_ribbon:
			s += 0.10 if bow >= 1.3 else -0.05
		else:
			s -= 0.10
	elif want_bow == "small":
		if has_ribbon:
			s += 0.10 if bow <= 0.8 else -0.05
		else:
			s -= 0.10
	var item_kind: String = Data.ITEMS[r["look"]["item_id"]]["kind"]
	if item_kind != "box":
		var want_wrap: String = c["wrap"]
		var got_wrap: String = r["wrap_choice"]
		if want_wrap == "box" or want_wrap == "shape":
			s += 0.15 if got_wrap == want_wrap else -0.25
	s += float(r["bonus"])
	if current_match == "perfect":
		s += 0.25   # угадали мысли клиента
	return clampf(s, 0.0, 1.0)


# --- Конец вечера, лавка, финал --------------------------------------------------

func _end_evening() -> void:
	var e := epoch
	order.input_enabled = false
	thinking = false
	if not complaint_list.is_empty():
		await _complaint_scene(e)
		if e != epoch:
			return
	if complaints_today > 0:
		econ.spend("complaint", complaints_today)
	if complaint_count > 0:
		econ.ledger["complaint_n"] = complaint_count
	complaints_today = 0
	complaint_count = 0
	var summary: Dictionary = econ.close_evening()
	status.set_money(econ.balance)
	hud.show_summary(summary, econ.balance, evening_idx + 1, Data.EVENINGS.size())


## После смены: каждый, кому мы продали брак, возвращается и ругается, а его деньги улетают из копилки обратно.
func _complaint_scene(e: int) -> void:
	complaint_mode = true
	var fast := auto_play
	status.show_patience(false)
	hud.set_hint("")
	order.hide_bubble()
	customer.reset()
	hud.show_title(Story.AFTER_HOURS_TITLE, Story.AFTER_HOURS_SUB)
	await get_tree().create_timer(0.3 if fast else 2.4).timeout
	var list := complaint_list.duplicate()
	complaint_list.clear()
	for c in list:
		if e != epoch:
			complaint_mode = false
			return
		var who: Dictionary = c["who"]
		var pay := int(c["pay"])
		current = who
		AudioSynth.play_sfx("door")
		customer.arrive(who)
		customer.face_override = customer.ANGRY_FACE   # входит уже злым
		await customer.arrived
		if e != epoch:
			complaint_mode = false
			return
		var toy := str(Data.ITEMS[str(c["item"])]["name"]).to_lower()
		var pool: Array = Story.COMPLAINT_BAD if str(c["defect"]) == "bad" else Story.COMPLAINT_SUB
		var line := str(pool[randi() % pool.size()]).replace("{toy}", toy).replace("{pay}", str(pay))
		order.show_bubble(str(who["name"]), line)
		if fast:
			await get_tree().create_timer(0.3).timeout
		else:
			var secs: float = AudioSynth.babble_seconds(line.length())
			AudioSynth.babble(str(Story.VOICES.get(str(who["name"]), "woman")), secs)
			await _wait_or_click(secs + 0.8)
			AudioSynth.stop_babble()
		if e != epoch:
			complaint_mode = false
			return
		# возвращаем деньги: монеты летят из копилки к клиенту, над копилкой «-N»
		econ.spend("complaint", pay)
		complaints_today = maxi(complaints_today - pay, 0)
		status.set_money(econ.balance)
		order.refund_pop(pay)
		order.show_bubble(str(who["name"]), str(Story.COMPLAINT_BYE[randi() % Story.COMPLAINT_BYE.size()]))
		await get_tree().create_timer(0.4 if fast else 2.0).timeout
		if e != epoch:
			complaint_mode = false
			return
		order.hide_bubble()
		customer.face_override = -1
		customer.leave()
		await customer.left
		await get_tree().create_timer(0.2 if fast else 0.5).timeout
	complaint_mode = false


## «Next» в итогах вечера: после ночи 1 на полке остаётся по 2 штуки, потом заказ игрушек и следующая ночь.
## После последней ночи демки показываем финальную карточку.
func _on_next_evening() -> void:
	if evening_idx >= Data.EVENINGS.size() - 1:
		_final()
		return
	if evening_idx == 0:
		stock.start_real_stock()
	_sync_shelf()
	await _order_toys()
	evening_idx += 1
	_begin_evening()


func _order_toys() -> void:
	var e := epoch
	if auto_play:
		# автотест: берём у обоих поставщиков по несколько игрушек
		var lines := {"bear": 1, "ball": 2, "train": 1}
		for po in preorders:   # под предзаказы берём с запасом: у Jolly бывает брак
			lines[str(po["item"])] = int(lines.get(str(po["item"]), 0)) + 2
		stock.place_order("jolly", lines, evening_idx)
		if evening_idx == 0:
			stock.place_order("frost", {"ornament": 2, "bear": 2, "ball_mid": 1}, evening_idx)
		return
	var due_next := preorders.filter(func(po): return int(po["night"]) == evening_idx + 1)
	reorder.open(stock, evening_idx, Data.EVENINGS.size() - 1, econ.balance, evening_idx == 0, due_next)
	var spent: int = await reorder.finished
	if e != epoch:
		return
	if spent > 0:
		_on_cost("stock", spent)


## Ящики, которые приехали перед этой ночью: проверяем игрушки и отправляем брак обратно.
func _receive_deliveries(e: int) -> void:
	for o in stock.due(evening_idx):
		var units: Array = stock.roll_delivery(o)
		if auto_play:
			var back: Array = []
			for i in units.size():
				if str(units[i]["defect"]) == "bad":
					back.append(i)
			var r: Dictionary = stock.finish_inspection(o, units, back)
			econ.refund(int(r["refund"]))
			continue
		AudioSynth.play_sfx("door")
		inspect.open(stock, o, units, stock.deliveries_done == 0)
		var res: Dictionary = await inspect.finished
		if e != epoch:
			return
		if int(res["refund"]) > 0:
			econ.refund(int(res["refund"]))
			status.set_money(econ.balance)
	_sync_shelf()


## Что сейчас лежит на полке: простые игрушки всегда (серые, если кончились), средние только пока они есть.
func _stock_counts() -> Dictionary:
	var d := {}
	for id in stock.all_ids():
		var n: int = stock.count(id)
		if Data.STOCK.has(id) or n > 0:
			d[id] = n
	return d


## Ночь 1: на полке бесконечно (set_stock не вызываем), потом показываем настоящий запас.
func _sync_shelf() -> void:
	if not order.has_method("set_stock"):
		return
	if stock.infinite:
		order.stock_set = false
	else:
		order.set_stock(_stock_counts())


func _santa_face(d: Dictionary) -> void:
	customer.face_override = int(d.get("face", 2))


## Конец ночи 3: приходит Санта, разговор, потом пустая коробка в подарок.
func _santa_scene(e: int) -> void:
	order.hide_bubble()
	hud.set_hint("")
	if not auto_play:
		await dialogue.play(Story.SANTA, _santa_face)
		if e != epoch:
			return
	customer.face_override = 2
	order.show_bubble(current["name"], str(current["pack"]))
	await get_tree().create_timer(0.2 if auto_play else 2.8).timeout
	if e != epoch:
		return
	order.hide_bubble()
	current_match = "perfect"
	chosen_item = str(current["ideal"])
	patience = patience_max
	patience_on = true
	status.show_patience(true)
	status.set_patience(1.0, patience_max)
	await _switch_to("wrap")
	if e != epoch:
		return
	wrap.set_ticket(current["name"], Data.ticket_lines(current, chosen_item))
	wrap.place_item(chosen_item)
	wrap.input_enabled = true
	patience_paused = false


func _on_shop_open() -> void:
	shop_list = econ.shop_items()
	hud.show_shop(shop_list, econ.balance)


func _on_buy(idx: int) -> void:
	if idx < 0 or idx >= shop_list.size():
		return
	var it: Dictionary = shop_list[idx]
	if econ.buy(it):
		AudioSynth.play_sfx("buy")
		status.set_money(econ.balance)
		_apply_inventory()
		shop_list = econ.shop_items()
		hud.refresh_shop(shop_list, econ.balance)
		hud.show_shop_note("Bought: " + str(it["name"]))
	else:
		hud.show_shop_note("Not enough coins")


func _final() -> void:
	hud.set_hint("")
	hud.show_final(econ.balance, tips_total)


func _restart() -> void:
	epoch += 1
	preorders = []
	night_queue = []
	free_gift = false
	order.clear_keepsakes()
	thinking = false
	offer_made = false
	complaints_today = 0
	complaint_count = 0
	complaint_list.clear()
	complaint_mode = false
	AudioSynth.stop_babble()
	patience_on = false
	evening_idx = 0
	customer_idx = 0
	tips_total = 0
	econ.reset()
	stock.reset()
	_sync_shelf()
	_apply_inventory()
	status.set_money(econ.balance, false)
	status.show_patience(false)
	order.reset()
	wrap.clear_gift()
	customer.reset()
	light.clear_fireworks()
	bg.clear_fireworks()
	hud.hide_all()
	_begin_evening()
