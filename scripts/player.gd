extends CharacterBody3D

# Core node references
@onready var animation: AnimationPlayer = $MeshInstance3D/player/AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var model: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = $Camera3D

# Link to the new Weapon Manager
@onready var weapon_manager: WeaponManager = $WeaponManager

# Raycast vectors
var ray_origin = Vector3()
var ray_end = Vector3()

# Movement parameters
const SPEED = 6.0
const JUMP_VELOCITY = 4.5

# Death and invisibilty frames.
var is_dead: bool = false
var is_invincible: bool = false

func _ready() -> void:
	anim_tree.active = true
	# Delegate weapon equipping to the manager
	weapon_manager.equip_weapon("rifle")

func _physics_process(delta: float) -> void:
	# Disables phyiscs process if the player is dead.
	if not is_dead:
		# Gravity
		if not is_on_floor():
			velocity += get_gravity() * delta
	
		# Jump
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	

		# Locomotion
		var input_dir := Input.get_vector("left", "right", "forward", "back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
		# Combat input forwarded to manager
		if Input.is_action_pressed("shoot"):
			weapon_manager.shoot()
		
		# Execution
		move_and_slide()
		look_at_mouse(delta)
		update_animation(delta)

func look_at_mouse(delta: float) -> void:
	var mouse_position = get_viewport().get_mouse_position()
	
	# 1. Elevate the math plane to chest/weapon height (e.g., 1.0 meter above the floor).
	# Adjust this number (1.0) up or down slightly to match exactly where your gun fires from
	var aim_height = global_position.y + 1.0 
	var aim_plane = Plane(Vector3.UP, aim_height)
	
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_normal = camera.project_ray_normal(mouse_position)
	
	var intersection = aim_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection != null: 
		# 2. Force the look target to be on the same Y level as the player's feet to prevent tilting
		var look_at_me = Vector3(intersection.x, global_position.y, intersection.z)
		
		# 3. Rotate the model (which now also rotates the WeaponManager child)
		if model.global_position.distance_to(look_at_me) > 0.1:
			var target_transform = model.global_transform.looking_at(look_at_me, Vector3.UP)
			# Increased the speed from 15 to 25 so the aim is snappier and more responsive
			model.global_transform = model.global_transform.interpolate_with(target_transform, delta * 25.0)

func update_animation(delta: float) -> void:
	var local_velocity = model.global_transform.basis.inverse() * velocity
	var target_blend_pos = Vector2(local_velocity.x, -local_velocity.z) / SPEED
	
	var current_blend_pos = anim_tree.get("parameters/blend_position")
	var smoothed_blend_pos = current_blend_pos.lerp(target_blend_pos, delta * 12.0)
	
	anim_tree.set("parameters/blend_position", smoothed_blend_pos)


func take_damage(attacker_pos: Vector3) -> void:
	if is_dead or is_invincible:
		return
		
	GameManager.lives -= 1
	
	if GameManager.lives > 0:
		_execute_down_sequence(attacker_pos)
	else:
		queue_free()
		
func _execute_down_sequence(attacker_pos: Vector3) -> void:
	is_dead = true
	GameManager.player_down = true
	velocity = Vector3.ZERO
	
	anim_tree.active = false
	animation.stop()
	
	var forward_vector = -model.global_transform.basis.z
	var dir_to_attacker = (attacker_pos - global_position).normalized()
	
	# Added the "player_animations/" prefix here!
	if forward_vector.dot(dir_to_attacker) > 0:
		animation.play("player_animations/death_from_front")
		print("HIT FROM FRONT! Attempting to play 'death_from_front'")
	else:
		animation.play("player_animations/death_from_back")
	
	await get_tree().create_timer(3.0).timeout
	_execute_revive_sequence()
	
func _execute_revive_sequence() -> void:
	is_dead = false
	GameManager.player_down = false
	is_invincible = true
	
	# Added the prefix here as well for the idle state!
	animation.play("player_animations/idle") 
	anim_tree.active = true
	
	for i in range(15):
		model.visible = not model.visible
		await get_tree().create_timer(0.2).timeout
	
	model.visible = true
	is_invincible = false
	
