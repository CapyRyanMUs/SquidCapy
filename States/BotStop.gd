extends State
class_name BotStop

var IsConnect = false

@export var Char : CharacterBody2D 
func ChangeState():
	change.emit(self, "Move")
func enter():
	StopMove()
	Char.MainNode.LightChanged.connect(ChangeState)

func exit():
	Char.MainNode.LightChanged.disconnect(ChangeState)

func update(delta):
	Char.Anim.play("%s/Idle" %Char.Sex) 

func StopMove():
	var TimeStop = randf_range(0.1, 1.0)
	await get_tree().create_timer(TimeStop).timeout
	Char.Direction = Vector2.ZERO
