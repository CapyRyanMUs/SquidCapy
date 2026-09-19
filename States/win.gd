extends State
class_name BotWin

func enter() -> void:
	super.enter()
	Char.Direction = Vector2.ZERO
	Char.velocity = Vector2.ZERO
