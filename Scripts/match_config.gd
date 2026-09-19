extends Resource
class_name MatchConfig

const PROTOCOL_VERSION := 1
const MAX_HUMANS := 8
const NPC_OPTIONS := [0, 1, 40, 60, 80]
@export var duration := 75.0
@export var countdown := 3.0
@export var npc_count := 40
@export var walk_speed := 60.0
@export var human_run_speed := 120.0
@export var bot_run_speed := 100.0
@export var friction := 200.0
@export var red_grace := 0.7
@export var movement_threshold := 30.0
@export var light_announcement := 0.25
@export var input_timeout := 0.25
@export var network_interval := 0.05
@export var light_interval := Vector2(3.0, 6.0)
@export var kill_delay := Vector2(1.0, 2.0)
@export var push_duration := 0.5
@export var push_impulse := 150.0
@export var human_fall_odds := 7
@export var bot_fall_odds := 9
@export var bot_getup_time := Vector2(4.0, 7.0)
@export var getup_per_press := 23.0
@export var getup_decay := 90.6
@export var bot_perception_interval := 8.0
