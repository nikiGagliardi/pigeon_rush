class_name PigeonModel
extends Node3D
## Piccione low-poly procedurale (piccione torraiolo). Guarda verso -Z.
## Parti animate: testa (oscilla), coda (segue il battito), ali in due segmenti
## (braccio + mano) con la mano in ritardo di fase per un battito "a onda".

const HEAD_PIVOT := Vector3(0.0, 0.2, -0.4)
const TAIL_PIVOT := Vector3(0.0, 0.03, 0.4)
const SHOULDER_X := 0.17
const ELBOW_X := 0.44

static var _body_mesh: ArrayMesh
static var _head_mesh: ArrayMesh
static var _tail_mesh: ArrayMesh
static var _inner_wing_meshes: Array[ArrayMesh] = [null, null]
static var _outer_wing_meshes: Array[ArrayMesh] = [null, null]

var _head: Node3D
var _tail: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase: float = 0.0


func _init() -> void:
	add_child(_mesh_instance(body_mesh()))

	_head = Node3D.new()
	_head.position = HEAD_PIVOT
	_head.add_child(_mesh_instance(head_mesh()))
	add_child(_head)

	_tail = Node3D.new()
	_tail.position = TAIL_PIVOT
	_tail.add_child(_mesh_instance(tail_mesh()))
	add_child(_tail)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * SHOULDER_X, 0.1, -0.06)
		shoulder.add_child(_mesh_instance(inner_wing(side)))
		var elbow := Node3D.new()
		elbow.position = Vector3(side * ELBOW_X, 0.0, 0.0)
		elbow.add_child(_mesh_instance(outer_wing(side)))
		shoulder.add_child(elbow)
		add_child(shoulder)
		_shoulders.append(shoulder)
		_elbows.append(elbow)


## rate: velocità angolare del battito (rad/s).
## amplitude: ampiezza del braccio in radianti (la mano aggiunge un'onda in ritardo).
func flap(dt: float, rate: float, amplitude: float = 0.75) -> void:
	_phase += dt * rate
	var arm := sin(_phase) * amplitude + 0.1
	var hand := sin(_phase - 0.8) * amplitude * 0.65
	_set_wings(arm, hand)

	# la testa resta quasi ferma mentre il corpo sobbalza; la coda compensa il battito
	_head.position = HEAD_PIVOT + Vector3(0.0, -sin(_phase) * 0.012, 0.0)
	_head.rotation = Vector3(sin(_phase) * 0.05, 0.0, 0.0)
	_tail.rotation = Vector3(-0.08 + sin(_phase + 0.5) * 0.07, 0.0, 0.0)


## Ali aperte e ferme (planata / caduta).
func glide(dt: float) -> void:
	var k := 1.0 - exp(-6.0 * dt)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_shoulders[i].rotation = _shoulders[i].rotation.lerp(Vector3(0.0, 0.0, side * 0.12), k)
		_elbows[i].rotation = _elbows[i].rotation.lerp(Vector3(0.0, 0.0, side * 0.06), k)
	_tail.rotation = _tail.rotation.lerp(Vector3(-0.15, 0.0, 0.0), k)


## arm: angolo del braccio (positivo = ala alzata). hand: angolo aggiuntivo della mano.
func _set_wings(arm: float, hand: float) -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# rotazione su Z: positiva alza l'ala destra, negativa alza la sinistra
		_shoulders[i].rotation = Vector3(0.0, 0.0, side * arm)
		_elbows[i].rotation = Vector3(0.0, 0.0, side * hand)


static func _mesh_instance(mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


# ------------------------------------------------------------------ mesh

static func body_mesh() -> ArrayMesh:
	if _body_mesh == null:
		_body_mesh = _build_body()
	return _body_mesh


static func head_mesh() -> ArrayMesh:
	if _head_mesh == null:
		_head_mesh = _build_head()
	return _head_mesh


static func tail_mesh() -> ArrayMesh:
	if _tail_mesh == null:
		_tail_mesh = _build_tail()
	return _tail_mesh


static func inner_wing(side: float) -> ArrayMesh:
	var i := 0 if side < 0.0 else 1
	if _inner_wing_meshes[i] == null:
		_inner_wing_meshes[i] = _build_inner_wing(side)
	return _inner_wing_meshes[i]


static func outer_wing(side: float) -> ArrayMesh:
	var i := 0 if side < 0.0 else 1
	if _outer_wing_meshes[i] == null:
		_outer_wing_meshes[i] = _build_outer_wing(side)
	return _outer_wing_meshes[i]


static func _build_body() -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(0.3, Vector3(0.0, 0.0, 0.02), Vector3(1.0, 0.88, 1.5), Palette.PIGEON_BODY, 14, 9) \
		.sphere(0.26, Vector3(0.0, -0.07, 0.05), Vector3(0.95, 0.72, 1.35), Palette.PIGEON_BELLY, 12, 7) \
		.sphere(0.23, Vector3(0.0, 0.01, -0.27), Vector3(1.0, 1.0, 0.95), Palette.PIGEON_CHEST, 12, 8) \
		.sphere(0.17, Vector3(0.0, 0.15, -0.36), Vector3(1.0, 1.05, 0.9), Palette.PIGEON_NECK, 12, 7) \
		.sphere(0.15, Vector3(0.0, 0.08, -0.41), Vector3(1.05, 0.8, 0.8), Palette.PIGEON_NECK_PURPLE, 12, 7) \
		.sphere(0.17, Vector3(0.0, 0.07, 0.36), Vector3(1.0, 0.55, 1.0), Palette.PIGEON_RUMP, 10, 6)
	# corpo, pancia, petto, collo verde, riflesso viola, groppone chiaro

	# zampe raccolte sotto il corpo
	for x: float in [-0.08, 0.08]:
		b.cylinder(0.022, 0.026, 0.1, Vector3(x, -0.24, 0.1), Palette.FOOT, 6, Vector3(-30.0, 0.0, 0.0))
		for t in range(-1, 2):
			b.box(Vector3(0.018, 0.018, 0.075), Vector3(x + t * 0.022, -0.28, 0.14), Palette.FOOT, Vector3(-15.0, t * 20.0, 0.0))

	return b.build()


## Testa con becco, cera, occhi (iride, pupilla, riflesso). Origine al perno del collo.
static func _build_head() -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(0.15, Vector3(0.0, 0.08, -0.12), Vector3(0.95, 0.95, 1.08), Palette.PIGEON_HEAD, 12, 8) \
		.sphere(0.1, Vector3(0.0, 0.12, -0.2), Vector3(0.9, 0.7, 1.0), Palette.PIGEON_HEAD, 10, 6) \
		.cylinder(0.0, 0.038, 0.15, Vector3(0.0, 0.06, -0.31), Palette.BEAK, 6, Vector3(-92.0, 0.0, 0.0)) \
		.cylinder(0.0, 0.014, 0.04, Vector3(0.0, 0.058, -0.385), Palette.BEAK_TIP, 5, Vector3(-100.0, 0.0, 0.0)) \
		.cylinder(0.0, 0.026, 0.11, Vector3(0.0, 0.03, -0.29), Palette.BEAK, 5, Vector3(-96.0, 0.0, 0.0)) \
		.sphere(0.045, Vector3(0.0, 0.09, -0.245), Vector3(1.1, 0.7, 1.2), Palette.CERE, 8, 5)
	# testa, fronte, becco sup., punta, becco inf., cera

	for side: float in [-1.0, 1.0]:
		b.sphere(0.04, Vector3(side * 0.124, 0.11, -0.17), Vector3(0.5, 1.0, 1.0), Palette.EYE_RING, 8, 5)
		b.sphere(0.031, Vector3(side * 0.132, 0.11, -0.17), Vector3(0.6, 1.0, 1.0), Palette.EYE, 8, 5)
		b.sphere(0.016, Vector3(side * 0.147, 0.11, -0.172), Vector3(0.6, 1.0, 1.0), Palette.PUPIL, 6, 4)
		b.sphere(0.006, Vector3(side * 0.155, 0.118, -0.18), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)

	return b.build()


## Coda a ventaglio di 7 penne con banda scura terminale. Origine alla base della coda.
static func _build_tail() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	for i in range(-3, 4):
		var angle := i * 9.0
		var rad := deg_to_rad(angle)
		var dir := Vector3(sin(rad), 0.0, cos(rad))
		var lift := 0.002 * (3 - absi(i)) # le centrali stanno sopra, niente z-fighting
		b.sphere(1.0, dir * 0.2 + Vector3(0.0, lift, 0.0), Vector3(0.07, 0.016, 0.24), Palette.PIGEON_TAIL, 6, 3, Vector3(-6.0, angle, 0.0))
		b.sphere(1.0, dir * 0.4 + Vector3(0.0, lift + 0.004, 0.0), Vector3(0.072, 0.017, 0.06), Palette.PIGEON_TAIL_BAND, 6, 3, Vector3(-6.0, angle, 0.0))
	b.sphere(0.12, Vector3(0.0, 0.01, 0.02), Vector3(1.1, 0.35, 1.0), Palette.PIGEON_BODY, 8, 4) # attacco
	return b.build()


## Braccio dell'ala: copritrici, scapolari, due barre scure, remiganti secondarie. Origine alla spalla.
static func _build_inner_wing(side: float) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.23, 0.0, 0.03), Vector3(0.26, 0.035, 0.19), Palette.PIGEON_WING, 10, 5) \
		.sphere(1.0, Vector3(side * 0.1, 0.02, 0.1), Vector3(0.14, 0.03, 0.2), Palette.PIGEON_BODY, 8, 4)

	# le due barre nere tipiche del piccione torraiolo
	b.box(Vector3(0.3, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.08), Palette.PIGEON_PRIMARY_DARK, Vector3(0.0, side * -8.0, 0.0))
	b.box(Vector3(0.28, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.15), Palette.PIGEON_PRIMARY_DARK, Vector3(0.0, side * -8.0, 0.0))

	for k in 5:
		var x := side * (0.07 + k * 0.085)
		b.sphere(1.0, Vector3(x, -0.006, 0.19), Vector3(0.075, 0.014, 0.15), Palette.PIGEON_SECONDARY, 6, 3, Vector3(0.0, side * k * 4.0, 0.0))

	return b.build()


## Mano dell'ala: copritrici e 6 remiganti primarie a ventaglio. Origine al gomito.
static func _build_outer_wing(side: float) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.12, 0.0, 0.02), Vector3(0.14, 0.028, 0.13), Palette.PIGEON_WING, 8, 4)

	var shades: Array[Color] = [
		Palette.PIGEON_PRIMARY_DARK, Palette.PIGEON_PRIMARY_DARK, Palette.PIGEON_PRIMARY_MID,
		Palette.PIGEON_PRIMARY_MID, Palette.PIGEON_PRIMARY_LIGHT, Palette.PIGEON_PRIMARY_LIGHT,
	]

	var base_point := Vector3(side * 0.12, -0.004, 0.04)
	for k in shades.size():
		# dalla punta (in avanti) verso l'interno (all'indietro), a ventaglio
		var yaw := -side * k * 9.0
		var rad := deg_to_rad(yaw)
		var dir := Vector3(side * cos(rad), 0.0, -side * sin(rad))
		var length := 0.3 - k * 0.02
		b.sphere(1.0, base_point + dir * length * 0.85 + Vector3(0.0, -k * 0.002, 0.0),
			Vector3(length, 0.012, 0.05), shades[k], 6, 3, Vector3(0.0, yaw, 0.0))

	return b.build()
