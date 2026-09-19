extends CapyActor
@export var MainNode: Node2D
@export var FrontArea: Area2D
@export var BackArea: Area2D
@export var PushHitbox: Area2D
@export var FaceRays: Node2D
@export var NavAgent: NavigationAgent2D
var perception_clock := 0.0

func _ready() -> void:
	is_bot = true
	MainNode = match_controller
	super._ready()
	for ray in FaceRays.get_children():
		ray.add_exception(self)
	$StateMachine.initialize(self)

func think(delta: float) -> void:
	$StateMachine.step(delta)
	if outcome != "active":
		return
	perception_clock += delta
	if perception_clock >= match_controller.config.bot_perception_interval:
		perception_clock = 0.0
		VerifyPlayers()

func VerifyPlayers() -> void:
	if not accepts_commands() or Fallen or pushing > 0.0:
		return
	for other in FrontArea.get_overlapping_bodies():
		if other is CapyActor and other != self and other.outcome == "active" and not other.Fallen:
			if randi_range(1, 17 if other.is_bot else 5) == 1:
				$StateMachine.transition("Push")
				return
	for other in BackArea.get_overlapping_bodies():
		if other is CapyActor and other != self and other.outcome == "active" and not other.Fallen:
			other.Danger += 1 if other.is_bot else 6
			if other.Danger > randi_range(1, 40):
				TargetPlayer = other
