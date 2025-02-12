extends State
class_name BotMove

@export var Char : CharacterBody2D

var IsConnect = false

func ChangeState():
	change.emit(self,"Stop")
func enter():
	if !IsConnect:
		Char.MainNode.LightChanged.connect(ChangeState)
		IsConnect = true
func update(delta):
	Char.Direction = Vector2.LEFT
