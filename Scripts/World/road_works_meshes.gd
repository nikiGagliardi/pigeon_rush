class_name RoadWorksMeshes
extends RefCounted
## Mesh del cantiere: corsia chiusa, ponteggio con rete (più alto del volo massimo), coni,
## carrelli segnaletici, cartelli e macchinari.
## Le due estremità sono speculari: lato +Z (verso il piccione) e lato -Z (da dove arrivano le auto).
## Per ogni estremità, dall'esterno verso il centro: cartello → carrello → invito con coni e rete diagonale.
## In mezzo: barriera e rete dritta.

enum MachineKind { EXCAVATOR, ROLLER }

const LENGTHS: Array[float] = [160.0, 200.0, 240.0]
const TAPER_LENGTH := 30.0
const TRAILER_OFFSET := 3.0 # centro del carrello rispetto all'estremità
const TAPER_START_OFFSET := 6.0 # l'invito inizia subito dietro al carrello
const SIGN_AHEAD := 40.0 # cartello "ROADWORKS" prima di ogni estremità
const SCAFFOLD_HEIGHT := 8.0 # sopra FLY_MAX_Y: impossibile passare sopra

static var _cache: Dictionary[int, ArrayMesh] = {}
static var _beacons: ArrayMesh
static var _excavator: ArrayMesh
static var _roller: ArrayMesh
static var _net: QuadMesh


static func side(lane: int) -> float:
	return -1.0 if lane == 0 else 1.0


## Linea di separazione tra la corsia chiusa e quella aperta adiacente.
static func boundary(lane: int) -> float:
	return GameConfig.lane_x(lane) - side(lane) * GameConfig.LANE_WIDTH * 0.5


static func barrier_x(lane: int) -> float:
	return boundary(lane) + side(lane) * 0.35


## Bordo esterno della corsia chiusa.
static func edge_x(lane: int) -> float:
	return GameConfig.lane_x(lane) + side(lane) * GameConfig.LANE_WIDTH * 0.5


static func sign_post_x(lane: int) -> float:
	return GameConfig.lane_x(lane) + side(lane) * (GameConfig.LANE_WIDTH * 0.5 + 0.8)


## Distanza dal centro dove inizia l'invito (rete al bordo esterno).
static func taper_outer(length: float) -> float:
	return length * 0.5 - TAPER_START_OFFSET


## Distanza dal centro dove l'invito raggiunge la barriera.
static func taper_inner(length: float) -> float:
	return taper_outer(length) - TAPER_LENGTH


## Rete di cantiere arancione semitrasparente (quad 1×1, scalato dal nodo).
static func net() -> QuadMesh:
	if _net == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.45, 0.05, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 1.0
		_net = QuadMesh.new()
		_net.size = Vector2.ONE
		_net.material = mat
	return _net


static func get_mesh(lane: int, length: float) -> ArrayMesh:
	var key := lane * 10000 + roundi(length)
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var mesh := _build(lane, length)
	_cache[key] = mesh
	return mesh


static func machine(kind: MachineKind) -> ArrayMesh:
	if kind == MachineKind.EXCAVATOR:
		if _excavator == null:
			_excavator = _build_excavator()
		return _excavator
	if _roller == null:
		_roller = _build_roller()
	return _roller


## Lampeggianti ambra del carrello, rivolti verso +Z (ruotare di 180° per l'altra estremità).
static func beacons() -> ArrayMesh:
	if _beacons == null:
		_beacons = LowPolyBuilder.new() \
			.sphere(0.16, Vector3(-1.15, 3.95, 1.5), Vector3.ONE, Palette.AMBER, 6, 3, Vector3.ZERO, true) \
			.sphere(0.16, Vector3(1.15, 3.95, 1.5), Vector3.ONE, Palette.AMBER, 6, 3, Vector3.ZERO, true) \
			.sphere(0.16, Vector3(-1.15, 1.35, 1.5), Vector3.ONE, Palette.AMBER, 6, 3, Vector3.ZERO, true) \
			.sphere(0.16, Vector3(1.15, 1.35, 1.5), Vector3.ONE, Palette.AMBER, 6, 3, Vector3.ZERO, true) \
			.build()
	return _beacons


static func _build(lane: int, length: float) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var half := length * 0.5
	var s := side(lane)
	var lane_x := GameConfig.lane_x(lane)
	var bound := boundary(lane)
	var bx := barrier_x(lane)
	var inner := taper_inner(length)

	# asfalto fresato e linea gialla provvisoria (in Svizzera la segnaletica di cantiere è gialla)
	# strati separati: fresato (1.2 cm) < strisce bianche (3 cm) < linea gialla provvisoria (4.5 cm, copre il tratteggio)
	b.box(Vector3(GameConfig.LANE_WIDTH - 0.3, 0.012, length), Vector3(lane_x, 0.006, 0.0), Palette.MILLED_ASPHALT)
	b.box(Vector3(0.18, 0.045, length + 20.0), Vector3(bound, 0.0225, 0.0), Palette.WORKS_YELLOW)

	# barriere bianche/rosse nel tratto centrale, con lampeggiante ogni 10 m
	var index := 0
	var z := -inner + 1.0
	while z < inner:
		b.box(Vector3(0.45, 0.9, 1.9), Vector3(bx, 0.45, z), Palette.WORKS_RED if index % 2 == 0 else Palette.SIGN_WHITE)
		if index % 5 == 0:
			b.box(Vector3(0.16, 0.16, 0.16), Vector3(bx, 1.0, z), Palette.AMBER, Vector3.ZERO, true)
		z += 2.0
		index += 1

	# ponteggio dritto: montanti e correnti
	var pole_x := bx + s * 0.25
	z = -inner
	while z <= inner:
		b.box(Vector3(0.08, SCAFFOLD_HEIGHT, 0.08), Vector3(pole_x, SCAFFOLD_HEIGHT * 0.5, z), Palette.METAL)
		z += 3.0
	for y: float in [2.6, 5.2, SCAFFOLD_HEIGHT - 0.1]:
		b.block(pole_x - 0.04, pole_x + 0.04, y - 0.04, y + 0.04, -inner, inner, Palette.METAL)

	# estremità speculari: +1 = lato piccione, -1 = lato da cui arrivano le auto
	for end: float in [1.0, -1.0]:
		_add_taper(b, lane, end * taper_outer(length), end * inner)
		_add_trailer(b, lane, end * (half - TRAILER_OFFSET), end)
		_add_sign(b, lane, end * (half + SIGN_AHEAD), end)

	return b.build()


## Invito: coni e ponteggio in diagonale dal bordo esterno (outer_z) alla barriera (inner_z).
static func _add_taper(b: LowPolyBuilder, lane: int, outer_z: float, inner_z: float) -> void:
	var s := side(lane)
	var edge := edge_x(lane)
	var bx := barrier_x(lane)

	var cones := 12
	for i in cones + 1:
		var t := float(i) / cones
		var x := lerpf(edge - s * 0.3, bx, t)
		var z := lerpf(outer_z, inner_z, t)
		b.cone(0.22, 0.75, Vector3(x, 0.0, z), Palette.WORKS_ORANGE, 8)
		b.cylinder(0.15, 0.17, 0.12, Vector3(x, 0.42, z), Palette.SIGN_WHITE, 8)
		b.box(Vector3(0.5, 0.05, 0.5), Vector3(x, 0.025, z), Palette.TRIM)

	var dx := bx - edge
	var dz := inner_z - outer_z
	var diagonal := sqrt(dx * dx + dz * dz)
	var yaw := rad_to_deg(atan2(dx, dz))
	for i in 7:
		var t := i / 6.0
		b.box(Vector3(0.08, SCAFFOLD_HEIGHT, 0.08), Vector3(edge + dx * t, SCAFFOLD_HEIGHT * 0.5, outer_z + dz * t), Palette.METAL)

	for y: float in [2.6, 5.2, SCAFFOLD_HEIGHT - 0.1]:
		b.box(Vector3(0.08, 0.08, diagonal), Vector3(edge + dx * 0.5, y, outer_z + dz * 0.5), Palette.METAL, Vector3(0.0, yaw, 0.0))


## Carrello con freccia verso le corsie aperte; facing = verso del pannello (+1/-1 su Z).
static func _add_trailer(b: LowPolyBuilder, lane: int, tz: float, facing: float) -> void:
	var s := side(lane)
	var lane_x := GameConfig.lane_x(lane)

	b.box(Vector3(2.2, 0.9, 3.0), Vector3(lane_x, 0.85, tz), Palette.WORKS_YELLOW)
	b.wheel(lane_x - 1.0, tz, 0.4, 0.25)
	b.wheel(lane_x + 1.0, tz, 0.4, 0.25)
	b.box(Vector3(0.12, 1.4, 0.12), Vector3(lane_x, 1.9, tz), Palette.METAL)
	b.box(Vector3(2.6, 2.6, 0.15), Vector3(lane_x, 2.65, tz + facing * 1.4), Palette.PANEL_BLACK)

	var arrow_y := 2.65
	var arrow_z := tz + facing * 1.49
	b.box(Vector3(1.5, 0.2, 0.05), Vector3(lane_x + s * 0.15, arrow_y, arrow_z), Palette.AMBER, Vector3.ZERO, true)
	b.box(Vector3(0.75, 0.2, 0.05), Vector3(lane_x - s * 0.42, arrow_y + 0.24, arrow_z), Palette.AMBER, Vector3(0.0, 0.0, -s * 45.0), true)
	b.box(Vector3(0.75, 0.2, 0.05), Vector3(lane_x - s * 0.42, arrow_y - 0.24, arrow_z), Palette.AMBER, Vector3(0.0, 0.0, s * 45.0), true)


## Cartello "ROADWORKS" + limite 80 sulla banchina (i testi sono Label3D nel nodo).
static func _add_sign(b: LowPolyBuilder, lane: int, sz: float, facing: float) -> void:
	var sx := sign_post_x(lane)
	b.cylinder(0.05, 0.05, 3.6, Vector3(sx, 1.8, sz - facing * 0.05), Palette.METAL, 6)
	b.box(Vector3(1.6, 1.0, 0.08), Vector3(sx, 2.3, sz), Palette.WORKS_YELLOW)
	b.cylinder(0.45, 0.45, 0.06, Vector3(sx, 3.4, sz), Palette.SIGN_WHITE, 16, Vector3(90.0, 0.0, 0.0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.46
	torus.rings = 16
	torus.ring_segments = 4
	b.add_primitive(torus, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)), Vector3(sx, 3.4, sz + facing * 0.04)), Palette.WORKS_RED)


## Escavatore con braccio alzato verso +Z. Origine al centro dei cingoli, a terra.
static func _build_excavator() -> ArrayMesh:
	return LowPolyBuilder.new() \
		.box(Vector3(2.6, 0.8, 4.2), Vector3(0.0, 0.4, 0.0), Palette.TRIM) \
		.box(Vector3(2.4, 1.3, 3.0), Vector3(0.0, 1.45, -0.3), Palette.MACHINE_YELLOW) \
		.box(Vector3(1.0, 1.3, 1.2), Vector3(-0.6, 2.75, 0.5), Palette.GLASS) \
		.box(Vector3(1.05, 0.1, 1.25), Vector3(-0.6, 3.42, 0.5), Palette.MACHINE_YELLOW) \
		.box(Vector3(0.5, 0.5, 4.0), Vector3(0.45, 3.6, 2.6), Palette.MACHINE_YELLOW, Vector3(-45.0, 0.0, 0.0)) \
		.box(Vector3(0.4, 0.4, 3.0), Vector3(0.45, 3.7, 4.75), Palette.MACHINE_YELLOW, Vector3(60.0, 0.0, 0.0)) \
		.box(Vector3(1.0, 0.7, 0.7), Vector3(0.45, 2.4, 5.5), Palette.TRIM) \
		.build()


## Rullo compressore. Origine al centro, a terra.
static func _build_roller() -> ArrayMesh:
	var b := LowPolyBuilder.new() \
		.box(Vector3(2.0, 1.2, 2.4), Vector3(0.0, 1.6, -0.2), Palette.MACHINE_YELLOW) \
		.box(Vector3(1.7, 0.08, 1.7), Vector3(0.0, 3.0, -0.3), Palette.MACHINE_YELLOW) \
		.cylinder(0.75, 0.75, 2.0, Vector3(0.0, 0.75, 1.6), Palette.TRIM, 10, Vector3(0.0, 0.0, 90.0)) \
		.cylinder(0.65, 0.65, 1.9, Vector3(0.0, 0.65, -1.5), Palette.TRIM, 10, Vector3(0.0, 0.0, 90.0)) \
		.box(Vector3(0.9, 0.6, 0.9), Vector3(0.0, 2.5, -0.3), Palette.GLASS)
	for x: float in [-0.8, 0.8]:
		for z: float in [-1.1, 0.5]:
			b.box(Vector3(0.08, 0.8, 0.08), Vector3(x, 2.6, z), Palette.TRIM)
	return b.build()
