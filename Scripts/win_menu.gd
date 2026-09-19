extends Control


func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/main_scene.tscn")
