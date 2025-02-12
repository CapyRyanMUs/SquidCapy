
extends Node

var current_state : State
var states : Dictionary = {}

@export var initial_state : State

func _ready():
	await get_tree().create_timer(1).timeout
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.change.connect(on_child_change)
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _physics_process(delta : float):
	if current_state:
		current_state.update(delta)

func on_child_change(state, new_state_name):
	if state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	if current_state:
		current_state.exit()
	
	new_state.enter()
	
	current_state = new_state
