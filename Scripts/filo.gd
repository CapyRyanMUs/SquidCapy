extends CharacterBody2D

@export var Anim : AnimationPlayer
@export var Sex : String = "Male"

@export var Danger : int = 1
@export var Alive : bool = true
@export var Fallen : bool = false

@export var WalkSpeed : int = 60
@export var RunSpeed : int = 100
var MoveSpeed : int = WalkSpeed

var Friction : int = 200
var input_vector

var FallDebounce = false
var UpBar : ProgressBar
func FallFunc():
	Anim.play("%s/Fallen"%Sex) 
	if !FallDebounce:
		FallDebounce = true
		UpBar = get_node("UiControls/Canvas/UpBar")
		var Progress : float = 0
		UpBar.visible = true
	UpBar.value -= 1.5
	if Input.is_action_just_pressed("ui_getup"):
		UpBar.value += 20
	if UpBar.value > 96.0:
		UpBar.visible = false
		Fallen = false
		FallDebounce = false
func _ready() -> void:
	await get_tree().create_timer(1).timeout
	Fallen = true
func Movement(delta):
	if !Fallen:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var AnimShouldToPlay : String = "%s/Walk" %Sex
	
	if input_vector.x != 0:
		$Sprite2D.flip_h = input_vector.x > 0
	
	MoveSpeed = WalkSpeed
	if Input.is_action_pressed("ui_shift"):
		var FallChance = randi_range(1,100)
		if FallChance > 98:
			Fallen = true
		MoveSpeed = RunSpeed
		AnimShouldToPlay = "%s/Run" %Sex
	
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * MoveSpeed
		Anim.play(AnimShouldToPlay)
	else:
		Anim.play("%s/Idle" %Sex)
		velocity = velocity.move_toward(Vector2.ZERO, Friction * delta)

func _physics_process(delta: float):
	Movement(delta)
	
	if Fallen:
		input_vector = Vector2.ZERO
		FallFunc()
	
	move_and_slide()
