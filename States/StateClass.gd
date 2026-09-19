extends Node
class_name State
signal change(state: State, new_state_name: String)
@export var Char: CharacterBody2D
var elapsed := 0.0

func enter() -> void:
	elapsed = 0.0

func exit() -> void:
	pass

func update(delta: float) -> void:
	elapsed += delta
