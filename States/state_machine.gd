extends Node
@export var current_state: State
@export var initial_state: State
var states: Dictionary = {}
var actor: CapyActor

func initialize(owner_actor: CapyActor) -> void:
	actor = owner_actor
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.Char = actor
			if not child.change.is_connected(on_child_change):
				child.change.connect(on_child_change)
	if actor.match_controller.session.is_authority() and initial_state:
		transition(initial_state.name)

func step(delta: float) -> void:
	if not actor.match_controller.session.is_authority():
		return
	if actor.outcome != "active":
		transition("Win" if actor.Win else "Ded")
	elif actor.Fallen:
		transition("Fallen")
	if current_state:
		current_state.update(delta)

func transition(new_state_name: String) -> void:
	var next: State = states.get(new_state_name.to_lower())
	if not next or next == current_state:
		return
	if current_state:
		current_state.exit()
	current_state = next
	current_state.enter()

func on_child_change(state: State, new_state_name: String) -> void:
	if state == current_state:
		transition(new_state_name)
