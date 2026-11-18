class_name AmbientTraffic
extends Node3D
## Traffico scenografico sulla carreggiata opposta: va nella stessa direzione del piccione (verso -Z),
## niente collisioni. Velocità relativa = velocità piccione − velocità auto:
## a inizio partita le auto ti sorpassano, quando acceleri sei tu a superarle.
## Corsia 0 = sorpasso (vicino allo spartitraffico), corsia 2 = lenta (camion e bus).

const Kind := VehicleCatalog.Kind


class Car:
	var node: MeshInstance3D
	var speed: float = 0.0
	var lane: int = 0
	var active: bool = false


const POOL_SIZE := 16
const MIN_GAP := 22.0
const LANE_SPEEDS: Array[float] = [33.0, 27.0, 22.0]

var _cars: Array[Car] = []
var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0


func _ready() -> void:
	for i in POOL_SIZE:
		var node := MeshInstance3D.new()
		node.rotation_degrees = Vector3(0.0, 180.0, 0.0) # muso verso -Z: vediamo il retro
		node.visible = false
		add_child(node)
		var car := Car.new()
		car.node = node
		_cars.append(car)

	# popolazione iniziale distribuita sulla strada visibile
	for i in 7:
		_try_spawn(_rng.randf_range(GameConfig.SPAWN_Z + 40.0, 0.0))


## pigeon_speed: velocità del piccione rispetto alla strada.
func tick(dt: float, pigeon_speed: float) -> void:
	for car: Car in _cars:
		if not car.active:
			continue
		var p := car.node.position
		p.z += (pigeon_speed - car.speed) * dt
		car.node.position = p
		if p.z > GameConfig.DESPAWN_Z + 15.0 or p.z < GameConfig.SPAWN_Z - 40.0:
			car.active = false
			car.node.visible = false

	_spawn_timer -= dt
	if _spawn_timer > 0.0:
		return
	_spawn_timer = _rng.randf_range(0.6, 1.6)

	# se il piccione è più lento le auto arrivano da dietro la camera, altrimenti le raggiunge da lontano
	var lane := _rng.randi_range(0, GameConfig.LANE_COUNT - 1)
	var faster := pigeon_speed > LANE_SPEEDS[lane]
	_try_spawn(GameConfig.SPAWN_Z - 20.0 if faster else GameConfig.DESPAWN_Z + 10.0, lane)


func _try_spawn(z: float, lane: int = -1) -> void:
	if lane < 0:
		lane = _rng.randi_range(0, GameConfig.LANE_COUNT - 1)

	var free: Car = null
	for car: Car in _cars:
		if not car.active:
			if free == null:
				free = car
			continue
		if car.lane == lane and absf(car.node.position.z - z) < MIN_GAP:
			return # corsia occupata in quel punto

	if free == null:
		return

	var kind := _pick_kind(lane)
	free.active = true
	free.lane = lane
	free.speed = LANE_SPEEDS[lane] + _rng.randf_range(-0.4, 0.4)
	free.node.mesh = VehicleMeshes.get_mesh(kind, _rng.randi_range(0, 15))
	free.node.position = Vector3(RoadMeshes.OPPOSITE_CENTER_X + GameConfig.lane_x(lane), 0.0, z)
	free.node.visible = true


func _pick_kind(lane: int) -> Kind:
	var r := _rng.randf()
	match lane:
		2:
			if r < 0.3:
				return Kind.TRUCK
			if r < 0.45:
				return Kind.BUS
			if r < 0.65:
				return Kind.VAN
			return Kind.CAR
		1:
			return Kind.VAN if r < 0.2 else Kind.CAR
		_:
			return Kind.CABRIO if r < 0.1 else Kind.CAR
