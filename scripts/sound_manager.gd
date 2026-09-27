extends Node
## Procedurally synthesised sound effects played through a fixed voice pool
## (no node allocation per sound). Positional voices give stereo panning.

const RATE := 22050
const VOICES_2D := 28
const VOICES_UI := 6

var _streams := {}
var _voices_2d: Array[AudioStreamPlayer2D] = []
var _voices_ui: Array[AudioStreamPlayer] = []
var _next_2d := 0
var _next_ui := 0
var _last_played := {}   # name -> msec, throttles identical sounds in one burst

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Firefights stack dozens of sounds: keep the master bus from clipping.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	limiter.pre_gain_db = -2.0
	AudioServer.add_bus_effect(0, limiter)
	for i in VOICES_2D:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 3400.0
		p.attenuation = 0.8
		p.panning_strength = 0.6
		add_child(p)
		_voices_2d.append(p)
	for i in VOICES_UI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices_ui.append(p)
	_build_library()

## Plays a named sound. With a position it is spatialised, otherwise global.
func play(sound: String, pos := Vector2.INF, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 28:
		return
	_last_played[sound] = now
	var jitter := randf_range(0.94, 1.06) * pitch
	if pos == Vector2.INF:
		var v := _voices_ui[_next_ui]
		_next_ui = (_next_ui + 1) % VOICES_UI
		v.stream = stream
		v.volume_db = volume_db
		v.pitch_scale = jitter
		v.play()
	else:
		var p := _voices_2d[_next_2d]
		_next_2d = (_next_2d + 1) % VOICES_2D
		p.stream = stream
		p.global_position = pos
		p.volume_db = volume_db
		p.pitch_scale = jitter
		p.play()

# ---------------------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------------------

func _build_library() -> void:
	# name: [duration, layers...]; each layer is a Dictionary understood by _render.
	_streams["pistol"]   = _mix(0.16, [
		{"noise": 0.8, "lp0": 9000.0, "lp1": 1200.0, "decay": 5.0},
		{"tone": 190.0, "tone1": 60.0, "amp": 0.6, "decay": 6.0},
	])
	_streams["smg"]      = _mix(0.1, [
		{"noise": 0.7, "lp0": 7000.0, "lp1": 1500.0, "decay": 6.0},
		{"tone": 160.0, "tone1": 70.0, "amp": 0.45, "decay": 7.0},
	])
	_streams["rifle"]    = _mix(0.18, [
		{"noise": 0.85, "lp0": 8000.0, "lp1": 900.0, "decay": 4.5},
		{"tone": 140.0, "tone1": 45.0, "amp": 0.7, "decay": 5.0},
	])
	_streams["minigun"]  = _mix(0.08, [
		{"noise": 0.6, "lp0": 6000.0, "lp1": 1800.0, "decay": 5.0},
		{"tone": 120.0, "tone1": 60.0, "amp": 0.4, "decay": 6.0},
	])
	_streams["shotgun"]  = _mix(0.42, [
		{"noise": 1.0, "lp0": 5000.0, "lp1": 300.0, "decay": 3.0},
		{"tone": 110.0, "tone1": 35.0, "amp": 0.9, "decay": 3.5},
	])
	_streams["sniper"]   = _mix(0.6, [
		{"noise": 1.0, "lp0": 11000.0, "lp1": 400.0, "decay": 3.5},
		{"tone": 95.0, "tone1": 30.0, "amp": 1.0, "decay": 2.5},
		{"tone": 2400.0, "tone1": 1800.0, "amp": 0.08, "decay": 8.0},
	])
	_streams["rail"]     = _mix(0.55, [
		{"tone": 1400.0, "tone1": 180.0, "amp": 0.5, "decay": 2.2, "wave": "saw"},
		{"noise": 0.5, "lp0": 9000.0, "lp1": 2000.0, "decay": 4.0},
		{"tone": 80.0, "tone1": 40.0, "amp": 0.8, "decay": 3.0},
	])
	_streams["rocket"]   = _mix(0.5, [
		{"noise": 0.9, "lp0": 2500.0, "lp1": 600.0, "decay": 1.8},
		{"tone": 90.0, "tone1": 50.0, "amp": 0.6, "decay": 2.5},
	])
	_streams["launcher"] = _mix(0.28, [
		{"noise": 0.5, "lp0": 1800.0, "lp1": 400.0, "decay": 4.0},
		{"tone": 130.0, "tone1": 60.0, "amp": 0.9, "decay": 4.0},
	])
	_streams["throw"]    = _mix(0.14, [
		{"noise": 0.5, "lp0": 1500.0, "lp1": 4000.0, "decay": 2.0, "attack": 0.3},
	])
	_streams["explosion"] = _mix(1.1, [
		{"noise": 1.0, "lp0": 4000.0, "lp1": 120.0, "decay": 2.2},
		{"tone": 70.0, "tone1": 25.0, "amp": 1.0, "decay": 1.8},
		{"noise": 0.35, "lp0": 800.0, "lp1": 200.0, "decay": 1.0},
	])
	_streams["hit"]      = _mix(0.09, [
		{"noise": 0.7, "lp0": 2500.0, "lp1": 700.0, "decay": 5.0},
		{"tone": 240.0, "tone1": 120.0, "amp": 0.5, "decay": 6.0},
	])
	_streams["headshot"] = _mix(0.28, [
		{"tone": 1760.0, "tone1": 1760.0, "amp": 0.35, "decay": 4.0},
		{"tone": 2640.0, "tone1": 2640.0, "amp": 0.2, "decay": 5.0},
		{"noise": 0.4, "lp0": 3000.0, "lp1": 800.0, "decay": 8.0},
	])
	_streams["hitmark"]  = _mix(0.05, [
		{"tone": 1300.0, "tone1": 1100.0, "amp": 0.3, "decay": 6.0, "wave": "square"},
	])
	_streams["kill"]     = _mix(0.3, [
		{"tone": 880.0, "tone1": 880.0, "amp": 0.25, "decay": 3.0, "wave": "square", "end": 0.45},
		{"tone": 1320.0, "tone1": 1320.0, "amp": 0.25, "decay": 3.0, "wave": "square", "start": 0.4},
	])
	_streams["death"]    = _mix(0.5, [
		{"noise": 0.8, "lp0": 1500.0, "lp1": 200.0, "decay": 2.5},
		{"tone": 200.0, "tone1": 50.0, "amp": 0.7, "decay": 2.0},
	])
	_streams["pickup"]   = _mix(0.22, [
		{"tone": 520.0, "tone1": 1040.0, "amp": 0.3, "decay": 2.0, "wave": "square"},
	])
	_streams["health"]   = _mix(0.35, [
		{"tone": 660.0, "tone1": 660.0, "amp": 0.3, "decay": 2.0, "end": 0.4},
		{"tone": 880.0, "tone1": 880.0, "amp": 0.3, "decay": 2.0, "start": 0.3, "end": 0.7},
		{"tone": 1320.0, "tone1": 1320.0, "amp": 0.3, "decay": 2.0, "start": 0.6},
	])
	_streams["reload"]   = _mix(0.12, [
		{"noise": 0.6, "lp0": 5000.0, "lp1": 3000.0, "decay": 9.0},
		{"tone": 900.0, "tone1": 600.0, "amp": 0.25, "decay": 9.0, "wave": "square"},
	])
	_streams["reload_done"] = _mix(0.14, [
		{"noise": 0.6, "lp0": 6000.0, "lp1": 2500.0, "decay": 8.0},
		{"tone": 500.0, "tone1": 400.0, "amp": 0.3, "decay": 8.0, "wave": "square", "start": 0.4},
	])
	_streams["empty"]    = _mix(0.06, [
		{"tone": 1800.0, "tone1": 1500.0, "amp": 0.25, "decay": 10.0, "wave": "square"},
	])
	_streams["swap"]     = _mix(0.1, [
		{"noise": 0.5, "lp0": 4000.0, "lp1": 2000.0, "decay": 6.0},
	])
	_streams["jump"]     = _mix(0.12, [
		{"noise": 0.35, "lp0": 900.0, "lp1": 300.0, "decay": 4.0},
	])
	_streams["rope_fire"] = _mix(0.14, [
		{"noise": 0.5, "lp0": 6000.0, "lp1": 2000.0, "decay": 3.0},
		{"tone": 900.0, "tone1": 1500.0, "amp": 0.15, "decay": 3.0, "wave": "saw"},
	])
	_streams["rope_hit"] = _mix(0.1, [
		{"tone": 1600.0, "tone1": 1200.0, "amp": 0.3, "decay": 7.0, "wave": "square"},
		{"noise": 0.5, "lp0": 5000.0, "lp1": 1500.0, "decay": 8.0},
	])
	_streams["gore"] = _mix(0.3, [
		{"noise": 0.9, "lp0": 1400.0, "lp1": 250.0, "decay": 3.0},
		{"tone": 120.0, "tone1": 60.0, "amp": 0.5, "decay": 4.0},
	])
	_streams["baa"] = _mix(0.42, [
		{"tone": 420.0, "tone1": 360.0, "amp": 0.35, "decay": 1.2, "wave": "saw", "attack": 0.1, "vibrato": 28.0},
		{"tone": 840.0, "tone1": 720.0, "amp": 0.12, "decay": 1.5, "wave": "saw", "attack": 0.1, "vibrato": 28.0},
		{"noise": 0.15, "lp0": 3000.0, "lp1": 1500.0, "decay": 2.0},
	])
	_streams["hallelujah"] = _mix(1.3, [
		{"tone": 440.0, "tone1": 440.0, "amp": 0.22, "decay": 0.6, "wave": "saw", "attack": 0.15, "vibrato": 6.0},
		{"tone": 554.0, "tone1": 554.0, "amp": 0.18, "decay": 0.6, "wave": "saw", "attack": 0.15, "vibrato": 6.0},
		{"tone": 659.0, "tone1": 659.0, "amp": 0.18, "decay": 0.6, "wave": "saw", "attack": 0.15, "vibrato": 6.0},
		{"tone": 880.0, "tone1": 880.0, "amp": 0.12, "decay": 0.6, "wave": "sine", "attack": 0.15, "vibrato": 6.0},
	])
	_streams["siren"] = _mix(1.0, [
		{"tone": 500.0, "tone1": 900.0, "amp": 0.25, "decay": 0.4, "wave": "saw", "attack": 0.05},
	])
	_streams["step"]     = _mix(0.06, [
		{"noise": 0.5, "lp0": 1200.0, "lp1": 300.0, "decay": 7.0},
	])
	_streams["land"]     = _mix(0.12, [
		{"noise": 0.5, "lp0": 700.0, "lp1": 150.0, "decay": 5.0},
		{"tone": 90.0, "tone1": 50.0, "amp": 0.4, "decay": 6.0},
	])
	_streams["jet"]      = _mix(0.14, [
		{"noise": 0.45, "lp0": 1400.0, "lp1": 900.0, "decay": 0.6, "attack": 0.2},
	])
	_streams["bounce"]   = _mix(0.07, [
		{"tone": 700.0, "tone1": 500.0, "amp": 0.25, "decay": 8.0},
		{"noise": 0.3, "lp0": 3000.0, "lp1": 1000.0, "decay": 9.0},
	])
	_streams["ricochet"] = _mix(0.08, [
		{"noise": 0.4, "lp0": 7000.0, "lp1": 3000.0, "decay": 9.0},
	])
	_streams["spawn"]    = _mix(0.4, [
		{"tone": 300.0, "tone1": 900.0, "amp": 0.25, "decay": 1.5, "wave": "saw"},
	])
	_streams["ui_move"]  = _mix(0.05, [
		{"tone": 900.0, "tone1": 900.0, "amp": 0.2, "decay": 6.0, "wave": "square"},
	])
	_streams["ui_ok"]    = _mix(0.2, [
		{"tone": 600.0, "tone1": 1200.0, "amp": 0.25, "decay": 2.0, "wave": "square"},
	])
	_streams["announce"] = _mix(0.5, [
		{"tone": 220.0, "tone1": 220.0, "amp": 0.3, "decay": 1.5, "wave": "saw"},
		{"tone": 330.0, "tone1": 330.0, "amp": 0.2, "decay": 1.5, "wave": "saw"},
		{"tone": 440.0, "tone1": 440.0, "amp": 0.2, "decay": 1.5, "wave": "square", "start": 0.15},
	])

func _mix(duration: float, layers: Array) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for layer in layers:
		_render(buf, layer)
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

func _render(buf: PackedFloat32Array, l: Dictionary) -> void:
	var n := buf.size()
	var start := int(float(l.get("start", 0.0)) * n)
	var end := int(float(l.get("end", 1.0)) * n)
	var count := maxi(end - start, 1)
	var decay: float = l.get("decay", 3.0)
	var attack: float = l.get("attack", 0.0)
	var noise_amp: float = l.get("noise", 0.0)
	var tone_amp: float = l.get("amp", 0.0) if l.has("tone") else 0.0
	var f0: float = l.get("tone", 0.0)
	var f1: float = l.get("tone1", f0)
	var lp0: float = l.get("lp0", 8000.0)
	var lp1: float = l.get("lp1", lp0)
	var wave: String = l.get("wave", "sine")
	var vibrato: float = l.get("vibrato", 0.0)
	var phase := 0.0
	var lp := 0.0
	for i in count:
		var t := float(i) / count
		var env := pow(1.0 - t, decay)
		if attack > 0.0 and t < attack:
			env *= t / attack
		var s := 0.0
		if noise_amp > 0.0:
			var cutoff := lerpf(lp0, lp1, t)
			var a := 1.0 - exp(-TAU * cutoff / RATE)
			lp += a * (randf() * 2.0 - 1.0 - lp)
			s += lp * noise_amp * 1.6
		if tone_amp > 0.0:
			var vib := sin(TAU * vibrato * float(i) / RATE) * 0.03 if vibrato > 0.0 else 0.0
			phase += lerpf(f0, f1, t) * (1.0 + vib) / RATE
			var p := fmod(phase, 1.0)
			match wave:
				"square": s += (1.0 if p < 0.5 else -1.0) * tone_amp * 0.5
				"saw":    s += (p * 2.0 - 1.0) * tone_amp * 0.6
				_:        s += sin(p * TAU) * tone_amp
		buf[start + i] += s * env
