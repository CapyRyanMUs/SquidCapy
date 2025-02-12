extends CharacterBody2D

@export var TargetPlayer : CharacterBody2D
@export var CheckPoint : Area2D
@onready var MainNode : Node2D = $"../../MainNode"

@export var Danger : int = 1
@export var Alive : bool = true

@export var Direction : Vector2

@export var WalkSpeed : int = 60
@export var RunSpeed : int = 100
@export var Running : bool = false
var Friction : int = 200

var PlayersInArea : Dictionary = {}

func VerifyPlayers(): #Tem um timer em loop que ativa está função 
	for Key in PlayersInArea:
		var Player = PlayersInArea[Key]
		

func _ready() -> void:
	CheckPoint = get_tree().get_first_node_in_group("CheckPoint")
	
func _physics_process(delta: float) -> void:
	var MoveSpeed = WalkSpeed
	if Running:
		MoveSpeed = RunSpeed
	if velocity != Vector2.ZERO:
		velocity = Direction.normalized() * MoveSpeed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, Friction * delta)
	move_and_slide()


func _on_safe_area_body_entered(body: Node2D) -> void:
	var Player = body
	if PlayersInArea.has(Player.name) and Player != self and !Player.Alive:
		return
	PlayersInArea[Player.name] = Player

func _on_safe_area_body_exited(body: Node2D) -> void:
	var Player = body
	if PlayersInArea.has(Player.name):
		PlayersInArea.erase(Player.name)
	
