class_name PigeonModel
extends Node3D
## Uccello low-poly procedurale: di default il piccione torraiolo, ma specie e piumaggio vengono da BirdLook
## (negozio). Guarda verso -Z. Parti animate: testa (oscilla), coda (segue il battito), ali in due segmenti
## (braccio + mano) con la mano in ritardo di fase per un battito "a onda".
##
## Agganci per gli accessori (BirdAccessories): sulla testa (sommità, faccia) e sul corpo (collo), più il punto
## da cui cade la cacca. Ogni specie può spostarli un po' (Species.socket_*_offset) e scalare gli accessori.
## Oltre agli uccelli ci sono il maiale volante e l'unicorno (Species.kind), con le stesse parti animate.
## La hitbox è del controller, non del modello: non cambia.

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
	_head_pivot = (HEAD_PIVOT + species.head_offset) * species.body_scale
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
		var offset := species.shoulder_offset
		shoulder.position = Vector3(side * (SHOULDER_X + offset.x), 0.1 + offset.y, -0.06 + offset.z) * species.body_scale
		shoulder.scale = Vector3.ONE * species.wing_scale
		shoulder.add_child(_mesh_instance(_part(key, "inner_wing_%d" % i, species)))
		var elbow := Node3D.new()
		elbow.position = Vector3(side * ELBOW_X, 0.0, 0.0)
		elbow.add_child(_mesh_instance(_part(key, "outer_wing_%d" % i, species)))
		shoulder.add_child(elbow)
		add_child(shoulder)
		_shoulders.append(shoulder)
		_elbows.append(elbow)

	_attach(_head, SOCKET_HEAD + species.socket_head_offset, look.head, species.accessory_scale)
	_attach(_head, SOCKET_FACE + species.socket_face_offset, look.face, species.accessory_scale)
	# il corpo è scalato con body_scale: l'accessorio del collo lo compensa per restare della sua misura
	_attach(body, SOCKET_NECK + species.socket_neck_offset, look.neck, species.accessory_scale, species.body_scale)


func _attach(parent: Node3D, socket: Vector3, id: StringName, scale_factor: float, parent_scale := Vector3.ONE) -> void:
	if id == BirdCatalog.NONE:
		return
	var mesh := BirdAccessories.mesh(id)
	if mesh == null:
		return
	var instance := _mesh_instance(mesh)
	instance.position = socket
	instance.scale = Vector3.ONE * scale_factor / parent_scale
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
			match species.kind:
				&"pig":
					mesh = _build_pig_body(p)
				&"unicorn":
					mesh = _build_unicorn_body(p)
				_:
					mesh = _build_body(p, species)
		"head":
			match species.kind:
				&"pig":
					mesh = _build_pig_head(p)
				&"unicorn":
					mesh = _build_unicorn_head(p)
				_:
					mesh = _build_head(p, species)
		"tail":
			match species.kind:
				&"pig":
					mesh = _build_pig_tail(p)
				&"unicorn":
					mesh = _build_unicorn_tail(p)
				_:
					mesh = _build_upright_tail(p) if species.tail_up else _build_tail(p, species)
		"inner_wing_0":
			mesh = _build_inner_wing(p, -1.0, species)
		"inner_wing_1":
			mesh = _build_inner_wing(p, 1.0, species)
		"outer_wing_0":
			mesh = _build_outer_wing(p, -1.0, species)
		"outer_wing_1":
			mesh = _build_outer_wing(p, 1.0, species)
	_meshes[full] = mesh
	return mesh


## Tutti i pezzi di un aspetto (AssetWarmup, anteprime del negozio).
static func warm(species_id: StringName, plumage_id: StringName) -> void:
	var species := BirdCatalog.species(species_id)
	var key := "%s/%s" % [species.id, plumage_id]
	for part: String in ["body", "head", "tail", "inner_wing_0", "inner_wing_1", "outer_wing_0", "outer_wing_1"]:
		_part(key, part, species)


## Meno spicchi per le specie "cattive": forme a faccette.
static func _seg(fierce: bool, n: int) -> int:
	return maxi(5, roundi(n * 0.55)) if fierce else n


static func _ring(fierce: bool, n: int) -> int:
	return maxi(3, roundi(n * 0.6)) if fierce else n


static func _c(p: Dictionary, key: String) -> Color:
	return p[key] as Color


static func _build_body(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var f := species.fierce
	# le specie "cattive" sono asciutte: pancia e petto più piatti e alti
	var belly_scale := Vector3(0.86, 0.5, 1.3) if f else Vector3(0.95, 0.72, 1.35)
	var belly_y := -0.04 if f else -0.07
	var chest_scale := Vector3(0.92, 0.8, 0.9) if f else Vector3(1.0, 1.0, 0.95)
	var b := LowPolyBuilder.new() \
		.sphere(0.3, Vector3(0.0, 0.0, 0.02), Vector3(1.0, 0.76 if f else 0.88, 1.5), _c(p, "body"), _seg(f, 14), _ring(f, 9)) \
		.sphere(0.26, Vector3(0.0, belly_y, 0.05), belly_scale, _c(p, "belly"), _seg(f, 12), _ring(f, 7)) \
		.sphere(0.23, Vector3(0.0, 0.03 if f else 0.01, -0.27), chest_scale, _c(p, "chest"), _seg(f, 12), _ring(f, 8)) \
		.sphere(0.17, Vector3(0.0, 0.15, -0.36), Vector3(0.92, 1.0, 0.85) if f else Vector3(1.0, 1.05, 0.9), _c(p, "neck"), _seg(f, 12), _ring(f, 7)) \
		.sphere(0.15, Vector3(0.0, 0.09 if f else 0.08, -0.4 if f else -0.41), Vector3(0.95, 0.7, 0.7) if f else Vector3(1.05, 0.8, 0.8), _c(p, "neck2"), _seg(f, 12), _ring(f, 7)) \
		.sphere(0.17, Vector3(0.0, 0.07, 0.36), Vector3(1.0, 0.55, 1.0), _c(p, "rump"), _seg(f, 10), _ring(f, 6))
	# corpo, pancia, petto, collo, riflesso del collo, groppone

	if f:
		# gola arruffata: piume a punta sotto il becco
		for h: Array in [[-0.05, 0.0, -0.46, 0.08], [0.05, 0.0, -0.46, 0.08], [0.0, -0.02, -0.47, 0.1], [-0.03, -0.05, -0.44, 0.07], [0.03, -0.05, -0.44, 0.07]]:
			b.prism(Vector3(0.05, float(h[3]), 0.035), Vector3(float(h[0]), float(h[1]), float(h[2])), _c(p, "neck2"), Vector3(160.0, 0.0, 0.0))

	# zampe raccolte sotto il corpo
	var foot_up := 0.035 if f else 0.0
	for x: float in [-0.08, 0.08]:
		b.cylinder(0.022, 0.026, 0.1, Vector3(x, -0.24 + foot_up, 0.1), _c(p, "foot"), 6, Vector3(-30.0, 0.0, 0.0))
		for t in range(-1, 2):
			b.box(Vector3(0.018, 0.018, 0.075), Vector3(x + t * 0.022, -0.28 + foot_up, 0.14), _c(p, "foot"), Vector3(-15.0, t * 20.0, 0.0))

	return b.build()


## Testa con becco (lunghezza e spessore della specie), cera, occhi. Origine al perno del collo.
static func _build_head(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var beak := _c(p, "beak")
	var length := species.beak_length
	var radius := species.beak_radius
	if species.fierce:
		return _build_fierce_head(p, species)
	if species.beak == &"owl":
		return _build_owl_head(p, species)
	var b := LowPolyBuilder.new() \
		.sphere(0.15, Vector3(0.0, 0.08, -0.12), Vector3(0.95, 0.95, 1.08), _c(p, "head"), 12, 8) \
		.sphere(0.1, Vector3(0.0, 0.12, -0.2), Vector3(0.9, 0.7, 1.0), _c(p, "head"), 10, 6)
	match species.beak:
		&"gull":
			# lungo e giallo, punta piegata in giù, macchia rossa sulla mandibola
			b.cylinder(0.0, radius, length, Vector3(0.0, 0.065, -0.235 - length * 0.5), beak, 6, Vector3(-91.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.5, 0.045, Vector3(0.0, 0.058, -0.225 - length), beak, 5, Vector3(-125.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.7, length * 0.8, Vector3(0.0, 0.035, -0.235 - length * 0.4), beak, 5, Vector3(-95.0, 0.0, 0.0))
			b.sphere(0.017, Vector3(0.0, 0.03, -0.225 - length * 0.72), Vector3(1.2, 1.0, 1.2), _c(p, "beak_spot"), 6, 4)
		&"hook":
			# grosso, con la base gialla e l'uncino che scende
			b.sphere(0.06, Vector3(0.0, 0.085, -0.235), Vector3(1.0, 0.8, 0.9), beak, 8, 5)
			b.cylinder(0.0, radius, length, Vector3(0.0, 0.075, -0.24 - length * 0.5), beak, 6, Vector3(-97.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.5, 0.075, Vector3(0.0, 0.045, -0.235 - length), _c(p, "beak_tip"), 5, Vector3(-150.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.6, length * 0.6, Vector3(0.0, 0.035, -0.24 - length * 0.3), beak.darkened(0.1), 5, Vector3(-100.0, 0.0, 0.0))
		&"chicken":
			# corto e appuntito, cresta sulla testa e bargigli sotto il becco
			b.cylinder(0.0, radius, length, Vector3(0.0, 0.06, -0.235 - length * 0.5), beak, 6, Vector3(-100.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.75, length * 0.8, Vector3(0.0, 0.035, -0.235 - length * 0.4), _c(p, "beak_tip"), 5, Vector3(-105.0, 0.0, 0.0))
			var comb := _c(p, "comb")
			for k in 4:
				var z := -0.22 + k * 0.055
				var r := 0.045 - absf(k - 1.2) * 0.006
				b.sphere(r, Vector3(0.0, 0.215 - absf(k - 1.2) * 0.012, z), Vector3(0.45, 1.0, 0.8), comb, 8, 5)
			b.sphere(0.03, Vector3(0.0, 0.17, -0.245), Vector3(0.5, 0.9, 0.9), comb, 6, 4)
			for side: float in [-1.0, 1.0]:
				b.sphere(0.03, Vector3(side * 0.018, -0.005, -0.25), Vector3(0.6, 1.3, 0.7), comb, 6, 4)
		_:
			b.cylinder(0.0, radius, length, Vector3(0.0, 0.06, -0.235 - length * 0.5), beak, 6, Vector3(-92.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.37, 0.04, Vector3(0.0, 0.058, -0.235 - length), _c(p, "beak_tip"), 5, Vector3(-100.0, 0.0, 0.0))
			b.cylinder(0.0, radius * 0.68, length * 0.73, Vector3(0.0, 0.03, -0.235 - length * 0.37), beak, 5, Vector3(-96.0, 0.0, 0.0))
	if species.has_cere:
		b.sphere(0.045, Vector3(0.0, 0.09, -0.245), Vector3(1.1, 0.7, 1.2), _c(p, "cere"), 8, 5)

	for side: float in [-1.0, 1.0]:
		b.sphere(0.04, Vector3(side * 0.124, 0.11, -0.17), Vector3(0.5, 1.0, 1.0), _c(p, "eye_ring"), 8, 5)
		b.sphere(0.031, Vector3(side * 0.132, 0.11, -0.17), Vector3(0.6, 1.0, 1.0), _c(p, "eye"), 8, 5)
		b.sphere(0.016, Vector3(side * 0.147, 0.11, -0.172), Vector3(0.6, 1.0, 1.0), _c(p, "pupil"), 6, 4)
		b.sphere(0.006, Vector3(side * 0.155, 0.118, -0.18), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)
		if species.brow:
			# sguardo fiero: sopracciglio sporgente sopra l'occhio, più basso verso il becco
			b.box(Vector3(0.085, 0.022, 0.07), Vector3(side * 0.118, 0.14, -0.18), _c(p, "head").darkened(0.18), Vector3(0.0, side * -12.0, side * 20.0))

	return b.build()


## Testa del gufo: grande e tonda, disco facciale chiaro con gli occhioni in avanti, becco piccolo e
## uncinato in mezzo, ciuffi sulle orecchie. Stessa origine e stessi agganci delle altre teste.
static func _build_owl_head(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var head := _c(p, "head")
	var face: Color = p.get("face", _c(p, "belly"))
	var b := LowPolyBuilder.new() \
		.sphere(0.16, Vector3(0.0, 0.09, -0.1), Vector3(1.05, 0.95, 0.95), head, 12, 8)
	for side: float in [-1.0, 1.0]:
		b.sphere(0.085, Vector3(side * 0.062, 0.095, -0.2), Vector3(1.0, 1.05, 0.45), face, 10, 6)
		b.sphere(0.042, Vector3(side * 0.062, 0.1, -0.235), Vector3(1.0, 1.0, 0.45), _c(p, "eye_ring"), 8, 5)
		b.sphere(0.035, Vector3(side * 0.062, 0.1, -0.245), Vector3(1.0, 1.0, 0.45), _c(p, "eye"), 8, 5)
		b.sphere(0.017, Vector3(side * 0.062, 0.1, -0.258), Vector3(1.0, 1.0, 0.45), _c(p, "pupil"), 6, 4)
		b.sphere(0.006, Vector3(side * 0.07, 0.11, -0.264), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)
		# ciuffi
		b.prism(Vector3(0.05, 0.1, 0.03), Vector3(side * 0.085, 0.235, -0.1), head, Vector3(0.0, 0.0, side * -22.0))
	var length := species.beak_length
	b.cylinder(0.0, species.beak_radius, length, Vector3(0.0, 0.055, -0.245 - length * 0.4), _c(p, "beak"), 5, Vector3(-125.0, 0.0, 0.0))
	return b.build()


## Testa "cattiva": a faccette, fronte bassa, becco squadrato con l'uncino, sopracciglia aggrottate
## sopra occhi gialli, ciuffi sulla nuca. Stessa origine e stessi agganci della testa normale.
static func _build_fierce_head(p: Dictionary, species: BirdCatalog.Species) -> ArrayMesh:
	var head := _c(p, "head")
	var beak := _c(p, "beak")
	var length := species.beak_length
	var radius := species.beak_radius
	var brow := head.darkened(0.45)
	var b := LowPolyBuilder.new() \
		.sphere(0.15, Vector3(0.0, 0.075, -0.12), Vector3(0.98, 0.86, 1.12), head, 7, 5) \
		.sphere(0.1, Vector3(0.0, 0.11, -0.2), Vector3(0.95, 0.62, 1.05), head, 6, 4)

	# becco snello a sezione romboidale (cresta in alto): mascella superiore, uncino in punta, mandibola
	b.cylinder(0.0, radius, length, Vector3(0.0, 0.07, -0.225 - length * 0.5), beak, 4, Vector3(-93.0, 0.0, 0.0))
	b.cylinder(0.0, radius * 0.5, 0.04, Vector3(0.0, 0.06, -0.205 - length), _c(p, "beak_tip"), 4, Vector3(-130.0, 0.0, 0.0))
	b.cylinder(0.0, radius * 0.62, length * 0.72, Vector3(0.0, 0.045, -0.225 - length * 0.36), beak.darkened(0.15), 4, Vector3(-98.0, 0.0, 0.0))

	for side: float in [-1.0, 1.0]:
		b.sphere(0.036, Vector3(side * 0.122, 0.105, -0.17), Vector3(0.5, 1.0, 1.0), _c(p, "eye_ring"), 6, 4)
		b.sphere(0.029, Vector3(side * 0.13, 0.105, -0.17), Vector3(0.6, 1.0, 1.0), _c(p, "eye"), 6, 4)
		b.sphere(0.013, Vector3(side * 0.145, 0.103, -0.173), Vector3(0.6, 1.0, 1.0), _c(p, "pupil"), 6, 4)
		b.sphere(0.005, Vector3(side * 0.152, 0.11, -0.18), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)
		# sopracciglio: copre la metà alta dell'occhio, più basso verso il becco
		b.box(Vector3(0.09, 0.024, 0.07), Vector3(side * 0.122, 0.13, -0.178), brow, Vector3(0.0, side * -12.0, side * 24.0))
		# ciuffi sulla nuca
		b.prism(Vector3(0.035, 0.085, 0.018), Vector3(side * 0.035, 0.175, -0.015), head, Vector3(58.0, side * 12.0, 0.0))
	b.prism(Vector3(0.04, 0.1, 0.018), Vector3(0.0, 0.19, -0.03), head, Vector3(52.0, 0.0, 0.0))

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
		if species.fierce:
			# penne dritte e squadrate
			var feather := 0.42 + extra
			b.box(Vector3(0.085, 0.018, feather), dir * (0.04 + feather * 0.5) + Vector3(0.0, lift, 0.0), _c(p, "tail"), Vector3(-6.0, angle, 0.0))
			b.box(Vector3(0.087, 0.02, 0.06), dir * (0.04 + feather - 0.03) + Vector3(0.0, lift + 0.002, 0.0), band, Vector3(-6.0, angle, 0.0))
			continue
		var l := species.tail_length
		b.sphere(1.0, dir * (0.2 * l + extra * 0.5) + Vector3(0.0, lift, 0.0), Vector3(0.07, 0.016, 0.24 * l + extra * 0.5), _c(p, "tail"), 6, 3, Vector3(-6.0, angle, 0.0))
		b.sphere(1.0, dir * (0.4 * l + extra) + Vector3(0.0, lift + 0.004, 0.0), Vector3(0.072, 0.017, 0.06), band, 6, 3, Vector3(-6.0, angle, 0.0))
	b.sphere(0.12, Vector3(0.0, 0.01, 0.02), Vector3(1.1, 0.35, 1.0), _c(p, "body"), 8, 4) # attacco
	return b.build()


## Coda della gallina: penne lunghe e curve che salgono all'indietro, scure con riflessi verdi.
static func _build_upright_tail(p: Dictionary) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var rainbow: bool = p.get("rainbow_tail", false)
	for i in range(-2, 3):
		var yaw := i * 11.0
		var color := Color.from_hsv((i + 2) / 5.0, 0.8, 0.95) if rainbow else (_c(p, "tail_band") if absi(i) == 1 else _c(p, "tail"))
		# due segmenti per penna: la curva che sale e la punta che ricade un po'
		b.sphere(1.0, Vector3(i * 0.035, 0.1, 0.07), Vector3(0.045, 0.16, 0.035), color, 6, 4, Vector3(-35.0, yaw, 0.0))
		b.sphere(1.0, Vector3(i * 0.05, 0.24, 0.16), Vector3(0.04, 0.1, 0.03), color, 6, 4, Vector3(-75.0, yaw, 0.0))
	b.sphere(0.12, Vector3(0.0, 0.02, 0.0), Vector3(1.0, 0.6, 0.9), _c(p, "rump"), 8, 4) # attacco
	return b.build()


## Braccio dell'ala: copritrici, scapolari, due barre, remiganti secondarie (croce bianca nel piumaggio "swiss").
static func _build_inner_wing(p: Dictionary, side: float, species: BirdCatalog.Species) -> ArrayMesh:
	var f := species.fierce
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.23, 0.0, 0.03), Vector3(0.26, 0.035, 0.19), _c(p, "wing"), _seg(f, 10), _ring(f, 5)) \
		.sphere(1.0, Vector3(side * 0.1, 0.02, 0.1), Vector3(0.14, 0.03, 0.2), _c(p, "body"), _seg(f, 8), _ring(f, 4))

	if species.id == BirdCatalog.PIGEON:
		# le due barre tipiche del piccione torraiolo
		b.box(Vector3(0.3, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.08), _c(p, "bar"), Vector3(0.0, side * -8.0, 0.0))
		b.box(Vector3(0.28, 0.075, 0.035), Vector3(side * 0.24, 0.004, 0.15), _c(p, "bar"), Vector3(0.0, side * -8.0, 0.0))

	for k in 5:
		var x := side * (0.07 + k * 0.085)
		if f:
			b.box(Vector3(0.07, 0.014, 0.26), Vector3(x, -0.006, 0.2), _c(p, "secondary"), Vector3(0.0, side * k * 4.0, 0.0))
		else:
			b.sphere(1.0, Vector3(x, -0.006, 0.19), Vector3(0.075, 0.014, 0.15), _c(p, "secondary"), 6, 3, Vector3(0.0, side * k * 4.0, 0.0))

	if p.get("cross", false):
		var c := Vector3(side * 0.25, 0.04, 0.01)
		b.box(Vector3(0.17, 0.012, 0.055), c, Color("f4f4f4"))
		b.box(Vector3(0.055, 0.012, 0.17), c, Color("f4f4f4"))

	return b.build()


## Mano dell'ala: copritrici e 6 remiganti primarie a ventaglio. Origine al gomito.
static func _build_outer_wing(p: Dictionary, side: float, species: BirdCatalog.Species) -> ArrayMesh:
	var f := species.fierce
	var b := LowPolyBuilder.new() \
		.sphere(1.0, Vector3(side * 0.12, 0.0, 0.02), Vector3(0.14, 0.028, 0.13), _c(p, "wing"), _seg(f, 8), _ring(f, 4))

	var shades: Array[Color] = [
		_c(p, "primary_dark"), _c(p, "primary_dark"), _c(p, "primary_mid"),
		_c(p, "primary_mid"), _c(p, "primary_light"), _c(p, "primary_light"),
	]

	var base_point := Vector3(side * 0.12, -0.004, 0.04)
	for k in shades.size():
		# dalla punta (in avanti) verso l'interno (all'indietro), a ventaglio
		var yaw := -side * k * (11.0 if f else 9.0)
		var rad := deg_to_rad(yaw)
		var dir := Vector3(side * cos(rad), 0.0, -side * sin(rad))
		var length := 0.3 - k * 0.02
		if f:
			# remiganti "a dita", strette e separate, con la punta squadrata
			b.box(Vector3(length * 1.7, 0.012, 0.042), base_point + dir * length * 0.85 + Vector3(0.0, -k * 0.002, 0.0),
				shades[k], Vector3(0.0, yaw, 0.0))
			continue
		b.sphere(1.0, base_point + dir * length * 0.85 + Vector3(0.0, -k * 0.002, 0.0),
			Vector3(length, 0.012, 0.05), shades[k], 6, 3, Vector3(0.0, yaw, 0.0))

	return b.build()


# ------------------------------------------------------------------ maiale volante

## Corpo del maiale: botte rosa con la pancia più chiara e quattro zampette con gli zoccoli.
static func _build_pig_body(p: Dictionary) -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.sphere(0.31, Vector3(0.0, -0.02, 0.02), Vector3(1.0, 0.9, 1.3), _c(p, "body"), 14, 9) \
		.sphere(0.25, Vector3(0.0, -0.09, 0.02), Vector3(0.95, 0.7, 1.25), _c(p, "belly"), 12, 7) \
		.sphere(0.2, Vector3(0.0, 0.0, -0.26), Vector3(1.05, 1.0, 0.9), _c(p, "chest"), 12, 8)
	for leg: Vector3 in [Vector3(-0.12, -0.25, -0.17), Vector3(0.12, -0.25, -0.17), Vector3(-0.12, -0.25, 0.2), Vector3(0.12, -0.25, 0.2)]:
		b.cylinder(0.045, 0.05, 0.12, leg, _c(p, "body"), 8)
		b.cylinder(0.046, 0.046, 0.04, leg + Vector3(0.0, -0.075, 0.0), _c(p, "foot"), 8)
	return b.build()


## Testa del maiale: tonda, grugno con le narici, orecchie a punta che ricadono, occhietti neri.
static func _build_pig_head(p: Dictionary) -> ArrayMesh:
	var head := _c(p, "head")
	var snout: Color = p.get("snout", _c(p, "beak"))
	var b := LowPolyBuilder.new() \
		.sphere(0.17, Vector3(0.0, 0.02, -0.07), Vector3(1.0, 0.95, 0.95), head, 12, 8) \
		.cylinder(0.07, 0.075, 0.07, Vector3(0.0, -0.01, -0.235), snout, 10, Vector3(-90.0, 0.0, 0.0))
	var nostril: Color = p.get("nostril", _c(p, "beak_tip"))
	var ear: Color = p.get("ear", head.darkened(0.08))
	for side: float in [-1.0, 1.0]:
		b.sphere(0.016, Vector3(side * 0.026, -0.005, -0.27), Vector3(0.8, 1.2, 0.5), nostril, 6, 4)
		b.prism(Vector3(0.09, 0.1, 0.025), Vector3(side * 0.1, 0.16, -0.05), ear, Vector3(-25.0, 0.0, side * -35.0))
		b.sphere(0.022, Vector3(side * 0.085, 0.07, -0.19), Vector3(0.7, 1.0, 0.8), _c(p, "eye"), 6, 4)
		b.sphere(0.006, Vector3(side * 0.092, 0.078, -0.206), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)
	return b.build()


## Codino a molla: due giri di spirale.
static func _build_pig_tail(p: Dictionary) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var color := _c(p, "tail")
	for k in 9:
		var a := k * 0.8
		var r := 0.045 - k * 0.002
		b.sphere(0.018, Vector3(cos(a) * r, 0.04 + sin(a) * r + k * 0.006, 0.03 + k * 0.012), Vector3.ONE, color, 6, 4)
	return b.build()


# ------------------------------------------------------------------ unicorno

## Corpo dell'unicorno: botte bianca, collo che sale in avanti con la criniera pastello, zampe raccolte in volo.
static func _build_unicorn_body(p: Dictionary) -> ArrayMesh:
	var body := _c(p, "body")
	var b := LowPolyBuilder.new() \
		.sphere(0.27, Vector3(0.0, -0.02, 0.06), Vector3(0.95, 0.88, 1.5), body, 14, 9) \
		.sphere(0.22, Vector3(0.0, -0.08, 0.06), Vector3(0.9, 0.7, 1.4), _c(p, "belly"), 12, 7) \
		.sphere(0.2, Vector3(0.0, 0.0, -0.24), Vector3(1.0, 1.05, 0.9), _c(p, "chest"), 12, 8) \
		.cylinder(0.085, 0.13, 0.32, Vector3(0.0, 0.17, -0.37), _c(p, "neck"), 10, Vector3(-30.0, 0.0, 0.0))
	var manes: Array[Color] = [_mane(p, 0), _mane(p, 1), _mane(p, 2)]
	for k in 6:
		var t := k / 5.0
		var pos := Vector3(0.0, 0.36, -0.42).lerp(Vector3(0.0, 0.13, -0.24), t)
		b.sphere(0.055, pos, Vector3(0.55, 1.0, 1.1), manes[k % 3], 8, 5, Vector3(-30.0, 0.0, 0.0))
	var hoof := _c(p, "foot")
	for side: float in [-1.0, 1.0]:
		# zampe davanti piegate in avanti, dietro distese all'indietro
		b.cylinder(0.035, 0.042, 0.2, Vector3(side * 0.1, -0.24, -0.2), body, 8, Vector3(35.0, 0.0, 0.0))
		b.cylinder(0.04, 0.04, 0.04, Vector3(side * 0.1, -0.31, -0.27), hoof, 8, Vector3(35.0, 0.0, 0.0))
		b.cylinder(0.035, 0.045, 0.2, Vector3(side * 0.1, -0.22, 0.32), body, 8, Vector3(-40.0, 0.0, 0.0))
		b.cylinder(0.04, 0.04, 0.04, Vector3(side * 0.1, -0.28, 0.4), hoof, 8, Vector3(-40.0, 0.0, 0.0))
	return b.build()


## Testa dell'unicorno: muso lungo, occhioni, orecchie, ciuffo pastello e il corno dorato a spirale.
static func _build_unicorn_head(p: Dictionary) -> ArrayMesh:
	var head := _c(p, "head")
	var b := LowPolyBuilder.new() \
		.sphere(0.12, Vector3(0.0, 0.02, -0.05), Vector3(0.85, 0.95, 1.1), head, 12, 8) \
		.sphere(0.09, Vector3(0.0, -0.035, -0.17), Vector3(0.78, 0.72, 1.25), head, 10, 6)
	var muzzle := _c(p, "beak")
	b.sphere(0.06, Vector3(0.0, -0.05, -0.245), Vector3(1.0, 0.85, 0.8), muzzle, 8, 5)
	for side: float in [-1.0, 1.0]:
		b.sphere(0.012, Vector3(side * 0.025, -0.04, -0.29), Vector3(0.8, 1.0, 0.5), _c(p, "beak_tip"), 5, 3)
		b.sphere(0.034, Vector3(side * 0.085, 0.04, -0.09), Vector3(0.5, 1.1, 1.0), _c(p, "eye"), 8, 5)
		b.sphere(0.009, Vector3(side * 0.1, 0.055, -0.105), Vector3.ONE, Color("ffffff"), 4, 3, Vector3.ZERO, true)
		b.box(Vector3(0.012, 0.012, 0.04), Vector3(side * 0.098, 0.078, -0.09), _c(p, "pupil"), Vector3(0.0, 0.0, side * -25.0)) # ciglia
		b.prism(Vector3(0.04, 0.08, 0.025), Vector3(side * 0.055, 0.135, 0.0), head, Vector3(0.0, 0.0, side * -12.0))
	# ciuffo sulla fronte e corno
	b.sphere(0.045, Vector3(0.0, 0.12, -0.02), Vector3(0.9, 0.7, 1.1), _mane(p, 1), 8, 5)
	b.sphere(0.04, Vector3(0.03, 0.115, 0.03), Vector3(0.8, 0.7, 1.0), _mane(p, 0), 8, 5)
	var horn: Color = p.get("horn", Color("f2c94c"))
	b.cylinder(0.0, 0.028, 0.2, Vector3(0.0, 0.2, -0.1), horn, 6, Vector3(-25.0, 0.0, 0.0))
	for k in 3:
		var t := 0.2 + k * 0.22
		b.cylinder(0.028 * (1.0 - t) + 0.003, 0.028 * (1.0 - t) + 0.003, 0.012, Vector3(0.0, 0.11 + 0.18 * t, -0.058 - 0.084 * t), horn.darkened(0.2), 6, Vector3(-25.0, 0.0, 0.0))
	return b.build()


## Coda dell'unicorno: ciocche pastello che scendono all'indietro (arcobaleno nel piumaggio "rainbow").
static func _build_unicorn_tail(p: Dictionary) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var rainbow: bool = p.get("rainbow_tail", false)
	for k in 7:
		var t := k / 6.0
		var color := Color.from_hsv(t * 0.85, 0.55, 1.0) if rainbow else _mane(p, k)
		var pos := Vector3(sin(t * 5.0) * 0.03, 0.02 - t * 0.2, 0.04 + t * 0.3)
		b.sphere(0.06 - t * 0.02, pos, Vector3(0.7, 0.8, 1.3), color, 8, 5, Vector3(35.0, 0.0, 0.0))
	return b.build()


## Colori della criniera (tre, in giro); con un piumaggio diverso dal naturale seguono la coda.
static func _mane(p: Dictionary, k: int) -> Color:
	var keys := ["mane", "mane2", "mane3"]
	var key: String = keys[k % 3]
	return p.get(key, _c(p, "tail")) as Color
