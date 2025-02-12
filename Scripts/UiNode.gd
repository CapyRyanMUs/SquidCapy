extends Control

@export var ExitButton : Button
@export var EffectScreen : ColorRect
@export var Anim : AnimationPlayer

@onready var MainNode : Node2D = get_node("/root/MainScene/MainNode")

func CU():
	get_tree().quit()

func AnimEffect():
	if MainNode:
		if MainNode.GreenLight:
			Anim.play("GreenLight")
		else:
			Anim.play("RedLight")

func _ready() -> void:
	ExitButton.pressed.connect(CU)
	MainNode.LightChanged.connect(AnimEffect)
