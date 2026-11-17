extends Node
## Автозагрузка AudioSynth: мягкие звуки, синтезированные в коде, и тихая «музыкальная шкатулка».
## Каждый звук нормализуется до одной пиковой громкости, а нужная тишина задаётся таблицей GAIN.

const RATE := 22050
const SFX_POOL := 10
const MUSIC_POOL := 6
const PEAK := 0.5
const MASTER_DB := -4.0

## Громкость каждого звука в дБ относительно нормализованного пика.
const GAIN := {
	"paper_pull": -13.0, "cut": -12.0, "fold": -12.0, "crumple": -16.0, "tape": -15.0,
	"stick": -16.0, "ribbon": -16.0, "bell": -11.0, "coin": -14.0, "purr": -18.0,
	"door": -13.0, "pop": -12.0, "dull": -18.0, "whoosh": -17.0, "pop_in": -15.0,
	"buy": -13.0, "spend": -17.0, "click": -18.0,
}

var sfx: Dictionary = {}
var notes: Array = []
var bass: Array = []

var _sfx_players: Array = []
var _music_players: Array = []
var _bass_player: AudioStreamPlayer
var _sfx_next := 0
var _music_next := 0
var _music_on := false
var _music_timer := 1.0
var _bass_timer := 0.5
var _bass_i := 0
var _rng := RandomNumberGenerator.new()
var _f1 := 0.0


func _ready() -> void:
	_rng.randomize()
	AudioServer.set_bus_volume_db(0, MASTER_DB)
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	for i in MUSIC_POOL:
		var q := AudioStreamPlayer.new()
		add_child(q)
		_music_players.append(q)
	_bass_player = AudioStreamPlayer.new()
	_bass_player.volume_db = -34.0
	add_child(_bass_player)
	_build_all()


## vol_db — добавка к таблице GAIN (обычно 0, можно чуть тише).
func play_sfx(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL
	p.stream = sfx[sfx_name]
	p.volume_db = float(GAIN.get(sfx_name, -14.0)) + minf(vol_db, 0.0)
	p.pitch_scale = pitch
	p.play()


func start_music() -> void:
	_music_on = true


func stop_music() -> void:
	_music_on = false


func _process(delta: float) -> void:
	if not _music_on or notes.is_empty():
		return
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = _rng.randf_range(0.7, 1.9)
		if _rng.randf() > 0.25:
			var p: AudioStreamPlayer = _music_players[_music_next]
			_music_next = (_music_next + 1) % MUSIC_POOL
			p.stream = notes[_rng.randi() % notes.size()]
			p.volume_db = _rng.randf_range(-33.0, -27.0)
			p.play()
	_bass_timer -= delta
	if _bass_timer <= 0.0:
		_bass_timer = 4.0
		_bass_player.stream = bass[_bass_i % bass.size()]
		_bass_i += 1
		_bass_player.play()


# --- Генерация -----------------------------------------------------------

func _build_all() -> void:
	sfx["paper_pull"] = _gen(0.5, _fn_paper_pull)
	sfx["cut"] = _gen(0.2, _fn_cut)
	sfx["fold"] = _gen(0.2, _fn_fold)
	sfx["crumple"] = _gen(0.45, _fn_crumple)
	sfx["tape"] = _gen(0.34, _fn_tape)
	sfx["stick"] = _gen(0.1, _fn_stick)
	sfx["ribbon"] = _gen(0.32, _fn_ribbon)
	sfx["bell"] = _gen(1.6, _fn_bell)
	sfx["coin"] = _gen(0.5, _fn_coin)
	sfx["purr"] = _gen(1.2, _fn_purr)
	sfx["door"] = _gen(1.0, _fn_door)
	sfx["pop"] = _gen(0.6, _fn_pop)
	sfx["dull"] = _gen(0.18, _fn_dull)
	sfx["whoosh"] = _gen(0.45, _fn_whoosh)
	sfx["pop_in"] = _gen(0.25, _fn_pop_in)
	sfx["buy"] = _gen(0.7, _fn_buy)
	sfx["spend"] = _gen(0.3, _fn_spend)
	sfx["click"] = _gen(0.08, _fn_click)
	for f in [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]:
		notes.append(_gen_note(f, 1.6))
	for f in [130.81, 110.0, 87.31, 98.0]:
		bass.append(_gen_pad(f, 2.6))


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Генерирует звук, нормализует пик, добавляет мягкие вход и выход (без щелчков).
func _gen(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	_f1 = 0.0
	var peak := 0.0001
	for i in n:
		var v: float = fn.call(float(i) / float(RATE), float(i) / float(n))
		s[i] = v
		peak = maxf(peak, absf(v))
	var k := PEAK / peak
	var fade_in := int(0.006 * RATE)
	var fade_out := int(0.02 * RATE)
	for i in n:
		var g := k
		if i < fade_in:
			g *= float(i) / float(fade_in)
		if i > n - fade_out:
			g *= float(n - i) / float(fade_out)
		s[i] *= g
	return _make_wav(s)


func _gen_note(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := minf(t / 0.012, 1.0) * exp(-t * 2.2)
		var v := sin(TAU * freq * t)
		v += 0.18 * sin(TAU * freq * 2.0 * t) * exp(-t * 3.0)
		s[i] = v * env * 0.4
	return _make_wav(s)


func _gen_pad(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := pow(sin(PI * t / dur), 1.8)
		s[i] = (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * env * 0.4
	return _make_wav(s)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _fn_paper_pull(t: float, p: float) -> float:
	_f1 += 0.10 * (_noise() - _f1)
	return _f1 * pow(sin(p * PI), 1.2) * (0.8 + 0.2 * sin(t * 50.0))


func _fn_cut(t: float, _p: float) -> float:
	var out := 0.0
	for off in [0.0, 0.09]:
		var tt: float = t - off
		if tt >= 0.0 and tt < 0.07:
			_f1 += 0.22 * (_noise() - _f1)
			out += _f1 * exp(-tt * 55.0) * 2.0 + sin(TAU * 700.0 * tt) * exp(-tt * 70.0) * 0.2
	return out


func _fn_fold(t: float, _p: float) -> float:
	_f1 += 0.08 * (_noise() - _f1)
	return _f1 * exp(-t * 18.0) * 2.0 + sin(TAU * 130.0 * t) * exp(-t * 22.0) * 0.5


func _fn_crumple(t: float, _p: float) -> float:
	_f1 += 0.18 * (_noise() - _f1)
	var burst := clampf(0.5 + 0.5 * sin(t * 38.0 + sin(t * 11.0) * 3.0), 0.0, 1.0)
	return _f1 * burst * exp(-t * 4.5)


func _fn_tape(t: float, p: float) -> float:
	_f1 += 0.14 * (_noise() - _f1)
	var m := 0.55 + 0.45 * sin(TAU * (34.0 + 20.0 * p) * t)
	return _f1 * m * pow(sin(p * PI), 0.8)


func _fn_stick(t: float, _p: float) -> float:
	return sin(TAU * 560.0 * t) * exp(-t * 55.0)


func _fn_ribbon(_t: float, p: float) -> float:
	_f1 += 0.07 * (_noise() - _f1)
	return _f1 * pow(sin(p * PI), 2.0)


func _fn_bell(t: float, _p: float) -> float:
	var v := sin(TAU * 659.25 * t) * exp(-t * 2.4)
	v += sin(TAU * 1318.5 * t) * exp(-t * 4.0) * 0.18
	v += sin(TAU * 1819.0 * t) * exp(-t * 6.0) * 0.06
	return v * minf(t / 0.006, 1.0)


func _fn_coin(t: float, _p: float) -> float:
	var v := sin(TAU * 1046.5 * t) * exp(-t * 7.0)
	if t > 0.06:
		var t2 := t - 0.06
		v += sin(TAU * 1568.0 * t2) * exp(-t2 * 7.0) * 0.8
	return v


func _fn_purr(t: float, p: float) -> float:
	_f1 += 0.04 * (_noise() - _f1)
	var m := 0.5 + 0.5 * sin(TAU * 22.0 * t)
	return (_f1 * 4.0 * m + sin(TAU * 58.0 * t) * 0.1 * m) * pow(sin(p * PI), 0.8)


func _fn_door(t: float, _p: float) -> float:
	var v := sin(TAU * 659.25 * t) * exp(-t * 3.2) * 0.7
	if t > 0.22:
		var t2 := t - 0.22
		v += sin(TAU * 880.0 * t2) * exp(-t2 * 3.2) * 0.7
	return v


func _fn_pop(t: float, _p: float) -> float:
	_f1 += 0.12 * (_noise() - _f1)
	return _f1 * exp(-t * 14.0) * 1.6 + sin(TAU * 85.0 * t) * exp(-t * 12.0) * 0.5


func _fn_dull(t: float, _p: float) -> float:
	return sin(TAU * 140.0 * t) * exp(-t * 26.0)


func _fn_whoosh(_t: float, p: float) -> float:
	_f1 += (0.04 + 0.16 * p) * (_noise() - _f1)
	return _f1 * pow(sin(p * PI), 1.5)


func _fn_pop_in(t: float, p: float) -> float:
	return sin(TAU * (300.0 + 320.0 * p) * t) * exp(-t * 14.0)


func _fn_buy(t: float, _p: float) -> float:
	var v := 0.0
	var freqs := [784.0, 987.8, 1318.5]
	for i in 3:
		var tt: float = t - float(i) * 0.09
		if tt > 0.0:
			var f: float = freqs[i]
			v += sin(TAU * f * tt) * exp(-tt * 6.0)
	return v


func _fn_spend(t: float, p: float) -> float:
	return sin(TAU * (520.0 - 160.0 * p) * t) * exp(-t * 11.0)


func _fn_click(t: float, _p: float) -> float:
	return sin(TAU * 480.0 * t) * exp(-t * 60.0)
