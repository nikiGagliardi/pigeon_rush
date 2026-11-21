class_name PigeonModel
extends Node3D
## Uccello low-poly procedurale: di default il piccione torraiolo, ma specie e piumaggio vengono da BirdLook
## (negozio). Guarda verso -Z. Parti animate: testa (oscilla), coda (segue il battito), ali in due segmenti
## (braccio + mano) con la mano in ritardo di fase per un battito "a onda".
##
## Agganci per gli accessori (BirdAccessories), uguali per ogni specie: sulla testa (sommità, faccia) e sul
## corpo (collo), più il punto da cui cade la cacca. La hitbox è del controller, non del modello: non cambia.

const HEAD_PIVOT := Vector3(0.0, 0.2, -0.4)
const TAIL_PIVOT := Vector3(0.0, 0.03, 0.4)
const SHOULDER_X := 0.17
const ELBOW_X := 0.44
## Agganci, nelle coordinate della testa (i primi due) e del corpo.
const SOCKET_HEAD := Vector3(0.0, 0.215, -0.13)
const SOCKET_FACE := Vector3(0.0, 0.11, -0.17)
const SOCKET_NECK := Vector3(0.0, 0.1, -0.36)
const POOP_ORIGIN := Vector3(0.0, -0.26, 0.16)

static var _meshes: Dictionary[String, ArrayMesh] = {}

var look: BirdLook
var _head: Node3D
var _tail: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase: float = 0.0
var _head_pivot := HEAD_PIVOT


func _init(p_look: BirdLook = null) -> void:
	_build(p_look if p_look != null else BirdLook.new())


## Cambia aspetto (anteprima del negozio, nuovo acquisto): ricostruisce i nodi, i mesh restano in cache.
func set_look(p_look: BirdLook) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_shoulders.clear()
	_elbows.clear()
	_build(p_look)


## Punto da cui cade la cacca, nelle coordinate del modello (per gli effetti: il gioco usa sempre lo stesso
## punto del controller, PoopSystem._drop_origin, così la mira non cambia con l'aspetto).
func poop_origin() -> Vector3:
	return POOP_ORIGIN * BirdCatalog.species(look.species).body_scale


func _build(p_look: BirdLook) -> void:
	look = p_look
	var species := BirdCatalog.species(look.species)
	var key := "%s/%s" % [species.id, look.plumage]

	var body := _mesh_instance(_part(key, "body", species))
	body.scale = species.body_scale
	add_child(body)

	_head = Node3D.new()
	_head_pivot = HEAD_PIVOT * species.body_scale
	_head.position = _head_pivot
	_head.scale = Vector3.ONE * species.head_scale
	_head.add_child(_mesh_instance(_part(key, "head", species)))
	add_child(_head)

	_tail = Node3D.new()
	_tail.position = TAIL_PIVOT * species.body_scale
	_tail.add_child(_mesh_instance(_part(key, "tail", species)))
	add_child(_tail)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * SHOULDER_X, 0.1, -0.06) * species.body_scale
		shoulder.add_child(_mesh_instance(_part(key, "inner_wing_%d" % i, species)))
		var elbow := Node3D.new()
		elbow.position = Vector3(side * ELBOW_X, 0.0, 0.0)
		elbow.add_child(_mesh_instance(_part(key, "outer_wing_%d" % i, species)))
		shoulder.add_child(elbow)
		add_child(shoulder)
		_shoulders.append(shoulder)
		_elbows.append(elbow)

	_attach(_head, SOCKET_HEAD, look.head)
	_attach(_head, SOCKET_FACE, look.face)
	_attach(body, SOCKET_NECK, look.neck)


func _attach(parent: Node3D, socket: Vector3, id: StringName) -> void:
	if id == BirdCatalog.NONE:
		return
	var mesh := BirdAccessories.mesh(id)
	if mesh == null:
		return
	var instance := _mesh_instance(mesh)
	instance.position = socket
	parent.add_child(instance)


## rate: velocità angolare del battito (rad/s).
## amplitude: ampiezza del braccio in radianti (la mano aggiunge un'onda in ritardo).
func flap(dt: float, rate: float, amplitude: float = 0.75) -> void:
	_phase += dt * rate
	var arm := sin(_phase) * amplitude + 0.1
	var hand := sin(_phase - 0.8) * amplitude * 0.65
	_set_wings(arm, hand)

	# la testa resta quasi ferma mentre il corpo sobbalza; la coda compensa il battito
	_head.position = _head_pivot + Vector3(0.0, -sin(_phase) * 0.012, 0.0)
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

static func _part(key: String, part: String, species: BirdCatalog.Species) -> ArrayMesh:
	var full := key + "/" + part
	var mesh: ArrayMesh = _meshes.get(full)
	if mesh != null:
		return mesh
	var p := BirdCatalog.plumage(species.id, StringName(key.get_slice("/", 1)))
	match part:
		"body":
			mesh = _build_body(p)
		"head":
			mesh = _build_head(p, species)
		"tail":
			mesh = _build_tail(p, species)
		"inner_wing_0":
			mesh = _build_inner_wing(p, -1.0)
		"inner_wing_1":
			mesh = _build_inner_wing(p, 1.0)
		"outer_wing_0":
			mesh = _build_outer_wing(p, -1.0)
		"outer_wing_1":
			mesh = _build_outer_wing(p, 1.0)
	_meshes[full] = mesh
	return mesh


## Tutti i pezzi di un aspetto (AssetWarmup, anteprime del negozio).
static func warm(species_id: StringName, plumage_id: StringName) -> void:
	var species := BirdCatalog.species(species_id)
	var key := "%s/%s" % [species.id, plumage_id]
	for part: String in ["body", "head", "tail", "inner_wing_0", "inner_wing_1", "outer_wing_0", "outer_wing_1"]:
		_part(key, part, species)


static func _c(p: Dictionary, key: String) -> Color:
	return p[key] as Color


static func _build_body(p: Dictionary) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(0.3, Vector3(0.0, 0.0, 0.02), Vector3(1.0, 0.88, 1.5), _c(p, "body"), 14, 9) \
		.sphere(0.26, Vector3(0.0, -0.07, 0.05), Vector3(0.95, 0.72, 1.35), _c(p, "belly"), 12, 7) \
		.sphere(0.23, Vector3(0.0, 0.01, -0.27), Vector3(1.0, 1.0, 0.95), _c(p, "chest"), 12, 8) \
		.sphere(0.17, Vector3(0.0, 0.15, -0.36), Vector3(1.0, 1.05, 0.9), _c(p, "neck"), 12, 7) \
		.sphere(0.15, Vector3(0.0, 0.08, -0.41), Vector3(1.05, 0.8, 0.8), _c(p, "neck2"), 12, 7) \
		.sphere(0.17, Vector3(0.0, 0.07, 0.36), Vector3(1.0, 0.55, 1.0), _c(p, "rump"), 10, 6)
	# corpo, pancia, petto, collo, riflesso del collo, groppone

	# zampe raccolte sotto il corpo
	for x: float in [-0.08, 0.08]:
		b.cylinder(0.022, 0.026, 0.1, Vector3(x, -0.24, 0.1), _c(p, "foot"), 6, Vector3(-30.0, 0.0, 0.0))
		for t in range(-1, 2):
			b.box(Vector3(0.018, 0.018, 0.075), Vector3(x + t * 0.022, -0.28, 0.14), _c(p, "foot"), Vector3(-15.0, t * 20.0, 0.0))

	return b.build()


## Testa con becco (lunghezza e spessore della specie), cera, occhi. Origine al perno del collo.
static func _build_head(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var beak := _c(p, "beak")
	var length := species.beak_length
	var radius := species.beak_radius
	var b := LowPolyBuilder.new() \
		.sphere(0.15, Vector3(0.0, 0.08, -0.12), Vector3(0.95, 0.95, 1.08), _c(p, "head"), 12, 8) \
		.sphere(0.1, Vector3(0.0, 0.12, -0.2), Vector3(0.9, 0.7, 1.0), _c(p, "head"), 10, 6) \
		.cylinder(0.0, radius, length, Vector3(0.0, 0.06, -0.235 - length * 0.5), beak, 6, Vector3(-92.0, 0.0, 0.0)) \
		.cylinder(0.0, radius * 0.37, 0.04, Vector3(0.0, 0.058, -0.235 - length), _c(p, "beak_tip"), 5, Vector3(-100.0, 0.0, 0.0)) \
		.cylinder(0.0, radius * 0.68, length * 0.73, Vector3(0.0, 0.03, -0.235 - length * 0.37), beak, 5, Vector3(-96.0, 0.0, 0.0))
	if species.has_cere:
		b.sphere(0.045, Vector3(0.0, 0.09, -0.245), Vector3(1.1, 0.7, 1.2), _c(p, "cere"), 8, 5)

	for side: float in [-1.0, 1.0]:
		b.sphere(0.04, Vector3(side * 0.124, 0.11, -0.17), Vector3(0.5, 1.0, 1.0), _c(p, "eye_ring"), 8, 5)
		b.sphere(0.031, Vector3(side * 0.132, 0.11, -0.17), Vector3(0.6, 1.0, 1.0), _c(p, "eye"), 8, 5)
		b.sphere(0.016, Vector3(side * 0.147, 0.11, -0.172), Vector3(0.6, 1.0, 1.0), _c(p, "pupil"), 6, 4)
		b.sphere(0.006, Vector3(side * 0.155, 0.118, -0.18), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)

	return b.build()


## Coda a ventaglio di 7 penne con banda terminale (arcobaleno nel piumaggio "rainbow"). Origine alla base.
static func _build_tail(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var rainbow: bool = p.get("rainbow_tail", false)
	for i in range(-3, 4):
		var angle := i * species.tail_spread
		var rad := deg_to_rad(angle)
		var dir := Vector3(sin(rad), 0.0, cos(rad))
		var extra := species.tail_center_extra * (1.0 - absi(i) / 3.0) # coda a cuneo del corvo
		var lift := 0.002 * (3 - absi(i)) # le centrali stanno sopra, niente z-fighting
		var band := Color.from_hsv((i + 3) / 7.0, 0.8, 0.95) if rainbow else _c(p, "tail_band")
		b.sphere(1.0, dir * (0.2 + extra * 0.5) + Vector3(0.0, lift, 0.0), Vector3(0.07, 0.016, 0.24 + extra * 0.5), _c(p, "tail"), 6, 3, Vector3(-6.0, angle, 0.0))
		b.sphere(1.0, dir * (0.4 + extra) + Vector3(0.0, lift + 0.004, 0.0), Vector3(0.072, 0.017, 0.06), band, 6, 3, Vector3(-6.0, angle, 0.0))
	b.sphere(0.12, Vector3(0.0, 0.01, 0.02), Vector3(1.1, 0.35, 1.0), _c(p, "body"), 8, 4) # attacco
	return b.build()


## Braccio dell'ala: copritrici, scapolari, due barre, remiganti secondarie (croce bianca nel piumaggio "swiss").
static func _build_inner_wing(p: Dictionary, side: float) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.23, 0.0, 0.03), Vector3(0.26, 0.035, 0.19), _c(p, "wing"), 10, 5) \
		.sphere(1.0, Vector3(side * 0.1, 0.02, 0.1), Vector3(0.14, 0.03, 0.2), _c(p, "body"), 8, 4)

	# le due barre tipiche del piccione torraiolo
	b.box(Vector3(0.3, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.08), _c(p, "bar"), Vector3(0.0, side * -8.0, 0.0))
	b.box(Vector3(0.28, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.15), _c(p, "bar"), Vector3(0.0, side * -8.0, 0.0))

	for k in 5:
		var x := side * (0.07 + k * 0.085)
		b.sphere(1.0, Vector3(x, -0.006, 0.19), Vector3(0.075, 0.014, 0.15), _c(p, "secondary"), 6, 3, Vector3(0.0, side * k * 4.0, 0.0))

	if p.get("cross", false):
		var c := Vector3(side * 0.25, 0.04, 0.01)
		b.box(Vector3(0.17, 0.012, 0.055), c, Color("f4f4f4"))
		b.box(Vector3(0.055, 0.012, 0.17), c, Color("f4f4f4"))

	return b.build()


## Mano dell'ala: copritrici e 6 remiganti primarie a ventaglio. Origine al gomito.
static func _build_outer_wing(p: Dictionary, side: float) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.12, 0.0, 0.02), Vector3(0.14, 0.028, 0.13), _c(p, "wing"), 8, 4)

	var shades: Array[Color] = [
		_c(p, "primary_dark"), _c(p, "primary_dark"), _c(p, "primary_mid"),
		_c(p, "primary_mid"), _c(p, "primary_light"), _c(p, "primary_light"),
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
