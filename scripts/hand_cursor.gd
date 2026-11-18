extends CanvasLayer
## Курсор: рука эльфа. Системный курсор прячется, вместо него рисуется рука. Поза зависит от того,
## что под мышью и что в руке: указатель, открытая ладонь, кулак, щепотка за край бумаги, поглаживание
## кота, ножницы, скотч, лента, линейка, звонок. Кадры лежат в атласе 6 на 4 (`art/cursor/hand_atlas.png`),
## все выровнены так, чтобы кончик пальца или инструмента был в одной точке (HOT) и совпадал с точкой клика.

const ATLAS := preload("res://art/cursor/hand_atlas.png")
const U = preload("res://scripts/util.gd")
const TOUCH_LINGER := 0.7   # на телефоне рука видна, пока палец на экране, и ещё столько секунд после
const CELL := 240.0     # размер клетки в атласе
const HOT := 48.0       # точка клика внутри клетки (в px атласа)
const SCALE := 0.5      # игровых px на px атласа
const COLS := 6
# рука с катушкой ленты: 7 цветов (в порядке Data.RIBBONS) x [держит, тянет ленту]; центр катушки совпадает с точкой клика
const RIBBON_ATLAS := preload("res://art/cursor/ribbon_atlas.png")
const RIBBON_HOT := Vector2(76.0, 58.0)

# номера кадров (по строкам атласа)
const F_POINT := 0
const F_POINT_PRESS := 1
const F_OPEN := 2
const F_FIST := 3
const F_PINCH := 4
const F_PINCH_PULL := 5
const F_PET := 6          # 6..11
const F_SCISSORS := 12    # 12..17: раскрыты, сходятся, сомкнуты, расходятся, раскрыты, щёлк
const F_TAPE := 18
const F_TAPE_PULL := 19
const F_RULER := 20
const F_RIBBON := 21
const F_BELL := 22
const F_BELL_PRESS := 23
const SNIP := [13, 14, 17, 15, 12]

var main: Node
var canvas: Node2D
var shown := false
var t := 0.0
var snip_t := 1.0
var was_pressed := false
var pet_phase := 0.0       # накопленный путь мыши при поглаживании, по нему идут кадры
var pose := "point"
var frame := 0
var ribbon_col := 0
var ribbon_row := 0
var touch := false          # телефон или планшет: рука не висит над экраном после касания
var idle_t := 99.0


func _ready() -> void:
	layer = 100
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_draw_hand)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	touch = U.is_touch()
	get_window().mouse_exited.connect(func(): shown = false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		shown = true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pet_phase += (event as InputEventMouseMotion).relative.length() * 0.06


func _process(delta: float) -> void:
	t += delta
	snip_t += delta
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if touch:
		idle_t = 0.0 if pressed else idle_t + delta
		canvas.modulate.a = 1.0 - smoothstep(TOUCH_LINGER * 0.5, TOUCH_LINGER, idle_t)
	if pressed and pose == "pet":
		pet_phase += delta * 2.5   # лёгкое движение и без мыши, чтобы рука не замирала
	pose = _pose_name()
	if pressed and not was_pressed and pose == "scissors":
		snip_t = 0.0
	was_pressed = pressed
	frame = _frame_for(pose, pressed)
	if pose == "ribbon":
		ribbon_col = clampi(main.wrap.ribbon_idx, 0, 6)
		ribbon_row = 1 if main.wrap.ribbon_anchored else 0
	canvas.queue_redraw()


## Что сейчас держит рука. Окна и кнопки поверх экрана важнее того, что под ними.
func _pose_name() -> String:
	var c := get_viewport().gui_get_hovered_control()
	if c != null:
		return "hover" if c is BaseButton else "point"
	var p := canvas.get_global_mouse_position()
	if main.screen == "order":
		return main.order.cursor_pose(p)
	return main.wrap.cursor_pose(p)


func _frame_for(p: String, pressed: bool) -> int:
	match p:
		"hover":
			return F_FIST if pressed else F_OPEN
		"grab":
			return F_FIST
		"pinch":
			return F_PINCH_PULL if pressed else F_PINCH
		"pet":
			# над котом рука спокойно лежит, гладит только пока кнопка нажата: кадры идут вслед за движением мыши
			if not pressed:
				return F_PET
			return F_PET + int(pet_phase) % 6
		"scissors":
			if snip_t < 0.3:
				return SNIP[mini(int(snip_t / 0.3 * float(SNIP.size())), SNIP.size() - 1)]
			return F_SCISSORS
		"tape":
			return F_TAPE_PULL if pressed else F_TAPE
		"ribbon":
			return F_RIBBON
		"ruler":
			return F_RULER
		"bell":
			return F_BELL_PRESS if pressed else F_BELL
	return F_POINT_PRESS if pressed else F_POINT


func _draw_hand() -> void:
	if not shown or (touch and idle_t >= TOUCH_LINGER):
		return
	var pos := canvas.get_global_mouse_position()
	var atlas: Texture2D = ATLAS
	var hot := Vector2(HOT, HOT)
	var src := Rect2(float(frame % COLS) * CELL, float(frame / COLS) * CELL, CELL, CELL)
	if pose == "ribbon":
		atlas = RIBBON_ATLAS
		hot = RIBBON_HOT
		src = Rect2(float(ribbon_col) * CELL, float(ribbon_row) * CELL, CELL, CELL)
	var dst := Rect2(-hot * SCALE, Vector2(CELL, CELL) * SCALE)
	var s := 0.94 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1.0
	# мягкая тень, чтобы рука читалась на любом фоне
	canvas.draw_set_transform(pos + Vector2(3.0, 5.0), 0.0, Vector2(s, s))
	canvas.draw_texture_rect_region(atlas, dst, src, Color(0, 0, 0, 0.28))
	canvas.draw_set_transform(pos, 0.0, Vector2(s, s))
	canvas.draw_texture_rect_region(atlas, dst, src)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
