class_name BirdAccessories
extends RefCounted
## Accessori dell'uccello, ognuno costruito nelle coordinate del suo aggancio (PigeonModel):
## - testa: Y = 0 sulla sommità della testa;
## - faccia: all'altezza degli occhi, al centro della testa (occhi a X ±0.14);
## - collo: al centro del collo sul corpo (raggio del collo circa 0.17).
## Avanti = -Z. Disegnati per il piccione; le altre specie li scalano (Species.accessory_scale).

const CAP_BLUE := Color("1f5fbf")
const FELT_GREEN := Color("3f6b3a")
const COWBOY_BROWN := Color("9a6a3a")
const LEATHER := Color("6b4423")
const GOLD := Color("f2c037")
const BRASS := Color("c9a227")
const SCARF_RED := Color("d63031")
const LENS_DARK := Color("15151c")
const LENS_BLUE := Color("bfe6f5")
const FRAME := Color("1a1a1a")

static var _cache: Dictionary[StringName, ArrayMesh] = {}


static func mesh(id: StringName) -> ArrayMesh:
	var cached: ArrayMesh = _cache.get(id)
	if cached != null:
		return cached
	var b := LowPolyBuilder.new()
	match id:
		&"cap":
			_cap(b)
		&"alpine_hat":
			_alpine_hat(b)
		&"cowboy_hat":
			_cowboy_hat(b)
		&"helmet":
			_helmet(b)
		&"crown":
			_crown(b)
		&"sunglasses":
			_sunglasses(b)
		&"goggles":
			_goggles(b)
		&"scarf":
			_scarf(b)
		&"cowbell":
			_cowbell(b)
		_:
			return null
	cached = b.build()
	_cache[id] = cached
	return cached


# ------------------------------------------------------------------ testa

static func _cap(b: LowPolyBuilder) -> void:
	b.sphere(0.13, Vector3(0.0, -0.02, 0.0), Vector3(1.0, 0.62, 1.06), CAP_BLUE, 12, 6)
	b.box(Vector3(0.2, 0.016, 0.13), Vector3(0.0, -0.01, -0.16), CAP_BLUE.darkened(0.15), Vector3(-6.0, 0.0, 0.0))
	b.sphere(0.016, Vector3(0.0, 0.06, 0.0), Vector3.ONE, Color.WHITE, 6, 3)
	b.sphere(0.035, Vector3(0.0, 0.02, -0.125), Vector3(1.0, 1.0, 0.3), Color("ffd54a"), 8, 4) # stemma


static func _alpine_hat(b: LowPolyBuilder) -> void:
	b.cylinder(0.16, 0.16, 0.016, Vector3(0.0, 0.0, 0.0), FELT_GREEN.darkened(0.1), 14)
	b.cylinder(0.075, 0.1, 0.11, Vector3(0.0, 0.063, 0.0), FELT_GREEN, 10)
	b.box(Vector3(0.05, 0.02, 0.1), Vector3(0.0, 0.118, 0.0), FELT_GREEN.darkened(0.2)) # piega in cima
	b.cylinder(0.102, 0.104, 0.024, Vector3(0.0, 0.024, 0.0), Color("c0392b"), 10) # cordoncino
	b.sphere(1.0, Vector3(0.1, 0.1, 0.06), Vector3(0.014, 0.022, 0.15), Color("e8e0c8"), 6, 3, Vector3(-35.0, 20.0, 0.0))
	b.sphere(1.0, Vector3(0.13, 0.185, 0.16), Vector3(0.015, 0.02, 0.05), Color("3a3a3a"), 5, 3, Vector3(-35.0, 20.0, 0.0))


static func _cowboy_hat(b: LowPolyBuilder) -> void:
	b.cylinder(0.21, 0.21, 0.016, Vector3(0.0, 0.0, 0.0), COWBOY_BROWN.darkened(0.08), 14, Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(0.07, 0.014, 0.3), Vector3(side * 0.19, 0.03, 0.0), COWBOY_BROWN.darkened(0.08), Vector3(0.0, 0.0, side * 32.0))
	b.cylinder(0.085, 0.097, 0.12, Vector3(0.0, 0.068, 0.0), COWBOY_BROWN, 10)
	b.box(Vector3(0.03, 0.025, 0.12), Vector3(0.0, 0.125, 0.0), COWBOY_BROWN.darkened(0.25)) # piega
	b.cylinder(0.099, 0.1, 0.026, Vector3(0.0, 0.02, 0.0), Color("4a2f1a"), 10)


static func _helmet(b: LowPolyBuilder) -> void:
	b.sphere(0.165, Vector3(0.0, -0.065, 0.01), Vector3(1.0, 0.86, 1.12), Color("f2f2f2"), 14, 8)
	b.sphere(0.167, Vector3(0.0, -0.065, 0.01), Vector3(0.24, 0.87, 1.13), Color("d63031"), 10, 8) # banda
	b.box(Vector3(0.22, 0.02, 0.06), Vector3(0.0, -0.05, -0.18), Color("2a2a2a"), Vector3(-10.0, 0.0, 0.0)) # visiera


static func _crown(b: LowPolyBuilder) -> void:
	b.cylinder(0.088, 0.09, 0.06, Vector3(0.0, 0.025, 0.0), GOLD, 12)
	for i in 5:
		var a := TAU * i / 5.0
		var p := Vector3(sin(a) * 0.078, 0.075, cos(a) * 0.078)
		b.cone(0.024, 0.06, p, GOLD, 5)
		b.sphere(0.012, p + Vector3(0.0, 0.065, 0.0), Vector3.ONE, GOLD.lightened(0.2), 6, 3)
	b.sphere(0.016, Vector3(0.0, 0.03, -0.09), Vector3(1.0, 1.0, 0.5), Color("e0245e"), 6, 3, Vector3.ZERO, true)
	b.sphere(0.012, Vector3(0.06, 0.03, -0.067), Vector3(1.0, 1.0, 0.5), Color("2f6fd0"), 6, 3, Vector3(0.0, 40.0, 0.0), true)
	b.sphere(0.012, Vector3(-0.06, 0.03, -0.067), Vector3(1.0, 1.0, 0.5), Color("2f6fd0"), 6, 3, Vector3(0.0, -40.0, 0.0), true)


# ------------------------------------------------------------------ faccia

## Occhiali da sole: lenti sui lati della testa (gli occhi del piccione sono di lato), ponte sopra il becco.
static func _sunglasses(b: LowPolyBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(0.022, 0.065, 0.09), Vector3(side * 0.152, 0.0, 0.0), LENS_DARK)
		b.box(Vector3(0.006, 0.014, 0.025), Vector3(side * 0.164, 0.016, -0.02), Color.WHITE, Vector3.ZERO, true)
		b.box(Vector3(0.016, 0.016, 0.13), Vector3(side * 0.14, 0.02, -0.07), FRAME, Vector3(0.0, side * 12.0, 0.0))
	b.box(Vector3(0.26, 0.018, 0.018), Vector3(0.0, 0.025, -0.14), FRAME)


## Occhialoni da aviatore alzati sulla fronte, con il cinturino di cuoio intorno alla testa.
static func _goggles(b: LowPolyBuilder) -> void:
	b.cylinder(0.112, 0.112, 0.03, Vector3(0.0, 0.07, 0.05), LEATHER, 12)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.05, 0.068, -0.095)
		b.cylinder(0.045, 0.045, 0.022, at, BRASS, 10, Vector3(70.0, 0.0, 0.0))
		b.cylinder(0.033, 0.033, 0.024, at + Vector3(0.0, 0.002, -0.004), LENS_BLUE, 10, Vector3(70.0, 0.0, 0.0))
		b.sphere(0.008, at + Vector3(side * -0.012, 0.016, -0.012), Vector3.ONE, Color.WHITE, 4, 3, Vector3.ZERO, true)


# ------------------------------------------------------------------ collo

## Sciarpa rossa con il nodo davanti e due code che scendono sulla schiena.
static func _scarf(b: LowPolyBuilder) -> void:
	b.cylinder(0.178, 0.182, 0.07, Vector3.ZERO, SCARF_RED, 12, Vector3(-15.0, 0.0, 0.0))
	b.sphere(0.042, Vector3(0.0, -0.03, -0.16), Vector3(1.0, 0.9, 0.8), SCARF_RED.darkened(0.12), 8, 4)
	# code: dal nodo dietro il collo, appoggiate sulla schiena fin oltre le ali
	b.box(Vector3(0.09, 0.03, 0.12), Vector3(0.0, 0.12, 0.14), SCARF_RED.darkened(0.12), Vector3(-25.0, 0.0, 0.0))
	b.box(Vector3(0.085, 0.02, 0.44), Vector3(0.04, 0.172, 0.38), SCARF_RED, Vector3(-5.0, 9.0, 0.0))
	b.box(Vector3(0.075, 0.02, 0.34), Vector3(-0.04, 0.166, 0.33), SCARF_RED.darkened(0.08), Vector3(-7.0, -7.0, 0.0))


## Collare di cuoio con il campanaccio sotto il collo, come le mucche.
static func _cowbell(b: LowPolyBuilder) -> void:
	b.cylinder(0.174, 0.176, 0.036, Vector3.ZERO, LEATHER, 12, Vector3(-15.0, 0.0, 0.0))
	b.cylinder(0.03, 0.046, 0.075, Vector3(0.0, -0.12, -0.13), Color("d8b23a"), 8)
	b.sphere(0.013, Vector3(0.0, -0.165, -0.13), Vector3.ONE, Color("3a3a3a"), 5, 3)
