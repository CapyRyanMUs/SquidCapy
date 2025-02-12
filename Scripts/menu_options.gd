extends Control

@export var MainNode : Node2D
@export var StartButton : Button
@export var BotNumbers : OptionButton
@export var Player : PackedScene
@export var Bot : PackedScene

@export var area_spawn : Area2D

func _ready() -> void:
	pass # Replace with function body.


func _on_start_button_pressed() -> void:
	var area_position = area_spawn.position
	var area_size = Vector2(2304 - 1936, 784 - 30)  # Largura e altura da área de spawn

	for i in range(2):
		var posicao_aleatoria = Vector2(
		randi_range(1936, 2304),
		randi_range(30, 784)
		)
		var objeto = Bot.instantiate()
		objeto.position = posicao_aleatoria
		MainNode.get_node("Players").add_child(objeto)

	var PlayerObj = Player.instantiate()
	PlayerObj.position = area_spawn.global_position
	MainNode.get_node("Players").add_child(PlayerObj)
	queue_free()
