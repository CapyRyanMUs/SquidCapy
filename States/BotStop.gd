extends State
class_name BotStop
var delay := 0.0

func enter() -> void:
	super.enter()
	Char.Running = false
	delay = randf_range(0.1, 0.55)
	if Char.MainNode.GreenLight:
		change.emit(self, "Move")

func update(delta: float) -> void:
	super.update(delta)
	if Char.MainNode.GreenLight:
		change.emit(self, "Move")
		return
	if elapsed >= delay:
		Char.Direction = Vector2.ZERO
