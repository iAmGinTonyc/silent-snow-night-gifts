extends SceneTree
## Хвостик облачка у разных клиентов (окно): godot --path . --script res://tools/shot_bubble.gd -- /папка

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


func run() -> void:
	await process_frame
	main.auto_play = true
	main.hud.start_root.visible = false
	main.complaint_mode = true   # приход без обычного сценария
	main._start_game()
	await create_timer(3.0).timeout
	var picks := {"Leo": 0, "Dmitri": 1, "Pavel": 0, "The Murphy family": 2, "Mrs. Tanaka": 0}
	for name in picks:
		var c: Dictionary = {}
		for ev in main.Data.EVENINGS:
			for cc in ev["customers"]:
				if str(cc["name"]) == name:
					c = cc
		if main.customer.state != "none":
			main.customer.leave()
			await main.customer.left
		main.current = c
		main.customer.arrive(c)
		await main.customer.arrived
		main.order.show_bubble(name, str(c["thought"]))
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png("%s/bubble_%s.png" % [out_dir, name.replace(" ", "_").replace(".", "")])
		print("shot ", name)
	quit()
