class_name EffectsFactory
extends RefCounted


## Esplosione di piume quando il piccione viene colpito. Riavviare con restart().
static func create_feather_burst() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 1.1
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.mesh = LowPolyBuilder.new() \
		.box(Vector3(0.09, 0.012, 0.26), Vector3.ZERO, Color("f2f2f2")) \
		.box(Vector3(0.07, 0.012, 0.2), Vector3(0.0, 0.0, 0.02), Palette.PIGEON_WING, Vector3(0.0, 30.0, 0.0)) \
		.build()
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0.0, -3.0, 6.0)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	return particles
