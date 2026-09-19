extends State
class_name BotFallen

func enter() -> void:
	super.enter()
	Char.Direction = Vector2.ZERO
	Char.Running = false

func update(_delta: float) -> void:
	if not Char.Fallen:
		change.emit(self, "Stop")
