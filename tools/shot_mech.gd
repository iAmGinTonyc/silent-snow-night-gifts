extends SceneTree
## Снимки новых механик (окно, не headless): godot --path . --script res://tools/shot_mech.gd -- /папка
## Кадры: клиент в новой нарезке, Окафор с целой перчаткой, просьба бесплатно с выбором, подарок нам на прилавке,
## злой клиент после смены.

var main
var out_dir := "/tmp"


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			return false
	return true


func shot(name: String) -> void:
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)


func run() -> void:
	await process_frame
	main.auto_play = true
	main.think_time = 30.0
	main.hud.start_root.visible = false
	main._start_game()
	await wait_until(func(): return main.customer.state == "idle", 60.0)
	await create_timer(0.8).timeout
	await shot("m1_customer")
	var okafor: Dictionary = main.Data.EVENINGS[0]["customers"][5]
	main.customer.leave()
	await main.customer.left
	main.complaint_mode = true   # чтобы приход не запускал обычный сценарий
	main.current = okafor
	main.customer.arrive(okafor)
	await main.customer.arrived
	main.order.hide_bubble()
	await create_timer(0.5).timeout
	await shot("m2_okafor")
	main.customer.face_override = main.customer.ANGRY_FACE
	await create_timer(0.3).timeout
	await shot("m3_angry")
	main.customer.face_override = -1
	main.order.show_gift({"base": "#c93a4a", "accent": "#f2c14e", "wrap_mode": "box", "item_id": "bear", "ribbon": "#f2c14e",
		"bow": 1.0, "w": 170.0, "h": 150.0, "kind": "box"})
	await create_timer(0.8).timeout
	main.order.keep_gift()
	await create_timer(1.4).timeout
	await shot("m4_keepsake")
	var leo: Dictionary = main.Data.EVENINGS[0]["customers"][3]
	main.dialogue.play([{"who": str(leo["name"]), "text": str(leo["ask_free"]), "choices": main.Story.FREE_CHOICES}])
	await create_timer(2.5).timeout
	await shot("m5_ask_free")
	quit()
