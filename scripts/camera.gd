extends Camera3D

@export var player: Node3D
@export var follow_speed: float = 4.0
@export var deadzone: Vector2 = Vector2(5.0, 3.0)

var camera_target: Vector3
var initial_offset: Vector3

func _ready() -> void:
	if player:
		initial_offset = global_position - player.global_position
		camera_target = global_position

func _physics_process(delta: float) -> void:
	if not player:
		return

	var ideal_player_pos = player.global_position + initial_offset
	var distance_x = camera_target.x - ideal_player_pos.x
	var distance_z = camera_target.z - ideal_player_pos.z

	if abs(distance_x) > deadzone.x:
		camera_target.x = ideal_player_pos.x + (deadzone.x * sign(distance_x))

	if abs(distance_z) > deadzone.y:
		camera_target.z = ideal_player_pos.z + (deadzone.y * sign(distance_z))

	global_position = global_position.lerp(camera_target, follow_speed * delta)
