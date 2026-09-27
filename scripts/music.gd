extends Node
## Procedural soundtrack. Two looping tracks (menu and combat) are synthesised
## on a worker thread at startup so the game never hitches, then cross-faded.

const RATE := 22050

var enabled := true
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _tracks := {}          # name -> AudioStreamWAV
var _wanted := ""
var _pending := {}         # name -> task id
var _mutex := Mutex.new()
var _results := {}         # name -> PackedByteArray

const BASE_DB := -9.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	for p in [_player_a, _player_b]:
		p.volume_db = -80.0
		add_child(p)
	_active = _player_a
	for track in ["menu", "combat"]:
		var name_copy: String = track
		_pending[track] = WorkerThreadPool.add_task(func(): _build(name_copy))

func _exit_tree() -> void:
	# Never quit while a worker is still writing into this node.
	for track in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(_pending[track])
	_pending.clear()

## Switch to a track ("menu", "combat" or "" for silence) with a cross-fade.
func play(track: String) -> void:
	_wanted = track
	_apply()

func set_enabled(on: bool) -> void:
	enabled = on
	_apply()

func _process(_delta: float) -> void:
	for track in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[track]):
			WorkerThreadPool.wait_for_task_completion(_pending[track])
			_pending.erase(track)
			_mutex.lock()
			var data: PackedByteArray = _results[track]
			_mutex.unlock()
			var s := AudioStreamWAV.new()
			s.format = AudioStreamWAV.FORMAT_16_BITS
			s.mix_rate = RATE
			s.data = data
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = data.size() / 2
			_tracks[track] = s
			if track == _wanted:
				_apply()

func _apply() -> void:
	var stream: AudioStreamWAV = _tracks.get(_wanted) if enabled else null
	if stream != null and _active.stream == stream and _active.playing:
		return
	var old := _active
	var new := _player_b if _active == _player_a else _player_a
	_fade(old, -80.0, true)
	if stream == null:
		return
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	_fade(new, BASE_DB, false)
	_active = new

func _fade(p: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, 1.2)
	if stop_after:
		tw.tween_callback(p.stop)

# --------------------------------------------------------------------------
# Synthesis (runs on a worker thread; touches no nodes)
# --------------------------------------------------------------------------

const A2 := 110.0

func _note(semitones_from_a2: float) -> float:
	return A2 * pow(2.0, semitones_from_a2 / 12.0)

func _build(track: String) -> void:
	var buf: PackedFloat32Array
	if track == "menu":
		buf = _render_track(92.0, 0.0, [
			[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5],   # Am F C G
		], false)
	else:
		buf = _render_track(128.0, 1.0, [
			[0, 3, 7], [0, 3, 7], [-4, 0, 3], [-2, 2, 5],     # Am Am F G
			[0, 3, 7], [3, 7, 10], [-4, 0, 3], [-5, -1, 2],   # Am C F E
		], true)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.85 / peak
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	_mutex.lock()
	_results[track] = data
	_mutex.unlock()

## Renders one loop: 2 bars per chord, 4/4. `drive` 0..1 scales the drums.
func _render_track(bpm: float, drive: float, chords: Array, arp: bool) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bars := chords.size() * 2
	var total := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var sixteenth := beat / 4.0
	var steps := bars * 16
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if drive > 0.5 else 3

	for step in steps:
		var t0 := int(step * sixteenth * RATE)
		var bar := step / 16
		var in_bar := step % 16
		var chord: Array = chords[(bar / 2) % chords.size()]
		# drums
		if drive > 0.0:
			if in_bar % 4 == 0 or (in_bar == 10 and bar % 2 == 1):
				_kick(buf, t0, 0.9 * drive)
			if in_bar == 4 or in_bar == 12:
				_snare(buf, t0, 0.5 * drive, rng)
			if in_bar % 2 == 0:
				_hat(buf, t0, (0.12 if in_bar % 4 == 2 else 0.07) * drive, rng)
		else:
			if in_bar == 0 or in_bar == 8:
				_kick(buf, t0, 0.35)
			if in_bar % 4 == 2:
				_hat(buf, t0, 0.03, rng)
		# bass: driving eighths in combat, long notes in the menu
		var root: float = _note(chord[0] - 12.0 if chord[0] > 2 else chord[0])
		if drive > 0.0:
			if in_bar % 2 == 0:
				var f := root * (2.0 if in_bar in [6, 14] else 1.0)
				_tone(buf, t0, sixteenth * 1.8, f, 0.28, "saw", 1200.0, 3.0)
		elif in_bar == 0:
			_tone(buf, t0, beat * 4.0, root, 0.25, "sine", 800.0, 0.8)
		# pad: whole chord at the start of every 2 bars
		if in_bar == 0 and bar % 2 == 0:
			for n in chord:
				_tone(buf, t0, beat * 8.0, _note(n + 12.0), 0.07 if drive > 0.0 else 0.1, "saw", 900.0, 0.4, 0.25)
		# arpeggio lead
		if arp and bar >= 4 or (not arp and bar % 2 == 1):
			if in_bar % (2 if arp else 4) == 0:
				var idx := (in_bar / (2 if arp else 4)) % 3
				var up := 24.0 if (in_bar / 6) % 2 == 0 else 36.0
				_tone(buf, t0, sixteenth * 1.6, _note(chord[idx] + up), 0.06, "square" if arp else "sine", 3000.0, 4.0)
	return buf

func _tone(buf: PackedFloat32Array, start: int, dur: float, freq: float, amp: float, wave: String, cutoff: float, decay: float, attack := 0.01) -> void:
	var n := int(dur * RATE)
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var size := buf.size()
	var att := maxi(1, int(attack * n))
	for i in n:
		var t := float(i) / n
		var env := pow(1.0 - t, decay) * minf(1.0, float(i) / att)
		phase = fmod(phase + freq / RATE, 1.0)
		phase2 = fmod(phase2 + freq * 1.006 / RATE, 1.0)
		var s: float
		match wave:
			"saw":    s = (phase * 2.0 - 1.0) * 0.5 + (phase2 * 2.0 - 1.0) * 0.5
			"square": s = 1.0 if phase < 0.5 else -1.0
			_:        s = sin(phase * TAU)
		lp += a * (s - lp)
		buf[(start + i) % size] += lp * amp * env

func _kick(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var n := int(0.22 * RATE)
	var phase := 0.0
	var size := buf.size()
	for i in n:
		var t := float(i) / n
		phase += lerpf(140.0, 42.0, sqrt(t)) / RATE
		buf[(start + i) % size] += sin(phase * TAU) * amp * pow(1.0 - t, 2.5)

func _snare(buf: PackedFloat32Array, start: int, amp: float, rng: RandomNumberGenerator) -> void:
	var n := int(0.16 * RATE)
	var lp := 0.0
	var phase := 0.0
	var size := buf.size()
	for i in n:
		var t := float(i) / n
		var noise := rng.randf_range(-1.0, 1.0)
		lp += 0.35 * (noise - lp)
		phase += 185.0 / RATE
		var s := (noise - lp) * 0.8 + sin(phase * TAU) * 0.5 * (1.0 - t)
		buf[(start + i) % size] += s * amp * pow(1.0 - t, 3.0)

func _hat(buf: PackedFloat32Array, start: int, amp: float, rng: RandomNumberGenerator) -> void:
	var n := int(0.05 * RATE)
	var lp := 0.0
	var size := buf.size()
	for i in n:
		var t := float(i) / n
		var noise := rng.randf_range(-1.0, 1.0)
		lp += 0.6 * (noise - lp)
		buf[(start + i) % size] += (noise - lp) * amp * pow(1.0 - t, 4.0)
