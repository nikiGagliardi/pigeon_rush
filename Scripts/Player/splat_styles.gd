class_name SplatStyles
extends RefCounted
## Stili della cacca (negozio, categoria SPLAT): la goccia che cade, la macchia sull'asfalto e quella sul
## tetto dei mezzi. "none" è la cacca classica. Cambia solo l'aspetto: forma e dimensioni restano quelle,
## quindi mira e colpi non cambiano.

const BUBBLEGUM := Color("ff7fc4")
const BUBBLEGUM_SHADE := Color("e05aa6")
const NEON := Color("8cff4a")
const NEON_SHADE := Color("3fd12a")
const SWISS_RED := Color("d52b1e")
const SWISS_WHITE := Color("f4f4f4")

## Stile in uso (Main lo imposta da quello che indossa il giocatore).
static var current: StringName = BirdCatalog.NONE

static var _cache: Dictionary[String, ArrayMesh] = {}


static func drop_mesh(style: StringName) -> ArrayMesh:
	return _mesh(style, "drop")


static func road_mesh(style: StringName) -> ArrayMesh:
	return _mesh(style, "road")


static func vehicle_mesh(style: StringName) -> ArrayMesh:
	return _mesh(style, "vehicle")


static func _mesh(style: StringName, kind: String) -> ArrayMesh:
	var key := "%s/%s" % [style, kind]
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var b := LowPolyBuilder.new()
	match kind:
		"drop":
			_drop(b, style)
		"road":
			_blob(b, style, 0.35, 0.06, 1.4, 1.0)
		_:
			_blob(b, style, 0.45, 0.12, 1.2, 1.3)
	var mesh := b.build()
	_cache[key] = mesh
	return mesh


## Colori principale e d'ombra; il neon è senza luce, così si vede anche di notte e in galleria.
static func _colors(style: StringName) -> Array[Color]:
	match style:
		&"bubblegum":
			return [BUBBLEGUM, BUBBLEGUM_SHADE]
		&"neon_splat":
			return [NEON, NEON_SHADE]
		&"swiss_splat":
			return [SWISS_RED, SWISS_RED.darkened(0.2)]
	return [Palette.POOP, Palette.POOP_SHADE]


static func _drop(b: LowPolyBuilder, style: StringName) -> void:
	var colors := _colors(style)
	var unlit := style == &"neon_splat"
	if style == &"rainbow_splat":
		b.sphere(0.11, Vector3.ZERO, Vector3(1.0, 1.2, 1.0), Color.from_hsv(0.0, 0.7, 1.0), 6, 4)
		b.sphere(0.07, Vector3(0.04, 0.05, 0.03), Vector3.ONE, Color.from_hsv(0.33, 0.7, 1.0), 5, 3)
		b.sphere(0.06, Vector3(-0.04, -0.04, -0.02), Vector3.ONE, Color.from_hsv(0.62, 0.7, 1.0), 5, 3)
		return
	b.sphere(0.11, Vector3.ZERO, Vector3(1.0, 1.2, 1.0), colors[0], 6, 4, Vector3.ZERO, unlit)
	b.sphere(0.06, Vector3(0.04, 0.05, 0.03), Vector3.ONE, colors[1], 5, 3, Vector3.ZERO, unlit)


## Macchia: chiazza principale e due schizzi. radius e flat dicono quanto è grande e schiacciata,
## stretch quanto è allungata, splash quanto si allontanano gli schizzi.
static func _blob(b: LowPolyBuilder, style: StringName, radius: float, flat: float, stretch: float, splash: float) -> void:
	if style == &"rainbow_splat":
		b.sphere(radius, Vector3.ZERO, Vector3(1.0, flat, stretch), Color.from_hsv(0.0, 0.7, 1.0), 7, 3)
		for k in 5:
			var a := TAU * k / 5.0
			var pos := Vector3(cos(a), 0.01, sin(a)) * radius * 0.7 * splash
			b.sphere(radius * 0.45, pos, Vector3(1.0, flat * 1.3, 1.0), Color.from_hsv((k + 1) / 6.0, 0.75, 1.0), 6, 3)
		return
	var colors := _colors(style)
	var unlit := style == &"neon_splat"
	b.sphere(radius, Vector3.ZERO, Vector3(1.0, flat, stretch), colors[0], 7, 3, Vector3.ZERO, unlit)
	b.sphere(radius * 0.48, Vector3(0.7, 0.0, 0.7) * radius * splash, Vector3(1.0, flat * 1.3, 1.0), colors[1], 6, 3, Vector3.ZERO, unlit)
	b.sphere(radius * 0.4, Vector3(-0.65, 0.0, 0.8) * radius * splash, Vector3(1.0, flat * 1.3, 1.0), colors[0], 6, 3, Vector3.ZERO, unlit)
	if style == &"swiss_splat":
		# croce bianca sopra la chiazza
		var top := radius * flat + 0.004
		b.box(Vector3(radius * 0.9, 0.01, radius * 0.28), Vector3(0.0, top, 0.0), SWISS_WHITE)
		b.box(Vector3(radius * 0.28, 0.01, radius * 0.9), Vector3(0.0, top, 0.0), SWISS_WHITE)
