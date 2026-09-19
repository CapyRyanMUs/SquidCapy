extends Node

signal changed
const ARENA_SOURCE = preload("res://Cenas/main_scene.tscn")
const UI_SCRIPT = preload("res://Scripts/session_ui.gd")
var mode := "offline"
var phase := "menu"
var roster: Dictionary = {}
var loaded: Dictionary = {}
var pending: Dictionary = {}
var rejected: Dictionary = {}
@export var config: MatchConfig = preload("res://Cenas/match_config.tres").duplicate()
var arena: MatchController
var clock := 0.0
var clock_offset := 0.0
var ping_ms := 0.0
var ping_clock := 0.0
var loading_deadline := 0.0
var connect_deadline := 0.0
var match_id := 0
var nickname := "Capy"
var appearance := "Male"
var message := ""
var round_results: Array = []
var port := 7000
var version := MatchConfig.PROTOCOL_VERSION
var ui: CanvasLayer
var auto_options: Dictionary = {}
var auto_start_at := -1.0
var exit_at := -1.0

func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	multiplayer.auth_callback = _authenticate
	multiplayer.auth_timeout = 5.0
	multiplayer.server_relay = false
	multiplayer.peer_authenticating.connect(_authenticating)
	multiplayer.peer_authentication_failed.connect(_authentication_failed)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave("Não foi possível conectar ao anfitrião."))
	multiplayer.server_disconnected.connect(func(): leave("O anfitrião saiu ou perdeu a conexão."))
	ui = CanvasLayer.new()
	ui.set_script(UI_SCRIPT)
	ui.session = self
	add_child(ui)
	parse_arguments()

func local_id() -> int:
	return 1 if mode == "offline" else multiplayer.get_unique_id()

func is_authority() -> bool:
	return mode != "client"

func server_time() -> float:
	return clock + (clock_offset if mode == "client" else 0.0)

func valid_port(value: int) -> bool:
	return value >= 1024 and value <= 65535

func profile(ready_status: bool = false) -> Dictionary:
	return {"label": nickname.strip_edges().left(20) if not nickname.strip_edges().is_empty() else "Capy",
		"sex": appearance if appearance in ["Male", "Female"] else "Male", "ready": ready_status}

func start_offline() -> void:
	leave()
	mode = "offline"
	roster = {1: profile(true)}
	start_match()

func host(port_number: int) -> void:
	leave()
	if not valid_port(port_number):
		set_message("A porta deve estar entre 1024 e 65535.")
		return
	var peer := ENetMultiplayerPeer.new()
	# Spare transport slots allow an explicit "room full" rejection at handshake.
	var error := peer.create_server(port_number, MatchConfig.MAX_HUMANS + 4, 4)
	if error != OK:
		set_message("Não foi possível hospedar: porta ocupada ou indisponível.")
		return
	port = port_number
	mode = "host"
	multiplayer.multiplayer_peer = peer
	roster = {1: profile()}
	phase = "lobby"
	set_message("Sala aberta na porta UDP %d." % port)
	print("TEST_LISTENING ", port)
	write_test_stage("listening")

func join(address: String, port_number: int) -> void:
	leave()
	if not address.is_valid_ip_address() or not valid_port(port_number):
		set_message("Informe um IP válido e uma porta entre 1024 e 65535.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port_number, 4)
	if error != OK:
		set_message("Não foi possível iniciar a conexão.")
		return
	mode = "client"
	phase = "connecting"
	port = port_number
	multiplayer.multiplayer_peer = peer
	connect_deadline = clock + 10.0
	set_message("Conectando…")

func leave(reason: String = "") -> void:
	_destroy_arena()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = "offline"
	phase = "menu"
	roster.clear()
	loaded.clear()
	pending.clear()
	rejected.clear()
	round_results.clear()
	clock_offset = 0.0
	ping_ms = 0.0
	connect_deadline = 0.0
	message = reason
	changed.emit()

func set_message(text: String) -> void:
	message = text
	changed.emit()

func _peer_connected(id: int) -> void:
	if mode == "host":
		pending.erase(id)
		broadcast_room()

func _peer_disconnected(id: int) -> void:
	if mode != "host":
		return
	pending.erase(id)
	rejected.erase(id)
	roster.erase(id)
	loaded.erase(id)
	if arena:
		arena.abandon(id)
	if phase == "loading":
		cancel_loading("Um jogador saiu durante o carregamento.")
	else:
		broadcast_room()

func _connected() -> void:
	pass # Admission has already completed before replication is allowed.

func _authenticating(id: int) -> void:
	if mode == "client":
		multiplayer.send_auth(id, var_to_bytes({"protocol": version, "profile": profile()}))
	elif mode == "host":
		pending[id] = true

func _authentication_failed(id: int) -> void:
	if mode == "host":
		pending.erase(id)
		rejected.erase(id)
		roster.erase(id)
		broadcast_room()
	elif mode == "client" and phase == "connecting":
		leave.call_deferred("Não foi possível entrar na sala: autenticação expirou.")

func _authenticate(id: int, data: PackedByteArray) -> void:
	if data.size() > 1024:
		return
	var decoded = bytes_to_var(data)
	if not decoded is Dictionary:
		return
	if mode == "client":
		if id != 1:
			return
		if decoded.get("accepted", false) == true:
			multiplayer.complete_auth(id)
		elif decoded.get("reason", "") is String:
			leave.call_deferred(decoded.reason)
		return
	if mode != "host" or not pending.has(id) or roster.has(id) or rejected.has(id):
		return
	var reason := ""
	if decoded.get("protocol", -1) != version:
		reason = "Versão incompatível. Todos devem usar a mesma versão do jogo."
	elif phase != "lobby":
		reason = "A partida já começou. Entre após o retorno à sala."
	elif roster.size() >= MatchConfig.MAX_HUMANS:
		reason = "A sala está cheia."
	var details = decoded.get("profile", {})
	if not details is Dictionary or not details.get("label", "") is String or not details.get("sex", "") is String:
		reason = "Perfil inválido."
	if not reason.is_empty():
		multiplayer.send_auth(id, var_to_bytes({"accepted": false, "reason": reason}))
		rejected[id] = clock + 0.5
		return
	roster[id] = {"label": str(details.get("label", "Capy")).strip_edges().left(20),
		"sex": "Female" if details.get("sex", "") == "Female" else "Male", "ready": false}
	multiplayer.send_auth(id, var_to_bytes({"accepted": true}))
	multiplayer.complete_auth(id)

func broadcast_room() -> void:
	if mode == "host":
		broadcast("_room", [roster, config.npc_count, clock, phase])
	changed.emit()

func broadcast(method: String, arguments: Array) -> void:
	# Only admitted peers receive session/game traffic.
	for peer in roster:
		if peer != 1 and peer in multiplayer.get_peers():
			callv("rpc_id", [peer, method] + arguments)

@rpc("authority", "call_remote", "reliable", 0)
func _room(members: Dictionary, bots: int, host_clock: float, room_phase: String) -> void:
	if mode != "client":
		return
	if phase == "connecting":
		clock_offset = host_clock - clock
		message = ""
		connect_deadline = 0.0
	roster = members
	config.npc_count = bots
	if room_phase == "lobby":
		phase = "lobby"
	changed.emit()

func toggle_ready() -> void:
	if not roster.has(local_id()) or phase != "lobby":
		return
	var value: bool = not roster[local_id()].ready
	if mode == "host":
		roster[1].ready = value
		broadcast_room()
	else:
		_ready_request.rpc_id(1, value)

@rpc("any_peer", "call_remote", "reliable", 0)
func _ready_request(value: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if mode == "host" and phase == "lobby" and roster.has(sender):
		roster[sender].ready = value
		broadcast_room()

func set_npcs(count: int) -> void:
	if not is_authority() or count not in MatchConfig.NPC_OPTIONS or phase not in ["menu", "lobby"]:
		return
	config.npc_count = count
	if mode == "host":
		broadcast_room()

func can_start() -> bool:
	if not is_authority() or phase != "lobby" or roster.is_empty():
		return false
	for member in roster.values():
		if not member.ready:
			return false
	return true

func start_match() -> void:
	if mode != "offline" and not can_start():
		return
	phase = "loading"
	match_id += 1
	loaded.clear()
	round_results.clear()
	loading_deadline = clock + 30.0
	load_arena()
	loaded[1] = true
	if mode == "host":
		broadcast("_load_match", [match_id, config.npc_count])
	changed.emit()

func load_arena() -> void:
	_destroy_arena()
	# Reuse the existing authored scene, including the doll's overrides.
	var authored := ARENA_SOURCE.instantiate()
	arena = authored.get_node("MainNode")
	authored.remove_child(arena)
	authored.free()
	arena.name = "Arena"
	arena.session = self
	arena.config = config
	add_child(arena)

@rpc("authority", "call_remote", "reliable", 0)
func _load_match(id: int, bots: int) -> void:
	match_id = id
	config.npc_count = bots
	phase = "loading"
	load_arena()
	_loaded.call_deferred()
	changed.emit()

func _loaded() -> void:
	if phase == "loading" and mode == "client":
		_arena_loaded.rpc_id(1, match_id)

@rpc("any_peer", "call_remote", "reliable", 0)
func _arena_loaded(id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if mode == "host" and phase == "loading" and id == match_id and roster.has(sender):
		loaded[sender] = true

func begin_loaded_match() -> void:
	arena.spawn_participants(roster)
	var at := clock + config.countdown
	arena.begin(at)
	phase = "match"
	if mode == "host":
		broadcast("_begin", [match_id, at, config.duration])
	changed.emit()
	print("MATCH_STARTED humans=%d npcs=%d" % [roster.size(), config.npc_count])
	write_test_stage("match")

func write_test_stage(stage: String) -> void:
	if not auto_options.has("report") or mode != "host":
		return
	var marker := FileAccess.open("res://.godot/test_%d_%s.ready" % [port, stage], FileAccess.WRITE)
	if marker:
		marker.store_string(stage)
		marker.close()

@rpc("authority", "call_remote", "reliable", 0)
func _begin(id: int, at: float, duration: float) -> void:
	if id == match_id and arena:
		config.duration = duration
		arena.begin(at)
		phase = "match"
		changed.emit()

func cancel_loading(reason: String) -> void:
	_destroy_arena()
	phase = "lobby"
	message = reason
	if mode == "host":
		broadcast("_back_to_room", [reason])
		broadcast_room()

func return_to_lobby() -> void:
	if mode == "offline":
		start_offline()
	elif mode == "host" and phase == "result":
		for member in roster.values():
			member.ready = false
		cancel_loading("")

@rpc("authority", "call_remote", "reliable", 0)
func _back_to_room(reason: String) -> void:
	_destroy_arena()
	phase = "lobby"
	round_results.clear()
	set_message(reason)

func _destroy_arena() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = null

func send_input(seq: int, direction: Vector2, run: bool) -> void:
	if is_authority():
		accept_input(local_id(), seq, direction, run)
	else:
		_input_command.rpc_id(1, match_id, seq, direction, run)

func accept_input(peer: int, seq: int, direction: Vector2, run: bool) -> bool:
	if not arena or phase != "match":
		return false
	var actor := arena.actor_for_peer(peer)
	return actor.set_command(seq, direction, run, clock) if actor else false

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _input_command(id: int, seq: int, direction: Vector2, run: bool) -> void:
	if mode == "host" and id == match_id:
		accept_input(multiplayer.get_remote_sender_id(), seq, direction, run)

func send_action(seq: int, kind: String) -> void:
	if is_authority():
		accept_action(local_id(), seq, kind)
	else:
		_action_command.rpc_id(1, match_id, seq, kind)

func accept_action(peer: int, seq: int, kind: String) -> bool:
	if not arena or phase != "match":
		return false
	var actor := arena.actor_for_peer(peer)
	return actor.action(seq, kind, clock) if actor else false

@rpc("any_peer", "call_remote", "reliable", 0)
func _action_command(id: int, seq: int, kind: String) -> void:
	if mode == "host" and id == match_id:
		accept_action(multiplayer.get_remote_sender_id(), seq, kind)

func announce_light(green: bool, at: float) -> void:
	if mode == "host":
		broadcast("_light", [match_id, green, at])

@rpc("authority", "call_remote", "reliable", 0)
func _light(id: int, green: bool, at: float) -> void:
	if arena and id == match_id and arena.phase != "result":
		arena.pending_green = green
		arena.pending_light_at = at

func publish_snapshot(seq: int, states: Array) -> void:
	if mode == "host":
		for index in range(0, states.size(), SnapshotCodec.CHUNK_SIZE):
			broadcast("_snapshot", [match_id, seq, SnapshotCodec.pack(states.slice(index, index + SnapshotCodec.CHUNK_SIZE))])

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _snapshot(id: int, seq: int, data: PackedFloat32Array) -> void:
	if arena and id == match_id:
		arena.receive_snapshot(seq, SnapshotCodec.unpack(data))

func publish_outcome(actor: int, result: String) -> void:
	if mode == "host":
		broadcast("_outcome", [match_id, actor, result])

@rpc("authority", "call_remote", "reliable", 0)
func _outcome(id: int, actor: int, result: String) -> void:
	if arena and id == match_id and arena.actors.has(actor):
		var capy: CapyActor = arena.actors[actor]
		if result == "won":
			capy.IsGoingDed = false
		capy.finish(result)
		if result == "abandoned":
			arena.actors.erase(actor)

func publish_result(results: Array) -> void:
	phase = "result"
	round_results = results
	if auto_options.has("quit-on-result"):
		exit_at = clock + 3.0
	if mode == "host":
		var final_states: Array = []
		for actor: CapyActor in arena.actors.values():
			final_states.append(actor.snapshot())
		broadcast("_result", [match_id, results, final_states])
	changed.emit()
	print("MATCH_RESULT ", JSON.stringify(results))

@rpc("authority", "call_remote", "reliable", 0)
func _result(id: int, results: Array, final_states: Array) -> void:
	if arena and id == match_id:
		for state in final_states:
			if arena.actors.has(int(state.id)):
				var actor: CapyActor = arena.actors[int(state.id)]
				actor.apply_snapshot(state)
				actor.position = state.p
		arena.phase = "result"
		arena.pending_light_at = -1.0
		phase = "result"
		round_results = results
		if auto_options.has("quit-on-result"):
			exit_at = clock + 1.0
		changed.emit()
		print("MATCH_RESULT ", JSON.stringify(results))

@rpc("any_peer", "call_remote", "unreliable", 3)
func _ping(sent: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if mode == "host" and roster.has(sender):
		_pong.rpc_id(sender, sent, clock)

@rpc("authority", "call_remote", "unreliable", 3)
func _pong(sent: float, host_clock: float) -> void:
	var rtt := maxf(0.0, clock - sent)
	ping_ms = rtt * 1000.0
	clock_offset = lerpf(clock_offset, host_clock + rtt * 0.5 - clock, 0.25)

func _process(delta: float) -> void:
	clock += delta
	if phase == "connecting" and clock >= connect_deadline:
		leave("Tempo de conexão esgotado. Confira IP, porta e limite da sala.")
	if mode == "client" and phase in ["lobby", "loading", "match", "result"]:
		ping_clock += delta
		if ping_clock >= 1.0:
			ping_clock = 0.0
			_ping.rpc_id(1, clock)
	if mode == "host":
		for id in rejected.keys():
			if clock >= rejected[id]:
				rejected.erase(id)
				multiplayer.disconnect_peer(id)
	if is_authority() and phase == "loading":
		if loaded.size() == roster.size():
			begin_loaded_match()
		elif clock >= loading_deadline:
			cancel_loading("Carregamento excedeu 30 segundos. Tente novamente.")
	if auto_start_at > 0.0 and clock >= auto_start_at and can_start() and roster.size() >= int(auto_options.get("expect-humans", "1")):
		auto_start_at = -1.0
		start_match()
	if auto_options.has("auto-ready") and phase == "lobby" and roster.has(local_id()) and not roster[local_id()].ready:
		toggle_ready()
	if exit_at > 0.0 and clock >= exit_at:
		if auto_options.has("report"):
			print("TEST_REPORT ", JSON.stringify({"phase": phase, "mode": mode,
				"actors": arena.actors.size() if arena else 0, "roster": roster.size(),
				"ping": ping_ms, "message": message,
				"snapshots": arena.local_actor().last_snapshot_seq if arena and arena.local_actor() else -1}))
		get_tree().quit()

# Reproducible multi-process smoke tests; not exposed through the game UI.
func parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var pair := arg.trim_prefix("--").split("=", true, 1)
			auto_options[pair[0]] = pair[1] if pair.size() == 2 else "true"
	if auto_options.has("name"):
		nickname = auto_options.name
	if auto_options.has("test-duration"):
		config.duration = maxf(1.0, float(auto_options["test-duration"]))
	if auto_options.has("npcs"):
		config.npc_count = int(auto_options.npcs) if int(auto_options.npcs) in MatchConfig.NPC_OPTIONS else 40
	if auto_options.has("protocol"):
		version = int(auto_options.protocol)
	var test_port := int(auto_options.get("port", "7000"))
	if auto_options.has("host"):
		host(test_port)
		auto_start_at = clock + float(auto_options.get("start-after", "4"))
	elif auto_options.has("join"):
		join(auto_options.join, test_port)
	elif auto_options.has("offline"):
		start_offline()
	if auto_options.has("quit-after"):
		exit_at = clock + float(auto_options["quit-after"])

