extends GPUParticles3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = true
	# Delete the node after the effect is finished
	await get_tree().create_timer(lifetime).timeout
	queue_free()
