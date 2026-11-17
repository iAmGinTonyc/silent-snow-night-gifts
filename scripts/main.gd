extends Node2D
## Поток игры: два экрана (заказ и упаковка), терпение клиента, деньги и лавка, вечера и финал.

const Data = preload("res://scripts/data.gd")
const SceneBg = preload("res://scripts/scene_bg.gd")
const CustomerView = preload("res://scripts/customer_view.gd")
const OrderCounter = preload("res://scripts/order_counter.gd")
const WrapScreen = preload("res://scripts/wrap_screen.gd")
const Hud = preload("res://scripts/hud.gd")
const StatusBar = preload("res://scripts/status_bar.gd")
const Fx = preload("res://scripts/fx.gd")
const Economy = preload("res://scripts/economy.gd")

var econ
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
var current_match := ""     # у покупателя: perfect, ok или miss
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
	tint.color = Color(1.0, 0.97, 0.9)
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
	wrap = WrapScreen.new()
	wrap_root.add_child(wrap)
	var wrap_light := SceneBg.new()
	wrap_light.mode = "vignette"
	wrap_root.add_child(wrap_light)

	hud = Hud.new()
	add_child(hud)
	status = StatusBar.new()
	hud.add_child(status)
	fx = Fx.new()
	add_child(fx)

	order.input_enabled = false
	wrap.input_enabled = false
	wrap.hint_changed.connect(hud.set_hint)
	wrap.toast.connect(hud.show_toast)
	wrap.cost.connect(_on_cost)
	wrap.gift_ready.connect(_on_gift_ready)
	customer.arrived.connect(_on_customer_arrived)
	order.accept_pressed.connect(_on_accept)
	order.offer_pressed.connect(_on_offer)
	hud.start_pressed.connect(_start_game)
	hud.next_pressed.connect(_on_next_evening)
	hud.shop_pressed.connect(_on_shop_open)
	hud.shop_back_pressed.connect(hud.back_to_summary)
	hud.buy_pressed.connect(_on_buy)
	hud.restart_pressed.connect(_restart)

	_apply_inventory()
	status.set_money(econ.balance, false)
	var ev: Dictionary = Data.EVENINGS[0]
	bg.sky_color = Color.html(ev["sky"])
	bg.sky_target = bg.sky_color
	var clock: Array = ev["clock"]
	bg.set_clock_instant(float(clock[0]))


func _process(delta: float) -> void:
	if not patience_on or patience_paused:
		return
	patience -= delta
	status.set_patience(patience / patience_max, patience)
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
	_apply_inventory()
	status.set_money(econ.balance, false)
	tips_total = 0
	_begin_evening()


func _begin_evening() -> void:
	var e := epoch
	var ev: Dictionary = Data.EVENINGS[evening_idx]
	_show_screen("order")
	econ.new_evening()
	bg.set_sky(Color.html(ev["sky"]))
	var clock: Array = ev["clock"]
	bg.set_clock_instant(float(clock[0]))
	patience_max = float(ev["patience"])
	customer_idx = 0
	redo_count = 0
	order.reset()
	order.input_enabled = false
	status.show_patience(false)
	hud.show_title("Night %d of %d" % [evening_idx + 1, Data.EVENINGS.size()], str(ev["date"]) + " · " + str(ev["place"]))
	await get_tree().create_timer(2.4).timeout
	if e != epoch:
		return
	_next_customer()


func _next_customer() -> void:
	var ev: Dictionary = Data.EVENINGS[evening_idx]
	var list: Array = ev["customers"]
	if customer_idx >= list.size():
		_end_evening()
		return
	current = list[customer_idx]
	redo_count = 0
	var clock: Array = ev["clock"]
	var frac := float(customer_idx) / float(maxi(list.size() - 1, 1))
	bg.set_clock(lerpf(float(clock[0]), float(clock[1]), frac))
	order.input_enabled = false
	AudioSynth.play_sfx("door")
	customer.arrive(current)


func _is_buyer() -> bool:
	return current.get("kind", "wrap") == "buyer"


func _on_customer_arrived() -> void:
	current_match = ""
	chosen_item = ""
	if _is_buyer():
		# покупатель: не принёс вещь, ему нужен подарок из наличия
		if current["mode"] == "mind":
			order.show_thought(current["name"], current["thought"])
			hud.set_hint("We can read their mind: pick a gift from the shelf")
		else:
			order.show_bubble(current["name"], current["request"])
			hud.set_hint("They ask for a gift: pick it from the shelf")
		order.input_enabled = true
		order.set_offer(true)
		patience = patience_max
		patience_on = true
		status.show_patience(true)
		status.set_patience(1.0, patience_max)
		return
	order.show_bubble(current["name"], current["request"])
	order.input_enabled = true
	order.set_accept(true)


## Покупателю предлагают подарок с полки. Угадали мысли, и он радостнее и охотнее даёт чаевые.
func _on_offer(offered: String) -> void:
	if not _is_buyer():
		return
	var e := epoch
	var ideal: String = current["ideal"]
	var okay: Array = current["okay"]
	var level := "miss"
	if offered == ideal:
		level = "perfect"
	elif okay.has(offered):
		level = "ok"
	if current["mode"] == "ask" and level != "perfect":
		hud.show_toast("That is not what they asked for")
		customer.set_mood(0)
		AudioSynth.play_sfx("dull")
		return
	order.set_offer(false)
	order.input_enabled = false
	patience_paused = true
	hud.set_hint("")
	current_match = level
	chosen_item = offered
	var it: Dictionary = Data.ITEMS[offered]
	_on_cost("stock", int(it["stock"]))
	order.give_item(offered)
	customer.set_mood(2 if level == "perfect" else (1 if level == "ok" else 0))
	order.show_bubble(current["name"], str(Data.BUYER_LINES[level]))
	await order.item_given
	if e != epoch:
		return
	await get_tree().create_timer(1.6).timeout
	if e != epoch:
		return
	order.hide_bubble()
	await _switch_to("wrap")
	if e != epoch:
		return
	wrap.set_ticket(current["name"], Data.ticket_lines(current, offered))
	wrap.place_item(offered)
	wrap.input_enabled = true
	patience_paused = false


## Клиент отдаёт вещь, экран переключается на рабочий стол.
func _on_accept() -> void:
	var e := epoch
	order.input_enabled = false
	order.hide_bubble()
	order.give_item(current["item"])
	await order.item_given
	if e != epoch:
		return
	await _switch_to("wrap")
	if e != epoch:
		return
	wrap.set_ticket(current["name"], Data.ticket_lines(current, str(current["item"])))
	wrap.place_item(current["item"])
	wrap.input_enabled = true
	patience = patience_max
	patience_on = true
	status.show_patience(true)
	status.set_patience(1.0, patience_max)


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

	# чем кривее подарок, тем выше шанс, что клиент расстроится
	var outcome := "pay"
	if neat < 0.7:
		var roll := randf()
		var can_redo := redo_count < 1
		if neat >= 0.4:
			if roll < 0.35 and can_redo:
				outcome = "redo"
		elif roll < 0.35 and can_redo:
			outcome = "redo"
		elif roll < 0.70:
			outcome = "refuse"
	if outcome == "redo":
		redo_count += 1
		customer.set_mood(0)
		order.show_bubble(current["name"], "That came out crooked. Please do it again.")
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
		order.show_bubble(current["name"], "What is this? I am not paying for that.")
		await get_tree().create_timer(2.8).timeout
		if e != epoch:
			return
		order.clear_gift()
		await _customer_leaves(e)
		return

	var it: Dictionary = Data.ITEMS[item_id]
	var buyer := _is_buyer()
	var pay: int = int(it["sell"]) if buyer else int(it["price"])
	econ.earn(pay)
	status.set_money(econ.balance)
	order.pay_pop()

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
	if buyer:
		var chance := 0.8
		if current_match == "perfect":
			tips = maxi(tips, 2)
			chance = 1.0
		elif current_match == "miss":
			chance = 0.4
		if randf() > chance:
			tips = 0
	if neat < 0.4:
		tips = 0
	if tips == 0:
		line = current["meh"]
		mood = mini(mood, 1)
	customer.set_mood(mood)
	order.show_bubble(current["name"], line)
	if tips > 0:
		order.add_tip_coins(tips)
		econ.add_tip(tips)
		tips_total += tips
	await get_tree().create_timer(2.9).timeout
	if e != epoch:
		return
	order.clear_gift()
	await _customer_leaves(e)


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
	if _is_buyer():
		s += {"perfect": 0.25, "ok": 0.10, "miss": -0.15}.get(current_match, 0.0)
	return clampf(s, 0.0, 1.0)


# --- Конец вечера, лавка, финал --------------------------------------------------

func _end_evening() -> void:
	order.input_enabled = false
	var summary: Dictionary = econ.close_evening()
	status.set_money(econ.balance)
	if evening_idx >= Data.EVENINGS.size() - 1:
		_final()
	else:
		hud.show_summary(summary, econ.balance, evening_idx + 1, Data.EVENINGS.size())


func _on_next_evening() -> void:
	evening_idx += 1
	_begin_evening()


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
	var e := epoch
	bg.set_clock(1440.0)
	hud.set_hint("")
	for i in 16:
		bg.spawn_firework()
		light.spawn_firework()
		AudioSynth.play_sfx("pop")
		await get_tree().create_timer(randf_range(0.45, 0.9)).timeout
		if e != epoch:
			return
		if i == 4:
			hud.show_final(econ.balance, tips_total)


func _restart() -> void:
	epoch += 1
	patience_on = false
	evening_idx = 0
	customer_idx = 0
	tips_total = 0
	econ.reset()
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
