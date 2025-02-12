extends Node2D

@export var GreenLight : bool = true
signal LightChanged

func wait(seconds):
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	while true:
		var WaitTime = randf_range(3.0, 6.0)
		await wait(WaitTime)
		GreenLight = !GreenLight
		emit_signal("LightChanged")
