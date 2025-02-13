extends State
class_name BotMove

@export var Char : CharacterBody2D

var Debounce = false

func ChangeState():
	change.emit(self,"Stop")
func enter():
	Char.MainNode.LightChanged.connect(ChangeState)
	var TimeWait = randf_range(0.5,2.0)
	await get_tree().create_timer(TimeWait).timeout
	Debounce = true
func exit():
	Debounce = false
	Char.MainNode.LightChanged.disconnect(ChangeState)
func update(delta):
	if Debounce:
		Char.Direction = Vector2.LEFT
		Char.Anim.play("%s/Walk"%Char.Sex) 
