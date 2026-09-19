extends Node2D
class_name MatchController

signal LightChanged(green_light: bool)
signal TimeTick(roundtime: String)
signal participant_finished(actor_id: int, result: String)
signal round_finished(results: Array)

@export var GreenLight := true
@export var RoundTimer := 75
@export var DevTest := false
@export var Doll: CharacterBody2D
@export var CheckPoint: Area2D
var session: Node
var config := MatchConfig.new()
var phase := "loading"
var actors: Dictionary = {}
var results: Array = []
var starts_at := 0.0
var ends_at := 0.0
var next_light_at := 0.0
var pending_light_at := -1.0
var pending_green := true
var red_since := 0.0
var announced := false
var net_clock := 0.0
var input_clock := 0.0
var input_seq := 0
var action_seq := 0
var sampled_direction := Vector2.ZERO
var sampled_run := false
var spectate_index := 0
var camera: Camera2D
var spawner: MultiplayerSpawner
var last_snapshot := -1
var snapshot_seq := 0
const HUMAN_SCENE = preload("res://CenasInstancias/player.tscn")
const BOT_SCENE = preload("res://CenasInstancias/Bot.tscn")

func _ready() -> void:
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_function = make_actor
	add_child(spawner)
	camera = Camera2D.new()
	camera.name = "MatchCamera"
	camera.position = $SpawnArea.position
	add_child(camera)
	camera.make_current()
	Doll.collision_layer = 4
	Doll.collision_mask = 0
	Doll.get_node("Sprite").frame = 1

func make_actor(data: Variant) -> Node:
	var actor: CapyActor = (BOT_SCENE if data.bot else HUMAN_SCENE).instantiate()
	actor.name = "Capy_%d" % int(data.id)
	actor.actor_id = data.id
	actor.peer_id = data.peer
	actor.is_bot = data.bot
	actor.display_name = data.label
	actor.Sex = data.sex
	actor.position = data.position
	actor.match_controller = self
	actor.WalkSpeed = int(config.walk_speed)
	actor.RunSpeed = int(config.bot_run_speed if data.bot else config.human_run_speed)
	actors[actor.actor_id] = actor
	actor.tree_exiting.connect(func(): actors.erase(actor.actor_id))
	actor.outcome_changed.connect(_on_outcome)
	return actor

func spawn_participants(roster: Dictionary) -> void:
	var shape_node: CollisionShape2D = $SpawnArea/CollisionShape2D
	var size: Vector2 = shape_node.shape.size * shape_node.scale
	var slots: Array[Vector2] = []
	for x in range(int(size.x / 40.0)):
		for y in range(int(size.y / 40.0)):
			# Feet collider is below the actor origin.
			slots.append($SpawnArea.position - size / 2.0 + Vector2(20 + x * 40, 5 + y * 40))
	slots.shuffle()
	var serial := 1
	for peer in roster:
		spawn_one({"id": serial, "peer": peer, "bot": false, "sex": roster[peer].sex,
			"label": roster[peer].label, "position": slots.pop_back()})
		serial += 1
	for index in range(config.npc_count):
		spawn_one({"id": serial, "peer": 0, "bot": true, "sex": "Male" if randi() % 2 == 0 else "Female",
			"label": "NPC %d" % (index + 1), "position": slots.pop_back()})
		serial += 1

func spawn_one(data: Dictionary) -> void:
	if session.mode == "offline":
		$Players.add_child(make_actor(data))
	else:
		spawner.spawn(data)

func begin(at: float) -> void:
	starts_at = at
	ends_at = at + config.duration
	phase = "countdown"
	set_light(true)
	if session.is_authority():
		next_light_at = starts_at + randf_range(config.light_interval.x, config.light_interval.y)

func local_actor() -> CapyActor:
	return actor_for_peer(session.local_id())

func actor_for_peer(peer: int) -> CapyActor:
	for actor: CapyActor in actors.values():
		if not actor.is_bot and actor.peer_id == peer:
			return actor
	return null

func _physics_process(delta: float) -> void:
	if session == null:
		return
	var now: float = session.server_time()
	if phase == "countdown" and now >= starts_at:
		phase = "playing"
	if phase == "playing":
		sample_input(delta)
		if session.is_authority():
			if now >= ends_at:
				end_round()
			else:
				advance_lights(now)
				for actor: CapyActor in actors.values():
					if actor.is_bot:
						actor.think(delta)
					actor.simulate(delta, now)
					if not GreenLight and now - red_since >= config.red_grace:
						if actor.actual_velocity.length() > config.movement_threshold:
							actor.mark_for_death(randf_range(config.kill_delay.x, config.kill_delay.y))
				if all_humans_finished():
					end_round()
		net_clock += delta
		if session.is_authority() and net_clock >= config.network_interval:
			net_clock = 0.0
			send_snapshot()
	if pending_light_at >= 0.0 and now >= pending_light_at:
		set_light(pending_green)
		pending_light_at = -1.0
	RoundTimer = maxi(0, int(ceil(ends_at - now))) if phase == "playing" else int(config.duration)
	TimeTick.emit(Format_time(RoundTimer))

func _process(delta: float) -> void:
	if session == null:
		return
	for actor: CapyActor in actors.values():
		actor.present(delta)
	var target := local_actor()
	if target and target.outcome != "active":
		var candidates: Array = actors.values().filter(func(a): return not a.is_bot and a.outcome == "active")
		if not candidates.is_empty():
			target = candidates[spectate_index % candidates.size()]
	if target:
		camera.position = camera.position.lerp(target.position, minf(delta * 12.0, 1.0))

func sample_input(delta: float) -> void:
	var actor := local_actor()
	if not actor or actor.outcome != "active":
		return
	input_clock += delta
	if input_clock >= config.network_interval:
		input_clock = 0.0
		input_seq += 1
		sampled_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		sampled_run = Input.is_action_pressed("ui_shift")
		if session.auto_options.has("test-walk"):
			sampled_direction = Vector2.LEFT
		session.send_input(input_seq, sampled_direction, sampled_run)
	for pair in [["ui_push", "push"], ["ui_getup", "getup"]]:
		if Input.is_action_just_pressed(pair[0]):
			action_seq += 1
			session.send_action(action_seq, pair[1])
	if not session.is_authority():
		actor.predict(delta, input_seq, sampled_direction, sampled_run)

func advance_lights(now: float) -> void:
	if not announced and now >= next_light_at - config.light_announcement:
		announced = true
		session.announce_light(not GreenLight, next_light_at)
	if now >= next_light_at:
		set_light(not GreenLight)
		pending_light_at = -1.0
		next_light_at = now + randf_range(config.light_interval.x, config.light_interval.y)
		announced = false

func set_light(green: bool) -> void:
	if GreenLight != green:
		play_match_sound("GREEN" if green else "RED")
		if not green:
			red_since = session.server_time()
	GreenLight = green
	Doll.get_node("Sprite").frame = 1 if green else 0
	LightChanged.emit(green)

func _on_check_point_body_entered(body: Node2D) -> void:
	if session != null and session.is_authority() and phase == "playing" and body is CapyActor:
		body.finish("won")

func _on_outcome(id: int, result: String) -> void:
	participant_finished.emit(id, result)
	if session.is_authority():
		var actor: CapyActor = actors[id]
		if not actor.is_bot:
			results.append({"id": id, "label": actor.display_name, "result": result})
		if result == "dead":
			play_match_sound("GUNSHOT")
		session.publish_outcome(id, result)

func all_humans_finished() -> bool:
	for actor: CapyActor in actors.values():
		if not actor.is_bot and actor.outcome == "active":
			return false
	return true

func end_round() -> void:
	if phase == "result":
		return
	phase = "result"
	pending_light_at = -1.0
	for actor: CapyActor in actors.values():
		if actor.outcome == "active":
			actor.finish("dead")
	play_match_sound("ACABE")
	send_snapshot()
	session.publish_result(results)
	round_finished.emit(results)

func abandon(peer: int) -> void:
	var actor := actor_for_peer(peer)
	if actor:
		actor.finish("abandoned")
		actors.erase(actor.actor_id)
		actor.queue_free()

func send_snapshot() -> void:
	var states: Array = []
	for actor: CapyActor in actors.values():
		states.append(actor.snapshot())
	snapshot_seq += 1
	session.publish_snapshot(snapshot_seq, states)

func receive_snapshot(seq: int, states: Array) -> void:
	for data in states:
		if actors.has(int(data.id)):
			var actor: CapyActor = actors[int(data.id)]
			if seq > actor.last_snapshot_seq:
				actor.last_snapshot_seq = seq
				actor.apply_snapshot(data)

func Format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

func play_match_sound(sound_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		$Sounds.get_node(sound_name).play()

func _exit_tree() -> void:
	for sound in $Sounds.get_children():
		if sound is AudioStreamPlayer2D:
			sound.stop()
