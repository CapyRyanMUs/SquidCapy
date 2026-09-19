extends State
class_name BotPush

func enter() -> void:
	super.enter()
	Char.Direction = Vector2.ZERO
	if not Char.start_push():
		change.emit(self, "Stop")

func exit() -> void:
	Char.pushing = 0.0
	Char.PushHitbox.monitoring = false

func update(_delta: float) -> void:
	if Char.pushing <= 0.0:
		change.emit(self, "Stop")

func _on_push_hit_box_body_entered(_body: Node2D) -> void:
	pass
