extends CharacterBody3D
class_name Zombie

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var health: float = 30.0
var is_dead: bool = false
var speed: float = 2.5
var player: Node3D
@export var attack_range: float = 1.5

# --- THE STATE MACHINE ---
# This strictly tracks what the zombie should be doing so it never gets confused.
var current_state: String = "CHASE"
var attack_cooldown: float = 0.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	anim_player.play("zombie_animations/run")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	# THE FIX: If the player is fully deleted (Game Over), stop moving safely.
	if not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
		if anim_player.is_playing():
			anim_player.stop()
		move_and_slide()
		return

	_evaluate_state()

	# Execute the correct logic based on the current state
	if current_state == "FLEE":
		_execute_flee(delta)
	elif current_state == "CHASE":
		_execute_chase(delta)
	elif current_state == "ATTACK":
		_execute_attack(delta)

	move_and_slide()

func _evaluate_state() -> void:
	# If player dies, drop everything and flee immediately
	if GameManager.player_down:
		current_state = "FLEE"
		return

	# If the player is back up, resume the chase
	if current_state == "FLEE" and not GameManager.player_down:
		current_state = "CHASE"

func _execute_chase(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# THE FIX: Always enforce the run animation during chase!
	# Even if they bump into each other and speed drops to 0, they will keep animating.
	if anim_player.current_animation != "zombie_animations/run":
		anim_player.play("zombie_animations/run")

	var dist = global_position.distance_to(player.global_position)
	if dist <= attack_range and attack_cooldown <= 0:
		_initiate_attack()
		return

	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished() or not nav_agent.is_target_reachable():
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
	else:
		var current_pos = global_position
		var next_pos = nav_agent.get_next_path_position()
		var direction = (Vector3(next_pos.x, current_pos.y, next_pos.z) - current_pos).normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		var look_target = Vector3(next_pos.x, current_pos.y, next_pos.z)
		if current_pos.distance_to(look_target) > 0.05:
			look_at(look_target, Vector3.UP)

func _execute_flee(delta: float) -> void:
	# reliable straight-line math away from the player
	var flee_dir = (global_position - player.global_position).normalized()
	flee_dir.y = 0

	# Push velocity directly in that direction (Bypass the Navigation Agent)
	velocity.x = flee_dir.x * speed
	velocity.z = flee_dir.z * speed

	# 3. Look in the direction they are running
	var look_target = global_position + flee_dir
	if global_position.distance_to(look_target) > 0.05:
		look_at(look_target, Vector3.UP)

	# 4. THE FIX: Check actual movement speed. 
	# get_real_velocity() tells us how fast they actually moved AFTER bumping into walls.
	var actual_speed = Vector2(get_real_velocity().x, get_real_velocity().z).length()

	# If they are successfully moving, play the run animation
	if actual_speed > 0.5:
		if anim_player.current_animation != "zombie_animations/run":
			anim_player.play("zombie_animations/run")
	else:
		# If their actual speed drops to 0 (because their face is stuck in a corner), stop the animation
		if anim_player.is_playing():
			anim_player.stop()

func _initiate_attack() -> void:
	current_state = "ATTACK"
	velocity = Vector3.ZERO
	anim_player.play("zombie_animations/attack", -1, 1.5)

	# Timer 1: The Hit Frame (Guaranteed to finish, unlike animations)
	await get_tree().create_timer(0.33).timeout

	if is_instance_valid(player) and current_state == "ATTACK" and not is_dead:
		var dist = global_position.distance_to(player.global_position)
		if dist <= attack_range:
			if player.has_method("take_damage"):
				player.take_damage(global_position)

	# Timer 2: Finish the animation
	await get_tree().create_timer(0.5).timeout

	if not is_dead:
		attack_cooldown = 0.5 # Small pause before they can swing again
		if current_state == "ATTACK":
			current_state = "CHASE"

func _execute_attack(delta: float) -> void:
	# Lock them in place while the attack timers do the work
	velocity.x = 0
	velocity.z = 0

func take_damage(amount: float) -> void:
	if is_dead:
		return
		
	health -= amount
	
	if health <= 0:
		is_dead = true
		die()
		
	var hit_points = randi_range(10,20)
	GameManager.add_score(hit_points)

func die() -> void:
	GameManager.active_zombies -= 1
	GameManager.total_kills += 1
	remove_from_group("zombie")
	anim_player.play("zombie_animations/death")
	$CollisionShape3D.set_deferred("disabled", true)
	GameManager.add_score(80)
