extends CanvasLayer
## Кинематографичный слой: плёночное зерно, царапины и ирис-переход между экранами.

const GRAIN_SHADER := """
shader_type canvas_item;
uniform float strength = 0.11;
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
void fragment() {
	float t = floor(TIME * 12.0);
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float n = hash(cell + vec2(t * 37.0, t * 17.0));
	float scratch = step(0.9985, hash(vec2(floor(FRAGCOORD.x / 2.0), t))) * 0.10;
	float a = abs(n - 0.5) * strength * 2.0 + scratch;
	vec3 col = n > 0.5 ? vec3(1.0, 0.97, 0.9) : vec3(0.0);
	COLOR = vec4(col, a);
}
"""

const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius = 1.1;
uniform vec2 center = vec2(0.5, 0.5);
void fragment() {
	vec2 p = (UV - center) * vec2(1.7778, 1.0);
	float d = length(p);
	COLOR = vec4(0.05, 0.03, 0.05, step(radius, d));
}
"""

var iris: ColorRect
var grain: ColorRect


func _ready() -> void:
	layer = 20
	grain = _make_rect(GRAIN_SHADER)
	add_child(grain)
	iris = _make_rect(IRIS_SHADER)
	iris.visible = false
	add_child(iris)


func _make_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 720)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r


func _set_radius(v: float) -> void:
	iris.material.set_shader_parameter("radius", v)


func iris_out(dur: float = 0.38, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	iris.material.set_shader_parameter("center", center)
	_set_radius(1.1)
	iris.visible = true
	var tw := create_tween()
	tw.tween_method(_set_radius, 1.1, 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished


func iris_in(dur: float = 0.38, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	iris.material.set_shader_parameter("center", center)
	_set_radius(0.0)
	iris.visible = true
	var tw := create_tween()
	tw.tween_method(_set_radius, 0.0, 1.1, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	iris.visible = false
