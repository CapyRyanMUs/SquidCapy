extends CharacterBody2D

@export var Danger : int = 1
@export var Alive : bool = true

@export var WalkSpeed : int = 60
@export var RunSpeed : int = 100
var MoveSpeed : int = WalkSpeed

var Friction : int = 200

func Movement(delta):
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vector.x != 0:
		$Sprite2D.flip_h = input_vector.x > 0
	
	MoveSpeed = WalkSpeed
	if Input.is_action_pressed("ui_shift"):
		MoveSpeed = RunSpeed
	
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * MoveSpeed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, Friction * delta)

func _physics_process(delta: float):
	Movement(delta)
	
	move_and_slide()
