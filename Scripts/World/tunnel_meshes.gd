class_name TunnelMeshes
extends RefCounted
## Mesh della galleria: montagna "scavata" con due canne (la nostra e quella opposta),
## rivestimento interno, lampade, nicchie SOS, delineatori, ventilatori e portale d'ingresso.

const LENGTHS: Array[float] = [320.0, 400.0, 480.0, 560.0]

const SIGN_X := -0.2
const SIGN_Y := 8.3

const LEFT_WALL := -7.2
const PILLAR_LEFT := 6.9 # lo spartitraffico (x 7.1) resta dentro il pilastro
const PILLAR_RIGHT := 7.6
const RIGHT_WALL := 21.6
const MOUNTAIN_LEFT := -70.0
const MOUNTAIN_RIGHT := 80.0
const MOUNTAIN_TOP := 24.0

static var _cache: Dictionary[int, ArrayMesh] = {}


static func get_mesh(length: float) -> ArrayMesh:
	var key := roundi(length)
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var mesh := _build(length)
	_cache[key] = mesh
	return mesh


static func _build(length: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length)
	var b := LowPolyBuilder.new()
	var half := length * 0.5
	var ceiling := Tunnel.CEILING_Y

	# --- massa della montagna attorno alle due canne ---
	b.block(MOUNTAIN_LEFT, LEFT_WALL, 0.0, MOUNTAIN_TOP, -half, half, Palette.ROCK)
	b.block(PILLAR_LEFT, PILLAR_RIGHT, 0.0, ceiling, -half, half, Palette.TUNNEL_WALL)
	b.block(RIGHT_WALL, MOUNTAIN_RIGHT, 0.0, MOUNTAIN_TOP, -half, half, Palette.ROCK)
	b.block(LEFT_WALL, RIGHT_WALL, ceiling, MOUNTAIN_TOP, -half, half, Palette.ROCK)
	b.block(MOUNTAIN_LEFT, MOUNTAIN_RIGHT, MOUNTAIN_TOP, MOUNTAIN_TOP + 0.8, -half, half, Palette.GRASS)

	# cupole e abeti sulla cima per una silhouette meno squadrata
	for i in 5 + int(length / 60.0):
		var x := MOUNTAIN_LEFT + 15.0 + rng.randf() * (MOUNTAIN_RIGHT - MOUNTAIN_LEFT - 30.0)
		var z := -half + rng.randf() * length
		var r := 16.0 + rng.randf() * 14.0
		b.sphere(r, Vector3(x, MOUNTAIN_TOP, z), Vector3(1.0, 0.45, 1.0), Palette.TREE_MID if rng.randf() < 0.5 else Palette.GRASS, 7, 4)

	for i in 10:
		var x := MOUNTAIN_LEFT + rng.randf() * (MOUNTAIN_RIGHT - MOUNTAIN_LEFT)
		var z := -half + rng.randf() * length
		var h := 5.0 + rng.randf() * 4.0
		b.cone(1.6 + rng.randf(), h, Vector3(x, MOUNTAIN_TOP + 0.5, z), Palette.TREE_DARK)

	# --- rivestimento interno (canna nostra + opposta) ---
	# arretrato di 2 cm alle estremità: facce di testa coincidenti con la roccia del portale = sfarfallio
	var lz := half - 0.02
	b.block(LEFT_WALL, LEFT_WALL + 0.06, 0.0, ceiling, -lz, lz, Palette.TUNNEL_WALL)
	b.block(PILLAR_LEFT - 0.06, PILLAR_LEFT, 0.0, ceiling, -lz, lz, Palette.TUNNEL_WALL)
	b.block(PILLAR_RIGHT, PILLAR_RIGHT + 0.06, 0.0, ceiling, -lz, lz, Palette.TUNNEL_WALL)
	b.block(RIGHT_WALL - 0.06, RIGHT_WALL, 0.0, ceiling, -lz, lz, Palette.TUNNEL_WALL)
	b.block(LEFT_WALL, RIGHT_WALL, ceiling - 0.06, ceiling, -lz, lz, Palette.TUNNEL_CEILING)
	b.block(LEFT_WALL + 0.06, LEFT_WALL + 0.1, 0.3, 2.6, -lz, lz, Palette.TUNNEL_TILE) # fascia chiara bassa
	b.block(PILLAR_LEFT - 0.1, PILLAR_LEFT - 0.06, 0.3, 2.6, -lz, lz, Palette.TUNNEL_TILE)

	# --- impianti ---
	var z := -half + 3.0
	while z < half:
		b.box(Vector3(0.3, 0.08, 1.6), Vector3(-2.8, ceiling - 0.1, z), Palette.TUNNEL_LAMP, Vector3.ZERO, true)
		b.box(Vector3(0.3, 0.08, 1.6), Vector3(2.8, ceiling - 0.1, z), Palette.TUNNEL_LAMP, Vector3.ZERO, true)
		z += 6.0

	z = -half + 12.0
	while z < half:
		b.box(Vector3(0.05, 0.12, 0.25), Vector3(LEFT_WALL + 0.12, 0.9, z), Palette.AMBER, Vector3.ZERO, true)
		b.box(Vector3(0.05, 0.12, 0.25), Vector3(PILLAR_LEFT - 0.12, 0.9, z), Palette.AMBER, Vector3.ZERO, true)
		z += 25.0

	z = -half + 25.0
	while z < half:
		b.box(Vector3(0.05, 0.45, 0.9), Vector3(LEFT_WALL + 0.12, 1.8, z), Palette.SOS_GREEN, Vector3.ZERO, true)
		z += 50.0

	z = -half + Tunnel.FAN_START
	while z < half - Tunnel.FAN_END_MARGIN:
		for x: float in [-Tunnel.FAN_X, Tunnel.FAN_X]:
			var y := ceiling - 0.6
			b.cylinder(Tunnel.FAN_RADIUS, Tunnel.FAN_RADIUS, Tunnel.FAN_LENGTH, Vector3(x, y, z), Palette.METAL, 10, Vector3(90.0, 0.0, 0.0))
			b.cylinder(Tunnel.FAN_RADIUS * 0.7, Tunnel.FAN_RADIUS * 0.7, Tunnel.FAN_LENGTH + 0.05, Vector3(x, y, z), Palette.TRIM, 8, Vector3(90.0, 0.0, 0.0))
			b.box(Vector3(0.15, 0.55, 0.4), Vector3(x, ceiling - 0.28, z), Palette.METAL)
		z += Tunnel.FAN_SPACING

	# --- portale d'ingresso (lato +Z, quello che vede il piccione) ---
	var p0 := half
	var p1 := half + Tunnel.PORTAL_DEPTH
	var frame_top := 7.2
	b.block(LEFT_WALL - 0.8, LEFT_WALL, 0.0, frame_top, p0, p1, Palette.CONCRETE)
	b.block(PILLAR_LEFT, PILLAR_RIGHT, 0.0, frame_top, p0, p1, Palette.CONCRETE)
	b.block(RIGHT_WALL, RIGHT_WALL + 0.8, 0.0, frame_top, p0, p1, Palette.CONCRETE)
	b.block(LEFT_WALL - 0.8, RIGHT_WALL + 0.8, ceiling, frame_top, p0, p1, Palette.CONCRETE)
	b.box(Vector3(9.0, 1.5, 0.15), Vector3(SIGN_X, SIGN_Y, p0 + 0.08), Palette.SIGN_BLUE)

	return b.build()
