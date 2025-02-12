extends State
class_name BotMove

@export var Char : CharacterBody2D

func enter():
	Char.MainNode.LightChanged.connect(ChangeState())
func update(delta):
	Char.Direction = Vector2.LEFT

func ChangeState():
	change.emit(self,"Move")
