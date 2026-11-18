class_name PigeonController
extends Node3D
## Movimento libero del piccione nel rettangolo di volo (X/Y), con inerzia e inclinazione.
## Resta sempre a Z = 0: è il mondo a venirgli incontro.

var velocity: Vector3 = Vector3.ZERO

var _model: PigeonModel
var _shadow: MeshInstance3D
var _idle_time: float = 0.0


func bounds() -> AABB:
	return AABB(position - GameConfig.PIGEON_HALF_EXTENTS, GameConfig.PIGEON_HALF_EXTENTS * 2.0)


func _ready() -> void:
	position = Vector3(0.0, GameConfig.PIGEON_START_Y, 0.0)

	_model = PigeonModel.new()
	add_child(_model)

	var blob := CylinderMesh.new()
	blob.top_radius = 0.5
	blob.bottom_radius = 0.5
	blob.height = 0.02
	blob.radial_segments = 12
	blob.rings = 1
	_shadow = MeshInstance3D.new()
	_shadow.mesh = blob
	_shadow.material_override = Palette.shadow_blob()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)
	_update_shadow()


## input: direzione desiderata, componenti in [-1, 1] (Y positivo = su).
## flap_rate: velocità del battito d'ali. min_x / max_x: limiti laterali (ristretti dai cantieri).
func tick(dt: float, input: Vector2, flap_rate: float, min_x: float = -GameConfig.FLY_HALF_WIDTH, max_x: float = GameConfig.FLY_HALF_WIDTH) -> void:
	var target := Vector3(input.x * GameConfig.MAX_LATERAL_SPEED, input.y * GameConfig.MAX_VERTICAL_SPEED, 0.0)
	velocity = velocity.move_toward(target, GameConfig.FLY_ACCELERATION * dt)

	var p := position + velocity * dt
	if p.x < min_x or p.x > max_x:
		# la rete del cantiere avanza in diagonale: il piccione viene spinto, senza danni
		p.x = clampf(p.x, min_x, max_x)
		velocity.x = 0.0
	if p.y < GameConfig.FLY_MIN_Y or p.y > GameConfig.FLY_MAX_Y:
		p.y = clampf(p.y, GameConfig.FLY_MIN_Y, GameConfig.FLY_MAX_Y)
		velocity.y = 0.0
	position = p

	# inclinazione: rollio sulle virate, beccheggio salendo/scendendo
	var bank := -velocity.x / GameConfig.MAX_LATERAL_SPEED * deg_to_rad(35.0)
	var pitch := velocity.y / GameConfig.MAX_VERTICAL_SPEED * deg_to_rad(22.0)
	var k := 1.0 - exp(-10.0 * dt)
	_model.rotation = _model.rotation.lerp(Vector3(pitch, 0.0, bank), k)

	# in salita sbatte di più, in discesa plana
	var rate_scale := 1.4 if input.y > 0.3 else (0.6 if input.y < -0.5 else 1.0)
	_model.flap(dt, flap_rate * rate_scale)
	_update_shadow()


## Volo "di presentazione" nel menu iniziale.
func tick_idle(dt: float) -> void:
	_idle_time += dt
	position = Vector3(sin(_idle_time * 0.7) * 1.2, GameConfig.PIGEON_START_Y + sin(_idle_time * 1.3) * 0.4, 0.0)
	_model.rotation = Vector3(cos(_idle_time * 1.3) * 0.12, 0.0, -cos(_idle_time * 0.7) * 0.25)
	_model.flap(dt, 11.0)
	_update_shadow()


## Caduta dopo il game over.
func tick_crash(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * dt)
	velocity.y -= 22.0 * dt
	var p := position + velocity * dt
	if p.y < 0.25:
		p.y = 0.25
		velocity = Vector3.ZERO
	else:
		_model.rotation += Vector3(4.0 * dt, 0.0, 7.0 * dt)
	position = p
	_model.glide(dt)
	_update_shadow()


func _update_shadow() -> void:
	var height01 := clampf(position.y / GameConfig.FLY_MAX_Y, 0.0, 1.0)
	var s := lerpf(1.1, 0.45, height01)
	_shadow.global_position = Vector3(position.x, 0.03, position.z)
	_shadow.scale = Vector3(s, 1.0, s * 1.3)
