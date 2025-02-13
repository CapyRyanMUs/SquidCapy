extends State
class_name BotDed

@export var Char : CharacterBody2D

var Debounce = false

func enter():
	Char.Direction = Vector2.ZERO
	Char.velocity = Vector2(300,0)
	Char.Friction = 600
	await get_tree().create_timer(3).timeout
	Char.Alive = false

func update(delta):
	Char.Anim.play("%s/Ded") %Char.Sex
	if !Char.Alive:
		Char.modulate.a = lerp(Char.modulate.a, 0.0,0.06)
		if Char.modulate.a <= 0.1:
			Char.queue_free()
