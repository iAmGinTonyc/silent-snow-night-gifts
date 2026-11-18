extends SceneTree
## Снимки экранов демки для проверки глазами (нужно окно, не headless):
##   godot --path . --script res://tools/shot_demo.gd -- /путь/к/папке
## Кладёт PNG: меню, внутренний голос, заказ игрушек, приёмка ящика, разговор с Сантой, финальная карточка.

var main
var out_dir := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	run()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name, " ", img.get_size())


func run() -> void:
	await create_timer(1.5).timeout
	await shot("01_menu")
	main.hud.start_root.visible = false
	main._start_game()
	await create_timer(3.4).timeout
	await shot("02_intro")
	# заказ игрушек (после ночи 1)
	main.dialogue.root.visible = false
	main.dialogue.active = false
	main.epoch += 1
	main.stock.start_real_stock()
	main.reorder.open(main.stock, 0, 2, 134, true)
	main.reorder._step("jolly", "bear", 1)
	main.reorder._step("jolly", "ball_mid", 1)
	main.reorder._step("frost", "train", 2)
	main.reorder._step("frost", "ornament", 2)
	await create_timer(0.4).timeout
	await shot("03_reorder")
	main.reorder.root.visible = false
	# приёмка ящика
	var order := {"supplier": "jolly", "arrive": 1, "lines": {"bear": 2, "ball_mid": 1, "train": 2, "ornament": 1}, "paid": 70}
	var units: Array = [
		{"id": "bear", "defect": "bad"}, {"id": "ball_mid", "defect": ""}, {"id": "train", "defect": "sub"},
		{"id": "ornament", "defect": ""}, {"id": "bear", "defect": ""}, {"id": "ornament_mid", "defect": "sub"},
		{"id": "train_mid", "defect": ""}, {"id": "ball", "defect": "bad"},
	]
	main.inspect.open(main.stock, order, units, true)
	main.inspect.flagged = [0, 3]
	main.inspect._refresh()
	await create_timer(0.4).timeout
	await shot("04_inspect")
	main.inspect.root.visible = false
	# Санта
	main.hud.hide_all()
	main.order.reset()
	var santa: Dictionary = main.Data.EVENINGS[2]["customers"][7]
	main.current = santa
	main.customer.arrive(santa)
	await create_timer(3.2).timeout
	main.dialogue.play(main.Story.SANTA, main._santa_face)
	await create_timer(1.4).timeout
	await shot("05_santa_line")
	main.dialogue._advance_request()
	main.dialogue._advance_request()
	await create_timer(1.2).timeout
	main.dialogue._advance_request()
	await create_timer(0.2).timeout
	main.dialogue._advance_request()
	await create_timer(1.5).timeout
	await shot("06_santa_choice")
	main.dialogue.root.visible = false
	main.dialogue.active = false
	main.hud.show_final(300, 45)
	await create_timer(0.4).timeout
	await shot("07_final")
	main.hud.hide_all()
	main.customer.reset()
	main.order.reset()
	var tanaka: Dictionary = main.Data.EVENINGS[0]["customers"][0]
	main.current = tanaka
	main.customer.arrive(tanaka)
	await create_timer(3.4).timeout
	main.order.show_bubble("Mrs. Tanaka", main.Story.HELLO["Mrs. Tanaka"][1])
	await create_timer(1.2).timeout
	await shot("08_hello")
	quit()
