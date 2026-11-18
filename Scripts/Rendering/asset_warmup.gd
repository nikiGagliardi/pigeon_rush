class_name AssetWarmup
extends Node3D
## Evita i micro-blocchi alla prima comparsa di un oggetto (galleria, cantiere, bus, abbaglianti…).
## Durante il menu costruisce tutti i mesh procedurali (uno per frame, così il menu resta fluido)
## e li disegna una volta in miniatura davanti alla camera: così la geometria è già caricata sulla GPU
## e gli shader/pipeline sono già compilati quando inizia la partita.
## Va aggiunto come figlio della camera.

const PREVIEW_DISTANCE := 3.0
const PREVIEW_SIZE := 0.05 # pochi pixel, e dietro al pannello del titolo
const FRAMES_VISIBLE := 3 # frame di rendering prima di rimuovere le anteprime

var is_done: bool = false

var _jobs: Array[Callable] = []
var _previews: Array[Node3D] = []
var _frames_left: int = -1
var _build_usec: int = 0
var _built: int = 0


func _ready() -> void:
	_jobs = _catalog()
	_add_glyph_previews()
	_add_particle_preview()


func _process(_delta: float) -> void:
	if is_done:
		return

	if not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		_build(job) # un solo mesh per frame: il menu non si blocca
		return

	if _frames_left < 0:
		_frames_left = FRAMES_VISIBLE
	_frames_left -= 1
	if _frames_left > 0:
		return

	for preview: Node3D in _previews:
		preview.queue_free()
	_previews.clear()
	is_done = true
	print("[Warmup] %d mesh costruiti in %.0f ms, forme in cache: %d" % [_built, _build_usec / 1000.0, LowPolyBuilder.cached_shape_count()])
	queue_free()


## Se si preme Play prima della fine, completa subito il lavoro rimasto.
func finish_now() -> void:
	while not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		_build(job)


func _build(job: Callable) -> void:
	var start := Time.get_ticks_usec()
	var mesh: Mesh = job.call()
	_build_usec += Time.get_ticks_usec() - start
	_built += 1

	var aabb := mesh.get_aabb()
	var extent := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s := PREVIEW_SIZE / extent if extent > 0.0 else 1.0

	# posizione a griglia per non sovrapporre tutto nello stesso punto
	var i := _previews.size()
	var offset := Vector3((i % 8 - 3.5) * 0.06, (int(i / 8.0) % 4 - 1.5) * 0.06, 0.0)
	var center := aabb.position + aabb.size * 0.5

	var preview := MeshInstance3D.new()
	preview.mesh = mesh
	preview.scale = Vector3.ONE * s
	preview.position = Vector3(0.0, 0.0, -PREVIEW_DISTANCE) + offset - center * s
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON # compila anche la passata ombre
	add_child(preview)
	_previews.append(preview)


## Tutti i mesh creati a runtime dal gioco.
static func _catalog() -> Array[Callable]:
	var jobs: Array[Callable] = []
	jobs.append(func() -> Mesh: return RoadMeshes.variants()[0])
	for v in range(1, RoadMeshes.VARIANT_COUNT):
		jobs.append(func() -> Mesh: return RoadMeshes.variants()[v])

	for kind: int in VehicleCatalog.Kind.values():
		for v in VehicleMeshes.variant_count(kind):
			jobs.append(func() -> Mesh: return VehicleMeshes.get_mesh(kind, v))

	jobs.append(func() -> Mesh: return VehicleMeshes.splat())
	jobs.append(func() -> Mesh: return StructureMeshes.gantry_frame())
	jobs.append(func() -> Mesh: return StructureMeshes.overpass())
	jobs.append(func() -> Mesh: return RouteSign.mesh())
	for bits in range(1, 0b111 + 1):
		jobs.append(func() -> Mesh: return StructureMeshes.panels(bits))

	for length: float in TunnelMeshes.LENGTHS:
		jobs.append(func() -> Mesh: return TunnelMeshes.get_mesh(length))

	for length: float in RoadWorksMeshes.LENGTHS:
		jobs.append(func() -> Mesh: return RoadWorksMeshes.get_mesh(0, length))
		jobs.append(func() -> Mesh: return RoadWorksMeshes.get_mesh(2, length))

	jobs.append(func() -> Mesh: return RoadWorksMeshes.machine(RoadWorksMeshes.MachineKind.EXCAVATOR))
	jobs.append(func() -> Mesh: return RoadWorksMeshes.machine(RoadWorksMeshes.MachineKind.ROLLER))
	jobs.append(func() -> Mesh: return RoadWorksMeshes.beacons())
	jobs.append(func() -> Mesh: return RoadWorksMeshes.net())

	jobs.append(func() -> Mesh: return HighBeamVisuals.flare())
	jobs.append(func() -> Mesh: return HighBeamVisuals.beam())
	jobs.append(func() -> Mesh: return HighBeamVisuals.low_beam())
	jobs.append(func() -> Mesh: return HighBeamVisuals.low_flare())
	jobs.append(func() -> Mesh: return Precipitation.rain_mesh())
	jobs.append(func() -> Mesh: return Precipitation.snow_mesh())
	jobs.append(func() -> Mesh: return RoadMeshes.night_pools())
	jobs.append(func() -> Mesh: return RoadMeshes.lamp_flare())
	jobs.append(func() -> Mesh: return IndicatorVisuals.lamp())
	jobs.append(func() -> Mesh: return IndicatorVisuals.flare())

	jobs.append(func() -> Mesh: return Pickup.crumbs_mesh())
	jobs.append(func() -> Mesh: return Pickup.golden_mesh())
	jobs.append(func() -> Mesh: return Pickup.halo())
	jobs.append(func() -> Mesh: return Pickup.golden_halo())
	jobs.append(func() -> Mesh: return Pickup.beam())
	jobs.append(func() -> Mesh: return PoopSystem.drop_mesh())
	jobs.append(func() -> Mesh: return PoopSystem.road_splat_mesh())
	jobs.append(func() -> Mesh: return PoopSystem.reticle_mesh())
	return jobs


## Etichette 3D con tutti i caratteri e le dimensioni usate, per popolare l'atlante dei font.
func _add_glyph_previews() -> void:
	var glyphs := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzüöäÜÖÄ0123456789+-!.,'/→ "
	var styles: Array[Vector2i] = [Vector2i(64, 14), Vector2i(64, 0), Vector2i(72, 0), Vector2i(96, 0)] # (dimensione, contorno)
	for i in styles.size():
		var label := Label3D.new()
		label.text = glyphs
		label.font_size = styles[i].x
		label.outline_size = styles[i].y
		label.pixel_size = 0.00005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if i == 0 else BaseMaterial3D.BILLBOARD_DISABLED
		label.no_depth_test = i == 0
		label.position = Vector3(0.0, -0.05 - i * 0.02, -PREVIEW_DISTANCE)
		add_child(label)
		_previews.append(label)


## Le particelle usano una variante di shader diversa (multimesh): va compilata anche quella.
func _add_particle_preview() -> void:
	var particles := EffectsFactory.create_feather_burst()
	particles.local_coords = true
	particles.scale = Vector3.ONE * 0.02
	particles.position = Vector3(0.0, 0.05, -PREVIEW_DISTANCE)
	add_child(particles)
	particles.emitting = true
	_previews.append(particles)
