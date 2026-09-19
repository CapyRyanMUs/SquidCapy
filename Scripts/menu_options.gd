extends Control

@export var MainNode : Node2D
@export var StartButton : Button
@export var BotNumbers : OptionButton
@export var SexOption : OptionButton
@export var Player : PackedScene
@export var Bot : PackedScene

@export var area_spawn : Area2D

var PlayerSex : String = "Male"
var RangeBots : int = 40

var BotsOptions : Dictionary = {
	0 : 2,
	1 : 40,
	2 : 60,
	3 : 80

}

func _ready() -> void:
	pass # Replace with function body.


func _on_start_button_pressed() -> void:
	var area_position = area_spawn.position
	var area_size = Vector2(2304 - 1936, 784 - 30)  # Largura e altura da área de spawn
	for i in range(RangeBots - 1):
		var posicao_aleatoria = Vector2(
		randi_range(1936, 2304),
		randi_range(30, 784)
		)
		var objeto = Bot.instantiate()
		objeto.position = posicao_aleatoria
		MainNode.get_node("Players").add_child(objeto)

	var PlayerObj = Player.instantiate()
	PlayerObj.Sex = PlayerSex
	PlayerObj.position = area_spawn.global_position
	MainNode.get_node("Players").add_child(PlayerObj)
	queue_free()

func _on_bot_option_item_selected(index: int) -> void:
	RangeBots = BotsOptions[index]

func _on_sex_option_item_selected(index: int) -> void:
	PlayerSex = SexOption.get_item_text(index)

func _on_more_button_pressed() -> void:
	var rick_roll_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
	OS.shell_open(rick_roll_url)
