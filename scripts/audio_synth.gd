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
	"paper_pull": -12.0, "paper_rustle": -16.0, "cut": -11.0, "snip": -12.0, "fold": -10.0, "crumple": -13.0,
	"tape": -13.0, "tape_stick": -15.0, "stick": -16.0, "ribbon": -15.0, "ruler": -13.0, "roll": -14.0, "bell": -11.0, "coin": -14.0, "purr": -18.0,
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
	var st = sfx[sfx_name]
	if st is Array:
		st = st[_rng.randi() % st.size()]
	p.stream = st
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
	# бумага, ножницы, скотч, лента, линейка: несколько вариантов, чтобы звук не повторялся
	sfx["paper_pull"] = _variants(3, _g_pull)
	sfx["paper_rustle"] = _variants(4, _g_rustle)
	sfx["fold"] = _variants(3, _g_fold)
	sfx["snip"] = _variants(2, _g_snip)
	sfx["cut"] = _variants(2, _g_cut)
	sfx["crumple"] = _variants(2, _g_crumple)
	sfx["tape"] = _variants(2, _g_tape_peel)
	sfx["tape_stick"] = _variants(2, _g_tape_stick)
	sfx["stick"] = _gen(0.1, _fn_stick)
	sfx["ribbon"] = _variants(2, _g_silk)
	sfx["ruler"] = _variants(2, _g_ruler)
	sfx["roll"] = _variants(2, _g_roll)
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


func _fn_stick(t: float, _p: float) -> float:
	return sin(TAU * 560.0 * t) * exp(-t * 55.0)


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


# --- Бумага, ножницы, скотч, лента, линейка: синтез из шума, фильтров и микроимпульсов -----

func _variants(count: int, builder: Callable) -> Array:
	var out: Array = []
	for i in count:
		out.append(builder.call())
	return out


## Строит звук: fn заполняет массив отсчётов, дальше нормализация пика и мягкие вход и выход.
func _synth(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	fn.call(s)
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(s[i]))
	var k := PEAK / peak
	var fade_in := int(0.003 * RATE)
	var fade_out := int(0.025 * RATE)
	for i in n:
		var g := k
		if i < fade_in:
			g *= float(i) / float(fade_in)
		if i > n - fade_out:
			g *= float(n - i) / float(fade_out)
		s[i] *= g
	return _make_wav(s)


## Короткий щелчок-хруст: затухающий шумовой импульс с резким краем (разность соседних отсчётов).
func _click(s: PackedFloat32Array, at: int, amp: float, tau_ms: float, tone: float = 0.0) -> void:
	var len := int(tau_ms * 6.0 * 0.001 * RATE)
	var prev := 0.0
	for j in len:
		var i := at + j
		if i >= s.size():
			return
		var x := _noise()
		var env := exp(-float(j) / (tau_ms * 0.001 * RATE))
		s[i] += (x - prev * 0.6) * amp * env
		if tone > 0.0:
			s[i] += sin(TAU * tone * float(j) / float(RATE)) * amp * 0.5 * env
		prev = x


## Рассыпает по звуку случайные хрусткие щелчки: так шуршит мнущаяся бумага.
func _crackles(s: PackedFloat32Array, per_sec: float, amp_lo: float, amp_hi: float, shape: float = 1.0) -> void:
	var n := s.size()
	var count := int(per_sec * float(n) / float(RATE))
	for k in count:
		var at := int(pow(_rng.randf(), shape) * float(n))
		_click(s, at, _rng.randf_range(amp_lo, amp_hi), _rng.randf_range(0.7, 2.6), _rng.randf_range(0.0, 1.0) * 3200.0)


func _g_pull() -> AudioStreamWAV:
	return _synth(0.75, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp1 := 0.0
		var lp2 := 0.0
		var wander := 0.0
		for i in n:
			var p := float(i) / float(n)
			var x := _noise()
			lp1 += 0.42 * (x - lp1)
			lp2 += 0.05 * (lp1 - lp2)
			wander += 0.0018 * (_noise() - wander)
			var am := clampf(0.5 + 7.0 * wander, 0.08, 1.2)
			s[i] = (lp1 - lp2) * am * pow(sin(p * PI), 0.6) * 0.9
		_crackles(s, 34.0, 0.12, 0.5))


func _g_rustle() -> AudioStreamWAV:
	return _synth(0.3, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp1 := 0.0
		var lp2 := 0.0
		for i in n:
			var p := float(i) / float(n)
			var x := _noise()
			lp1 += 0.4 * (x - lp1)
			lp2 += 0.07 * (lp1 - lp2)
			s[i] = (lp1 - lp2) * 0.35 * sin(p * PI)
		_crackles(s, 110.0, 0.2, 0.8))


## Складка бумаги: резкий щелчок, хруст и тихий глухой хлопок.
func _g_fold() -> AudioStreamWAV:
	return _synth(0.42, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp1 := 0.0
		var lp2 := 0.0
		for i in n:
			var t := float(i) / float(RATE)
			var x := _noise()
			lp1 += 0.38 * (x - lp1)
			lp2 += 0.09 * (lp1 - lp2)
			var env := exp(-t * 17.0)
			s[i] = (lp1 - lp2) * env * 1.4
			s[i] += sin(TAU * (118.0 - 40.0 * t) * t) * exp(-t * 26.0) * 0.45
		_click(s, 0, 1.4, 0.9, 2400.0)
		_click(s, int(0.012 * RATE), 0.9, 1.6)
		_crackles(s, 50.0, 0.2, 0.7, 2.2))


## Один чик ножниц: два металлических лезвия и хруст бумаги.
func _g_snip() -> AudioStreamWAV:
	return _synth(0.2, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var f1 := _rng.randf_range(2900.0, 3500.0)
		var f2 := _rng.randf_range(5200.0, 6200.0)
		for i in n:
			var t := float(i) / float(RATE)
			s[i] = sin(TAU * f1 * t) * exp(-t * 55.0) * 0.55 + sin(TAU * f2 * t) * exp(-t * 80.0) * 0.28
		_click(s, 0, 1.2, 0.5, 4200.0)
		_click(s, int(0.018 * RATE), 0.55, 2.2)
		_crackles(s, 80.0, 0.12, 0.4, 1.6))


## Разрез: чик и второй, тише (ножницы смыкаются, и лист отваливается).
func _g_cut() -> AudioStreamWAV:
	return _synth(0.34, func(s: PackedFloat32Array) -> void:
		var f1 := _rng.randf_range(2900.0, 3400.0)
		for off in [0.0, 0.11]:
			var o: float = off
			var amp := 1.0 if o == 0.0 else 0.6
			var base := int(o * RATE)
			for j in int(0.1 * RATE):
				var t := float(j) / float(RATE)
				if base + j < s.size():
					s[base + j] += (sin(TAU * f1 * t) * exp(-t * 50.0) * 0.5 + sin(TAU * f1 * 1.8 * t) * exp(-t * 75.0) * 0.25) * amp
			_click(s, base, 1.2 * amp, 0.5, 4200.0)
			_click(s, base + int(0.02 * RATE), 0.6 * amp, 2.4)
		_crackles(s, 70.0, 0.1, 0.4, 1.2))


func _g_crumple() -> AudioStreamWAV:
	return _synth(0.7, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp := 0.0
		for i in n:
			var p := float(i) / float(n)
			lp += 0.05 * (_noise() - lp)
			s[i] = lp * 0.5 * exp(-p * 3.0)
		_crackles(s, 260.0, 0.2, 1.0, 1.7))


## Скотч отрывают от рулона: рваное «зззит» с растущим тоном.
func _g_tape_peel() -> AudioStreamWAV:
	return _synth(0.5, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp := 0.0
		var phase := 0.0
		for i in n:
			var p := float(i) / float(n)
			var t := float(i) / float(RATE)
			var x := _noise()
			lp += (0.1 + 0.3 * p) * (x - lp)
			phase += TAU * (70.0 + 90.0 * p) / float(RATE)
			var teeth := maxf(sin(phase), 0.0)
			teeth = pow(teeth, 0.7)
			s[i] = lp * (0.25 + 0.75 * teeth) * pow(sin(minf(p * 1.25, 1.0) * PI * 0.5 + 0.0), 1.0) * (1.0 - 0.6 * p)
		_crackles(s, 40.0, 0.1, 0.35))


func _g_tape_stick() -> AudioStreamWAV:
	return _synth(0.12, func(s: PackedFloat32Array) -> void:
		for i in s.size():
			var t := float(i) / float(RATE)
			s[i] = sin(TAU * 170.0 * t) * exp(-t * 38.0) * 0.5
		_click(s, 0, 0.7, 1.4)
		_click(s, int(0.02 * RATE), 0.3, 2.0))


## Атласная лента скользит по бумаге: гладкий, мягкий шелест.
func _g_silk() -> AudioStreamWAV:
	return _synth(0.55, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp1 := 0.0
		var lp2 := 0.0
		var wander := 0.0
		for i in n:
			var p := float(i) / float(n)
			lp1 += 0.3 * (_noise() - lp1)
			lp2 += 0.12 * (lp1 - lp2)
			wander += 0.0006 * (_noise() - wander)
			s[i] = (lp1 - lp2) * clampf(0.7 + 9.0 * wander, 0.25, 1.1) * pow(sin(p * PI), 1.4) * 0.8
		_crackles(s, 8.0, 0.03, 0.1))


## Деревянная линейка: два глухих «тук» разной высоты.
func _g_ruler() -> AudioStreamWAV:
	return _synth(0.22, func(s: PackedFloat32Array) -> void:
		var f := _rng.randf_range(760.0, 900.0)
		for off in [0.0, 0.085]:
			var o: float = off
			var base := int(o * RATE)
			var ff := f if o == 0.0 else f * 0.78
			for j in int(0.1 * RATE):
				var t := float(j) / float(RATE)
				if base + j < s.size():
					s[base + j] += (sin(TAU * ff * t) * exp(-t * 48.0) + sin(TAU * ff * 2.4 * t) * exp(-t * 90.0) * 0.4) * (1.0 if o == 0.0 else 0.7)
			_click(s, base, 0.5, 0.9))


## Рулон берут со стойки: шорох и мягкий глухой стук.
func _g_roll() -> AudioStreamWAV:
	return _synth(0.28, func(s: PackedFloat32Array) -> void:
		var n := s.size()
		var lp := 0.0
		for i in n:
			var t := float(i) / float(RATE)
			var p := float(i) / float(n)
			lp += 0.2 * (_noise() - lp)
			s[i] = lp * 0.5 * sin(p * PI) + sin(TAU * 95.0 * t) * exp(-t * 20.0) * 0.45
		_crackles(s, 60.0, 0.1, 0.4))
