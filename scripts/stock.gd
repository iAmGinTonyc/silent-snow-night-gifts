extends RefCounted
## Запас игрушек, заказы поставщикам, брак. Логика без рисования (правила в STORY.md, раздел 5).
## Ночь 1: обучение, игрушек бесконечно. После неё остаётся по 2 штуки каждой дешёвой игрушки
## (`start_real_stock`). Заказы приходят ящиком перед нужной ночью, брак ищем руками.

const Data = preload("res://scripts/data.gd")

const SUPPLIERS := [
	{
		"id": "jolly", "name": "Jolly Jingle Wholesale", "short": "Jolly Jingle", "nights": 1, "mult": 0.85,
		"defect": 0.30, "fee": 6, "min_order": 0, "refund": 0.5, "tiers": ["cheap", "mid"],
		"blurb": "Fast and cheap. Packs in a hurry.",
	},
	{
		"id": "frost", "name": "Frost & Daughters Toy Workshop", "short": "Frost & Daughters", "nights": 2, "mult": 1.0,
		"defect": 0.05, "fee": 0, "min_order": 4, "refund": 1.0, "tiers": ["cheap", "mid"],
		"blurb": "Slow and careful. Everything by the list.",
	},
]

const MAX_PER_ORDER := 15          # больше в один ящик не влезает (и на стол приёмки)
const SUBTLE_SHARE := 0.4          # доля брака, который почти не виден
const START_STOCK := 2             # сколько каждой дешёвой игрушки остаётся после ночи 1

var infinite := true               # ночь 1: игрушек бесконечно
var units := {}                    # id игрушки -> массив штук, у каждой "defect": "" | "bad" | "sub" (скрытый брак)
var pending: Array = []            # заказы в пути: {supplier, arrive, lines: {id: qty}, paid}
var deliveries_done := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func reset() -> void:
	infinite = true
	units = {}
	pending = []
	deliveries_done = 0


func all_ids() -> Array:
	return Data.STOCK + Data.STOCK_MID


func supplier(sid: String) -> Dictionary:
	for s in SUPPLIERS:
		if s["id"] == sid:
			return s
	return {}


## Цена покупки одной штуки у поставщика.
func buy_price(sid: String, item_id: String) -> int:
	var base := float(Data.ITEMS[item_id]["stock"])
	return roundi(base * float(supplier(sid)["mult"]))


## После ночи 1: больше не бесконечно, на полке по START_STOCK целых игрушек каждого дешёвого вида.
func start_real_stock() -> void:
	infinite = false
	units = {}
	for id in Data.STOCK:
		units[id] = []
		for i in START_STOCK:
			units[id].append({"defect": ""})


func count(item_id: String) -> int:
	if infinite:
		return 99 if Data.STOCK.has(item_id) else 0
	return (units.get(item_id, []) as Array).size()


func on_the_way(item_id: String) -> int:
	var n := 0
	for o in pending:
		n += int((o["lines"] as Dictionary).get(item_id, 0))
	return n


## Какие игрушки есть на полке (для экрана заказа игрушек).
func available_ids() -> Array:
	var out: Array = []
	for id in all_ids():
		if count(id) > 0:
			out.append(id)
	return out


func total_count() -> int:
	var n := 0
	for id in all_ids():
		n += count(id)
	return n


## Клиент сам выбирает игрушку нужного вида: самую дешёвую из имеющихся, иначе любую другую.
func pick_for_kind(kind: String) -> String:
	var best := ""
	var best_sell := 1 << 30
	for id in available_ids():
		if Data.ITEMS[id]["kind"] == kind and int(Data.ITEMS[id]["sell"]) < best_sell:
			best = id
			best_sell = int(Data.ITEMS[id]["sell"])
	if best != "":
		return best
	var rest := available_ids()
	if rest.is_empty():
		return ""
	return rest[rng.randi_range(0, rest.size() - 1)]


## Забрать одну штуку с полки. Возвращает её скрытый брак: "" целая, "bad" явный, "sub" почти незаметный.
func take(item_id: String) -> String:
	if infinite:
		return ""
	var arr: Array = units.get(item_id, [])
	if arr.is_empty():
		return ""
	var i := rng.randi_range(0, arr.size() - 1)
	var u: Dictionary = arr[i]
	arr.remove_at(i)
	return str(u["defect"])


# --- Заказы -----------------------------------------------------------------

## Считаем заказ у поставщика. lines: {id: qty}. Возвращает {ok, reason, items, fee, total, qty}.
func quote(sid: String, lines: Dictionary) -> Dictionary:
	var s := supplier(sid)
	var qty := 0
	var items_cost := 0
	for id in lines:
		var q := int(lines[id])
		if q <= 0:
			continue
		qty += q
		items_cost += q * buy_price(sid, id)
	var fee := int(s["fee"]) if qty > 0 else 0
	var res := {"ok": true, "reason": "", "items": items_cost, "fee": fee, "total": items_cost + fee, "qty": qty}
	if qty == 0:
		res["ok"] = true
	elif qty < int(s["min_order"]):
		res["ok"] = false
		res["reason"] = "Minimum %d toys" % int(s["min_order"])
	elif qty > MAX_PER_ORDER:
		res["ok"] = false
		res["reason"] = "At most %d toys per crate" % MAX_PER_ORDER
	return res


## Оформляем заказ. night: номер ночи (с 0), после которой заказ сделан; приедет перед ночью night + nights.
func place_order(sid: String, lines: Dictionary, night: int) -> Dictionary:
	var q := quote(sid, lines)
	if int(q["qty"]) == 0 or not bool(q["ok"]):
		return {}
	var clean := {}
	for id in lines:
		if int(lines[id]) > 0:
			clean[id] = int(lines[id])
	var o := {"supplier": sid, "arrive": night + int(supplier(sid)["nights"]), "lines": clean, "paid": int(q["total"])}
	pending.append(o)
	return o


## Заказы, которые приезжают перед ночью с номером night (с 0).
func due(night: int) -> Array:
	var out: Array = []
	for o in pending:
		if int(o["arrive"]) == night:
			out.append(o)
	return out


## Ящик заказа: список штук {id, defect}. Шанс брака у поставщика, у первой доставки Jolly Jingle брак есть всегда.
func roll_delivery(o: Dictionary) -> Array:
	var s := supplier(str(o["supplier"]))
	var out: Array = []
	for id in o["lines"]:
		for i in int(o["lines"][id]):
			var d := ""
			if rng.randf() < float(s["defect"]):
				d = "sub" if rng.randf() < SUBTLE_SHARE else "bad"
			out.append({"id": str(id), "defect": d})
	if str(s["id"]) == "jolly" and deliveries_done == 0:
		var has := false
		for u in out:
			if str(u["defect"]) == "bad":
				has = true
		if not has and not out.is_empty():
			(out[rng.randi_range(0, out.size() - 1)] as Dictionary)["defect"] = "bad"
	# перемешиваем, чтобы брак не лежал подряд
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Итог проверки ящика. units_in: что приехало, sent_back: индексы, которые мы вернули.
## Возвращает {refund, back_bad, back_good, kept, slipped}.
func finish_inspection(o: Dictionary, units_in: Array, sent_back: Array) -> Dictionary:
	var s := supplier(str(o["supplier"]))
	var refund := 0
	var back_bad := 0
	var back_good := 0
	var kept := 0
	var slipped := 0
	for i in units_in.size():
		var u: Dictionary = units_in[i]
		var id: String = u["id"]
		var d: String = u["defect"]
		if sent_back.has(i):
			if d != "":
				back_bad += 1
				refund += roundi(float(buy_price(str(o["supplier"]), id)) * float(s["refund"]))
			else:
				back_good += 1
		else:
			kept += 1
			if d != "":
				slipped += 1
			if not units.has(id):
				units[id] = []
			(units[id] as Array).append({"defect": d})
	pending.erase(o)
	deliveries_done += 1
	return {"refund": refund, "back_bad": back_bad, "back_good": back_good, "kept": kept, "slipped": slipped}
