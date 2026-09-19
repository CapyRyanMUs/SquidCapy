extends CanvasLayer

var session: Node
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var status: Label
var watch: Button
var leave_button: Button
var address := "127.0.0.1"

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_theme_font_override("font", load("res://PeaberryBase.ttf"))
	root.add_theme_font_size_override("font_size", 13)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#163d32")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	scroll.add_child(body)
	status = Label.new()
	status.position = Vector2(150, 3)
	status.add_theme_font_size_override("font_size", 12)
	root.add_child(status)
	watch = Button.new()
	watch.text = "Próximo jogador"
	watch.position = Vector2(190, 40)
	watch.pressed.connect(func(): session.arena.spectate_index += 1)
	root.add_child(watch)
	leave_button = Button.new()
	leave_button.text = "Sair"
	leave_button.position = Vector2(520, 3)
	leave_button.pressed.connect(func(): session.leave())
	root.add_child(leave_button)
	session.changed.connect(rebuild)
	rebuild()

func label(text: String, parent: Node = body) -> Label:
	var item := Label.new()
	item.text = text
	parent.add_child(item)
	return item

func row() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	return box

func button(text: String, callback: Callable, parent: Node = body) -> Button:
	var item := Button.new()
	item.text = text
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.custom_minimum_size.y = 29
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func npc_picker(parent: Node, editable: bool) -> void:
	label("NPCs:", parent)
	var choice := OptionButton.new()
	for count in MatchConfig.NPC_OPTIONS:
		choice.add_item(str(count))
	choice.select(MatchConfig.NPC_OPTIONS.find(session.config.npc_count))
	choice.disabled = not editable
	choice.item_selected.connect(func(index): session.set_npcs(MatchConfig.NPC_OPTIONS[index]))
	parent.add_child(choice)

func rebuild() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	panel.visible = session.phase != "match"
	status.visible = not panel.visible
	leave_button.visible = not panel.visible
	watch.visible = false
	if session.phase == "menu":
		build_menu()
	elif session.phase == "connecting":
		label("Conectando à sala…")
		button("Cancelar", func(): session.leave())
	elif session.phase == "lobby":
		build_lobby()
	elif session.phase == "loading":
		label("Carregando a arena…")
		label("Aguardando todos os jogadores (até 30 segundos).")
		button("Sair", func(): session.leave())
	elif session.phase == "result":
		build_results()
	if panel.visible and not session.message.is_empty():
		var notice := label(session.message)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_menu() -> void:
	label("CAPY NA BATATINHA").add_theme_font_size_override("font_size", 23)
	var profile_row := row()
	label("Nome:", profile_row)
	var nickname := LineEdit.new()
	nickname.text = session.nickname
	nickname.max_length = 20
	nickname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname.text_changed.connect(func(value): session.nickname = value)
	profile_row.add_child(nickname)
	var appearance := OptionButton.new()
	appearance.add_item("Male")
	appearance.add_item("Female")
	appearance.select(1 if session.appearance == "Female" else 0)
	appearance.item_selected.connect(func(index): session.appearance = "Female" if index == 1 else "Male")
	profile_row.add_child(appearance)
	var settings := row()
	npc_picker(settings, true)
	label("Porta:", settings)
	var port := SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = session.port
	port.value_changed.connect(func(value): session.port = int(value))
	settings.add_child(port)
	var connection := row()
	label("IP:", connection)
	var ip := LineEdit.new()
	ip.text = address
	ip.placeholder_text = "192.168.1.10"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.text_changed.connect(func(value): address = value.strip_edges())
	connection.add_child(ip)
	var choices := row()
	button("Offline", session.start_offline, choices)
	button("Hospedar", func(): session.host(session.port), choices)
	button("Entrar por IP", func(): session.join(address, session.port), choices)
	label("Setas: mover · Shift: correr · Espaço: empurrar · Ctrl: levantar")
	label("No celular, use os botões de toque.")
	label("Internet por IP pode exigir liberar a porta UDP no roteador.")

func build_lobby() -> void:
	label("SALA · %d/%d humanos · UDP %d" % [session.roster.size(), MatchConfig.MAX_HUMANS, session.port])
	if session.mode == "host":
		var ips: Array = Array(IP.get_local_addresses()).filter(func(ip): return ip.contains(".") and not ip.begins_with("127."))
		var ip_label := label("IP local: " + ", ".join(ips))
		ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var list := RichTextLabel.new()
	list.custom_minimum_size.y = 112
	list.scroll_active = true
	for id in session.roster:
		var member: Dictionary = session.roster[id]
		list.append_text("%s%s · %s · %s\n" % [member.label, " (você)" if id == session.local_id() else "", member.sex, "PRONTO" if member.ready else "aguardando"])
	body.add_child(list)
	npc_picker(row(), session.mode == "host")
	var controls := row()
	button("Alternar pronto", session.toggle_ready, controls)
	if session.mode == "host":
		button("Iniciar", session.start_match, controls).disabled = not session.can_start()
	button("Sair", func(): session.leave(), controls)

func build_results() -> void:
	label("RESULTADO DA RODADA").add_theme_font_size_override("font_size", 20)
	var names := {"won": "Classificado", "dead": "Eliminado", "abandoned": "Abandonou"}
	for result in session.round_results:
		label("%s — %s" % [result.label, names.get(result.result, result.result)])
	var controls := row()
	if session.mode != "client":
		button("Jogar novamente" if session.mode == "offline" else "Voltar à sala", session.return_to_lobby, controls)
	else:
		label("Aguardando o anfitrião voltar à sala.")
	button("Menu", func(): session.leave(), controls)

func _process(_delta: float) -> void:
	if session.phase != "match" or not session.arena:
		return
	var match_node: MatchController = session.arena
	var actor := match_node.local_actor()
	var text := "VERDE" if match_node.GreenLight else "VERMELHO"
	if match_node.phase == "countdown":
		text = "Começa em %d" % maxi(0, int(ceil(match_node.starts_at - session.server_time())))
	if session.mode == "client":
		text += " · %d ms%s" % [int(session.ping_ms), " · conexão lenta" if session.ping_ms > 200 else ""]
	watch.visible = actor != null and actor.outcome != "active"
	if watch.visible:
		text = ("Classificado" if actor.Win else "Eliminado") + " · Assistindo"
	status.text = text
