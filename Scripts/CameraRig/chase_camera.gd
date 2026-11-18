class_name ChaseCamera
extends Camera3D
## Camera alle spalle del piccione: inseguimento morbido, FOV che si allarga col boost, shake sui colpi.

var target: PigeonController = null

var _smoothed: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _roll: float = 0.0


func _ready() -> void:
	fov = 66.0
	near = 0.1
	far = 700.0


func snap() -> void:
	if target != null:
		_smoothed = _desired(target.position)


func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## ceiling: quota massima consentita alla camera (soffitto delle gallerie).
func tick(dt: float, boost_normalized: float, speed_normalized: float, ceiling: float = INF) -> void:
	if target == null:
		return

	var p := target.position
	var k := 1.0 - exp(-7.0 * dt)
	_smoothed = _smoothed.lerp(_desired(p), k)
	if _smoothed.y > ceiling:
		_smoothed.y = ceiling # il limite scende già in modo graduale: nessuno scatto

	_trauma = maxf(0.0, _trauma - dt * 1.6)
	var shake := _trauma * _trauma
	var offset := Vector3(randf_range(-1.0, 1.0) * 0.6, randf_range(-1.0, 1.0) * 0.45, 0.0) * shake

	var look_at_point := Vector3(p.x * 0.85, p.y * 0.85 + 0.4, -14.0)
	look_at_from_position(_smoothed + offset, look_at_point, Vector3.UP)

	_roll = lerpf(_roll, -target.velocity.x * 0.006 + randf_range(-1.0, 1.0) * shake * 0.05, k)
	rotate_object_local(Vector3.BACK, _roll)

	var target_fov := 66.0 + boost_normalized * 16.0 + speed_normalized * 6.0
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * dt))


static func _desired(pigeon: Vector3) -> Vector3:
	return Vector3(pigeon.x * 0.7, pigeon.y * 0.75 + 2.3, 7.5)
