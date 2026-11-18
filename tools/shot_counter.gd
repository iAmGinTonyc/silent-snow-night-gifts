extends SceneTree
## Снимок прилавка для проверки глазами (нужно окно): godot --path . --script res://tools/shot_counter.gd -- /папка
## Облачко с хвостиком, кот на месте бывшей кассы, копилка на разных суммах, «+N» над ней, подарок на столе, вода в мыслях.

var main
var out_dir := "/tmp"


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)   # иначе macOS замораживает кадры, если окно закрыто другим
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
	print("saved ", name, " start_visible=", main.hud.start_root.visible, " px=", img.get_pixel(640, 360), " screen=", main.screen)


func run() -> void:
	await create_timer(1.0).timeout
	main.hud.start_root.visible = false
	main.auto_play = true
	main._start_game()
	await create_timer(3.0).timeout
	main.customer.reset()
	main.order.reset()
	var tanaka: Dictionary = main.Data.EVENINGS[0]["customers"][0]
	main.current = tanaka
	main.customer.arrive(tanaka)
	await create_timer(3.4).timeout
	main.order.show_bubble("Mrs. Tanaka", main.Story.HELLO["Mrs. Tanaka"][1])
	await create_timer(1.2).timeout
	await shot("c1_bubble")
	main.order.hide_bubble()
	main.order.give_item("ornament")
	await create_timer(0.6).timeout
	main.order.set_gift_clickable(true)
	await create_timer(0.8).timeout
	await shot("c2_gift")
	main.order.take_item()
	main.econ.balance = 134
	await create_timer(2.0).timeout
	await shot("c3_jar_134")
	main.econ.earn(30)
	main.order.pay_pop(30)
	await create_timer(0.5).timeout
	await shot("c4_coins_flying")
	await create_timer(0.9).timeout
	await shot("c5_plus_float")
	await create_timer(0.7).timeout
	await shot("c6_float_fading")
	main.econ.balance = 300
	await create_timer(3.0).timeout
	await shot("c7_jar_300")
	for m in [0, 60, 700]:
		main.econ.balance = m
		main.order.jar_money = -1.0
		await create_timer(0.3).timeout
		await shot("c7_jar_%d" % m)
	main.order.hide_bubble()
	main.customer.reset()
	var okafor: Dictionary = main.Data.EVENINGS[0]["customers"][5]
	main.current = okafor
	main.customer.arrive(okafor)
	await create_timer(3.4).timeout
	main.thinking = false
	main.order.show_thought("Mr. Okafor", okafor["thought"])
	main.order.set_thought_fill(0.4)
	await create_timer(1.2).timeout
	await shot("c8_thought_40")
	main.order.set_thought_fill(0.85)
	await create_timer(0.6).timeout
	await shot("c9_thought_85")
	quit()
