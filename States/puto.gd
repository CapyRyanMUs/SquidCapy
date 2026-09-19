extends State
class_name BotPuto
var delay := 0.0
var path_clock := 0.0

func enter() -> void:
	super.enter()
	Char.Direction = Vector2.ZERO
	delay = randf_range(0.5, 1.0)
	path_clock = 0.1

func update(delta: float) -> void:
	super.update(delta)
	if not Char.MainNode.GreenLight:
		change.emit(self, "Stop")
		return
	if not is_instance_valid(Char.TargetPlayer) or Char.TargetPlayer.outcome != "active" or Char.TargetPlayer.Fallen:
		Char.TargetPlayer = null
		change.emit(self, "Stop")
		return
	if elapsed < delay:
		return
	path_clock += delta
	if path_clock >= 0.1:
		path_clock = 0.0
		Char.NavAgent.target_position = Char.TargetPlayer.global_position
	if Char.global_position.distance_to(Char.TargetPlayer.global_position) <= 55.0:
		change.emit(self, "Push")
		return
	Char.Direction = (Char.NavAgent.get_next_path_position() - Char.global_position).normalized()

func _on_loop_timer_nav_agent_timeout() -> void:
	pass
