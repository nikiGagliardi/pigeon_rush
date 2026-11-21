class_name PoopSystem
extends Node3D
## Sgancio della cacca con mirino automatico.
## Ogni frame cerca il mezzo che verrebbe centrato sganciando ADESSO (stessa corsia, tetto sotto il piccione,
## davanti entro GameConfig.LOCK_MAX_AHEAD) e mostra un anello sul tetto.
## Se c'è un bersaglio, la traiettoria viene calcolata per intercettarlo.

signal vehicle_hit(vehicle: Vehicle, position: Vector3)
## La cacca ha mancato i mezzi ed è finita sull'asfalto.
signal road_hit(position: Vector3)


class Poop:
	var node: MeshInstance3D
	var velocity: Vector3 = Vector3.ZERO
	var active: bool = false
	var on_road: bool = false


const POOL_SIZE := 16
## Valore restituito da _compute_shot quando il mezzo non è un bersaglio valido.
const NO_SHOT := Vector3(INF, INF, INF)

static var _reticle_mesh: ArrayMesh

var locked_target: Vehicle = null

var _poops: Array[Poop] = []
var _reticle: MeshInstance3D
var _cooldown: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	for i in POOL_SIZE:
		var node := MeshInstance3D.new()
		node.mesh = drop_mesh()
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		var poop := Poop.new()
		poop.node = node
		_poops.append(poop)

	_reticle = MeshInstance3D.new()
	_reticle.mesh = reticle_mesh()
	_reticle.visible = false
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_reticle)


## Aggiorna il bersaglio agganciato e la posizione del mirino. Chiamare dopo aver mosso i veicoli.
func update_lock(dt: float, pigeon: PigeonController, vehicles: Array[Vehicle], approach_speed: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	_pulse += dt

	var from := _drop_origin(pigeon)
	var best: Vehicle = null
	var best_ahead := INF
	for vehicle: Vehicle in vehicles:
		if vehicle.is_hit or not _compute_shot(from, vehicle, approach_speed).is_finite():
			continue
		var ahead := from.z - vehicle.front_z()
		if ahead < best_ahead:
			best_ahead = ahead
			best = vehicle

	locked_target = best
	if best == null:
		_reticle.visible = false
		return

	var spec := best.spec
	var radius := spec.width * 0.55
	var pulse := 1.0 + sin(_pulse * 14.0) * 0.12
	_reticle.visible = true
	_reticle.position = best.position + Vector3(0.0, spec.target_top + 0.08, 0.0)
	_reticle.scale = Vector3(radius * pulse, 1.0, radius * pulse)


## Restituisce true se la cacca è partita.
func try_drop(pigeon: PigeonController, session: GameSession, approach_speed: float) -> bool:
	if _cooldown > 0.0 or not session.try_use_ammo():
		return false

	_cooldown = GameConfig.POOP_COOLDOWN
	var from := _drop_origin(pigeon)
	var velocity := Vector3(pigeon.velocity.x * 0.3, -GameConfig.POOP_INITIAL_DOWN, 0.0)
	if locked_target != null:
		var shot := _compute_shot(from, locked_target, approach_speed)
		if shot.is_finite():
			velocity = shot

	var poop := _get_free()
	if poop == null:
		return true # pool pieno: munizione consumata comunque, caso rarissimo

	poop.active = true
	poop.on_road = false
	poop.velocity = velocity
	poop.node.mesh = drop_mesh()
	poop.node.position = from
	poop.node.scale = Vector3.ONE
	poop.node.visible = true
	return true


func tick(dt: float, ground_step: float, traffic_step: float, vehicles: Array[Vehicle]) -> void:
	for poop: Poop in _poops:
		if not poop.active:
			continue
		var node := poop.node
		if poop.on_road:
			# la macchia sulla strada scorre col manto stradale
			node.position += Vector3(0.0, 0.0, ground_step)
			if node.position.z > GameConfig.DESPAWN_Z:
				_deactivate(poop)
			continue

		poop.velocity.y -= GameConfig.POOP_GRAVITY * dt
		var p := node.position + poop.velocity * dt
		node.position = p
		node.scale = Vector3(0.85, 1.25, 0.85) # goccia allungata in caduta

		if _check_vehicle_hit(poop, p, traffic_step, vehicles):
			continue

		if p.y <= 0.04:
			poop.on_road = true
			node.mesh = road_splat_mesh()
			node.position = Vector3(p.x, 0.03, p.z)
			node.scale = Vector3.ONE
			road_hit.emit(node.position)
		elif p.z < GameConfig.SPAWN_Z or p.z > GameConfig.DESPAWN_Z:
			_deactivate(poop)


func _check_vehicle_hit(poop: Poop, p: Vector3, traffic_step: float, vehicles: Array[Vehicle]) -> bool:
	for vehicle: Vehicle in vehicles:
		if vehicle.is_hit:
			continue
		# tolleranza su Z pari allo spostamento del mezzo in questo frame
		if not vehicle.target_box(0.35 + traffic_step, 0.35).has_point(p):
			continue
		vehicle.mark_hit(p)
		_deactivate(poop)
		vehicle_hit.emit(vehicle, p)
		return true
	return false


## Velocità iniziale per centrare il mezzo, NO_SHOT se non è un bersaglio valido.
static func _compute_shot(from: Vector3, vehicle: Vehicle, approach_speed: float) -> Vector3:
	var spec := vehicle.spec
	var aim_y := spec.target_top - 0.15
	var dy := from.y - aim_y
	if dy < 0.35:
		return NO_SHOT # il piccione è più basso del tetto

	if absf(vehicle.position.x - from.x) > spec.width * 0.5 + 0.7:
		return NO_SHOT # corsia sbagliata

	var ahead := from.z - vehicle.front_z()
	if ahead < GameConfig.LOCK_MIN_AHEAD or ahead > GameConfig.LOCK_MAX_AHEAD:
		return NO_SHOT

	# tempo di caduta: dy = v0·t + ½·g·t²
	var g := GameConfig.POOP_GRAVITY
	var v0 := GameConfig.POOP_INITIAL_DOWN
	var t := (-v0 + sqrt(v0 * v0 + 2.0 * g * dy)) / g
	if t <= 0.01:
		return NO_SHOT

	var impact_z := vehicle.position.z + approach_speed * t # centro del mezzo all'impatto
	var vz := (impact_z - from.z) / t
	if vz < -45.0 or vz > 15.0:
		return NO_SHOT # servirebbe un lancio irrealistico

	var vx := (vehicle.position.x - from.x) / t
	return Vector3(vx, -v0, vz)


static func _drop_origin(pigeon: PigeonController) -> Vector3:
	return pigeon.position + Vector3(0.0, -0.25, 0.15)


func _get_free() -> Poop:
	for poop: Poop in _poops:
		if not poop.active:
			return poop
	# ricicla la macchia sulla strada più vecchia (la più vicina alla camera)
	var oldest: Poop = null
	for poop: Poop in _poops:
		if poop.on_road and (oldest == null or poop.node.position.z > oldest.node.position.z):
			oldest = poop
	return oldest


static func _deactivate(poop: Poop) -> void:
	poop.active = false
	poop.on_road = false
	poop.node.visible = false


## Goccia e macchia sull'asfalto nello stile scelto nel negozio (SplatStyles).
static func drop_mesh() -> ArrayMesh:
	return SplatStyles.drop_mesh(SplatStyles.current)


static func road_splat_mesh() -> ArrayMesh:
	return SplatStyles.road_mesh(SplatStyles.current)


## Anello giallo unlit di raggio 1 (scalato in base al mezzo).
static func reticle_mesh() -> ArrayMesh:
	if _reticle_mesh == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.86
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		_reticle_mesh = LowPolyBuilder.new() \
			.add_primitive(torus, Transform3D.IDENTITY, Palette.RETICLE, true) \
			.box(Vector3(0.5, 0.04, 0.08), Vector3.ZERO, Palette.RETICLE, Vector3.ZERO, true) \
			.box(Vector3(0.08, 0.04, 0.5), Vector3.ZERO, Palette.RETICLE, Vector3.ZERO, true) \
			.build()
	return _reticle_mesh
