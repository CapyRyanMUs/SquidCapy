extends Node2D

@export var GreenLight : bool = true

var Players : Dictionary = {}

signal LightChanged

func wait(seconds):
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	await get_node("/root/MainScene/MenuOptionsControl").tree_exited
	while true:
		var WaitTime = randf_range(3.0, 6.0)
		await wait(WaitTime)
		GreenLight = !GreenLight
		emit_signal("LightChanged")
