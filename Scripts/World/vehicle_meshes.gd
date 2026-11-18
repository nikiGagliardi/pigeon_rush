class_name VehicleMeshes
extends RefCounted
## Mesh low-poly dei veicoli, costruiti una volta e messi in cache per (tipo, variante colore).
## Origine = centro a livello strada; il muso guarda verso +Z (verso il piccione).

const Kind := VehicleCatalog.Kind

static var CAR_COLORS: Array[Color] = [Color("c0392b"), Color("2e86de"), Color("7f8c8d"), Color("27ae60"), Color("34495e"), Color("d35400")]
static var VAN_COLORS: Array[Color] = [Color("f5c400"), Color("ecf0f1"), Color("95a5a6"), Color("c0392b")]
static var TRUCK_CAB_COLORS: Array[Color] = [Color("c0392b"), Color("2e86de"), Color("e67e22"), Color("16a085")]
static var TRUCK_STRIPE_COLORS: Array[Color] = [Color("c0392b"), Color("2e86de"), Color("f39c12"), Color("27ae60")]
static var CABRIO_COLORS: Array[Color] = [Color("e74c3c"), Color("f1c40f"), Color("8e44ad")]
# giallo AutoPostale, pullman bianco/blu, rosso
static var BUS_COLORS: Array[Color] = [Color("f5c400"), Color("f2f2ee"), Color("c0392b")]
static var BUS_STRIPE_COLORS: Array[Color] = [Color("c0392b"), Color("2e86de"), Color("f2f2ee")]

static var _cache: Dictionary[int, ArrayMesh] = {}
static var _splat: ArrayMesh


static func variant_count(kind: Kind) -> int:
	match kind:
		Kind.CAR:
			return CAR_COLORS.size()
		Kind.VAN:
			return VAN_COLORS.size()
		Kind.TRUCK:
			return TRUCK_CAB_COLORS.size()
		Kind.CABRIO:
			return CABRIO_COLORS.size()
		Kind.BUS:
			return BUS_COLORS.size()
		_:
			return 1


static func get_mesh(kind: Kind, variant: int) -> ArrayMesh:
	variant %= variant_count(kind)
	var key := kind * 100 + variant
	var cached: ArrayMesh = _cache.get(key)
	if cached != null:
		return cached
	var mesh: ArrayMesh
	match kind:
		Kind.VAN:
			mesh = _build_van(VAN_COLORS[variant])
		Kind.TRUCK:
			mesh = _build_truck(TRUCK_CAB_COLORS[variant], TRUCK_STRIPE_COLORS[variant])
		Kind.BUS:
			mesh = _build_bus(BUS_COLORS[variant], BUS_STRIPE_COLORS[variant])
		Kind.CABRIO:
			mesh = _build_cabrio(CABRIO_COLORS[variant])
		Kind.CLEAN_CAR:
			mesh = _build_car(Color("ffffff"), true)
		_:
			mesh = _build_car(CAR_COLORS[variant], false)
	_cache[key] = mesh
	return mesh


## Macchia di cacca che appare sul tetto colpito.
static func splat() -> ArrayMesh:
	if _splat == null:
		_splat = LowPolyBuilder.new() \
			.sphere(0.45, Vector3.ZERO, Vector3(1.0, 0.12, 1.2), Palette.POOP, 7, 3) \
			.sphere(0.22, Vector3(0.35, 0.0, -0.3), Vector3(1.0, 0.15, 1.0), Palette.POOP_SHADE, 6, 3) \
			.sphere(0.18, Vector3(-0.3, 0.0, 0.38), Vector3(1.0, 0.15, 1.0), Palette.POOP, 6, 3) \
			.build()
	return _splat


static func _build_car(body: Color, clean: bool) -> ArrayMesh:
	var spec := VehicleCatalog.CAR
	var l := spec.length
	var w := spec.width
	var b := LowPolyBuilder.new()

	b.box(Vector3(w, 0.62, l), Vector3(0.0, 0.62, 0.0), body) # scocca
	b.box(Vector3(w * 0.86, 0.5, l * 0.48), Vector3(0.0, 1.18, -0.25), Palette.GLASS) # abitacolo
	b.box(Vector3(w * 0.84, 0.06, l * 0.42), Vector3(0.0, 1.45, -0.25), body) # tetto
	b.box(Vector3(w * 1.02, 0.18, 0.22), Vector3(0.0, 0.4, l * 0.5), Palette.TRIM) # paraurti ant.
	b.box(Vector3(w * 1.02, 0.18, 0.22), Vector3(0.0, 0.4, -l * 0.5), Palette.TRIM)
	b.box(Vector3(0.7, 0.16, 0.05), Vector3(0.0, 0.68, l * 0.5 + 0.01), Palette.TRIM) # griglia
	b.box(Vector3(0.36, 0.14, 0.06), Vector3(-0.62, 0.72, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.36, 0.14, 0.06), Vector3(0.62, 0.72, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	_add_taillights(b, 0.65, 0.75, -l * 0.5)
	_add_wheels(b, w, l * 0.32, 0.34)

	if clean:
		# scintillii "appena lavata"
		b.box(Vector3(0.14, 0.14, 0.14), Vector3(-0.5, 1.75, 0.2), Color("bff4ff"), Vector3(45.0, 45.0, 0.0), true)
		b.box(Vector3(0.1, 0.1, 0.1), Vector3(0.45, 1.9, -0.6), Color("ffffff"), Vector3(45.0, 0.0, 45.0), true)
		b.box(Vector3(0.12, 0.12, 0.12), Vector3(0.2, 1.68, 1.2), Color("bff4ff"), Vector3(0.0, 45.0, 45.0), true)

	return b.build()


static func _build_van(body: Color) -> ArrayMesh:
	var spec := VehicleCatalog.VAN
	var l := spec.length
	var w := spec.width
	var b := LowPolyBuilder.new()

	var rear_length := l - 0.9
	b.box(Vector3(w, 1.95, rear_length), Vector3(0.0, 1.3, -0.45), body) # vano
	b.box(Vector3(w, 1.0, 0.9), Vector3(0.0, 0.85, l * 0.5 - 0.45), body) # cofano
	b.box(Vector3(w * 0.9, 0.75, 0.06), Vector3(0.0, 1.82, rear_length * 0.5 - 0.43), Palette.GLASS) # parabrezza
	b.box(Vector3(w * 1.01, 0.55, 1.0), Vector3(0.0, 1.82, rear_length * 0.5 - 0.95), Palette.GLASS) # finestrini
	b.box(Vector3(w * 1.02, 0.2, 0.22), Vector3(0.0, 0.42, l * 0.5), Palette.TRIM)
	b.box(Vector3(0.34, 0.16, 0.06), Vector3(-0.66, 0.92, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.34, 0.16, 0.06), Vector3(0.66, 0.92, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	_add_taillights(b, 0.8, 1.1, -0.45 - rear_length * 0.5)
	_add_wheels(b, w, l * 0.34, 0.36)
	return b.build()


static func _build_truck(cab: Color, stripe: Color) -> ArrayMesh:
	var spec := VehicleCatalog.TRUCK
	var l := spec.length
	var w := spec.width
	var b := LowPolyBuilder.new()

	var cab_length := 2.4
	var cab_z := l * 0.5 - cab_length * 0.5
	b.box(Vector3(w, 2.6, cab_length), Vector3(0.0, 2.0, cab_z), cab) # cabina
	b.box(Vector3(w * 0.9, 1.0, 0.06), Vector3(0.0, 2.65, l * 0.5 + 0.01), Palette.GLASS) # parabrezza
	b.box(Vector3(w * 0.88, 0.55, 1.4), Vector3(0.0, 3.58, cab_z - 0.3), cab) # spoiler
	b.box(Vector3(w * 1.02, 0.35, 0.25), Vector3(0.0, 0.75, l * 0.5), Palette.TRIM) # paraurti
	b.box(Vector3(1.2, 0.6, 0.05), Vector3(0.0, 1.45, l * 0.5 + 0.02), Palette.CHROME) # griglia
	b.box(Vector3(0.4, 0.2, 0.06), Vector3(-0.85, 1.0, l * 0.5 + 0.03), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.4, 0.2, 0.06), Vector3(0.85, 1.0, l * 0.5 + 0.03), Palette.HEADLIGHT, Vector3.ZERO, true)

	var trailer_length := l - cab_length - 0.3
	var trailer_z := -l * 0.5 + trailer_length * 0.5
	b.box(Vector3(w, 3.0, trailer_length), Vector3(0.0, 2.5, trailer_z), Color("f2f2ee")) # rimorchio
	# la fascia sporge di 2 cm per lato: facce di testa coincidenti col rimorchio = z-fighting (sfarfallio)
	b.box(Vector3(w + 0.02, 0.4, trailer_length + 0.04), Vector3(0.0, 2.0, trailer_z), stripe) # fascia
	b.box(Vector3(w * 0.8, 0.4, l - 0.4), Vector3(0.0, 0.75, 0.0), Palette.TRIM) # telaio
	b.box(Vector3(0.06, 2.8, 0.04), Vector3(0.0, 2.5, -l * 0.5 - 0.02), Palette.CONCRETE_DARK) # porte posteriori
	_add_taillights(b, 1.0, 1.1, -l * 0.5)

	var r := 0.5
	var wx := w * 0.5 - 0.15
	for z: float in [l * 0.5 - 0.9, l * 0.5 - 3.3, -l * 0.5 + 2.6, -l * 0.5 + 1.4]:
		b.wheel(-wx, z, r, 0.4)
		b.wheel(wx, z, r, 0.4)

	return b.build()


static func _build_cabrio(body: Color) -> ArrayMesh:
	var spec := VehicleCatalog.CABRIO
	var l := spec.length
	var w := spec.width
	var b := LowPolyBuilder.new()

	b.box(Vector3(w, 0.6, l), Vector3(0.0, 0.6, 0.0), body)
	b.box(Vector3(w * 0.8, 0.04, l * 0.45), Vector3(0.0, 0.91, -0.2), Palette.TRIM) # interno
	b.box(Vector3(0.6, 0.45, 0.5), Vector3(-0.42, 1.12, -0.35), Palette.SEAT) # sedili
	b.box(Vector3(0.6, 0.45, 0.5), Vector3(0.42, 1.12, -0.35), Palette.SEAT)
	b.box(Vector3(0.6, 0.35, 0.12), Vector3(-0.42, 1.5, -0.62), Palette.SEAT) # schienali
	b.box(Vector3(0.6, 0.35, 0.12), Vector3(0.42, 1.5, -0.62), Palette.SEAT)
	b.box(Vector3(w * 0.9, 0.4, 0.05), Vector3(0.0, 1.1, 0.55), Palette.GLASS, Vector3(-30.0, 0.0, 0.0))
	b.box(Vector3(w * 1.02, 0.18, 0.22), Vector3(0.0, 0.4, l * 0.5), Palette.TRIM)
	b.box(Vector3(0.36, 0.12, 0.06), Vector3(-0.62, 0.72, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.36, 0.12, 0.06), Vector3(0.62, 0.72, l * 0.5 + 0.02), Palette.HEADLIGHT, Vector3.ZERO, true)
	_add_taillights(b, 0.65, 0.7, -l * 0.5)
	_add_wheels(b, w, l * 0.32, 0.34)
	return b.build()


static func _build_bus(body: Color, stripe: Color) -> ArrayMesh:
	var spec := VehicleCatalog.BUS
	var l := spec.length
	var w := spec.width
	var b := LowPolyBuilder.new()

	b.box(Vector3(w, 2.9, l), Vector3(0.0, 1.95, 0.0), body) # carrozzeria
	b.box(Vector3(w + 0.02, 0.95, l - 2.6), Vector3(0.0, 2.6, -0.5), Palette.GLASS) # finestrini laterali
	b.box(Vector3(w + 0.02, 0.28, l + 0.04), Vector3(0.0, 1.45, 0.0), stripe) # fascia (sporge: niente z-fighting)
	b.box(Vector3(w * 0.92, 1.35, 0.06), Vector3(0.0, 2.35, l * 0.5 + 0.01), Palette.GLASS) # parabrezza
	b.box(Vector3(1.5, 0.22, 0.05), Vector3(0.0, 3.17, l * 0.5 + 0.02), Palette.DESTINATION_DISPLAY, Vector3.ZERO, true) # display destinazione
	b.box(Vector3(1.5, 0.22, 2.6), Vector3(0.0, 3.46, -1.5), Palette.CHROME) # clima sul tetto
	b.box(Vector3(w * 1.02, 0.3, 0.22), Vector3(0.0, 0.6, l * 0.5), Palette.TRIM) # paraurti
	b.box(Vector3(0.42, 0.16, 0.06), Vector3(-spec.headlight_x, spec.headlight_y, l * 0.5 + 0.03), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.42, 0.16, 0.06), Vector3(spec.headlight_x, spec.headlight_y, l * 0.5 + 0.03), Palette.HEADLIGHT, Vector3.ZERO, true)
	b.box(Vector3(w * 0.85, 0.9, 0.05), Vector3(0.0, 2.7, -l * 0.5 - 0.01), Palette.GLASS) # lunotto
	_add_taillights(b, 1.05, 0.9, -l * 0.5)

	var r := 0.5
	var wx := w * 0.5 - 0.12
	for z: float in [l * 0.5 - 2.2, -l * 0.5 + 3.6, -l * 0.5 + 2.4]:
		b.wheel(-wx, z, r, 0.36)
		b.wheel(wx, z, r, 0.36)

	return b.build()


## Fanalini rossi sul retro (visibili sulla carreggiata opposta).
static func _add_taillights(b: LowPolyBuilder, x: float, y: float, rear_z: float) -> void:
	b.box(Vector3(0.32, 0.14, 0.06), Vector3(-x, y, rear_z - 0.02), Palette.TAILLIGHT, Vector3.ZERO, true)
	b.box(Vector3(0.32, 0.14, 0.06), Vector3(x, y, rear_z - 0.02), Palette.TAILLIGHT, Vector3.ZERO, true)


static func _add_wheels(b: LowPolyBuilder, width: float, axle_z: float, radius: float) -> void:
	var x := width * 0.5
	b.wheel(-x, axle_z, radius)
	b.wheel(x, axle_z, radius)
	b.wheel(-x, -axle_z, radius)
	b.wheel(x, -axle_z, radius)
