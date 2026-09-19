extends CharacterBody2D
class_name CapyActor

signal outcome_changed(actor_id: int, outcome: String)
@export var Anim: AnimationPlayer
@export var Sex := "Male"
@export var Danger := 1
@export var WalkSpeed := 60
@export var RunSpeed := 120
var Alive := true
var Fallen := false
var Running := false
var IsGoingDed := false
var Win := false
var Direction := Vector2.ZERO
var TargetPlayer: CapyActor
var match_controller: Node
var actor_id := 0
var peer_id := 0
var display_name := "Capy"
var is_bot := false
var outcome := "active"
var actual_velocity := Vector2.ZERO
var facing := -1
var pushing := 0.0
var fallen_time := 0.0
var getup_progress := 0.0
var death_delay := -1.0
var fall_clock := 0.0
var danger_clock := 0.0
var command_direction := Vector2.ZERO
var command_run := false
var last_command_time := -100.0
var last_command_seq := -1
var last_action_seq := -1
var last_action_time := -100.0
var received_position := Vector2.ZERO
var prediction_history: Array[Dictionary] = []
var hit_ids: Dictionary = {}
var last_visual_state := ""
var last_snapshot_seq := -1

func _ready() -> void:
	set_physics_process(false)
	for timer_name in ["LoopTimer", "LoopTimerNavAgent"]:
		if has_node(timer_name):
			get_node(timer_name).stop()
	if has_node("Camera2D"):
		$Camera2D.enabled = false
	if has_node("UiControls") and not is_local():
		$UiControls.queue_free()
	$PushHitBox.monitoring = false
	received_position = position

func is_local() -> bool:
	return not is_bot and match_controller != null and peer_id == match_controller.session.local_id()

func accepts_commands() -> bool:
	return outcome == "active" and match_controller.phase == "playing"

func set_command(seq: int, direction: Vector2, run: bool, now: float) -> bool:
	if seq <= last_command_seq or not direction.is_finite() or not accepts_commands():
		return false
	if now - last_command_time < 0.015:
		return false
	last_command_seq = seq
	last_command_time = now
	command_direction = direction.limit_length(1.0)
	command_run = run
	return true

func action(seq: int, kind: String, now: float) -> bool:
	if seq <= last_action_seq or not accepts_commands() or kind not in ["push", "getup"]:
		return false
	last_action_seq = seq
	if now - last_action_time < 0.06:
		return false
	last_action_time = now
	if kind == "push":
		return start_push()
	if Fallen:
		getup_progress = minf(100.0, getup_progress + match_controller.config.getup_per_press)
		return true
	return false

func start_push() -> bool:
	if not accepts_commands() or Fallen or pushing > 0.0:
		return false
	pushing = match_controller.config.push_duration
	Danger += 5 if is_bot else 14
	hit_ids.clear()
	return true

func mark_for_death(delay: float) -> void:
	if outcome != "active" or IsGoingDed:
		return
	IsGoingDed = true
	death_delay = delay

func finish(result: String) -> bool:
	if outcome != "active" or (result == "won" and IsGoingDed):
		return false
	outcome = result
	Alive = result == "won"
	Win = result == "won"
	Fallen = false
	Running = false
	pushing = 0.0
	death_delay = -1.0
	Direction = Vector2.ZERO
	command_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	actual_velocity = Vector2.ZERO
	TargetPlayer = null
	collision_layer = 0
	collision_mask = 0
	if has_node("StateMachine"):
		$StateMachine.transition("Win" if Win else "Ded")
	outcome_changed.emit(actor_id, result)
	return true

func fall(impulse := Vector2.ZERO) -> void:
	if outcome != "active" or Fallen:
		return
	Fallen = true
	Running = false
	pushing = 0.0
	getup_progress = 0.0
	fallen_time = randf_range(match_controller.config.bot_getup_time.x, match_controller.config.bot_getup_time.y)
	Direction = Vector2.ZERO
	velocity = impulse

func simulate(delta: float, now: float) -> void:
	if outcome != "active":
		return
	if death_delay >= 0.0:
		death_delay -= delta
		if death_delay <= 0.0:
			finish("dead")
			return
	if not is_bot:
		Direction = command_direction if now - last_command_time <= match_controller.config.input_timeout else Vector2.ZERO
		Running = command_run and now - last_command_time <= match_controller.config.input_timeout
		if Fallen or pushing > 0.0:
			Direction = Vector2.ZERO
	if Fallen:
		Direction = Vector2.ZERO
		Running = false
		fallen_time -= delta
		getup_progress = maxf(0.0, getup_progress - match_controller.config.getup_decay * delta)
		if (is_bot and fallen_time <= 0.0) or (not is_bot and getup_progress > 96.0):
			Fallen = false
			getup_progress = 0.0
			velocity = Vector2(-80 if is_bot else -100, 0)
	if pushing > 0.0:
		Direction = Vector2.ZERO
		pushing = maxf(0.0, pushing - delta)
		apply_push_contacts()
	move_actor(delta, Direction, Running)
	fall_clock += delta
	danger_clock += delta
	if fall_clock >= 1.0:
		fall_clock -= 1.0
		if Running and not Fallen and actual_velocity.length() > 30.0:
			if randi_range(1, match_controller.config.bot_fall_odds if is_bot else match_controller.config.human_fall_odds) == 1:
				fall()
	if not is_bot and danger_clock >= 15.0:
		danger_clock -= 15.0
		Danger += 20

func move_actor(delta: float, direction: Vector2, run: bool) -> void:
	if absf(direction.x) > 0.01:
		facing = 1 if direction.x > 0.0 else -1
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * (RunSpeed if run else WalkSpeed)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, match_controller.config.friction * delta)
	var previous := position
	move_and_collide(velocity * delta)
	actual_velocity = (position - previous) / delta

func apply_push_contacts() -> void:
	var shape: CollisionShape2D = $PushHitBox/CollisionShape2D
	$PushHitBox.scale.x = -facing
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 3
	query.exclude = [get_rid()]
	for contact in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var other = contact.collider
		if other is CapyActor and other.outcome == "active" and not other.Fallen and not hit_ids.has(other.actor_id):
			hit_ids[other.actor_id] = true
			other.Danger = 1
			other.fall(Vector2(facing * match_controller.config.push_impulse, 0))
			if other.is_bot and randi_range(1, 3) == 1:
				other.TargetPlayer = self
			if other == TargetPlayer:
				TargetPlayer = null
			if is_bot:
				break

func present(delta: float) -> void:
	if not match_controller.session.is_authority():
		if not is_local() or outcome != "active":
			position = position.lerp(received_position, minf(1.0, delta * 20.0))
	z_index = int(position.y)
	$Sprite2D.flip_h = facing > 0
	$PushHitBox.scale.x = -facing
	var visual := "Idle"
	if outcome in ["dead", "abandoned"]:
		visual = "Ded"
	elif Fallen:
		visual = "Fallen"
	elif pushing > 0.0:
		visual = "Push"
	elif velocity.length() > 5.0 and outcome == "active":
		visual = "Run" if Running and Anim.has_animation(Sex + "/Run") else "Walk"
	if visual != last_visual_state:
		Anim.play(Sex + "/" + visual)
		if visual == "Push":
			play_sound("HIT")
		elif visual == "Fallen":
			play_sound("UEPA")
		elif Win:
			play_sound("GG")
		last_visual_state = visual
	if DisplayServer.get_name() != "headless" and has_node("Sounds/WALK"):
		var walking := visual in ["Walk", "Run"]
		if walking and not $Sounds/WALK.playing:
			$Sounds/WALK.play()
		elif not walking:
			$Sounds/WALK.stop()

func play_sound(sound_name: String) -> void:
	if DisplayServer.get_name() != "headless" and has_node("Sounds/" + sound_name):
		get_node("Sounds/" + sound_name).play()

func _exit_tree() -> void:
	if has_node("Sounds"):
		for sound in $Sounds.get_children():
			if sound is AudioStreamPlayer2D:
				sound.stop()

func snapshot() -> Dictionary:
	return {"id": actor_id, "p": position, "v": velocity, "f": facing, "run": Running,
		"fallen": Fallen, "push": pushing, "up": getup_progress, "outcome": outcome,
		"marked": IsGoingDed, "ack": last_command_seq}

func apply_snapshot(data: Dictionary) -> void:
	if outcome != "active" and data.outcome == "active":
		return
	received_position = data.p
	velocity = data.v
	facing = data.f
	Running = data.run
	Fallen = data.fallen
	pushing = data.push
	getup_progress = data.up
	IsGoingDed = data.marked
	if outcome == "active" and data.outcome != "active":
		finish(data.outcome)
	if is_local():
		position = received_position
		prediction_history = prediction_history.filter(func(entry): return entry.seq > int(data.ack))
		if outcome == "active" and not Fallen and pushing <= 0.0:
			for entry in prediction_history:
				move_actor(entry.dt, entry.dir, entry.run)
		else:
			prediction_history.clear()

func predict(delta: float, seq: int, direction: Vector2, run: bool) -> void:
	if not accepts_commands() or Fallen or pushing > 0.0:
		return
	move_actor(delta, direction, run)
	prediction_history.append({"seq": seq, "dir": direction, "run": run, "dt": delta})
	if prediction_history.size() > 120:
		prediction_history.pop_front()
