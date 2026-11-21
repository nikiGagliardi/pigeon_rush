class_name ShopIcons
extends Node
## Icone delle schede del negozio, fotografate in 3D a runtime: niente immagini da tenere allineate ai modelli.
## Una foto per frame in un SubViewport con un mondo tutto suo e lo sfondo trasparente; le icone restano in
## una cache statica, così sopravvivono a "Try again". Senza grafica (prova automatica) non fa niente.

signal icon_ready(id: StringName)

const SIZE := Vector2i(128, 128)
const FOV := 30.0
## Da dove si guarda (l'uccello guarda verso -Z): davanti a destra e dall'alto per uccelli e cappelli,
## quasi di fronte per occhiali, sciarpa e campanaccio.
const VIEW_DIR := Vector3(0.62, 0.42, -1.0)
const VIEW_DIR_FRONT := Vector3(0.3, 0.05, -1.0)

static var _textures: Dictionary[StringName, Texture2D] = {}

var _viewport: SubViewport
var _camera: Camera3D
var _subject: Node3D
var _queue: Array[StringName] = []
var _running: bool = false


static func get_icon(id: StringName) -> Texture2D:
	return _textures.get(id)


static func can_render() -> bool:
	return DisplayServer.get_name() != "headless"


func _ready() -> void:
	if not can_render():
		return
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.63, 0.7)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.light_energy = 1.15
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_viewport.add_child(_camera)


## Mette in coda le icone che mancano; icon_ready arriva per ognuna appena è pronta.
func request(ids: Array[StringName]) -> void:
	if _viewport == null:
		return
	for id: StringName in ids:
		if not _textures.has(id) and not _queue.has(id) and BirdCatalog.knows(id):
			_queue.append(id)
	if not _running and not _queue.is_empty():
		_run()


func _run() -> void:
	_running = true
	while not _queue.is_empty() and is_inside_tree():
		var id: StringName = _queue.pop_front()
		_pose(id)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			break
		var image := _viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			_textures[id] = ImageTexture.create_from_image(image)
			icon_ready.emit(id)
	_running = false


## Prepara la scena per un oggetto: l'uccello intero per specie e piumaggi, l'accessorio da solo per il resto.
func _pose(id: StringName) -> void:
	if _subject != null:
		_viewport.remove_child(_subject)
		_subject.queue_free()
	var category := BirdCatalog.category_of(id)
	var bounds: AABB
	if category == BirdCatalog.CATEGORY_BIRD or category == BirdCatalog.CATEGORY_FEATHERS:
		var look := BirdLook.new()
		look.set_item(category, id)
		var bird := PigeonModel.new(look)
		bird.flap(-1.2, 1.0, 0.75) # ali abbassate: sagoma compatta
		_subject = bird
		bounds = AABB(Vector3(-0.38, -0.4, -0.62), Vector3(0.76, 0.72, 1.2))
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BirdAccessories.mesh(id)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_subject = mesh_instance
		bounds = mesh_instance.mesh.get_aabb()
	_viewport.add_child(_subject)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.05)
	var distance := radius / sin(deg_to_rad(FOV * 0.5)) * 1.02
	var front := category == BirdCatalog.CATEGORY_FACE or category == BirdCatalog.CATEGORY_NECK
	var dir := VIEW_DIR_FRONT if front else VIEW_DIR
	_camera.look_at_from_position(center + dir.normalized() * distance, center, Vector3.UP)
