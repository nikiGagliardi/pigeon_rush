class_name RoadWorks
extends Hazard
## Cantiere che chiude la corsia sinistra o destra: la strada diventa a due corsie.
## Le due estremità sono speculari: quella verso il piccione (+Z) e quella da cui arrivano le auto (-Z),
## perché la chiusura serve al traffico. Ognuna ha cartello, carrello con freccia e invito con coni e rete.
## Il ponteggio con rete alto 8 m (sopra il volo massimo) impedisce di passare sopra la corsia chiusa:
## la rete è un muro morbido che spinge il piccione verso le corsie aperte (nessun danno).
## I carrelli e i macchinari sono invece ostacoli veri.

const MachineKind := RoadWorksMeshes.MachineKind
const MAX_MACHINES := 3
## Distanza minima tra il centro del piccione e la rete (metà barriera + metà piccione + margine).
const NET_CLEARANCE := 0.7
const ENDS: Array[float] = [1.0, -1.0]

var closed_lane: int = 0
var length: float = 0.0

var _mesh: MeshInstance3D
var _beacons: Array[MeshInstance3D] = []
var _net_tapers: Array[MeshInstance3D] = []
var _net_straight: MeshInstance3D
var _machines: Array[MeshInstance3D] = []
var _works_labels: Array[Label3D] = []
var _limit_labels: Array[Label3D] = []
var _beeper: AudioStreamPlayer3D
var _blink: float = 0.0


func _init() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)

	_net_straight = _make_net()
	for e in 2:
		var yaw := 0.0 if e == 0 else PI # estremità -Z: girato verso le auto
		var beacon := MeshInstance3D.new()
		beacon.mesh = RoadWorksMeshes.beacons()
		beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beacon.rotation = Vector3(0.0, yaw, 0.0)
		add_child(beacon)
		_beacons.append(beacon)
		_net_tapers.append(_make_net())

		var works := _make_label("ROADWORKS", 64, 0.0042, yaw)
		var limit := _make_label("80", 72, 0.006, yaw)
		_works_labels.append(works)
		_limit_labels.append(limit)

	for i in MAX_MACHINES:
		var machine := MeshInstance3D.new()
		machine.visible = false
		add_child(machine)
		_machines.append(machine)

	# cicalino di retromarcia della prima macchina operatrice
	_beeper = GameAudio.create_spatial_player(GameAudio.WORLD_BUS, 8.0, 90.0)
	_beeper.volume_db = -4.0
	add_child(_beeper)


## Include il cartello dell'estremità lontana, così non sparisce mentre è ancora in vista.
func rear_z() -> float:
	return position.z - length * 0.5 - RoadWorksMeshes.SIGN_AHEAD - 1.0


## p_closed_lane: 0 = sinistra, 2 = destra (dal punto di vista del piccione).
## front_z: posizione dell'estremità verso il piccione (+Z), cartello escluso.
func activate(p_closed_lane: int, p_length: float, p_front_z: float, rng: RandomNumberGenerator) -> void:
	reset_flags()
	closed_lane = p_closed_lane
	length = p_length
	position = Vector3(0.0, 0.0, p_front_z - p_length * 0.5)
	_mesh.mesh = RoadWorksMeshes.get_mesh(p_closed_lane, p_length)

	var half := p_length * 0.5
	var lane_x := GameConfig.lane_x(p_closed_lane)
	var inner := RoadWorksMeshes.taper_inner(p_length)
	var trailer_z := half - RoadWorksMeshes.TRAILER_OFFSET
	var sign_x := RoadWorksMeshes.sign_post_x(p_closed_lane)
	var sign_z := half + RoadWorksMeshes.SIGN_AHEAD + 0.06

	local_boxes.clear()

	# barriera longitudinale nel tratto centrale
	var barrier_x := RoadWorksMeshes.barrier_x(p_closed_lane)
	local_boxes.append(AABB(Vector3(barrier_x - 0.25, 0.0, -inner), Vector3(0.5, 1.0, inner * 2.0)))

	for e in 2:
		var end := ENDS[e]
		_beacons[e].position = Vector3(lane_x, 0.0, end * trailer_z)
		_works_labels[e].position = Vector3(sign_x, 2.3, end * sign_z)
		_limit_labels[e].position = Vector3(sign_x, 3.4, end * sign_z)
		# carrello segnaletico (ostacolo)
		local_boxes.append(AABB(Vector3(lane_x - 1.3, 0.0, end * trailer_z - 1.55), Vector3(2.6, 3.95, 3.1)))

	_place_nets(p_closed_lane, p_length)
	_place_machines(lane_x, inner, rng)
	_start_beeper()

	cell_mask = Cells.of(p_closed_lane, 0) | Cells.of(p_closed_lane, 1) | Cells.of(p_closed_lane, 2)


## Limite laterale imposto dalla rete alla coordinata Z del mondo, NAN se la rete non c'è.
## Per la corsia 0 è un minimo su X, per la corsia 2 un massimo.
## La rete si chiude in diagonale all'estremità +Z e si riapre, speculare, all'estremità -Z.
func lateral_limit(world_z: float) -> float:
	var distance := absf(world_z - position.z)
	var outer := RoadWorksMeshes.taper_outer(length)
	if distance > outer:
		return NAN
	var inner := RoadWorksMeshes.taper_inner(length)
	var barrier := RoadWorksMeshes.barrier_x(closed_lane)
	var wall := barrier
	if distance > inner:
		wall = lerpf(RoadWorksMeshes.edge_x(closed_lane), barrier, (outer - distance) / RoadWorksMeshes.TAPER_LENGTH)
	return wall - RoadWorksMeshes.side(closed_lane) * NET_CLEARANCE


func _process(_delta: float) -> void:
	# tornato nel pool: il cicalino si spegne
	if not visible and _beeper.playing:
		_beeper.stop()


func animate(dt: float) -> void:
	_blink += dt
	var on := fposmod(_blink, 0.7) < 0.35
	_beacons[0].visible = on
	_beacons[1].visible = on


## True se un mezzo generato in spawn_z nella corsia chiusa attraverserebbe il cantiere
## prima di uscire dalla visuale (i mezzi sono più veloci del cantiere e lo raggiungono da dietro).
func blocks_vehicle(spawn_z: float, approach_speed: float, pigeon_speed: float) -> bool:
	var margin := 8.0 # mezza lunghezza del mezzo più lungo + tolleranza
	var front := position.z + length * 0.5 + margin
	var rear := position.z - length * 0.5 - margin
	if spawn_z >= front:
		return false # già davanti al cantiere: non lo incontrerà mai
	var relative := maxf(0.1, approach_speed - pigeon_speed)
	var catch_up := maxf(0.0, (rear - spawn_z) / relative)
	return spawn_z + approach_speed * catch_up < GameConfig.DESPAWN_Z


func _start_beeper() -> void:
	_beeper.stop()
	if GameAudio.instance == null:
		return
	var stream := GameAudio.instance.stream(GameAudio.Sfx.WORKS_BEEP)
	if stream == null:
		return
	for machine: MeshInstance3D in _machines:
		if not machine.visible:
			continue
		_beeper.stream = stream
		_beeper.position = machine.position + Vector3(0.0, 2.2, 0.0)
		_beeper.pitch_scale = 0.95 + randf() * 0.1
		_beeper.play()
		return


func _make_net() -> MeshInstance3D:
	var net := MeshInstance3D.new()
	net.mesh = RoadWorksMeshes.net()
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	return net


func _make_label(text: String, font_size: int, pixel_size: float, yaw: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Palette.PANEL_BLACK
	label.outline_size = 0
	label.rotation = Vector3(0.0, yaw, 0.0)
	add_child(label)
	return label


func _place_nets(lane: int, p_length: float) -> void:
	var height := RoadWorksMeshes.SCAFFOLD_HEIGHT
	var barrier_x := RoadWorksMeshes.barrier_x(lane)
	var edge := RoadWorksMeshes.edge_x(lane)
	var inner := RoadWorksMeshes.taper_inner(p_length)
	var outer := RoadWorksMeshes.taper_outer(p_length)

	# rete dritta: quad ruotato di 90° su Y (asse X locale → asse Z del mondo)
	_net_straight.position = Vector3(barrier_x, height * 0.5, 0.0)
	_net_straight.rotation = Vector3(0.0, PI * 0.5, 0.0)
	_net_straight.scale = Vector3(inner * 2.0, height, 1.0)

	# reti diagonali: dal bordo esterno (±outer) alla barriera (±inner)
	for e in 2:
		var end := ENDS[e]
		var dx := barrier_x - edge
		var dz := end * (inner - outer)
		var diagonal := sqrt(dx * dx + dz * dz)
		var net := _net_tapers[e]
		net.position = Vector3(edge + dx * 0.5, height * 0.5, end * outer + dz * 0.5)
		net.rotation = Vector3(0.0, atan2(-dz, dx), 0.0)
		net.scale = Vector3(diagonal, height, 1.0)


func _place_machines(lane_x: float, inner: float, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(1, MAX_MACHINES)
	var cursor := inner - 15.0
	for i in MAX_MACHINES:
		var machine := _machines[i]
		if i >= count or cursor < -inner + 10.0:
			machine.visible = false
			continue
		var z := cursor - rng.randf() * 15.0
		var kind: MachineKind = MachineKind.EXCAVATOR if rng.randf() < 0.6 else MachineKind.ROLLER
		var x := lane_x + (rng.randf() - 0.5) * 0.5
		machine.mesh = RoadWorksMeshes.machine(kind)
		machine.position = Vector3(x, 0.0, z)
		machine.visible = true
		_add_machine_boxes(kind, x, z)
		cursor = z - 30.0 - rng.randf() * 20.0


func _add_machine_boxes(kind: MachineKind, x: float, z: float) -> void:
	if kind == MachineKind.EXCAVATOR:
		local_boxes.append(AABB(Vector3(x - 1.3, 0.0, z - 2.1), Vector3(2.6, 3.5, 4.2))) # corpo
		local_boxes.append(AABB(Vector3(x - 0.15, 2.1, z + 1.0), Vector3(1.2, 3.3, 4.9))) # braccio
	else:
		local_boxes.append(AABB(Vector3(x - 1.1, 0.0, z - 2.2), Vector3(2.2, 3.1, 4.6)))
