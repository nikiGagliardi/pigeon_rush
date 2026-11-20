class_name LandmarkMeshes
extends RefCounted
## Luoghi tipici dell'anello, uno per tratta (RouteSegment.landmark): castelli di Bellinzona, chiesa della
## Leventina, Ponte della Cappella a Lucerna, skyline di Zurigo, Churfirsten sul Walensee, castelli di Sargans
## e di Mesocco. Coordinate come un segmento di strada: Z = 0 è il punto in cui lo si affianca, la X è già
## quella giusta (sinistra oltre il guardrail, destra oltre la carreggiata opposta o sul lago).

const IDS: Array[StringName] = [&"bellinzona", &"leventina_church", &"lucerne", &"zurich", &"churfirsten", &"sargans", &"mesocco"]

const HILL := Color("5f8a45")
const CASTLE_STONE := Color("a39d92")
const CASTLE_DARK := Color("847e74")
const WHITE_WALL := Color("efe9dc")
const SANDSTONE := Color("d8cdb5")
const PRIME_GLASS := Color("5f8f86")
const FRAUMUENSTER_GREEN := Color("4f8a72")
const CLIFF := Color("7d8a99")
const CLIFF_GRASS := Color("7c9474")
const SWISS_RED := Color("d52b1e")

## Lontani come le montagne di sfondo: ignorano la nebbia (colori già "velati"), altrimenti sparirebbero.
const FAR: Array[StringName] = [&"churfirsten"]

static var _cache: Dictionary[StringName, ArrayMesh] = {}


static func get_mesh(id: StringName) -> ArrayMesh:
	var mesh: ArrayMesh = _cache.get(id)
	if mesh != null:
		return mesh
	var b := LowPolyBuilder.new()
	match id:
		&"bellinzona":
			_bellinzona(b)
		&"leventina_church":
			_leventina_church(b)
		&"lucerne":
			_lucerne(b)
		&"zurich":
			_zurich(b)
		&"churfirsten":
			_churfirsten(b)
		&"sargans":
			_sargans(b)
		&"mesocco":
			_mesocco(b)
	b.origin = Transform3D.IDENTITY
	mesh = b.build()
	_cache[id] = mesh
	return mesh


## Collina con la roccia che affiora (base a Y 0, cima piatta a top_y).
static func _hill(b: LowPolyBuilder, center: Vector3, radius: float, top_y: float) -> void:
	b.sphere(radius, Vector3(center.x, top_y - radius * 0.62, center.z), Vector3(1.25, 0.62, 1.0), HILL, 10, 5)
	b.sphere(radius * 0.45, Vector3(center.x + radius * 0.5, top_y * 0.35, center.z + radius * 0.3),
		Vector3(1.0, 0.8, 1.0), Palette.ROCK, 6, 4)


## Merli sopra un muro lungo l'asse indicato (dir: X o Z).
static func _battlements(b: LowPolyBuilder, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	var step := 1.6
	var n := int(length / step)
	for i in n:
		var p := from.lerp(to, (i + 0.5) / n)
		b.box(Vector3(0.8, 0.8, 0.8), p + Vector3(0.0, 0.4, 0.0), color)


static func _wall(b: LowPolyBuilder, from: Vector3, to: Vector3, height: float, thickness: float, color: Color) -> void:
	var mid := (from + to) * 0.5
	var length := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var yaw := rad_to_deg(atan2(to.x - from.x, to.z - from.z))
	b.box(Vector3(thickness, height, length), mid + Vector3(0.0, height * 0.5, 0.0), color, Vector3(0.0, yaw, 0.0))
	_battlements(b, from + Vector3(0.0, height, 0.0), to + Vector3(0.0, height, 0.0), color)


static func _square_tower(b: LowPolyBuilder, base: Vector3, width: float, height: float, color: Color, roof: Color,
		battlements: bool = false) -> void:
	b.box(Vector3(width, height, width), base + Vector3(0.0, height * 0.5, 0.0), color)
	if battlements:
		var h := base.y + height
		var r := width * 0.5 - 0.4
		for corner: Vector3 in [Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(-r, 0, r), Vector3(r, 0, r)]:
			b.box(Vector3(0.8, 1.0, 0.8), Vector3(base.x, h + 0.5, base.z) + corner, color)
	else:
		b.cylinder(0.0, width * 0.78, width * 1.3, base + Vector3(0.0, height + width * 0.65, 0.0), roof, 4,
			Vector3(0.0, 45.0, 0.0))
	b.box(Vector3(width * 0.3, 1.2, width + 0.04), base + Vector3(0.0, height - 2.0, 0.0), Palette.TRIM)


# ------------------------------------------------------------------ luoghi

## Bellinzona: Castelgrande sulla collina con la Torre Bianca e la Torre Nera, e la Murata che scende verso la strada.
static func _bellinzona(b: LowPolyBuilder) -> void:
	var c := Vector3(-72.0, 0.0, 0.0)
	_hill(b, c, 30.0, 14.0)
	b.box(Vector3(26.0, 4.0, 34.0), c + Vector3(0.0, 13.0, 0.0), CASTLE_DARK) # spianata
	var top := 15.0
	_wall(b, c + Vector3(-12.0, top, -16.0), c + Vector3(-12.0, top, 16.0), 5.0, 1.4, CASTLE_STONE)
	_wall(b, c + Vector3(12.0, top, -16.0), c + Vector3(12.0, top, 16.0), 5.0, 1.4, CASTLE_STONE)
	_wall(b, c + Vector3(-12.0, top, 16.0), c + Vector3(12.0, top, 16.0), 5.0, 1.4, CASTLE_STONE)
	_wall(b, c + Vector3(-12.0, top, -16.0), c + Vector3(12.0, top, -16.0), 5.0, 1.4, CASTLE_STONE)
	_square_tower(b, c + Vector3(-4.0, top, -6.0), 6.0, 22.0, WHITE_WALL, LandscapeMeshes.ROOF_STONE, true) # Torre Bianca
	_square_tower(b, c + Vector3(6.0, top, 8.0), 6.5, 15.0, CASTLE_DARK, LandscapeMeshes.ROOF_STONE, true) # Torre Nera
	b.box(Vector3(14.0, 6.0, 8.0), c + Vector3(2.0, top + 3.0, -10.0), WHITE_WALL) # palazzo
	b.prism(Vector3(14.6, 2.6, 8.6), c + Vector3(2.0, top + 7.3, -10.0), LandscapeMeshes.ROOF_RED, Vector3(0.0, 90.0, 0.0))
	# la Murata: muro merlato che scende dal castello fin quasi all'autostrada
	_wall(b, Vector3(-48.0, 0.0, 18.0), Vector3(-20.0, 0.0, 18.0), 7.0, 1.6, CASTLE_STONE)
	_square_tower(b, Vector3(-20.0, 0.0, 18.0), 4.5, 10.0, CASTLE_STONE, LandscapeMeshes.ROOF_STONE, true)


## Leventina: chiesa bianca con un campanile alto e la parete di roccia dietro.
static func _leventina_church(b: LowPolyBuilder) -> void:
	var c := Vector3(-34.0, 0.0, 0.0)
	b.sphere(18.0, Vector3(-70.0, 4.0, -4.0), Vector3(1.0, 1.6, 1.4), Palette.ROCK, 7, 4)
	b.sphere(12.0, Vector3(-58.0, 0.0, 14.0), Vector3(1.0, 1.3, 1.0), LandscapeMeshes.STONE_DARK, 6, 4)
	b.box(Vector3(9.0, 8.0, 18.0), c + Vector3(0.0, 4.0, 0.0), WHITE_WALL)
	b.prism(Vector3(9.8, 3.4, 18.6), c + Vector3(0.0, 9.7, 0.0), LandscapeMeshes.ROOF_STONE)
	b.box(Vector3(2.0, 3.6, 0.1), c + Vector3(0.0, 1.8, 9.02), LandscapeMeshes.WOOD_DARK)
	b.cylinder(1.1, 1.1, 0.1, c + Vector3(0.0, 6.4, 9.02), Palette.GLASS, 8, Vector3(90.0, 0.0, 0.0))
	_square_tower(b, c + Vector3(7.5, 0.0, -5.0), 4.0, 30.0, WHITE_WALL, LandscapeMeshes.ROOF_STONE)
	# sagrato con il muretto del cimitero
	b.box(Vector3(0.6, 1.2, 14.0), c + Vector3(-9.0, 0.6, 2.0), LandscapeMeshes.STONE)
	for x: float in [-6.0, -3.0]:
		b.cone(1.2, 7.0, c + Vector3(x, 0.0, 10.5), Palette.TREE_DARK, 6) # cipressi
		b.cone(1.2, 7.0, c + Vector3(x, 0.0, -10.5), Palette.TREE_DARK, 6)


## Lucerna: Ponte della Cappella (coperto, con i fiori) in diagonale sull'acqua e la Torre dell'acqua ottagonale.
static func _lucerne(b: LowPolyBuilder) -> void:
	b.origin = Transform3D(Basis(Vector3.UP, deg_to_rad(-28.0)), Vector3(70.0, 0.0, 0.0))
	var length := 96.0
	var y := LandscapeMeshes.WATER_Y
	var x := -length * 0.5
	while x <= length * 0.5:
		b.box(Vector3(0.5, 2.0, 3.4), Vector3(x, y + 0.6, 0.0), LandscapeMeshes.WOOD_DARK) # pali
		x += 6.0
	b.box(Vector3(length, 0.3, 3.4), Vector3(0.0, y + 1.7, 0.0), LandscapeMeshes.WOOD)
	b.box(Vector3(length, 1.0, 0.15), Vector3(0.0, y + 2.35, 1.65), LandscapeMeshes.WOOD)
	b.box(Vector3(length, 1.0, 0.15), Vector3(0.0, y + 2.35, -1.65), LandscapeMeshes.WOOD)
	b.box(Vector3(length, 0.35, 0.4), Vector3(0.0, y + 2.95, 1.8), LandscapeMeshes.GERANIUM)
	b.box(Vector3(length, 0.35, 0.4), Vector3(0.0, y + 2.95, -1.8), LandscapeMeshes.GERANIUM)
	b.prism(Vector3(4.6, 1.8, length), Vector3(0.0, y + 4.8, 0.0), LandscapeMeshes.ROOF_RED, Vector3(0.0, 90.0, 0.0))
	x = -length * 0.5
	while x <= length * 0.5:
		b.box(Vector3(0.18, 2.0, 0.18), Vector3(x, y + 3.0, 1.6), LandscapeMeshes.WOOD_DARK)
		b.box(Vector3(0.18, 2.0, 0.18), Vector3(x, y + 3.0, -1.6), LandscapeMeshes.WOOD_DARK)
		x += 4.0
	# Wasserturm accanto al ponte
	var tower := Vector3(8.0, y, 6.0)
	b.cylinder(4.6, 4.8, 18.0, tower + Vector3(0.0, 9.0, 0.0), Color("a8775a"), 8)
	b.cylinder(0.0, 5.3, 6.0, tower + Vector3(0.0, 21.0, 0.0), LandscapeMeshes.ROOF_RED, 8)
	b.box(Vector3(1.0, 1.4, 9.7), tower + Vector3(0.0, 14.0, 0.0), Palette.TRIM)
	b.box(Vector3(9.7, 1.4, 1.0), tower + Vector3(0.0, 14.0, 0.0), Palette.TRIM)
	b.origin = Transform3D.IDENTITY
	# riva di Lucerna in fondo: facciate colorate sull'acqua
	for i in 7:
		var z := -40.0 + i * 11.0
		var h := 12.0 + (i % 3) * 3.0
		var color := LandscapeMeshes.TOWN_COLORS[i % LandscapeMeshes.TOWN_COLORS.size()]
		b.box(Vector3(9.0, h, 10.0), Vector3(150.0, h * 0.5 + y, z), color)
		b.prism(Vector3(9.6, 3.0, 10.4), Vector3(150.0, h + 1.5 + y, z), LandscapeMeshes.ROOF_RED)


## Zurigo: Prime Tower verde, il Grossmünster con le due torri e la guglia verde del Fraumünster, altri palazzi.
static func _zurich(b: LowPolyBuilder) -> void:
	# Prime Tower: alta e un po' rastremata, vetro verde con fasce
	var prime := Vector3(78.0, 0.0, -10.0)
	b.box(Vector3(16.0, 88.0, 11.0), prime + Vector3(0.0, 44.0, 0.0), PRIME_GLASS)
	b.box(Vector3(17.0, 12.0, 12.0), prime + Vector3(0.0, 6.0, 0.0), Color("6c9a91"))
	var y := 14.0
	while y < 88.0:
		b.box(Vector3(16.06, 0.35, 11.06), prime + Vector3(0.0, y, 0.0), Color("9cc3bb"))
		y += 4.0
	b.box(Vector3(14.0, 2.0, 9.0), prime + Vector3(0.0, 89.0, 0.0), Color("9cc3bb"))
	# Grossmünster: navata e due torri gemelle con le cupole
	var gross := Vector3(52.0, 0.0, 22.0)
	b.box(Vector3(14.0, 14.0, 26.0), gross + Vector3(0.0, 7.0, -6.0), SANDSTONE)
	b.prism(Vector3(14.6, 5.0, 26.6), gross + Vector3(0.0, 16.5, -6.0), Color("8e8a83"))
	for x: float in [-4.5, 4.5]:
		var t := gross + Vector3(x, 0.0, 7.0)
		b.box(Vector3(5.5, 30.0, 5.5), t + Vector3(0.0, 15.0, 0.0), SANDSTONE)
		b.cylinder(2.6, 2.9, 4.0, t + Vector3(0.0, 32.0, 0.0), SANDSTONE, 8)
		b.sphere(2.6, t + Vector3(0.0, 34.5, 0.0), Vector3(1.0, 1.1, 1.0), Color("6f6f6f"), 8, 4)
		b.box(Vector3(1.2, 2.0, 5.56), t + Vector3(0.0, 24.0, 0.0), Palette.TRIM)
	# Fraumünster: torre con la guglia verde
	var frau := Vector3(66.0, 0.0, 44.0)
	b.box(Vector3(5.0, 24.0, 5.0), frau + Vector3(0.0, 12.0, 0.0), Color("cfc6b2"))
	b.cylinder(0.0, 2.9, 13.0, frau + Vector3(0.0, 30.5, 0.0), FRAUMUENSTER_GREEN, 8)
	b.box(Vector3(10.0, 12.0, 20.0), frau + Vector3(-7.0, 6.0, 4.0), Color("cfc6b2"))
	b.prism(Vector3(10.6, 4.0, 20.6), frau + Vector3(-7.0, 14.0, 4.0), FRAUMUENSTER_GREEN)
	# altri palazzi in fondo
	var rng := RandomNumberGenerator.new()
	rng.seed = 8000
	for i in 9:
		var at := Vector3(rng.randf_range(100.0, 150.0), 0.0, rng.randf_range(-45.0, 45.0))
		var h := rng.randf_range(18.0, 42.0)
		var color := LandscapeMeshes.BLOCK_COLORS[i % LandscapeMeshes.BLOCK_COLORS.size()]
		b.box(Vector3(14.0, h, 12.0), at + Vector3(0.0, h * 0.5, 0.0), color)
		var fy := 3.0
		while fy < h:
			b.box(Vector3(14.06, 1.1, 12.06), at + Vector3(0.0, fy, 0.0), LandscapeMeshes.CITY_GLASS)
			fy += 3.2


## Walensee: i sette Churfirsten oltre il lago, denti inclinati con la parete ripida verso l'acqua
## e il pendio dolce dietro, bosco sulla riva opposta.
static func _churfirsten(b: LowPolyBuilder) -> void:
	for i in 7:
		var z := -96.0 + i * 32.0
		var h := 64.0 + float((i * 37) % 19)
		# prisma ruotato: la cima si sposta verso il lago, la faccia verso la strada diventa una parete
		var lean := 18.0
		var lift := 28.0 * sin(deg_to_rad(lean)) - h * 0.5 * cos(deg_to_rad(lean))
		b.prism(Vector3(56.0, h, 30.0), Vector3(175.0, -lift, z), CLIFF, Vector3(0.0, 0.0, lean))
		b.prism(Vector3(40.0, h * 0.45, 30.6), Vector3(196.0, h * 0.18, z), CLIFF_GRASS)
	b.box(Vector3(16.0, 10.0, 230.0), Vector3(150.0, 3.0, 0.0), Color("56705a"))

## Sargans: castello bianco sulla rupe, mastio con il tetto a piramide e la bandiera svizzera.
static func _sargans(b: LowPolyBuilder) -> void:
	var c := Vector3(-62.0, 0.0, 0.0)
	_hill(b, c, 22.0, 12.0)
	b.box(Vector3(20.0, 3.0, 22.0), c + Vector3(0.0, 11.5, 0.0), CASTLE_DARK)
	var top := 13.0
	b.box(Vector3(16.0, 9.0, 9.0), c + Vector3(-1.0, top + 4.5, 4.0), WHITE_WALL) # ala abitata
	b.prism(Vector3(16.6, 4.0, 9.6), c + Vector3(-1.0, top + 11.0, 4.0), LandscapeMeshes.ROOF_RED, Vector3(0.0, 90.0, 0.0))
	for x: float in [-6.0, -2.0, 2.0]:
		b.box(Vector3(1.0, 1.4, 0.1), c + Vector3(x, top + 5.0, 8.52), Palette.GLASS)
		b.box(Vector3(0.4, 1.4, 0.08), c + Vector3(x - 0.75, top + 5.0, 8.56), SWISS_RED)
		b.box(Vector3(0.4, 1.4, 0.08), c + Vector3(x + 0.75, top + 5.0, 8.56), SWISS_RED)
	# mastio
	var keep := c + Vector3(6.0, top, -4.0)
	b.box(Vector3(9.0, 18.0, 9.0), keep + Vector3(0.0, 9.0, 0.0), WHITE_WALL)
	b.cylinder(0.0, 7.2, 9.0, keep + Vector3(0.0, 22.5, 0.0), LandscapeMeshes.ROOF_RED, 4, Vector3(0.0, 45.0, 0.0))
	# bandiera svizzera sul pennone
	var pole := keep + Vector3(0.0, 27.0, 0.0)
	b.cylinder(0.08, 0.08, 6.0, pole + Vector3(0.0, 3.0, 0.0), Palette.METAL, 5)
	b.box(Vector3(0.1, 2.4, 2.4), pole + Vector3(0.0, 4.6, 1.3), SWISS_RED)
	b.box(Vector3(0.14, 1.4, 0.45), pole + Vector3(0.0, 4.6, 1.3), Palette.SIGN_WHITE)
	b.box(Vector3(0.14, 0.45, 1.4), pole + Vector3(0.0, 4.6, 1.3), Palette.SIGN_WHITE)


## Mesocco: rovine del castello sulla collina e il campanile romanico di Santa Maria del Castello ai piedi.
static func _mesocco(b: LowPolyBuilder) -> void:
	var c := Vector3(-60.0, 0.0, -4.0)
	_hill(b, c, 26.0, 16.0)
	var top := 16.0
	var stone := LandscapeMeshes.STONE
	# mura in rovina: tratti di altezza diversa, con varchi
	_wall(b, c + Vector3(-13.0, top, -18.0), c + Vector3(-13.0, top, -2.0), 6.0, 1.4, stone)
	_wall(b, c + Vector3(-13.0, top, 3.0), c + Vector3(-13.0, top, 16.0), 4.0, 1.4, stone)
	_wall(b, c + Vector3(-13.0, top, 16.0), c + Vector3(8.0, top, 16.0), 5.0, 1.4, stone)
	_wall(b, c + Vector3(10.0, top, -18.0), c + Vector3(-13.0, top, -18.0), 7.0, 1.4, stone)
	# torre principale senza tetto e una torre crollata a metà
	_square_tower(b, c + Vector3(0.0, top, -8.0), 7.0, 20.0, LandscapeMeshes.STONE_DARK, stone, true)
	b.box(Vector3(5.0, 9.0, 5.0), c + Vector3(6.0, top + 4.5, 10.0), stone)
	b.box(Vector3(3.0, 3.0, 2.0), c + Vector3(7.0, top + 10.0, 9.0), stone)
	# Santa Maria del Castello ai piedi della collina, verso la strada
	var church := Vector3(-24.0, 0.0, 16.0)
	b.box(Vector3(7.0, 7.0, 14.0), church + Vector3(0.0, 3.5, 0.0), WHITE_WALL)
	b.prism(Vector3(7.6, 2.8, 14.6), church + Vector3(0.0, 8.4, 0.0), LandscapeMeshes.ROOF_STONE)
	_square_tower(b, church + Vector3(5.0, 0.0, -5.0), 3.6, 24.0, LandscapeMeshes.STONE, LandscapeMeshes.ROOF_STONE)
