class_name TrafficSpawner
extends Node3D
## Genera, muove e ricicla traffico, strutture e raccoglibili.
## Il traffico arriva a "file" (righe): ogni riga lascia almeno MIN_FREE_CELLS celle libere
## e almeno una adiacente a una cella libera della riga precedente, quindi c'è sempre un varco raggiungibile.

const Kind := VehicleCatalog.Kind

signal pigeon_hit(position: Vector3)
signal near_miss(position: Vector3)
signal pickup_collected(kind: Pickup.PickupKind, position: Vector3)
## Un mezzo ha visto il piccione davanti e lampeggia (clacson).
signal vehicle_warned(vehicle: Vehicle)
## Un mezzo sta per sfrecciare accanto al piccione.
signal vehicle_passing(vehicle: Vehicle)

const MIN_FREE_CELLS := 2
const ARRIVAL_WINDOW := 0.75

# cambio corsia: solo mezzi lontani (in secondi dal piccione), raramente
const LANE_CHANGE_MIN_TIME := 3.5
const LANE_CHANGE_MAX_TIME := 5.5
const LANE_CHANGE_MAX_AHEAD := 280.0
const LANE_CHANGE_CLEARANCE := 12.0 # spazio libero davanti/dietro nella corsia di destinazione
const ROW_NEIGHBOURHOOD := 12.0 # mezzi considerati "sulla stessa fila" per il varco

# finestra in cui un mezzo "vede" il piccione davanti e lampeggia
const FLASH_MIN_AHEAD := 15.0
const FLASH_MAX_AHEAD := 85.0

# suono di passaggio: parte in anticipo perché il picco del file coincida col sorpasso
const PASSBY_LEAD_CAR := 0.6
const PASSBY_LEAD_HEAVY := 0.85
const PASSBY_MAX_LATERAL := 5.5

var spawning_enabled: bool = false
var vehicles: Array[Vehicle] = []
## 0..1: quanto il piccione è dentro una galleria (per l'illuminazione).
var tunnel_darkness: float = 0.0

var _structures: Array[Hazard] = []
var _pickups: Array[Pickup] = []
var _rng := RandomNumberGenerator.new()

var _vehicle_pool: NodePool
var _gantry_pool: NodePool
var _overpass_pool: NodePool
var _tunnel_pool: NodePool
var _works_pool: NodePool
var _pickup_pool: NodePool

var _row_countdown: float = 0.0
var _structure_countdown: float = 90.0
var _grace: float = GameConfig.START_GRACE
var _prev_free_mask: int = Cells.ALL
var _lane_change_cooldown: float = 12.0


func _ready() -> void:
	_vehicle_pool = NodePool.new(self, func() -> Node3D: return Vehicle.new(), 24)
	_gantry_pool = NodePool.new(self, func() -> Node3D: return SignGantry.new(), 3)
	_overpass_pool = NodePool.new(self, func() -> Node3D: return Overpass.new(), 2)
	_tunnel_pool = NodePool.new(self, func() -> Node3D: return Tunnel.new(), 1)
	_works_pool = NodePool.new(self, func() -> Node3D: return RoadWorks.new(), 1)
	_pickup_pool = NodePool.new(self, func() -> Node3D: return Pickup.new(), 8)


func tick(dt: float, ground_step: float, traffic_step: float, session: GameSession) -> void:
	_move_and_recycle(dt, ground_step, traffic_step)
	_update_tunnel_darkness()

	if not spawning_enabled:
		return

	if _grace > 0.0:
		_grace -= dt
		return

	_structure_countdown -= ground_step
	if _structure_countdown <= 0.0:
		var occupied := _spawn_structure(-_structure_countdown)
		_structure_countdown += occupied + _next_structure_gap(session.difficulty)

	_row_countdown -= traffic_step
	if _row_countdown <= 0.0:
		_spawn_row(session, -_row_countdown)
		_row_countdown += _row_spacing(session)

	_lane_change_cooldown -= dt
	if _lane_change_cooldown <= 0.0:
		if _try_start_lane_change(session):
			_lane_change_cooldown = lerpf(10.0, 6.0, session.difficulty) + _rng.randf_range(0.0, 5.0)
		else:
			_lane_change_cooldown = 1.0 # nessun candidato valido: riprova tra poco


## Collisioni, passaggi a filo e raccolta oggetti.
## invulnerable: dopo il Continua gli ostacoli attraversano il piccione senza colpirlo (e senza passaggi a filo).
func resolve_pigeon(pigeon: PigeonController, ground_step: float, traffic_step: float, approach_speed: float, invulnerable: bool = false) -> void:
	var pigeon_box := pigeon.bounds()
	var pigeon_z := pigeon.position.z

	_flash_lead_vehicles(pigeon_box, pigeon_z)

	for vehicle: Vehicle in vehicles:
		_resolve_hazard(vehicle, pigeon, pigeon_box, pigeon_z, traffic_step, invulnerable)
		_check_passby(vehicle, pigeon.position, approach_speed)

	for structure: Hazard in _structures:
		_resolve_hazard(structure, pigeon, pigeon_box, pigeon_z, ground_step, invulnerable)

	for i in range(_pickups.size() - 1, -1, -1):
		var pickup := _pickups[i]
		var delta := pickup.position - pigeon.position
		# tolleranza estesa su Z: a 60 m/s il raccoglibile si sposta di 1 m per frame
		if absf(delta.x) < 1.4 and absf(delta.y) < 1.3 and delta.z > -1.4 - traffic_step and delta.z < 1.4:
			pickup_collected.emit(pickup.kind, pickup.position)
			_remove_pickup_at(i)


## Abbaglianti: lampeggia solo il primo mezzo di ogni corsia (il più vicino al piccione, non ancora passato),
## e solo se il piccione è sulla sua traiettoria. Quelli dietro non vedono il piccione.
func _flash_lead_vehicles(pigeon_box: AABB, pigeon_z: float) -> void:
	var lead: Array[int] = [-1, -1, -1]
	for i in vehicles.size():
		var vehicle := vehicles[i]
		var front := vehicle.front_z()
		if front >= pigeon_z:
			continue # già accanto o dietro al piccione
		var current := lead[vehicle.lane]
		if current < 0 or front > vehicles[current].front_z():
			lead[vehicle.lane] = i

	for index: int in lead:
		if index < 0:
			continue
		var vehicle := vehicles[index]
		if vehicle.has_flashed or vehicle.is_hit:
			continue
		var ahead := pigeon_z - vehicle.front_z()
		if ahead > FLASH_MIN_AHEAD and ahead < FLASH_MAX_AHEAD and vehicle.is_in_path(pigeon_box):
			vehicle.flash_high_beams(_rng.randi_range(2, 3)) # 2 o 3 lampeggi
			vehicle_warned.emit(vehicle)


func _check_passby(vehicle: Vehicle, pigeon: Vector3, approach_speed: float) -> void:
	if vehicle.passby_played:
		return
	var lead := PASSBY_LEAD_HEAVY if vehicle.is_heavy else PASSBY_LEAD_CAR
	var time_to_pass := (pigeon.z - vehicle.position.z) / maxf(1.0, approach_speed)
	if time_to_pass > lead:
		return
	vehicle.mark_passby() # uno solo per mezzo, anche se lontano lateralmente
	if absf(vehicle.position.x - pigeon.x) < PASSBY_MAX_LATERAL:
		vehicle_passing.emit(vehicle)


func _resolve_hazard(hazard: Hazard, pigeon: PigeonController, pigeon_box: AABB, pigeon_z: float, sweep: float, invulnerable: bool) -> void:
	if hazard.passed_pigeon:
		return

	if invulnerable:
		# chi supera il piccione mentre è invulnerabile non conta come passaggio a filo
		if hazard.rear_z() > pigeon_z + GameConfig.PIGEON_HALF_EXTENTS.z:
			hazard.passed_pigeon = true
		return

	var min_gap := INF
	for b in hazard.box_count():
		var box := hazard.world_box(b, sweep)
		if box.intersects(pigeon_box):
			if not hazard.touched_pigeon:
				pigeon_hit.emit(pigeon.position)
			hazard.touched_pigeon = true
		min_gap = minf(min_gap, Hazard.gap_xy(box, pigeon_box))

	# Valuta il passaggio a filo quando l'ostacolo supera il piccione
	if hazard.rear_z() > pigeon_z + GameConfig.PIGEON_HALF_EXTENTS.z:
		hazard.passed_pigeon = true
		if not hazard.touched_pigeon and min_gap < GameConfig.NEAR_MISS_DISTANCE:
			near_miss.emit(pigeon.position)


func _move_and_recycle(dt: float, ground_step: float, traffic_step: float) -> void:
	var traffic_delta := Vector3(0.0, 0.0, traffic_step)
	var ground_delta := Vector3(0.0, 0.0, ground_step)

	for i in range(vehicles.size() - 1, -1, -1):
		var vehicle := vehicles[i]
		vehicle.position += traffic_delta
		vehicle.tick_lights(dt)
		vehicle.tick_lane_change(dt)
		if vehicle.rear_z() > GameConfig.DESPAWN_Z:
			_vehicle_pool.release(vehicle)
			_remove_swap(vehicles, i)

	for i in range(_structures.size() - 1, -1, -1):
		var structure := _structures[i]
		structure.position += ground_delta
		structure.animate(dt)
		if structure.rear_z() <= GameConfig.DESPAWN_Z:
			continue
		_release_structure(structure)
		_remove_swap(_structures, i)

	for i in range(_pickups.size() - 1, -1, -1):
		var pickup := _pickups[i]
		pickup.position += traffic_delta
		pickup.animate(dt)
		if pickup.position.z > GameConfig.DESPAWN_Z:
			_remove_pickup_at(i)


func _release_structure(structure: Hazard) -> void:
	if structure is SignGantry:
		_gantry_pool.release(structure)
	elif structure is Overpass:
		_overpass_pool.release(structure)
	elif structure is Tunnel:
		_tunnel_pool.release(structure)
	elif structure is RoadWorks:
		_works_pool.release(structure)


## Ripresa dopo il Continua: toglie mezzi e strutture tra il piccione e distance metri davanti,
## compreso quello appena colpito. Le gallerie restano (il piccione può esserci dentro e si vola
## sotto il soffitto): si azzera solo il contatto, così le ventole tornano pericolose.
func clear_ahead(distance: float) -> void:
	var behind := GameConfig.PIGEON_HALF_EXTENTS.z + 1.0
	for i in range(vehicles.size() - 1, -1, -1):
		var vehicle := vehicles[i]
		if vehicle.front_z() > -distance and vehicle.rear_z() < behind:
			_vehicle_pool.release(vehicle)
			_remove_swap(vehicles, i)

	for i in range(_structures.size() - 1, -1, -1):
		var structure := _structures[i]
		if structure.front_z() <= -distance or structure.rear_z() >= behind:
			continue
		if structure is Tunnel:
			structure.touched_pigeon = false
			continue
		_release_structure(structure)
		_remove_swap(_structures, i)

	# la prossima fila riparte senza vincoli dalla precedente (che non c'è più)
	_prev_free_mask = Cells.ALL


## Limiti laterali di volo alla coordinata Z (le reti dei cantieri restringono la strada): x = minimo, y = massimo.
func get_fly_limits(z: float) -> Vector2:
	var limits := Vector2(-GameConfig.FLY_HALF_WIDTH, GameConfig.FLY_HALF_WIDTH)
	for structure: Hazard in _structures:
		var works := structure as RoadWorks
		if works == null:
			continue
		var limit := works.lateral_limit(z)
		if is_nan(limit):
			continue
		if works.closed_lane == 0:
			limits.x = maxf(limits.x, limit)
		else:
			limits.y = minf(limits.y, limit)
	return limits


## Quota massima della camera alla coordinata Z indicata (gallerie).
func camera_ceiling(z: float) -> float:
	var ceiling := INF
	for structure: Hazard in _structures:
		var tunnel := structure as Tunnel
		if tunnel != null:
			ceiling = minf(ceiling, tunnel.camera_ceiling_at(z))
	return ceiling


func _update_tunnel_darkness() -> void:
	var darkness := 0.0
	for structure: Hazard in _structures:
		var tunnel := structure as Tunnel
		if tunnel != null:
			darkness = maxf(darkness, tunnel.darkness_at(0.0))
	tunnel_darkness = darkness


## Restituisce la lunghezza occupata dalla struttura oltre la sua profondità standard (gallerie, cantieri).
func _spawn_structure(overshoot: float) -> float:
	var z := GameConfig.SPAWN_Z + overshoot
	var roll := _rng.randf()

	if roll < 0.16:
		var length: float = TunnelMeshes.LENGTHS[_rng.randi_range(0, TunnelMeshes.LENGTHS.size() - 1)]
		var tunnel: Tunnel = _tunnel_pool.acquire()
		tunnel.activate(length, z, _rng)
		_structures.append(tunnel)
		return length + Tunnel.PORTAL_DEPTH

	if roll < 0.32:
		var length: float = RoadWorksMeshes.LENGTHS[_rng.randi_range(0, RoadWorksMeshes.LENGTHS.size() - 1)]
		var works: RoadWorks = _works_pool.acquire()
		# il cartello "ROADWORKS" sta 40 m prima del cantiere: è lui a comparire per primo sulla linea di spawn
		var lane := 0 if _rng.randf() < 0.5 else GameConfig.LANE_COUNT - 1
		works.activate(lane, length, z - RoadWorksMeshes.SIGN_AHEAD, _rng)
		_structures.append(works)
		return length + RoadWorksMeshes.SIGN_AHEAD * 2.0 # un cartello per estremità

	if roll < 0.74:
		var panel_roll := _rng.randf()
		var lane_bits: int
		if panel_roll < 0.5:
			lane_bits = 1 << _rng.randi_range(0, GameConfig.LANE_COUNT - 1)
		elif panel_roll < 0.85:
			lane_bits = 0b111 & ~(1 << _rng.randi_range(0, GameConfig.LANE_COUNT - 1))
		else:
			lane_bits = 0b111
		var gantry: SignGantry = _gantry_pool.acquire()
		gantry.activate(lane_bits, z, _rng)
		_structures.append(gantry)
	else:
		var overpass: Overpass = _overpass_pool.acquire()
		overpass.activate(z)
		_structures.append(overpass)

	return 0.0


func _spawn_row(session: GameSession, overshoot: float) -> void:
	var speed := session.speed
	var difficulty := session.difficulty
	var z := GameConfig.SPAWN_Z + overshoot

	var structure_info := _structure_mask_at(z, speed)
	var structure_mask := structure_info.x
	var closed_lanes := structure_info.y

	# Contenuto delle corsie: -1 = vuota
	var kinds: Array[int] = [-1, -1, -1]
	var open_lanes := 0
	for lane in GameConfig.LANE_COUNT:
		if (closed_lanes & (1 << lane)) == 0:
			open_lanes += 1

	var count := mini(_pick_vehicle_count(difficulty), open_lanes)
	var placed := 0
	while placed < count:
		var lane := _rng.randi_range(0, GameConfig.LANE_COUNT - 1)
		if kinds[lane] >= 0 or (closed_lanes & (1 << lane)) != 0:
			continue
		kinds[lane] = _pick_kind(difficulty)
		placed += 1

	# Garantisce varco minimo e raggiungibilità dalla riga precedente
	var reachable := Cells.dilate(_prev_free_mask)
	var blocked := _blocked_mask(kinds, structure_mask)
	for guard in GameConfig.LANE_COUNT:
		var free := Cells.ALL & ~blocked
		if Cells.count_of(free) >= MIN_FREE_CELLS and (free & reachable) != 0:
			break
		var lane := _lane_to_clear(kinds, reachable)
		if lane < 0:
			break
		kinds[lane] = -1
		blocked = _blocked_mask(kinds, structure_mask)

	var free_mask := Cells.ALL & ~blocked
	_prev_free_mask = free_mask if free_mask != 0 else Cells.ALL

	for lane in GameConfig.LANE_COUNT:
		if kinds[lane] < 0:
			continue
		var vehicle: Vehicle = _vehicle_pool.acquire()
		var x := GameConfig.lane_x(lane) + _rng.randf_range(-0.25, 0.25)
		vehicle.activate(kinds[lane] as Kind, _rng.randi_range(0, 15), lane, x, z + _rng.randf_range(-2.5, 2.5))
		vehicles.append(vehicle)

	_try_spawn_pickup(session, free_mask, z)


## Celle occupate dalle strutture quando un mezzo che ora è in z arriverà al piccione (x),
## e corsie chiuse da cantieri che quel mezzo attraverserebbe in vista (y).
func _structure_mask_at(z: float, speed: SpeedController) -> Vector2i:
	var pigeon_speed := maxf(1.0, speed.pigeon_speed)
	var arrival := -z / maxf(1.0, speed.approach_speed)
	var mask := 0
	var closed_lanes := 0
	for structure: Hazard in _structures:
		var start := -structure.front_z() / pigeon_speed
		var end := -structure.rear_z() / pigeon_speed
		if arrival > start - ARRIVAL_WINDOW and arrival < end + ARRIVAL_WINDOW:
			mask |= structure.cell_mask
		var works := structure as RoadWorks
		if works != null and works.blocks_vehicle(z, speed.approach_speed, pigeon_speed):
			closed_lanes |= 1 << works.closed_lane
	return Vector2i(mask, closed_lanes)


## Sceglie a caso un mezzo lontano che può spostarsi in una corsia adiacente in sicurezza.
## Regole: spazio libero nella corsia di destinazione, niente corsie chiuse da cantieri,
## e la "fila" del mezzo deve continuare a lasciare almeno MIN_FREE_CELLS celle libere.
func _try_start_lane_change(session: GameSession) -> bool:
	if vehicles.is_empty():
		return false

	var speed := session.speed
	var approach := maxf(1.0, speed.approach_speed)
	var min_ahead := LANE_CHANGE_MIN_TIME * approach
	var max_ahead := minf(LANE_CHANGE_MAX_AHEAD, LANE_CHANGE_MAX_TIME * approach)

	var start := _rng.randi_range(0, vehicles.size() - 1)
	for n in vehicles.size():
		var vehicle := vehicles[(start + n) % vehicles.size()]
		if vehicle.is_changing_lane:
			continue
		var ahead := -vehicle.front_z() # il piccione è a Z = 0
		if ahead < min_ahead or ahead > max_ahead:
			continue
		# prova prima una direzione a caso, poi l'altra
		var first := -1 if _rng.randf() < 0.5 else 1
		for d in 2:
			var target := vehicle.lane + (first if d == 0 else -first)
			if _can_change_lane(vehicle, target, speed):
				vehicle.start_lane_change(target)
				return true

	return false


func _can_change_lane(vehicle: Vehicle, target: int, speed: SpeedController) -> bool:
	if target < 0 or target >= GameConfig.LANE_COUNT:
		return false

	var structure_info := _structure_mask_at(vehicle.position.z, speed)
	if (structure_info.y & (1 << target)) != 0:
		return false # corsia chiusa da un cantiere

	var blocked := structure_info.x
	for other: Vehicle in vehicles:
		if other == vehicle:
			continue
		var dz := absf(other.position.z - vehicle.position.z)
		# spazio libero nella corsia di destinazione (anche per chi ci sta già entrando)
		var gap := (other.spec.length + vehicle.spec.length) * 0.5 + LANE_CHANGE_CLEARANCE
		if dz < gap and (other.lane == target or other.target_lane == target):
			return false
		# occupazione della "fila": chi cambia corsia conta su entrambe
		if dz < ROW_NEIGHBOURHOOD:
			blocked |= _vehicle_mask(other.lane, other.spec) | _vehicle_mask(other.target_lane, other.spec)

	blocked |= _vehicle_mask(target, vehicle.spec) | _vehicle_mask(vehicle.lane, vehicle.spec)
	return Cells.count_of(Cells.ALL & ~blocked) >= MIN_FREE_CELLS


static func _vehicle_mask(lane: int, spec: VehicleCatalog.Spec) -> int:
	return Cells.of(lane, 0) | (Cells.of(lane, 1) if spec.blocks_mid else 0)


func _try_spawn_pickup(session: GameSession, free_mask: int, z: float) -> void:
	var chance := 0.5 if session.ammo <= 2 else 0.25
	if free_mask == 0 or _rng.randf() > chance:
		return

	# cella libera casuale
	var pick := _rng.randi_range(0, Cells.count_of(free_mask) - 1)
	for lane in GameConfig.LANE_COUNT:
		for band in GameConfig.BAND_COUNT:
			if not Cells.has(free_mask, lane, band):
				continue
			if pick != 0:
				pick -= 1
				continue
			var pickup: Pickup = _pickup_pool.acquire()
			pickup.activate(Pickup.PickupKind.CRUMBS, Vector3(GameConfig.lane_x(lane), GameConfig.band_center_y(band), z - 8.0))
			_pickups.append(pickup)
			return


static func _blocked_mask(kinds: Array[int], structure_mask: int) -> int:
	var mask := structure_mask
	for lane in kinds.size():
		if kinds[lane] < 0:
			continue
		mask |= Cells.of(lane, 0)
		if VehicleCatalog.get_spec(kinds[lane] as Kind).blocks_mid:
			mask |= Cells.of(lane, 1)
	return mask


## Sceglie la corsia occupata più vicina alle celle raggiungibili.
static func _lane_to_clear(kinds: Array[int], reachable: int) -> int:
	var best := -1
	var best_score := 1 << 30
	for lane in kinds.size():
		if kinds[lane] < 0:
			continue
		var score := 10
		for band in GameConfig.BAND_COUNT:
			if Cells.has(reachable, lane, band):
				score = band # preferisci liberare dove il piccione può già arrivare in basso
				break
		if score < best_score:
			best_score = score
			best = lane
	return best


func _pick_vehicle_count(difficulty: float) -> int:
	var r := _rng.randf()
	if r < 0.08:
		return 0
	if r < 0.08 + 0.10 + 0.35 * difficulty:
		return 3
	if r < 0.65 + 0.1 * difficulty:
		return 2
	return 1


func _pick_kind(difficulty: float) -> Kind:
	var r := _rng.randf()
	if r < 0.05:
		return Kind.CABRIO
	if r < 0.10:
		return Kind.CLEAN_CAR
	if r < 0.21 + 0.06 * difficulty:
		return Kind.TRUCK
	if r < 0.32 + 0.13 * difficulty:
		return Kind.BUS
	if r < 0.50 + 0.13 * difficulty:
		return Kind.VAN
	return Kind.CAR


func _row_spacing(session: GameSession) -> float:
	return lerpf(46.0, 30.0, session.difficulty) + session.speed.approach_speed * 0.15 + _rng.randf_range(-4.0, 6.0)


func _next_structure_gap(difficulty: float) -> float:
	return lerpf(150.0, 85.0, difficulty) + _rng.randf_range(0.0, 50.0)


func _remove_pickup_at(index: int) -> void:
	_pickup_pool.release(_pickups[index])
	_remove_swap(_pickups, index)


static func _remove_swap(list: Array, index: int) -> void:
	list[index] = list[list.size() - 1]
	list.pop_back()
