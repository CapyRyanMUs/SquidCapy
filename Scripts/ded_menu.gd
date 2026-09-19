extends Control

var TargetScene = "res://Cenas/main_scene.tscn"

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(TargetScene)
