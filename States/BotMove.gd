extends State
class_name BotMove
var delay := 0.0
var vertical := 0.0

func enter() -> void:
	super.enter()
	Char.Direction = Vector2.ZERO
	if is_instance_valid(Char.TargetPlayer):
		change.emit(self, "Puto")
		return
	Char.Running = randi_range(1, 3) == 1
	delay = randf_range(1.0, 2.0)
	vertical = randf_range(-0.2, 0.2)

func update(delta: float) -> void:
	super.update(delta)
	if not Char.MainNode.GreenLight:
		change.emit(self, "Stop")
		return
	if is_instance_valid(Char.TargetPlayer):
		change.emit(self, "Puto")
		return
	if elapsed >= delay:
		Char.Direction = Vector2(-1, vertical)
		for ray in Char.FaceRays.get_children():
			if ray.is_colliding():
				Char.Direction = Vector2(0, ray.name.to_int())
