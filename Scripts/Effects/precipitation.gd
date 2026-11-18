class_name Precipitation
extends Node3D
## Pioggia e neve attorno alla camera, senza particelle né luci: due mesh di trattini/fiocchi già pronti
## (costruiti e compilati durante il menu) che scorrono in giù e verso la camera e si ripetono senza cucitura.
## Va aggiunto come figlio della camera.

## Volume coperto davanti alla camera (la camera guarda verso -Z).
const BOX := Vector3(30.0, 14.0, 32.0)
## Da 8 a 40 m davanti alla camera: una goccia o un fiocco troppo vicini sembrerebbero sbarre enormi.
const BOX_Z_CENTER := -24.0

const RAIN_STREAKS := 240
const RAIN_SIZE := Vector2(0.028, 0.75)
const RAIN_FALL := 15.0
const RAIN_COLOR := Color(0.78, 0.84, 0.95, 0.42)

const SNOW_FLAKES := 170
const SNOW_SIZE := Vector2(0.11, 0.11)
const SNOW_FALL := 2.2
const SNOW_COLOR := Color(1.0, 1.0, 1.0, 0.9)

## La pioggia arriva verso la camera solo in parte (si guarda il cielo davanti, non il vento contro).
const FORWARD_FACTOR := 0.55

static var _rain_mesh: ArrayMesh
static var _snow_mesh: ArrayMesh

## Velocità del mondo verso la camera (m/s), dal gioco.
var world_speed: float = 0.0

var _rain: MeshInstance3D
var _snow: MeshInstance3D
var _rain_amount: float = 0.0
var _snow_amount: float = 0.0
var _rain_fall: float = 0.0
var _snow_fall: float = 0.0
var _forward: float = 0.0
var _sway_time: float = 0.0


static func rain_mesh() -> ArrayMesh:
	if _rain_mesh == null:
		_rain_mesh = _build(RAIN_STREAKS, RAIN_SIZE, RAIN_COLOR, 101)
	return _rain_mesh


static func snow_mesh() -> ArrayMesh:
	if _snow_mesh == null:
		_snow_mesh = _build(SNOW_FLAKES, SNOW_SIZE, SNOW_COLOR, 202)
	return _snow_mesh


func _ready() -> void:
	_rain = _make_layer(rain_mesh())
	_snow = _make_layer(snow_mesh())


## 0..1 per tipo: l'atmosfera le fa salire e scendere con le transizioni (e le spegne in galleria).
func set_amounts(rain: float, snow: float) -> void:
	_rain_amount = clampf(rain, 0.0, 1.0)
	_snow_amount = clampf(snow, 0.0, 1.0)
	_apply_alpha(_rain, RAIN_COLOR, _rain_amount)
	_apply_alpha(_snow, SNOW_COLOR, _snow_amount)


func _process(delta: float) -> void:
	if not _rain.visible and not _snow.visible:
		return
	_forward = fposmod(_forward + world_speed * FORWARD_FACTOR * delta, BOX.z)
	_sway_time += delta
	if _rain.visible:
		_rain_fall = fposmod(_rain_fall + RAIN_FALL * delta, BOX.y)
		_rain.position = Vector3(0.0, -_rain_fall, _forward)
	if _snow.visible:
		_snow_fall = fposmod(_snow_fall + SNOW_FALL * delta, BOX.y)
		_snow.position = Vector3(sin(_sway_time * 0.7) * 0.6, -_snow_fall, _forward)


func _make_layer(mesh: ArrayMesh) -> MeshInstance3D:
	var layer := MeshInstance3D.new()
	layer.mesh = mesh
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.visible = false
	add_child(layer)
	return layer


static func _apply_alpha(layer: MeshInstance3D, base: Color, amount: float) -> void:
	layer.visible = amount > 0.01
	var mat := layer.mesh.surface_get_material(0) as StandardMaterial3D
	mat.albedo_color = Color(base.r, base.g, base.b, base.a * amount)


## count elementi casuali nel volume, ripetuti 2×2 (in alto e indietro): spostando il nodo di un multiplo
## di BOX.y in Y o di BOX.z in Z l'immagine resta identica, quindi il ciclo non si vede.
static func _build(count: int, size: Vector2, color: Color, rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	for i in count:
		var base := Vector3(
			rng.randf_range(-BOX.x * 0.5, BOX.x * 0.5),
			rng.randf_range(-BOX.y * 0.5, BOX.y * 0.5),
			BOX_Z_CENTER + rng.randf_range(-BOX.z * 0.5, BOX.z * 0.5))
		for copy_y in 2:
			for copy_z in 2:
				var p := base + Vector3(0.0, copy_y * BOX.y, -copy_z * BOX.z)
				var a := p + Vector3(-hw, -hh, 0.0)
				var b := p + Vector3(hw, -hh, 0.0)
				var c := p + Vector3(hw, hh, 0.0)
				var d := p + Vector3(-hw, hh, 0.0)
				vertices.append_array([a, b, c, a, c, d])
				for n in 6:
					normals.append(Vector3.BACK)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mesh.surface_set_material(0, mat)
	# il volume si sposta col nodo: AABB larga per non sparire per il culling
	mesh.custom_aabb = AABB(Vector3(-BOX.x, -BOX.y * 1.5, BOX_Z_CENTER - BOX.z * 2.0), Vector3(BOX.x * 2.0, BOX.y * 3.5, BOX.z * 3.5))
	return mesh
