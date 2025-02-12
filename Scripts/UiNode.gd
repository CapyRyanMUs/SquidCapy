extends Control

@export var ExitButton : Button
@export var EffectScreen : ColorRect
@export var Anim : AnimationPlayer

@export var SceneNode : Node2D

func CU():
	get_tree().quit()

func AnimEffect():
	if SceneNode:
		if SceneNode.GreenLight:
			Anim.play("GreenLight")
		else:
			Anim.play("RedLight")

func _ready() -> void:
	ExitButton.pressed.connect(CU)
	SceneNode.LightChanged.connect(AnimEffect)
