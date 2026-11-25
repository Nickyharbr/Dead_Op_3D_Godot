extends Marker3D

class_name ZombieSpawner

@export_category("Spawn Configuration")
@export var zombie_scenes: Array[PackedScene]
@export var total_to_spawn: int = 10
@export var spawn_duration: float = 15.0 #seconds to output zombies

@export_category("Conditions")
@export var initial_delay: float = 0.0
@export var required_kills_to_start: int = 0
@export var global_zombie_limit: int = 30 # Pause if GameManager.active_zombies >= this

var _spawned_count: int = 0
var _delay_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.0

var spawning_complete: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if total_to_spawn > 0:
		_spawn_interval = spawn_duration / float(total_to_spawn)
	_delay_timer = initial_delay


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _spawned_count >= total_to_spawn:
		spawning_complete = true
		set_process(false)
		return
	# Gate 1: Kill count
	if GameManager.total_kills < required_kills_to_start:
		return
	
	# Gate 2: Initial Delay
	if _delay_timer > 0.0:
		_delay_timer -= delta
		return
		
	# Gate 3: Performance Limit
	if GameManager.active_zombies >= global_zombie_limit:
		return
		
	# Execution
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		spawn_zombie()
		_spawn_timer = _spawn_interval
		
func spawn_zombie() -> void:
	if zombie_scenes.is_empty():
		push_error("No zombie scenes assigned to spawner")
		return
		
	var random_scene = zombie_scenes.pick_random()
	var zombie_instance = random_scene.instantiate()
	
	# Add to main scene tree, not the spawner, to seperate transform depencies
	get_tree().current_scene.add_child(zombie_instance)
	zombie_instance.global_position = global_position
	
	GameManager.active_zombies += 1
	_spawned_count += 1
	
