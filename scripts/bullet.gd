extends Area3D

@onready var ray: RayCast3D = $RayCast3D

var speed: float = 40.0 
var damage: float = 10.0
var trail: Node3D = null # Added reference

func _physics_process(delta: float) -> void:
	# 1. Check for collisions BEFORE moving
	# This prevents the bullet from passing through a wall in a single frame
	if ray.is_colliding():
		var target = ray.get_collider()
		impact(target)
		return # Stop execution here if we hit something

	# 2. Move the bullet forward along its local -Z axis
	var motion = -global_transform.basis.z * speed * delta
	global_position += motion

func impact(target: Node3D) -> void:
	# Truncate trail trajectory to impact point
	if is_instance_valid(trail):
		trail.target_pos = global_position
	# Check if the target has a health system/take_damage function
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Destroy the bullet immediately on impact
	queue_free()

func _on_timer_timeout() -> void:
	# Destroy the bullet if it hasn't hit anything after X seconds (prevents lag)
	queue_free()
