extends SceneTree
## Снимки на экране другой формы (окно, не headless):
##   godot --path . --script res://tools/shot_wide.gd -- /папка 1560 720 phone
## Кадры <имя>_menu, _order, _shelf, _wrap, _dialog: игра должна заполнять окно целиком, без полос.

var main
var out_dir := "/tmp"
var tag := "wide"


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	if args.size() > 3:
		tag = args[3]
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
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, tag, name])
	print("shot ", tag, "_", name, " ", root.get_texture().get_size())


func run() -> void:
	await create_timer(0.8).timeout
	await shot("menu")
	main.auto_play = true
	main.think_time = 30.0
	main.hud.start_root.visible = false
	main._start_game()
	await wait_until(func(): return main.customer.state == "idle" and main.order.offer_enabled, 60.0)
	await create_timer(0.6).timeout
	await shot("order")
	main.order.shelf_open = true
	await create_timer(0.6).timeout
	await shot("shelf")
	main.order.shelf_open = false
	main._on_offer(str(main.current["ideal"]))
	var w = main.wrap
	await wait_until(func(): return main.screen == "wrap" and (w.step == w.Step.CHOOSE or w.step == w.Step.PAPER), 30.0)
	await create_timer(0.8).timeout
	await shot("wrap")
	main.dialogue.play([{"who": "Elf", "text": "Night one. First time running the shop all by myself."}])
	await create_timer(1.5).timeout
	await shot("dialog")
	quit()
