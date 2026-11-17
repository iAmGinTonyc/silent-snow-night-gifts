extends RefCounted
## Деньги: касса, расходы вечера, чаевые из банки и купленные материалы.

const Data = preload("res://scripts/data.gd")

var balance := 0
var owned := {}
var ledger := {}


func _init() -> void:
	reset()


func reset() -> void:
	balance = Data.START_MONEY
	owned = {}
	for kind in ["paper", "ribbon", "box"]:
		var src: Array = _source(kind)
		for e in src:
			if int(e["price"]) == 0:
				owned[kind + ":" + str(e["id"])] = true
	new_evening()


func _source(kind: String) -> Array:
	if kind == "paper":
		return Data.PAPERS
	if kind == "ribbon":
		return Data.RIBBONS
	return Data.BOXES


func new_evening() -> void:
	ledger = {"revenue": 0, "tips": 0, "paper": 0, "waste": 0, "tape": 0, "ribbon": 0, "box": 0}


func earn(amount: int) -> void:
	balance += amount
	ledger["revenue"] = int(ledger["revenue"]) + amount


func spend(category: String, amount: int) -> void:
	balance -= amount
	ledger[category] = int(ledger[category]) + amount


func add_tip(n: int) -> void:
	ledger["tips"] = int(ledger["tips"]) + n


func expenses() -> int:
	var s := 0
	for k in ["paper", "waste", "tape", "ribbon", "box"]:
		s += int(ledger[k])
	return s


## Банк с чаевыми пересчитывается в кассу. Возвращает итоги вечера.
func close_evening() -> Dictionary:
	var out := ledger.duplicate()
	out["expenses"] = expenses()
	out["net"] = int(ledger["revenue"]) + int(ledger["tips"]) - expenses()
	balance += int(ledger["tips"])
	return out


func shop_items() -> Array:
	var items: Array = []
	for kind in ["paper", "ribbon", "box"]:
		var src: Array = _source(kind)
		for i in src.size():
			var e: Dictionary = src[i]
			if int(e["price"]) > 0:
				var key: String = kind + ":" + str(e["id"])
				items.append({
					"key": key, "kind": kind, "idx": i, "name": e["name"],
					"price": int(e["price"]), "premium": bool(e["premium"]), "owned": owned.has(key),
				})
	return items


func buy(item: Dictionary) -> bool:
	var key: String = item["key"]
	var price: int = item["price"]
	if owned.has(key) or balance < price:
		return false
	balance -= price
	owned[key] = true
	return true


func owned_indices(kind: String) -> Array:
	var arr: Array = []
	var src: Array = _source(kind)
	for i in src.size():
		var e: Dictionary = src[i]
		if owned.has(kind + ":" + str(e["id"])):
			arr.append(i)
	return arr
