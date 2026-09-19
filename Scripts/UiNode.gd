extends Control
@export var ExitButton: Button
@export var EffectScreen: ColorRect
@export var DedScreen: ColorRect
@export var Anim: AnimationPlayer
@export var TimeLabel: Label
@export var PlayersCountLabel: Label
@export var FinishLineLabel: Label
@export var Buttons: Array[TouchScreenButton]
var actor: CapyActor

func _ready() -> void:
	actor = get_parent()
	ExitButton.hide()
	DedScreen.hide()
	EffectScreen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DedScreen.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if not actor.is_local():
		$Canvas.hide()
		return
	var match_node: MatchController = actor.match_controller
	var active := actor.outcome == "active" and match_node.phase == "playing"
	$Canvas.visible = match_node.session.phase == "match"
	for control in Buttons:
		control.visible = active
		control.modulate.a = 0.1 if actor.Fallen else 1.0
	$Canvas/AspectRatioContainer/GetUp.visible = active and actor.Fallen
	$Canvas/UpBar.visible = active and actor.Fallen
	$Canvas/UpBar.value = actor.getup_progress
	EffectScreen.color = Color(0.1, 0.8, 0.2, 0.06) if match_node.GreenLight else Color(0.9, 0.05, 0.05, 0.12)
	EffectScreen.modulate = Color.WHITE
	TimeLabel.text = match_node.Format_time(match_node.RoundTimer)
	var count := 0
	for capy: CapyActor in match_node.actors.values():
		if capy.outcome == "active":
			count += 1
	PlayersCountLabel.text = str(count)
	FinishLineLabel.text = "WIN" if actor.Win else str(maxi(0, int((actor.position.x - match_node.CheckPoint.position.x) / 5.0)))
