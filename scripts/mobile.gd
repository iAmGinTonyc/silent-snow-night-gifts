extends Node
## Телефон и планшет в веб-сборке: пока устройство стоит вертикально, страница (web/shell.html) просит
## повернуть его, а игра стоит на паузе, чтобы клиенты не теряли терпение. Флаг window.__ssngPortrait
## ставит страница; здесь он проверяется четыре раза в секунду. На компьютере ничего не делает.

var blocked := false
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var portrait := bool(JavaScriptBridge.eval("window.__ssngPortrait === true", true))
	if portrait == blocked:
		return
	blocked = portrait
	get_tree().paused = portrait
	JavaScriptBridge.eval("window.__ssngPaused = %s" % ("true" if portrait else "false"), true)   # для проверки со страницы
