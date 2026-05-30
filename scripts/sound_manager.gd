extends Node

var _shoot_stream: AudioStreamWAV
var _hit_stream:   AudioStreamWAV
var _reload_stream: AudioStreamWAV
var _death_stream: AudioStreamWAV

func _ready() -> void:
	_shoot_stream  = _make_noise(0.07, 0.6, 1.8)
	_hit_stream    = _make_noise(0.12, 0.4, 0.9)
	_reload_stream = _make_tone(320.0, 0.08, 0.3)
	_death_stream  = _make_noise(0.35, 0.5, 0.4)

func play_shoot() -> void:  _play(_shoot_stream, -6.0)
func play_hit()   -> void:  _play(_hit_stream,   -8.0)
func play_reload() -> void: _play(_reload_stream, -4.0)
func play_death()  -> void: _play(_death_stream,  -4.0)

func _play(stream: AudioStreamWAV, db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = db
	player.autoplay = true
	add_child(player)
	player.finished.connect(player.queue_free)

func _make_noise(duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var rate    := 22050
	var samples := int(rate * duration)
	var data    := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var env    := pow(1.0 - float(i) / samples, decay)
		var sample := int((randf() * 2.0 - 1.0) * env * volume * 32767)
		data.encode_s16(i * 2, clamp(sample, -32767, 32767))
	var s        := AudioStreamWAV.new()
	s.format     = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate   = rate
	s.stereo     = false
	s.data       = data
	return s

func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate    := 22050
	var samples := int(rate * duration)
	var data    := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var env    := pow(1.0 - float(i) / samples, 1.5)
		var sample := int(sin(TAU * freq * float(i) / rate) * env * volume * 32767)
		data.encode_s16(i * 2, clamp(sample, -32767, 32767))
	var s        := AudioStreamWAV.new()
	s.format     = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate   = rate
	s.stereo     = false
	s.data       = data
	return s
