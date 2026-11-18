class_name RoadMeshes
extends RefCounted
## Segmento di autostrada lungo GameConfig.SEGMENT_LENGTH: la nostra carreggiata (3 corsie),
## spartitraffico New Jersey con lampioni, carreggiata opposta, guardrail e vegetazione.
## Più varianti generate con seed diversi per evitare ripetizioni evidenti.

const VARIANT_COUNT := 5
const CARRIAGEWAY_WIDTH := GameConfig.ROAD_HALF_WIDTH * 2.0 + 2.4 # corsie + banchine
# Guida a destra: i mezzi contromano (verso +Z) hanno lo spartitraffico alla loro sinistra (+X),
# la carreggiata opposta (traffico verso -Z) sta quindi sul lato +X.
const MEDIAN_X := 7.1
const OPPOSITE_CENTER_X := 14.2
const OUTER_GUARDRAIL_X := -7.0

# lampioni: altezza delle due lampade e loro X (una sulla nostra carreggiata, una sull'opposta)
const POLE_HEIGHT := 9.0
const LAMP_Y := POLE_HEIGHT + 0.75
const LAMP_ARM := 2.2

## Luce dei lampioni di notte: macchie di luce sull'asfalto e alone sulle lampade, additivi (nessuna luce vera).
const POOL_SIZE := Vector2(10.0, 15.0) # larghezza (X) e lunghezza (Z) della macchia
const POOL_COLOR := Color(1.0, 0.82, 0.52) * 0.55
const LAMP_FLARE_COLOR := Color(1.0, 0.86, 0.6) * 0.9
## Oltre questa distanza le luci si spengono gradualmente (in nebbia non "galleggiano" nel nulla).
const LIGHT_FADE_NEAR := 110.0
const LIGHT_FADE_FAR := 230.0

static var _variants: Array[ArrayMesh] = []
static var _pools: ArrayMesh
static var _pool_material: StandardMaterial3D
static var _lamp_flare: QuadMesh


static func variants() -> Array[ArrayMesh]:
	if _variants.is_empty():
		for i in VARIANT_COUNT:
			_variants.append(_build(1234 + i * 97))
	return _variants


static func _build(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := LowPolyBuilder.new()
	var length := GameConfig.SEGMENT_LENGTH
	var half := length * 0.5

	# --- nostra carreggiata ---
	b.box(Vector3(CARRIAGEWAY_WIDTH, 0.1, length), Vector3(0.0, -0.05, 0.0), Palette.ASPHALT)
	_add_lane_markings(b, 0.0)

	# guardrail esterno
	b.box(Vector3(0.1, 0.32, length), Vector3(OUTER_GUARDRAIL_X, 0.62, 0.0), Palette.METAL)
	var z := -half + 2.0
	while z < half:
		b.box(Vector3(0.12, 0.75, 0.12), Vector3(OUTER_GUARDRAIL_X - 0.1, 0.375, z), Palette.CONCRETE_DARK)
		z += 4.0

	# spartitraffico New Jersey
	b.box(Vector3(0.75, 0.45, length), Vector3(MEDIAN_X, 0.225, 0.0), Palette.CONCRETE)
	b.box(Vector3(0.32, 0.5, length), Vector3(MEDIAN_X, 0.7, 0.0), Palette.CONCRETE)

	# lampione doppio sullo spartitraffico
	var pole_height := POLE_HEIGHT
	b.cylinder(0.1, 0.14, pole_height, Vector3(MEDIAN_X, pole_height * 0.5 + 0.9, 0.0), Palette.METAL, 6)
	b.box(Vector3(4.6, 0.1, 0.14), Vector3(MEDIAN_X, pole_height + 0.85, 0.0), Palette.METAL)
	b.box(Vector3(0.7, 0.12, 0.3), Vector3(MEDIAN_X + LAMP_ARM, LAMP_Y, 0.0), Palette.LAMP, Vector3.ZERO, true)
	b.box(Vector3(0.7, 0.12, 0.3), Vector3(MEDIAN_X - LAMP_ARM, LAMP_Y, 0.0), Palette.LAMP, Vector3.ZERO, true)

	# --- carreggiata opposta (solo scenografia) ---
	b.box(Vector3(CARRIAGEWAY_WIDTH, 0.1, length), Vector3(OPPOSITE_CENTER_X, -0.05, 0.0), Palette.ASPHALT_DARK)
	_add_lane_markings(b, OPPOSITE_CENTER_X)
	b.box(Vector3(0.1, 0.32, length), Vector3(OPPOSITE_CENTER_X + 7.0, 0.62, 0.0), Palette.METAL)

	# --- vegetazione e dettagli ---
	_add_trees(b, rng, -9.5, -55.0, rng.randi_range(6, 10), half)
	_add_trees(b, rng, 24.0, 75.0, rng.randi_range(6, 10), half)

	if rng.randf() < 0.45:
		var house_x := -32.0 - rng.randf() * 15.0 if rng.randf() < 0.5 else 40.0 + rng.randf() * 20.0
		_add_house(b, rng, house_x, half)

	return b.build()


static func _add_lane_markings(b: LowPolyBuilder, center_x: float) -> void:
	var length := GameConfig.SEGMENT_LENGTH
	var edge := GameConfig.ROAD_HALF_WIDTH + 0.05
	# strisce alte 3 cm: abbastanza sopra l'asfalto da non sfarfallare in lontananza
	b.box(Vector3(0.15, 0.03, length), Vector3(center_x - edge, 0.015, 0.0), Palette.LINE_WHITE)
	b.box(Vector3(0.15, 0.03, length), Vector3(center_x + edge, 0.015, 0.0), Palette.LINE_WHITE)

	# tratteggio: periodo 10 m (divisore di 40) così i segmenti combaciano
	for lane in range(1, GameConfig.LANE_COUNT):
		var x := center_x + GameConfig.lane_x(lane) - GameConfig.LANE_WIDTH * 0.5
		var z := -length * 0.5 + 5.0
		while z < length * 0.5:
			b.box(Vector3(0.14, 0.03, 4.5), Vector3(x, 0.015, z), Palette.LINE_WHITE)
			z += 10.0


static func _add_trees(b: LowPolyBuilder, rng: RandomNumberGenerator, near_x: float, far_x: float, count: int, half: float) -> void:
	for i in count:
		var x := near_x + (far_x - near_x) * rng.randf()
		var z := -half + rng.randf() * half * 2.0
		var roll := rng.randf()
		if roll < 0.55:
			# abete
			var h := 3.5 + rng.randf() * 3.0
			var r := 1.1 + rng.randf() * 0.8
			b.cylinder(0.15, 0.2, 1.2, Vector3(x, 0.6, z), Palette.TRUNK, 5)
			b.cone(r, h, Vector3(x, 1.0, z), Palette.TREE_DARK if rng.randf() < 0.5 else Palette.TREE_MID)
			b.cone(r * 0.7, h * 0.6, Vector3(x, 1.0 + h * 0.45, z), Palette.TREE_MID)
		elif roll < 0.85:
			# latifoglia
			var r := 1.3 + rng.randf() * 0.9
			b.cylinder(0.18, 0.24, 1.8, Vector3(x, 0.9, z), Palette.TRUNK, 5)
			b.sphere(r, Vector3(x, 1.8 + r * 0.8, z), Vector3(1.0, 0.9, 1.0), Palette.TREE_LIGHT, 6, 4)
		else:
			# roccia
			var r := 0.6 + rng.randf() * 1.2
			b.sphere(r, Vector3(x, r * 0.3, z), Vector3(1.3, 0.7, 1.0), Palette.ROCK, 5, 3, Vector3(0.0, rng.randf() * 90.0, 0.0))


static func _add_house(b: LowPolyBuilder, rng: RandomNumberGenerator, x: float, half: float) -> void:
	var z := -half * 0.5 + rng.randf() * half
	var walls := Color("efe6d2") if rng.randf() < 0.5 else Color("e8d9b5")
	var roof := Color("8e3b2e") if rng.randf() < 0.5 else Color("5b5f66")
	b.box(Vector3(7.0, 4.0, 9.0), Vector3(x, 2.0, z), walls)
	b.prism(Vector3(7.6, 2.6, 9.6), Vector3(x, 5.3, z), roof)
	b.box(Vector3(1.2, 1.2, 0.1), Vector3(x - 1.8, 2.4, z + 4.52), Palette.GLASS)
	b.box(Vector3(1.2, 1.2, 0.1), Vector3(x + 1.8, 2.4, z + 4.52), Palette.GLASS)


## X delle due lampade del lampione (nostra carreggiata, carreggiata opposta).
static func lamp_xs() -> PackedFloat32Array:
	return PackedFloat32Array([MEDIAN_X - LAMP_ARM, MEDIAN_X + LAMP_ARM])


## Le due macchie di luce sotto il lampione di un segmento, appena sopra l'asfalto.
static func night_pools() -> ArrayMesh:
	if _pools != null:
		return _pools
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var hw := POOL_SIZE.x * 0.5
	var hl := POOL_SIZE.y * 0.5
	# la luce cade un po' verso il centro della carreggiata, non sotto il palo
	for center_x: float in [MEDIAN_X - LAMP_ARM - 1.4, MEDIAN_X + LAMP_ARM + 1.4]:
		var y := 0.03
		var a := Vector3(center_x - hw, y, -hl)
		var b := Vector3(center_x + hw, y, -hl)
		var c := Vector3(center_x + hw, y, hl)
		var d := Vector3(center_x - hw, y, hl)
		vertices.append_array([a, b, c, a, c, d])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
		for i in 6:
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	_pools = ArrayMesh.new()
	_pools.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_pool_material = _additive_material(HighBeamVisuals.radial_glow(), POOL_COLOR, false)
	_pools.surface_set_material(0, _pool_material)
	return _pools


## Alone sulla lampada (billboard).
static func lamp_flare() -> QuadMesh:
	if _lamp_flare == null:
		_lamp_flare = QuadMesh.new()
		_lamp_flare.size = Vector2(3.6, 3.6)
		_lamp_flare.material = _additive_material(HighBeamVisuals.radial_glow(), LAMP_FLARE_COLOR, true)
	return _lamp_flare


## Intensità comune di tutti i lampioni (0..1): un solo materiale per tipo, nessun costo per segmento.
static func set_street_light_level(level: float) -> void:
	var k := clampf(level, 0.0, 1.0)
	night_pools()
	_pool_material.albedo_color = POOL_COLOR * k
	(lamp_flare().material as StandardMaterial3D).albedo_color = LAMP_FLARE_COLOR * k


static func _additive_material(texture: Texture2D, color: Color, billboard: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	mat.albedo_color = color
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	# con min > max la dissolvenza è al contrario: visibili vicino, spente in lontananza
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = LIGHT_FADE_FAR
	mat.distance_fade_max_distance = LIGHT_FADE_NEAR
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return mat
