extends SceneTree
## Сравнивает размеры, по которым считается бумага (ITEMS w/h), с реальным силуэтом предмета.
const Data = preload("res://scripts/data.gd")
const Shapes = preload("res://scripts/shapes.gd")

func _init() -> void:
	for id in Data.ITEMS:
		var it: Dictionary = Data.ITEMS[id]
		var kind: String = it["kind"]
		if kind == "box":
			continue
		var poly: PackedVector2Array = Shapes.silhouette(kind)
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		print("%-9s declared %dx%d  silhouette bbox %dx%d  at (%d,%d)-(%d,%d)" % [id, int(it["w"]), int(it["h"]), int(r.size.x), int(r.size.y), int(r.position.x), int(r.position.y), int(r.end.x), int(r.end.y)])
	quit()
