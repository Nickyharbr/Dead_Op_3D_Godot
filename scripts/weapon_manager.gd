extends Node3D
class_name WeaponManager

# References assigned in the Inspector
@export var weapon_slot: BoneAttachment3D
@export var left_hand_ik: SkeletonIK3D
@export var shoot_sound: AudioStreamPlayer3D

# Internal node reference
@onready var fire_timer: Timer = $FireTimer

# Preloaded scenes
var flash_scene = preload("res://effects/muzzle_flash.tscn")
var bullet_scene = preload("res://scenes/bullet.tscn")
var trail_scene = preload("res://effects/bullet_trail.tscn")

var current_weapon: Node3D = null

# Weapon dictionary
var weapons = {
	"rifle": preload("res://scenes/weapons/rifle.tscn"),
}

func equip_weapon(weapon_name: String) -> void:
	if not weapons.has(weapon_name):
		return
		
	# Clear existing weapon
	if current_weapon != null:
		current_weapon.queue_free()
		
	# Instantiate and attach new weapon
	var weapon_instance = weapons[weapon_name].instantiate()
	weapon_slot.add_child(weapon_instance)
	weapon_instance.transform = Transform3D.IDENTITY
	current_weapon = weapon_instance
	
	# Handle IK targeting for the left hand
	var grip_target = weapon_instance.get_node_or_null("LeftHandGrip")
	if grip_target:
		left_hand_ik.target_node = grip_target.get_path()
		left_hand_ik.start()
	else:
		left_hand_ik.stop()

func shoot() -> void:
	# Halt execution if no weapon is equipped or the firing cooldown is still active.
	if current_weapon == null or not fire_timer.is_stopped():
		return
		
	# Locate the 'Muzzle' Marker3D node on the currently equipped weapon instance.
	var muzzle = current_weapon.get_node_or_null("Muzzle")
	if muzzle:
		# Randomize audio pitch slightly per shot to prevent audio fatigue.
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		shoot_sound.play()
		
		# --- POINT-BLANK RAYCAST CHECK ---
		# Calculate a raycast from the player's center to the weapon's muzzle.
		# Prevents bullets from spawning behind enemies that overlap the player's geometry.
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position, muzzle.global_position)
		
		# Exclude the player's own CharacterBody3D collision shape from this raycast.
		# Assumes WeaponManager is a direct child of the Player node.
		query.exclude = [get_parent().get_rid()] 
		
		# Execute the physics query.
		var hit_result = space_state.intersect_ray(query)
		
		if hit_result:
			var flash = flash_scene.instantiate()
			# The raycast hit an enemy inside the player's bounding box before reaching the muzzle.
			# Apply damage directly to the intersected collider.
			if hit_result.collider.has_method("take_damage"):
				hit_result.collider.take_damage(10.0)
				
			# Spawn the muzzle flash exactly at the point of intersection on the enemy body.
			get_tree().root.add_child(flash)
			flash.global_position = hit_result.position
			
			# Start cooldown timer and abort the rest of the function.
			# Do not spawn a physical projectile or visual trail.
			fire_timer.start()
			return 

		# --- STANDARD PROJECTILE SPAWN ---
		# Instantiate the physical bullet projectile.
		var bullet = bullet_scene.instantiate()
		
		# Add to the root scene tree to detach its movement from the player's movement.
		get_tree().root.add_child(bullet)
		
		# Align bullet origin and orientation perfectly with the muzzle marker.
		bullet.global_transform = muzzle.global_transform
		
		# Extract Euler rotation, force pitch (X-axis) to 0 to ensure the bullet travels perfectly level.
		var bullet_rotation = muzzle.global_transform.basis.get_euler()
		bullet_rotation.x = 0 
		bullet.global_transform.basis = Basis.from_euler(bullet_rotation)
		
		# Instantiate standard muzzle flash attached directly to the weapon's muzzle.
		var flash = flash_scene.instantiate()
		muzzle.add_child(flash) 
		
		# Instantiate the visual bullet trail.
		var trail = trail_scene.instantiate()
		get_tree().root.add_child(trail)
		
		# Snap trail origin to the muzzle.
		trail.global_position = muzzle.global_position
		
		# Calculate the initial target coordinate for the trail mesh to stretch toward.
		# Projects 1000 units forward along the bullet's leveled Z-axis vector.
		trail.target_pos = muzzle.global_position - bullet.global_transform.basis.z * 1000.0
		
		# Synchronize the visual trail's movement speed with the bullet's physics speed.
		trail.speed = bullet.speed
		
		# Pass the trail node reference to the bullet node.
		# Allows the bullet to update the trail's termination coordinate upon impact.
		bullet.trail = trail

	# Start cooldown timer for standard shots.
	fire_timer.start()
