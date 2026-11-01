extends Node

signal shake_changed(screen_offset: Vector2)

@export var camera: Camera2D

const SOUNDS = [
	preload("res://assets/audio/small_explosion3.mp3"),
	preload("res://assets/audio/small_explosion2.mp3"),
	preload("res://assets/audio/small_explosion1.mp3"),
	preload("res://assets/audio/big explosion.mp3"),
]
const PROFILES = {
	4: {"interval": Vector2(10, 18), "strengths": [1, 1, 2], "volume": -16.0, "cutoff": 3500.0,
		"shake": [0.0, 2.0, 4.0, 8.0], "duration": 0.5, "big_duration": 0.9, "big_cooldown": 30.0},
	5: {"interval": Vector2(6, 14), "strengths": [1, 1, 2, 2, 2, 3], "volume": -11.0, "cutoff": 6500.0,
		"shake": [0.0, 3.0, 7.0, 16.0], "duration": 0.5, "big_duration": 1.1, "big_cooldown": 20.0},
	6: {"interval": Vector2(3, 7), "strengths": [1, 2, 2, 3], "volume": -8.0, "cutoff": 9000.0,
		"shake": [0.0, 6.0, 14.0, 28.0], "duration": 0.65, "big_duration": 1.35, "big_cooldown": 12.0},
	7: {"interval": Vector2(1.5, 4), "strengths": [2, 2, 3], "volume": -5.0, "cutoff": 12000.0,
		"shake": [0.0, 10.0, 22.0, 42.0], "duration": 0.8, "big_duration": 1.65, "big_cooldown": 7.0},
}

var day := 0
var countdown := 0.0
var _players: Array[AudioStreamPlayer] = []
var _filter: AudioEffectLowPassFilter
var _bus_name: StringName
var _random := RandomNumberGenerator.new()
var _big_cooldown := 0.0
var _shake_left := 0.0
var _shake_duration := 0.0
var _shake_pixels := 0.0


func _ready() -> void:
	# Update the camera before the separate, undithered text layer follows it.
	process_priority = -100
	_random.randomize()
	_bus_name = StringName("Bombardment_%d" % get_instance_id())
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, _bus_name)
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(bus, _filter)
	AudioServer.add_bus_effect(bus, AudioEffectLimiter.new())
	for sound in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = sound
		player.bus = _bus_name
		player.max_polyphony = 2
		add_child(player)
		_players.append(player)
	set_process(false)


func set_day(new_day: int) -> void:
	stop()
	day = new_day
	if not PROFILES.has(day):
		return
	_filter.cutoff_hz = PROFILES[day].cutoff
	countdown = _random.randf_range(1.5, 3.0)
	_big_cooldown = PROFILES[day].big_cooldown * 0.5
	set_process(true)


func stop() -> void:
	day = 0
	set_process(false)
	for player in _players:
		player.stop()
	_shake_left = 0.0
	_shake_pixels = 0.0
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
		camera.force_update_scroll()
	shake_changed.emit(Vector2.ZERO)


func _process(delta: float) -> void:
	countdown -= delta
	_big_cooldown = maxf(0.0, _big_cooldown - delta)
	if countdown <= 0.0:
		var choices: Array = PROFILES[day].strengths
		var strength: int = choices[_random.randi_range(0, choices.size() - 1)]
		if strength == 3 and _big_cooldown > 0.0:
			strength = 2
		_play_explosion(strength)
		var interval: Vector2 = PROFILES[day].interval
		countdown = _random.randf_range(interval.x, interval.y)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var decay := _shake_left / _shake_duration
		var motion := Vector2(_random.randf_range(-1, 1), _random.randf_range(-1, 1))
		# Offset is in world units; divide by zoom to keep the reading shake bounded in pixels.
		camera.offset = motion * _shake_pixels * decay * decay / camera.zoom
		camera.force_update_scroll()
		shake_changed.emit(camera.offset * camera.zoom)


func _play_explosion(strength: int) -> void:
	var player := _players[strength]
	player.volume_db = PROFILES[day].volume - (4.0 if strength == 3 else 0.0)
	player.pitch_scale = _random.randf_range(0.96, 1.03)
	player.play()
	if strength == 3:
		_big_cooldown = PROFILES[day].big_cooldown
	var pixels: float = PROFILES[day].shake[strength]
	var duration: float = PROFILES[day].big_duration if strength == 3 else PROFILES[day].duration
	if pixels > 0.0:
		_shake_pixels = maxf(pixels, _shake_pixels * _shake_left / maxf(_shake_duration, 0.001))
		_shake_duration = duration
		_shake_left = duration


func _exit_tree() -> void:
	for player in _players:
		player.stop()
	var bus := AudioServer.get_bus_index(_bus_name)
	if bus >= 0:
		AudioServer.remove_bus(bus)
