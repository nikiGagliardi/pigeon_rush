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

static var _variants: Array[ArrayMesh] = []


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
	var pole_height := 9.0
	b.cylinder(0.1, 0.14, pole_height, Vector3(MEDIAN_X, pole_height * 0.5 + 0.9, 0.0), Palette.METAL, 6)
	b.box(Vector3(4.6, 0.1, 0.14), Vector3(MEDIAN_X, pole_height + 0.85, 0.0), Palette.METAL)
	b.box(Vector3(0.7, 0.12, 0.3), Vector3(MEDIAN_X + 2.2, pole_height + 0.75, 0.0), Palette.LAMP, Vector3.ZERO, true)
	b.box(Vector3(0.7, 0.12, 0.3), Vector3(MEDIAN_X - 2.2, pole_height + 0.75, 0.0), Palette.LAMP, Vector3.ZERO, true)

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
