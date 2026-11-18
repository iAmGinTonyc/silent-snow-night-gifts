extends Node
## Шрифт игры: Londrina Solid (лицензия SIL OFL, см. fonts/OFL.txt). Обычный остаётся основным шрифтом
## всего интерфейса, жирный (BLACK) берут заголовки. Автозагрузка выставляет его раньше всех экранов.

const REGULAR := preload("res://fonts/LondrinaSolid-Regular.ttf")
const BLACK := preload("res://fonts/LondrinaSolid-Black.ttf")


func _enter_tree() -> void:
	ThemeDB.fallback_font = REGULAR
