extends Node3D

@export_file("*.tscn") var next_level: String = ""
@export var round_number: int = 1

@export_group("Required Nodes")
@export var player: Node3D
@export var exit_area: Area3D
@export var exit_sign: Sprite3D
@export var guide_arrow: Node3D
@export var round_label: Label

var level_complete: bool = false

func _ready() -> void:
	exit_area.monitoring = false
	exit_sign.visible = false
	guide_arrow.visible = false
	round_label.visible = false
	
	exit_area.body_entered.connect(_on_exit_entered)

func _process(_delta: float) -> void:
	if level_complete:
		_process_arrow_tracking()
	else:
		_evaluate_level_state()

func _evaluate_level_state() -> void:
	var spawners = get_tree().get_nodes_in_group("spawner")
	if spawners.is_empty():
		return
		
	var all_spawners_finished: bool = true
	for spawner in spawners:
		if not spawner.spawning_complete:
			all_spawners_finished = false
			break
			
	if not all_spawners_finished:
		return
		
	var active_zombies = get_tree().get_nodes_in_group("zombie").size()
	print("Zombies: ", active_zombies, " | Spawners Finished: ", all_spawners_finished)
	if active_zombies == 0:
		_initiate_exit_phase()

func _initiate_exit_phase() -> void:
	level_complete = true
	round_label.text = "Round " + str(round_number) + " Complete"
	round_label.visible = true
	
	exit_area.monitoring = true
	exit_sign.visible = true
	guide_arrow.visible = true

func _process_arrow_tracking() -> void:
	if not is_instance_valid(player) or not is_instance_valid(exit_area):
		return
		
	var orbit_radius: float = 1.5
	var height_offset: float = 1.0
	
	var p_pos = player.global_position
	var e_pos = exit_area.global_position
	
	# Extract horizontal directional vector
	var direction = e_pos - p_pos
	direction.y = 0 
	
	# Prevent vector math crash if player origin precisely overlaps exit origin
	if direction.length_squared() < 0.01:
		return
		
	direction = direction.normalized()
	
	# Push arrow outward along the directional vector
	var orbit_coordinate = p_pos + Vector3(0, height_offset, 0) + (direction * orbit_radius)
	guide_arrow.global_position = orbit_coordinate
	
	# Flatten target coordinate to strictly horizontal plane to prevent pitching
	var look_target = e_pos
	look_target.y = guide_arrow.global_position.y 
	
	guide_arrow.look_at(look_target, Vector3.UP)

# Local signal connection evaluating overlap
func _on_exit_entered(body: Node3D) -> void:
	if body == player and next_level != "":
		get_tree().change_scene_to_file(next_level)
