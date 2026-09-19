extends SceneTree

var failures := 0
var checks := 0
var session: Node

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	session = load("res://Cenas/session.tscn").instantiate()
	root.add_child(session)
	await process_frame
	check(session.ui.body.get_combined_minimum_size().x <= 540, "Main menu fits the 576px viewport")
	session.config.npc_count = 1
	session.start_offline()
	await process_frame
	await process_frame
	var arena: MatchController = session.arena
	arena.set_physics_process(false)
	arena.phase = "playing"
	arena.ends_at = session.clock + 75.0
	var human: CapyActor = arena.local_actor()
	var bot: CapyActor = arena.actors[2]
	check(arena.actors.size() == 2, "NPC count excludes humans")
	check(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Offline opens no network socket")
	check(human.position.distance_to(bot.position) >= 39.0, "Spawns have spacing")
	check(not bot.has_node("UiControls"), "NPC has no local controls")
	check(human.is_local() and not bot.is_local(), "Only local human owns input")
	check(human.set_command(1, Vector2(4, 0), true, 1.0), "Accept valid input")
	check(human.command_direction.length() <= 1.0, "Clamp direction")
	check(not human.set_command(1, Vector2.LEFT, false, 1.1), "Reject duplicate input sequence")
	check(not human.set_command(2, Vector2(NAN, 0), false, 1.1), "Reject non-finite input")
	check(not human.set_command(2, Vector2.LEFT, false, 1.001), "Limit input frequency")
	check(not session.accept_input(999, 5, Vector2.LEFT, true), "Unknown peer cannot control an actor")
	human.simulate(1.0 / 60.0, 1.4)
	check(human.Direction == Vector2.ZERO and not human.Running, "Stale commands stop after 250 ms")
	check(human.action(1, "push", 2.0), "Push begins once")
	check(not human.action(1, "push", 2.2), "Duplicate action rejected")
	check(not human.action(2, "teleport", 2.3), "Unknown action rejected")
	human.fall()
	check(human.Fallen and human.pushing == 0.0, "Falling cancels push")
	check(not human.start_push(), "Cannot push while fallen")
	human.getup_progress = 95.0
	human.simulate(1.0 / 60.0, 2.5)
	check(is_equal_approx(human.getup_progress, 93.49), "Get-up decay uses simulation time")
	# Exercise the old enter-before-current_state failure with real states.
	var machine = bot.get_node("StateMachine")
	arena.GreenLight = false
	machine.transition("Stop")
	arena.GreenLight = true
	machine.transition("Move")
	bot.TargetPlayer = human
	machine.transition("Stop")
	check(machine.current_state.name == "Puto", "Nested Stop -> Move -> Puto transition succeeds")
	bot.fall()
	machine.step(0.01)
	check(machine.current_state.name == "Fallen", "Fallen takes priority over pursuit")
	bot.mark_for_death(0.01)
	bot.simulate(0.02, 3.0)
	check(bot.outcome == "dead" and machine.current_state.name == "Ded", "Death takes priority over fallen")
	machine.step(10.0)
	check(machine.current_state.name == "Ded", "No old get-up timer can revive a dead bot")
	human.mark_for_death(1.0)
	check(not human.finish("won"), "Marked participant cannot win")
	check(human.finish("dead"), "First result accepted")
	check(not human.finish("won") and not human.finish("dead"), "Terminal result is idempotent")
	var result_count := arena.results.size()
	arena.end_round()
	arena.end_round()
	check(arena.results.size() == result_count, "Ending twice cannot duplicate results")
	check(session.phase == "result", "Offline reaches result UI")
	session.start_offline()
	await process_frame
	await process_frame
	arena = session.arena
	arena.set_physics_process(false)
	arena.phase = "playing"
	human = arena.local_actor()
	check(human.last_command_seq == -1 and human.outcome == "active", "Restart resets participants and sequences")
	# Check authoritative shape contact between two human-capable actor bodies.
	bot = arena.actors[2]
	human.position = Vector2(2000, 300)
	bot.position = Vector2(1970, 300)
	human.facing = -1
	await physics_frame
	await physics_frame
	check(human.start_push(), "Push prepared for physical contact")
	human.apply_push_contacts()
	check(bot.Fallen and bot.velocity.x == -150.0, "Authoritative push hits and applies impulse")
	var before := bot.velocity
	human.apply_push_contacts()
	check(bot.velocity == before, "Repeated overlap does not repeat hit")
	human.position = Vector2(2100, 400)
	human.Direction = Vector2.UP
	human.move_actor(0.016, Vector2.UP, false)
	human.present(0.016)
	check(absf(human.get_node("PushHitBox").scale.x) == 1.0, "Vertical movement preserves hitbox width")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = human.position + Vector2(-40, 28)
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = RectangleShape2D.new()
	wall_shape.shape.size = Vector2(10, 100)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	for index in range(90):
		human.move_actor(1.0 / 60.0, Vector2.LEFT, false)
	check(human.actual_velocity.length() < 1.0 and human.velocity.length() > 30.0, "Wall contact is not treated as actual movement")
	var original := human.snapshot()
	var decoded: Dictionary = SnapshotCodec.unpack(SnapshotCodec.pack([original]))[0]
	check(decoded.id == original.id and decoded.p.is_equal_approx(original.p), "Compact snapshot round-trips identity and position")
	check(SnapshotCodec.pack([original]).size() * 4 * SnapshotCodec.CHUNK_SIZE < 1200, "Snapshot chunks remain below MTU")
	# Human hitboxes used to mask out other humans; exercise the new shared rule.
	human.position = Vector2(2000, 500)
	bot.position = Vector2(2200, 700)
	human.pushing = 0.0
	arena.spawn_one({"id": 3, "peer": 2, "bot": false, "sex": "Female",
		"label": "Remote", "position": Vector2(1970, 500)})
	await physics_frame
	await physics_frame
	var remote: CapyActor = arena.actors[3]
	check(not remote.has_node("UiControls") and not remote.get_node("Camera2D").enabled, "Remote human has no HUD or active camera")
	human.start_push()
	human.apply_push_contacts()
	check(remote.Fallen, "Human can push another human")
	check(remote.finish("won") and remote.collision_layer == 0, "Winner stops interacting with the arena")
	check(not arena.all_humans_finished(), "One winner does not end a round with another active human")
	check(human.finish("won"), "Unmarked human can win")
	human.apply_snapshot(original)
	check(human.Win and human.outcome == "won", "Late active snapshot cannot undo final result")
	arena.ends_at = session.server_time() - 0.01
	arena._physics_process(0.016)
	check(arena.phase == "result" and arena.RoundTimer >= 0, "Deadline ends immediately without negative timer")
	session.leave()
	await process_frame
	check(session.arena == null and session.roster.is_empty(), "Leaving clears actors and roster")
	session.roster = {1: {}, 2: {}}
	session.loaded = {1: true}
	session.phase = "loading"
	session.loading_deadline = session.clock - 1.0
	session._process(0.0)
	check(session.phase == "lobby" and session.message.contains("30 segundos"), "Incomplete loading returns everyone to lobby")
	session.leave()
	session.free()
	await create_timer(0.1).timeout
	print("TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
