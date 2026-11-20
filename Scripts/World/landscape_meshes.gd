class_name LandscapeMeshes
extends RefCounted
## Paesaggio a bordo strada, per zona: aggiunto ai segmenti di strada da RoadMeshes (un mesh per segmento,
## quindi nessuna draw call in più). Ogni tratta dell'anello ha la sua sequenza di paesaggi (RouteSegment).
##
## Coordinate del segmento: Z da -half a +half (40 m), il muso dei mezzi e la camera guardano verso -Z,
## quindi le facce +Z degli oggetti sono quelle che si vedono arrivare.
## Lato sinistro (-X): oltre il guardrail esterno. Lato destro (+X): oltre la carreggiata opposta.

enum Landscape {
	TICINO,  ## castagni, rustici in pietra, campanili
	RIVIERA, ## vigneti, case in pietra, ferrovia accanto all'autostrada
	ALPINE,  ## abeti, rocce, chalet con i gerani, mucche
	PLATEAU, ## campi, fattorie, mucche, capannoni
	LAKE,    ## lago oltre la carreggiata opposta, barche a vela, ville
	TOWN,    ## case colorate, chiese
	CITY,    ## palazzi, uffici, capannoni, barriere antirumore
}

const LEFT_NEAR := -9.5
const LEFT_FAR := -75.0
const RIGHT_NEAR := 24.0
const RIGHT_FAR := 90.0
## Riva del lago: muretto oltre il guardrail della carreggiata opposta (21.2), acqua più in basso della strada.
const SHORE_X := 22.4
const WATER_Y := -0.08

# --- colori del paesaggio
const PLASTER := Color("f1ece0")
const WOOD := Color("7a4a2a")
const WOOD_DARK := Color("5e3820")
const WOOD_LIGHT := Color("9a6a42")
const ROOF_DARK := Color("4f4842")
const ROOF_RED := Color("9c4430")
const ROOF_STONE := Color("6e6a64")
const STONE := Color("9a958c")
const STONE_DARK := Color("85807a")
const GERANIUM := Color("d63031")
const LEAVES := Color("3f7a35")
const SHUTTER_GREEN := Color("2f6b3a")
const CHESTNUT := Color("557a3a")
const VINE := Color("4e7a35")
const WATER := Color("3b7189")
const SAIL := Color("f6f6f2")
const HULL := Color("e9edf0")
const GRAVEL := Color("8a8580")
const SLEEPER := Color("5a4a3a")
const BARRIER := Color("9fb3bf")
const CITY_GLASS := Color("3d5266")
const TOWN_COLORS: Array[Color] = [Color("e9d8a6"), Color("f2c6a0"), Color("cfe0c3"), Color("f4e1d2"), Color("d8e2ea"), Color("f0d6d6")]
const BLOCK_COLORS: Array[Color] = [Color("d6d2c8"), Color("c9cfd6"), Color("e3d9c6"), Color("b8bfc8")]
const FIELD_COLORS: Array[Color] = [Color("d9c27a"), Color("7fb04f"), Color("5c8f3d"), Color("8b6a4a"), Color("e8d23a")]
const BRAND_COLORS: Array[Color] = [Color("e30613"), Color("0057b8"), Color("f39200"), Color("2e8b57")]
# razze: bruna alpina, pezzata rossa (Simmental), Holstein
const COW_BROWN := Color("7b6a5a")
const COW_RED := Color("a5542d")
const COW_WHITE := Color("f2f0eb")
const COW_BLACK := Color("2a2a2a")
const COW_MUZZLE := Color("d9cfc4")
const HORN := Color("e8e0c8")


## Rettangoli occupati (X, Z) per non sovrapporre case, campi e alberi.
class Placer:
	var rects: Array[Rect2] = []
	var half: float

	func _init(p_half: float) -> void:
		half = p_half

	## Centro (x, z) di un'area libera di size dentro x_range, o NAN se non c'è posto.
	func find(rng: RandomNumberGenerator, x_range: Vector2, size: Vector2, tries: int = 10) -> Vector2:
		var x_min := minf(x_range.x, x_range.y) + size.x * 0.5
		var x_max := maxf(x_range.x, x_range.y) - size.x * 0.5
		var z_limit := half - size.y * 0.5 - 0.5
		if x_max < x_min:
			return Vector2(NAN, NAN)
		for i in tries:
			var center := Vector2(rng.randf_range(x_min, x_max), rng.randf_range(-z_limit, z_limit) if z_limit > 0.0 else 0.0)
			var rect := Rect2(center - size * 0.5, size)
			var free := true
			for other: Rect2 in rects:
				if other.intersects(rect):
					free = false
					break
			if free:
				rects.append(rect)
				return center
		return Vector2(NAN, NAN)

	func claim(center: Vector2, size: Vector2) -> void:
		rects.append(Rect2(center - size * 0.5, size))


static func add(b: LowPolyBuilder, rng: RandomNumberGenerator, theme: Landscape, half: float) -> void:
	var placer := Placer.new(half)
	match theme:
		Landscape.TICINO:
			_ticino(b, rng, placer)
		Landscape.RIVIERA:
			_riviera(b, rng, placer, half)
		Landscape.ALPINE:
			_alpine(b, rng, placer)
		Landscape.PLATEAU:
			_plateau(b, rng, placer)
		Landscape.LAKE:
			_lake(b, rng, placer, half)
		Landscape.TOWN:
			_town(b, rng, placer)
		Landscape.CITY:
			_city(b, rng, placer, half)
	b.origin = Transform3D.IDENTITY


# ------------------------------------------------------------------ temi

static func _ticino(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer) -> void:
	if rng.randf() < 0.18:
		_place(b, placer, rng, Vector2(-38.0, LEFT_FAR), Vector2(16.0, 18.0), _church.bind(b, rng))
	for i in rng.randi_range(0, 2):
		_place(b, placer, rng, Vector2(LEFT_NEAR - 6.0, -45.0), Vector2(8.0, 8.0), _rustico.bind(b, rng))
	if rng.randf() < 0.5:
		_place(b, placer, rng, Vector2(RIGHT_NEAR + 6.0, 60.0), Vector2(8.0, 8.0), _rustico.bind(b, rng))
	if rng.randf() < 0.35:
		_stone_wall(b, rng.randf_range(-14.0, -24.0), placer.half)
	_trees(b, rng, placer, Vector2(LEFT_NEAR, LEFT_FAR), rng.randi_range(5, 8), [0.15, 0.85, 1.0])
	_trees(b, rng, placer, Vector2(RIGHT_NEAR, RIGHT_FAR), rng.randi_range(5, 8), [0.15, 0.85, 1.0])


static func _riviera(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer, half: float) -> void:
	_vineyard(b, placer, rng.randf_range(-12.0, -16.0), rng.randi_range(5, 8), half)
	if rng.randf() < 0.45:
		_place(b, placer, rng, Vector2(-34.0, -55.0), Vector2(8.0, 8.0), _rustico.bind(b, rng))
	_railway(b, placer, half)
	if rng.randf() < 0.4:
		_place(b, placer, rng, Vector2(36.0, 65.0), Vector2(8.0, 8.0), _rustico.bind(b, rng))
	_trees(b, rng, placer, Vector2(-34.0, LEFT_FAR), rng.randi_range(2, 4), [0.2, 0.9, 1.0])
	_trees(b, rng, placer, Vector2(36.0, RIGHT_FAR), rng.randi_range(4, 7), [0.2, 0.9, 1.0])


static func _alpine(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer) -> void:
	if rng.randf() < 0.55:
		var at := _place(b, placer, rng, Vector2(-18.0, -42.0), Vector2(11.0, 10.0), _chalet.bind(b, rng))
		if not is_nan(at.x) and rng.randf() < 0.7:
			_herd(b, rng, placer, Vector2(LEFT_NEAR - 1.0, at.x + 9.0), rng.randi_range(2, 4))
	elif rng.randf() < 0.5:
		_herd(b, rng, placer, Vector2(LEFT_NEAR - 1.0, -30.0), rng.randi_range(2, 4))
	if rng.randf() < 0.3:
		_place(b, placer, rng, Vector2(-30.0, -60.0), Vector2(6.0, 7.0), _hay_barn.bind(b))
	if rng.randf() < 0.35:
		_place(b, placer, rng, Vector2(RIGHT_NEAR + 6.0, 60.0), Vector2(11.0, 10.0), _chalet.bind(b, rng))
	if rng.randf() < 0.4:
		_herd(b, rng, placer, Vector2(RIGHT_NEAR, 50.0), rng.randi_range(2, 3))
	_trees(b, rng, placer, Vector2(LEFT_NEAR, LEFT_FAR), rng.randi_range(5, 9), [0.75, 0.88, 1.0])
	_trees(b, rng, placer, Vector2(RIGHT_NEAR, RIGHT_FAR), rng.randi_range(5, 9), [0.75, 0.88, 1.0])


static func _plateau(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer) -> void:
	for side: float in [-1.0, 1.0]:
		var near := LEFT_NEAR if side < 0.0 else RIGHT_NEAR
		var far := LEFT_FAR if side < 0.0 else RIGHT_FAR
		for i in rng.randi_range(1, 2):
			var size := Vector2(rng.randf_range(14.0, 30.0), rng.randf_range(16.0, 34.0))
			var at := placer.find(rng, Vector2(near - 1.0 * side, far), size)
			if not is_nan(at.x):
				_field(b, rng, at, size)
	if rng.randf() < 0.4:
		_place(b, placer, rng, Vector2(-26.0, -60.0), Vector2(18.0, 22.0), _farm.bind(b, rng))
	if rng.randf() < 0.5:
		_herd(b, rng, placer, Vector2(LEFT_NEAR - 1.0, -40.0), rng.randi_range(3, 5))
	if rng.randf() < 0.22:
		_place(b, placer, rng, Vector2(30.0, 70.0), Vector2(28.0, 22.0), _warehouse.bind(b, rng))
	elif rng.randf() < 0.35:
		_place(b, placer, rng, Vector2(30.0, 70.0), Vector2(18.0, 22.0), _farm.bind(b, rng))
	if rng.randf() < 0.3:
		_fruit_row(b, rng, placer)
	_trees(b, rng, placer, Vector2(LEFT_NEAR, LEFT_FAR), rng.randi_range(1, 3), [0.3, 1.0, 1.0])
	_trees(b, rng, placer, Vector2(RIGHT_NEAR, RIGHT_FAR), rng.randi_range(1, 3), [0.3, 1.0, 1.0])


static func _lake(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer, half: float) -> void:
	# riva e acqua lunghe esattamente un segmento: si uniscono senza giunte con i segmenti vicini
	b.box(Vector3(1.6, 0.9, half * 2.0), Vector3(SHORE_X, -0.1, 0.0), STONE)
	b.box(Vector3(600.0, 0.1, half * 2.0), Vector3(SHORE_X + 300.8, WATER_Y, 0.0), WATER)
	placer.claim(Vector2(300.0, 0.0), Vector2(560.0, half * 2.0))
	for i in rng.randi_range(0, 2):
		_sailboat(b, rng, Vector3(rng.randf_range(35.0, 140.0), WATER_Y, rng.randf_range(-half + 4.0, half - 4.0)))
	if rng.randf() < 0.15:
		b.box(Vector3(14.0, 0.25, 1.6), Vector3(SHORE_X + 7.5, 0.1, rng.randf_range(-12.0, 12.0)), WOOD_LIGHT) # pontile
	if rng.randf() < 0.5:
		_place(b, placer, rng, Vector2(-16.0, -40.0), Vector2(11.0, 10.0), _chalet.bind(b, rng) if rng.randf() < 0.5 else _town_house.bind(b, rng))
	_trees(b, rng, placer, Vector2(LEFT_NEAR, LEFT_FAR), rng.randi_range(4, 7), [0.45, 0.95, 1.0])


static func _town(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer) -> void:
	if rng.randf() < 0.15:
		_place(b, placer, rng, Vector2(-30.0, -60.0), Vector2(16.0, 18.0), _church.bind(b, rng))
	for i in rng.randi_range(2, 4):
		_place(b, placer, rng, Vector2(LEFT_NEAR - 2.0, -55.0), Vector2(10.0, 11.0), _town_house.bind(b, rng))
	for i in rng.randi_range(2, 3):
		_place(b, placer, rng, Vector2(RIGHT_NEAR + 2.0, 70.0), Vector2(10.0, 11.0), _town_house.bind(b, rng))
	_trees(b, rng, placer, Vector2(LEFT_NEAR, LEFT_FAR), rng.randi_range(1, 3), [0.2, 1.0, 1.0])
	_trees(b, rng, placer, Vector2(RIGHT_NEAR, RIGHT_FAR), rng.randi_range(1, 3), [0.2, 1.0, 1.0])


static func _city(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer, half: float) -> void:
	if rng.randf() < 0.5:
		_noise_barrier(b, half)
		placer.claim(Vector2(-8.4, 0.0), Vector2(1.0, half * 2.0))
	for i in rng.randi_range(1, 2):
		_place(b, placer, rng, Vector2(-16.0, -60.0), Vector2(20.0, 18.0), _apartment_block.bind(b, rng))
	if rng.randf() < 0.45:
		_place(b, placer, rng, Vector2(-40.0, LEFT_FAR), Vector2(16.0, 14.0), _office_tower.bind(b, rng))
	if rng.randf() < 0.55:
		_place(b, placer, rng, Vector2(RIGHT_NEAR + 1.0, 60.0), Vector2(28.0, 22.0), _warehouse.bind(b, rng))
	else:
		_place(b, placer, rng, Vector2(RIGHT_NEAR + 2.0, 60.0), Vector2(20.0, 18.0), _apartment_block.bind(b, rng))
	if rng.randf() < 0.5:
		_place(b, placer, rng, Vector2(55.0, RIGHT_FAR), Vector2(16.0, 14.0), _office_tower.bind(b, rng))
	_trees(b, rng, placer, Vector2(LEFT_NEAR, -30.0), rng.randi_range(0, 2), [0.1, 1.0, 1.0])


# ------------------------------------------------------------------ posa

## Trova posto per un oggetto e lo costruisce lì (rotazione casuale di qualche grado). Restituisce il centro o NAN.
static func _place(b: LowPolyBuilder, placer: Placer, rng: RandomNumberGenerator, x_range: Vector2, size: Vector2,
		build: Callable) -> Vector2:
	var at := placer.find(rng, x_range, size)
	if is_nan(at.x):
		return at
	b.origin = Transform3D(Basis(Vector3.UP, deg_to_rad(rng.randf_range(-8.0, 8.0))), Vector3(at.x, 0.0, at.y))
	build.call()
	b.origin = Transform3D.IDENTITY
	return at


## weights: soglie cumulative [abete, latifoglia/castagno, roccia].
static func _trees(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer, x_range: Vector2, count: int,
		weights: Array) -> void:
	for i in count:
		var at := placer.find(rng, x_range, Vector2(3.0, 3.0), 4)
		if is_nan(at.x):
			continue
		var x := at.x
		var z := at.y
		var roll := rng.randf()
		if roll < float(weights[0]):
			var h := 3.5 + rng.randf() * 3.5
			var r := 1.1 + rng.randf() * 0.8
			b.cylinder(0.15, 0.2, 1.2, Vector3(x, 0.6, z), Palette.TRUNK, 5)
			b.cone(r, h, Vector3(x, 1.0, z), Palette.TREE_DARK if rng.randf() < 0.5 else Palette.TREE_MID)
			b.cone(r * 0.7, h * 0.6, Vector3(x, 1.0 + h * 0.45, z), Palette.TREE_MID)
		elif roll < float(weights[1]):
			var r := 1.3 + rng.randf() * 1.0
			b.cylinder(0.18, 0.26, 1.8, Vector3(x, 0.9, z), Palette.TRUNK, 5)
			var crown := CHESTNUT if rng.randf() < 0.5 else Palette.TREE_LIGHT
			b.sphere(r, Vector3(x, 1.8 + r * 0.75, z), Vector3(1.15, 0.85, 1.1), crown, 6, 4)
		else:
			var r := 0.6 + rng.randf() * 1.2
			b.sphere(r, Vector3(x, r * 0.3, z), Vector3(1.3, 0.7, 1.0), Palette.ROCK, 5, 3, Vector3(0.0, rng.randf() * 90.0, 0.0))


# ------------------------------------------------------------------ edifici (coordinate locali, fronte verso +Z)

## Chalet: zoccolo bianco, piano in legno scuro, tetto largo, balcone con i gerani sul frontone.
static func _chalet(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var wood := WOOD if rng.randf() < 0.6 else WOOD_DARK
	b.box(Vector3(8.0, 2.4, 7.0), Vector3(0.0, 1.2, 0.0), PLASTER)
	b.box(Vector3(8.0, 2.6, 7.0), Vector3(0.0, 3.7, 0.0), wood)
	b.prism(Vector3(10.0, 2.4, 9.0), Vector3(0.0, 6.2, 0.0), ROOF_DARK)
	b.box(Vector3(8.6, 0.15, 1.0), Vector3(0.0, 2.95, 3.95), WOOD_LIGHT) # balcone
	b.box(Vector3(8.6, 0.75, 0.1), Vector3(0.0, 3.4, 4.4), WOOD_LIGHT)
	b.box(Vector3(8.2, 0.28, 0.32), Vector3(0.0, 3.92, 4.42), GERANIUM)
	b.box(Vector3(8.2, 0.1, 0.34), Vector3(0.0, 3.76, 4.42), LEAVES)
	for x: float in [-2.0, 2.0]:
		b.box(Vector3(1.1, 1.2, 0.1), Vector3(x, 4.3, 3.52), Palette.GLASS)
		b.box(Vector3(1.1, 1.1, 0.1), Vector3(x, 1.3, 3.52), Palette.GLASS)
		b.box(Vector3(0.4, 1.1, 0.08), Vector3(x - 0.8, 1.3, 3.55), SHUTTER_GREEN)
		b.box(Vector3(0.4, 1.1, 0.08), Vector3(x + 0.8, 1.3, 3.55), SHUTTER_GREEN)
		b.box(Vector3(1.0, 0.22, 0.3), Vector3(x, 0.72, 3.62), GERANIUM) # fioriera sotto la finestra


static func _hay_barn(b: LowPolyBuilder) -> void:
	b.box(Vector3(4.0, 3.0, 5.0), Vector3(0.0, 1.5, 0.0), WOOD_DARK)
	b.prism(Vector3(4.8, 1.6, 5.8), Vector3(0.0, 3.8, 0.0), ROOF_STONE)
	b.box(Vector3(1.4, 1.8, 0.1), Vector3(0.0, 1.0, 2.52), WOOD_LIGHT)


## Rustico ticinese: muri in pietra, tetto basso di piode, finestre piccole.
static func _rustico(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var stone := STONE if rng.randf() < 0.5 else STONE_DARK
	var height := rng.randf_range(4.0, 5.5)
	b.box(Vector3(6.0, height, 5.5), Vector3(0.0, height * 0.5, 0.0), stone)
	b.prism(Vector3(6.6, 1.5, 6.1), Vector3(0.0, height + 0.75, 0.0), ROOF_STONE)
	b.box(Vector3(0.7, 0.8, 0.1), Vector3(-1.4, height - 1.3, 2.77), Palette.GLASS)
	b.box(Vector3(0.7, 0.8, 0.1), Vector3(1.4, height - 1.3, 2.77), Palette.GLASS)
	b.box(Vector3(1.0, 1.9, 0.1), Vector3(0.0, 0.95, 2.77), WOOD_DARK)
	if rng.randf() < 0.4:
		b.box(Vector3(4.0, 0.12, 0.9), Vector3(0.0, height - 2.2, 3.2), WOOD) # loggia in legno
		b.box(Vector3(4.0, 0.6, 0.08), Vector3(0.0, height - 1.85, 3.62), WOOD)


## Chiesa con campanile (Ticino e cittadine): navata bianca, torre alta con cella e cuspide.
static func _church(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var walls := PLASTER if rng.randf() < 0.6 else Color("e8dcc4")
	b.box(Vector3(7.0, 7.0, 13.0), Vector3(0.0, 3.5, -1.0), walls)
	b.prism(Vector3(7.6, 2.8, 13.6), Vector3(0.0, 8.4, -1.0), ROOF_RED if rng.randf() < 0.5 else ROOF_STONE)
	b.box(Vector3(1.6, 3.0, 0.1), Vector3(0.0, 1.5, 5.52), WOOD_DARK)
	b.cylinder(0.9, 0.9, 0.1, Vector3(0.0, 5.6, 5.52), Palette.GLASS, 8, Vector3(90.0, 0.0, 0.0)) # rosone
	_tower(b, Vector3(5.5, 0.0, -4.0), 3.2, rng.randf_range(18.0, 24.0), walls)


static func _tower(b: LowPolyBuilder, base: Vector3, width: float, height: float, walls: Color) -> void:
	b.box(Vector3(width, height, width), base + Vector3(0.0, height * 0.5, 0.0), walls)
	# cella campanaria: aperture scure sui quattro lati
	var y := height - 2.2
	b.box(Vector3(width * 0.5, 1.6, width + 0.04), base + Vector3(0.0, y, 0.0), Palette.TRIM)
	b.box(Vector3(width + 0.04, 1.6, width * 0.5), base + Vector3(0.0, y, 0.0), Palette.TRIM)
	b.box(Vector3(width + 0.3, 0.3, width + 0.3), base + Vector3(0.0, height, 0.0), STONE)
	b.cylinder(0.0, width * 0.75, width * 1.6, base + Vector3(0.0, height + 0.15 + width * 0.8, 0.0), ROOF_STONE, 4,
		Vector3(0.0, 45.0, 0.0))


## Casa di paese: colori pastello, 2-4 piani, tetto rosso, finestre sul fronte.
static func _town_house(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var floors := rng.randi_range(2, 4)
	var w := rng.randf_range(7.0, 9.0)
	var d := rng.randf_range(8.0, 9.5)
	var h := floors * 3.0
	b.box(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), TOWN_COLORS[rng.randi_range(0, TOWN_COLORS.size() - 1)])
	b.prism(Vector3(w + 0.6, 2.6, d + 0.6), Vector3(0.0, h + 1.3, 0.0), ROOF_RED if rng.randf() < 0.75 else ROOF_DARK)
	var shutters := SHUTTER_GREEN if rng.randf() < 0.5 else Color("8e3b2e")
	for f in floors:
		for i in 3:
			var x := (i - 1) * w * 0.3
			b.box(Vector3(1.0, 1.3, 0.1), Vector3(x, f * 3.0 + 1.6, d * 0.5 + 0.02), Palette.GLASS)
			if f > 0:
				b.box(Vector3(0.35, 1.3, 0.08), Vector3(x - 0.7, f * 3.0 + 1.6, d * 0.5 + 0.05), shutters)
				b.box(Vector3(0.35, 1.3, 0.08), Vector3(x + 0.7, f * 3.0 + 1.6, d * 0.5 + 0.05), shutters)


## Condominio: piani a fasce di finestre tutt'intorno, tetto piatto.
static func _apartment_block(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var floors := rng.randi_range(5, 10)
	var w := rng.randf_range(14.0, 18.0)
	var d := rng.randf_range(11.0, 14.0)
	var h := floors * 3.0
	b.box(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), BLOCK_COLORS[rng.randi_range(0, BLOCK_COLORS.size() - 1)])
	for f in floors:
		b.box(Vector3(w + 0.06, 1.2, d + 0.06), Vector3(0.0, f * 3.0 + 1.7, 0.0), CITY_GLASS)
	b.box(Vector3(w * 0.3, 2.0, d * 0.3), Vector3(w * 0.2, h + 1.0, 0.0), Palette.CONCRETE_DARK) # locale tecnico


## Torre di uffici: vetro con marcapiani chiari.
static func _office_tower(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(30.0, 50.0)
	var w := rng.randf_range(11.0, 14.0)
	var d := rng.randf_range(9.0, 12.0)
	# solo azzurri: il verde è della Prime Tower di Zurigo, che deve spiccare
	var glass := Color("4a6b82") if rng.randf() < 0.5 else Color("56708a")
	b.box(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), glass)
	var y := 4.0
	while y < h:
		b.box(Vector3(w + 0.06, 0.4, d + 0.06), Vector3(0.0, y, 0.0), Color("c9d1d8"))
		y += 3.8
	b.box(Vector3(w + 0.4, 1.2, d + 0.4), Vector3(0.0, h + 0.6, 0.0), Color("c9d1d8"))


## Capannone: lamiera, fascia con il colore dell'azienda, portoni di carico sul fronte.
static func _warehouse(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(20.0, 26.0)
	var d := rng.randf_range(15.0, 20.0)
	var h := rng.randf_range(7.0, 9.0)
	b.box(Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), Color("b9bec4") if rng.randf() < 0.5 else Color("9aa3ad"))
	b.box(Vector3(w + 0.06, 1.2, d + 0.06), Vector3(0.0, h - 0.9, 0.0), BRAND_COLORS[rng.randi_range(0, BRAND_COLORS.size() - 1)])
	for i in 3:
		b.box(Vector3(3.5, 4.0, 0.1), Vector3((i - 1) * w * 0.3, 2.0, d * 0.5 + 0.02), Palette.TRIM)


## Fattoria dell'altopiano: tetto enorme che scende basso, parte abitata bianca davanti, silo.
static func _farm(b: LowPolyBuilder, rng: RandomNumberGenerator) -> void:
	b.box(Vector3(12.0, 3.6, 16.0), Vector3(0.0, 1.8, 0.0), WOOD)
	b.box(Vector3(12.02, 3.6, 5.0), Vector3(0.0, 1.8, 5.5), PLASTER) # parte abitata
	b.prism(Vector3(15.0, 6.0, 18.0), Vector3(0.0, 6.6, 0.0), ROOF_RED if rng.randf() < 0.4 else ROOF_DARK)
	for x: float in [-3.0, 0.0, 3.0]:
		b.box(Vector3(1.0, 1.1, 0.1), Vector3(x, 2.0, 8.02), Palette.GLASS)
		b.box(Vector3(1.0, 0.22, 0.3), Vector3(x, 1.35, 8.12), GERANIUM)
	if rng.randf() < 0.6:
		b.cylinder(1.8, 1.8, 11.0, Vector3(8.2, 5.5, -4.0), Color("c8cfd6"), 10)
		b.sphere(1.8, Vector3(8.2, 11.0, -4.0), Vector3(1.0, 0.5, 1.0), Color("a9b3bc"), 10, 4)


# ------------------------------------------------------------------ campagna

## Mucche al pascolo: bruna alpina, pezzata rossa o Holstein, a gruppi, alcune con la testa giù.
static func _herd(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer, x_range: Vector2, count: int) -> void:
	var area := placer.find(rng, x_range, Vector2(12.0, 12.0), 6)
	if is_nan(area.x):
		return
	var breed := rng.randi_range(0, 2)
	for i in count:
		var at := area + Vector2(rng.randf_range(-4.5, 4.5), rng.randf_range(-4.5, 4.5))
		b.origin = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(at.x, 0.0, at.y))
		_cow(b, breed if rng.randf() < 0.8 else rng.randi_range(0, 2), rng.randf() < 0.5)
	b.origin = Transform3D.IDENTITY


## Mucca lunga lungo +X (testa verso +X).
static func _cow(b: LowPolyBuilder, breed: int, grazing: bool) -> void:
	var body := COW_BROWN if breed == 0 else (COW_RED if breed == 1 else COW_WHITE)
	var head := COW_WHITE if breed == 1 else body
	b.box(Vector3(1.9, 0.85, 0.8), Vector3(0.0, 1.15, 0.0), body)
	for x: float in [-0.7, 0.7]:
		for z: float in [-0.27, 0.27]:
			b.box(Vector3(0.18, 0.75, 0.18), Vector3(x, 0.37, z), body)
	b.box(Vector3(0.3, 0.15, 0.3), Vector3(-0.35, 0.68, 0.0), Color("e6b8b0")) # mammella
	b.box(Vector3(0.06, 0.8, 0.06), Vector3(-0.97, 0.95, 0.0), body) # coda
	var head_pos := Vector3(1.15, 0.65, 0.0) if grazing else Vector3(1.15, 1.45, 0.0)
	var tilt := -45.0 if grazing else -10.0
	b.box(Vector3(0.55, 0.42, 0.4), head_pos, head, Vector3(0.0, 0.0, tilt))
	b.box(Vector3(0.2, 0.3, 0.36), head_pos + Vector3(0.28, -0.12 if grazing else -0.06, 0.0), COW_MUZZLE, Vector3(0.0, 0.0, tilt))
	b.box(Vector3(0.08, 0.08, 0.6), head_pos + Vector3(-0.1, 0.25, 0.0), HORN, Vector3(0.0, 0.0, tilt))
	b.box(Vector3(0.12, 0.16, 0.12), head_pos + Vector3(-0.25, -0.35, 0.0), Color("d8b23a")) # campanaccio
	if breed == 2:
		# macchie nere della Holstein, appena sporgenti dal corpo
		b.box(Vector3(0.6, 0.5, 0.82), Vector3(-0.3, 1.2, 0.0), COW_BLACK)
		b.box(Vector3(0.4, 0.35, 0.82), Vector3(0.5, 1.05, 0.0), COW_BLACK)
	elif breed == 1:
		b.box(Vector3(0.5, 0.25, 0.82), Vector3(0.2, 0.85, 0.0), COW_WHITE) # pancia bianca


## Campo coltivato: piano sottile colorato, con i solchi se arato o coltivato a righe.
static func _field(b: LowPolyBuilder, rng: RandomNumberGenerator, at: Vector2, size: Vector2) -> void:
	var color := FIELD_COLORS[rng.randi_range(0, FIELD_COLORS.size() - 1)]
	b.box(Vector3(size.x, 0.04, size.y), Vector3(at.x, -0.07, at.y), color)
	if rng.randf() < 0.5:
		var rows := int(size.x / 2.5)
		for i in rows:
			var x := at.x - size.x * 0.5 + 1.25 + i * 2.5
			b.box(Vector3(0.5, 0.05, size.y - 0.5), Vector3(x, -0.04, at.y), color.darkened(0.18))


static func _fruit_row(b: LowPolyBuilder, rng: RandomNumberGenerator, placer: Placer) -> void:
	var at := placer.find(rng, Vector2(LEFT_NEAR - 4.0, -50.0), Vector2(4.0, 32.0), 4)
	if is_nan(at.x):
		return
	var z := at.y - 14.0
	while z < at.y + 14.0:
		b.cylinder(0.12, 0.16, 1.4, Vector3(at.x, 0.7, z), Palette.TRUNK, 5)
		b.sphere(1.1, Vector3(at.x, 2.1, z), Vector3(1.0, 0.85, 1.0), Palette.TREE_LIGHT, 6, 4)
		z += 5.0


## Vigneto: filari lungo la strada con un muretto davanti.
static func _vineyard(b: LowPolyBuilder, placer: Placer, near_x: float, rows: int, half: float) -> void:
	var length := half * 2.0 - 4.0
	b.box(Vector3(0.6, 0.9, length + 2.0), Vector3(near_x + 1.0, 0.45, 0.0), STONE)
	for i in rows:
		var x := near_x - 1.0 - i * 2.4
		b.box(Vector3(0.55, 1.1, length), Vector3(x, 0.55, 0.0), VINE)
		b.box(Vector3(0.1, 1.5, 0.1), Vector3(x, 0.75, -length * 0.5), Palette.TRUNK)
		b.box(Vector3(0.1, 1.5, 0.1), Vector3(x, 0.75, length * 0.5), Palette.TRUNK)
	var far_x := near_x - 1.0 - rows * 2.4
	placer.claim(Vector2((near_x + 1.5 + far_x) * 0.5, 0.0), Vector2(near_x + 1.5 - far_x, half * 2.0))


## Ferrovia accanto all'autostrada (lato destro): massicciata, binari, traversine e linea aerea.
static func _railway(b: LowPolyBuilder, placer: Placer, half: float) -> void:
	var x := 27.5
	var length := half * 2.0
	b.box(Vector3(4.2, 0.4, length), Vector3(x, 0.0, 0.0), GRAVEL)
	var z := -half + 0.5
	while z < half:
		b.box(Vector3(2.6, 0.12, 0.3), Vector3(x, 0.24, z), SLEEPER)
		z += 1.0
	for rail: float in [-0.72, 0.72]:
		b.box(Vector3(0.1, 0.14, length), Vector3(x + rail, 0.35, 0.0), Palette.METAL)
	b.box(Vector3(0.3, 7.2, 0.3), Vector3(x + 2.6, 3.6, 0.0), Palette.CONCRETE_DARK) # palo della linea aerea
	b.box(Vector3(3.0, 0.15, 0.15), Vector3(x + 1.2, 6.6, 0.0), Palette.METAL)
	b.box(Vector3(0.04, 0.04, length), Vector3(x, 6.2, 0.0), Palette.TRIM)
	placer.claim(Vector2(x + 0.8, 0.0), Vector2(6.0, length))


## Muretto a secco dei terrazzamenti (Ticino).
static func _stone_wall(b: LowPolyBuilder, x: float, half: float) -> void:
	b.box(Vector3(0.7, 1.1, half * 2.0), Vector3(x, 0.55, 0.0), STONE_DARK)


## Barriera antirumore lungo il guardrail esterno: zoccolo in cemento, pannelli e montanti.
static func _noise_barrier(b: LowPolyBuilder, half: float) -> void:
	var x := -8.4
	var length := half * 2.0
	b.box(Vector3(0.4, 1.0, length), Vector3(x, 0.5, 0.0), Palette.CONCRETE)
	b.box(Vector3(0.12, 2.6, length), Vector3(x, 2.3, 0.0), BARRIER)
	var z := -half + 2.0
	while z < half:
		b.box(Vector3(0.25, 3.8, 0.2), Vector3(x + 0.1, 1.9, z), Palette.METAL)
		z += 4.0


static func _sailboat(b: LowPolyBuilder, rng: RandomNumberGenerator, at: Vector3) -> void:
	b.origin = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
	b.box(Vector3(1.8, 0.7, 5.0), Vector3(0.0, 0.3, 0.0), HULL)
	b.box(Vector3(1.2, 0.5, 1.6), Vector3(0.0, 0.85, -0.6), Color("c9d1d8"))
	b.cylinder(0.06, 0.06, 7.0, Vector3(0.0, 4.1, 0.4), Palette.METAL, 5)
	b.prism(Vector3(3.4, 6.2, 0.06), Vector3(0.0, 3.9, -0.95), SAIL, Vector3(0.0, 90.0, 0.0))
	b.origin = Transform3D.IDENTITY
