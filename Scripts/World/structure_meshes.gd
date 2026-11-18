class_name StructureMeshes
extends RefCounted
## Mesh di portali segnaletici e cavalcavia.

const GANTRY_POST_X := 7.0
const GANTRY_BEAM_BOTTOM := 6.4
const GANTRY_BEAM_TOP := 7.6
const PANEL_BOTTOM := 4.55
const PANEL_TOP := 6.45
const PANEL_WIDTH := 3.3

const OVERPASS_DECK_BOTTOM := 5.4
const OVERPASS_DEPTH := 12.0

static var _gantry_frame: ArrayMesh
static var _overpass: ArrayMesh
static var _panel_cache: Dictionary[int, ArrayMesh] = {}


static func gantry_frame() -> ArrayMesh:
	if _gantry_frame == null:
		_gantry_frame = _build_gantry_frame()
	return _gantry_frame


static func overpass() -> ArrayMesh:
	if _overpass == null:
		_overpass = _build_overpass()
	return _overpass


## Pannelli per la combinazione di corsie richiesta (bit 0..2).
static func panels(lane_bits: int) -> ArrayMesh:
	var cached: ArrayMesh = _panel_cache.get(lane_bits)
	if cached != null:
		return cached

	var b := LowPolyBuilder.new()
	var panel_height := PANEL_TOP - PANEL_BOTTOM
	var center_y := (PANEL_TOP + PANEL_BOTTOM) * 0.5
	for lane in GameConfig.LANE_COUNT:
		if (lane_bits & (1 << lane)) == 0:
			continue
		var x := GameConfig.lane_x(lane)
		b.box(Vector3(PANEL_WIDTH + 0.12, panel_height + 0.12, 0.08), Vector3(x, center_y, -0.06), Palette.SIGN_WHITE)
		b.box(Vector3(PANEL_WIDTH, panel_height, 0.12), Vector3(x, center_y, 0.0), Palette.SIGN_GREEN)
		# tiranti verso la trave
		b.box(Vector3(0.08, GANTRY_BEAM_BOTTOM - PANEL_TOP + 0.1, 0.08), Vector3(x - 1.2, (GANTRY_BEAM_BOTTOM + PANEL_TOP) * 0.5, -0.05), Palette.METAL)
		b.box(Vector3(0.08, GANTRY_BEAM_BOTTOM - PANEL_TOP + 0.1, 0.08), Vector3(x + 1.2, (GANTRY_BEAM_BOTTOM + PANEL_TOP) * 0.5, -0.05), Palette.METAL)

	var mesh := b.build()
	_panel_cache[lane_bits] = mesh
	return mesh


static func _build_gantry_frame() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var beam_height := GANTRY_BEAM_TOP - GANTRY_BEAM_BOTTOM
	var post_height := GANTRY_BEAM_TOP + 0.2

	for side: float in [-1.0, 1.0]:
		b.cylinder(0.22, 0.26, post_height, Vector3(side * GANTRY_POST_X, post_height * 0.5, 0.0), Palette.METAL, 8)
		b.box(Vector3(0.9, 0.3, 0.9), Vector3(side * GANTRY_POST_X, 0.15, 0.0), Palette.CONCRETE)

	# trave reticolare: due correnti + diagonali
	b.box(Vector3(GANTRY_POST_X * 2.0 + 0.4, 0.22, 0.5), Vector3(0.0, GANTRY_BEAM_TOP - 0.11, 0.0), Palette.METAL)
	b.box(Vector3(GANTRY_POST_X * 2.0 + 0.4, 0.22, 0.5), Vector3(0.0, GANTRY_BEAM_BOTTOM + 0.11, 0.0), Palette.METAL)
	var x := -GANTRY_POST_X + 0.7
	while x < GANTRY_POST_X:
		b.box(Vector3(0.08, beam_height * 1.25, 0.08), Vector3(x, GANTRY_BEAM_BOTTOM + beam_height * 0.5, 0.0), Palette.METAL, Vector3(0.0, 0.0, 35.0))
		x += 1.4

	return b.build()


static func _build_overpass() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var width := 46.0
	var deck_thickness := 1.2
	var deck_y := OVERPASS_DECK_BOTTOM + deck_thickness * 0.5
	var half := OVERPASS_DEPTH * 0.5

	b.box(Vector3(width, deck_thickness, OVERPASS_DEPTH), Vector3(0.0, deck_y, 0.0), Palette.CONCRETE) # impalcato
	b.box(Vector3(width, 0.4, OVERPASS_DEPTH - 1.5), Vector3(0.0, OVERPASS_DECK_BOTTOM - 0.2, 0.0), Palette.CONCRETE_DARK) # travi
	b.box(Vector3(width, 0.06, OVERPASS_DEPTH - 1.2), Vector3(0.0, OVERPASS_DECK_BOTTOM + deck_thickness + 0.03, 0.0), Palette.ASPHALT_DARK)
	b.box(Vector3(width, 0.9, 0.3), Vector3(0.0, OVERPASS_DECK_BOTTOM + deck_thickness + 0.45, half - 0.15), Palette.CONCRETE) # parapetti
	b.box(Vector3(width, 0.9, 0.3), Vector3(0.0, OVERPASS_DECK_BOTTOM + deck_thickness + 0.45, -half + 0.15), Palette.CONCRETE)

	# pile: fuori dal guardrail esterno, sullo spartitraffico, oltre la carreggiata opposta
	for px: float in [-8.2, RoadMeshes.MEDIAN_X, RoadMeshes.OPPOSITE_CENTER_X + 7.8]:
		b.box(Vector3(0.9, OVERPASS_DECK_BOTTOM, OVERPASS_DEPTH - 3.0), Vector3(px, OVERPASS_DECK_BOTTOM * 0.5, 0.0), Palette.CONCRETE_DARK)

	# rampe di terra ai lati
	b.box(Vector3(14.0, OVERPASS_DECK_BOTTOM + 0.6, OVERPASS_DEPTH + 6.0), Vector3(-30.0, (OVERPASS_DECK_BOTTOM + 0.6) * 0.5, 0.0), Palette.GRASS)
	b.box(Vector3(14.0, OVERPASS_DECK_BOTTOM + 0.6, OVERPASS_DEPTH + 6.0), Vector3(37.0, (OVERPASS_DECK_BOTTOM + 0.6) * 0.5, 0.0), Palette.GRASS)

	return b.build()
