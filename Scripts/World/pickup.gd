class_name Pickup
extends Node3D
## Oggetto raccoglibile sospeso in aria: ruota, ondeggia, ha un alone dorato pulsante
## e un raggio di luce fino all'asfalto (fa capire subito corsia e altezza).

enum PickupKind {
	CRUMBS, ## Briciole: ricaricano la cacca.
}

const MESH_SCALE := 1.7

static var _crumbs_mesh: ArrayMesh
static var _halo: QuadMesh
static var _beam: CylinderMesh

var kind: PickupKind = PickupKind.CRUMBS

var _mesh: MeshInstance3D
var _halo_instance: MeshInstance3D
var _beam_instance: MeshInstance3D
var _phase: float = 0.0
var _base_y: float = 0.0


func _init() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * MESH_SCALE
	add_child(_mesh)

	_halo_instance = MeshInstance3D.new()
	_halo_instance.mesh = halo()
	_halo_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo_instance)

	_beam_instance = MeshInstance3D.new()
	_beam_instance.mesh = beam()
	_beam_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam_instance)


func activate(p_kind: PickupKind, p_position: Vector3) -> void:
	kind = p_kind
	position = p_position
	_base_y = p_position.y
	_phase = p_position.x
	_mesh.mesh = crumbs_mesh()
	# raggio dall'asfalto all'oggetto: cilindro alto 1, scalato sull'altezza
	_beam_instance.position = Vector3(0.0, -_base_y * 0.5, 0.0)
	_beam_instance.scale = Vector3(1.0, _base_y, 1.0)


func animate(dt: float) -> void:
	_phase += dt
	_mesh.rotation = Vector3(0.0, _phase * 2.5, 0.0)
	var bob := sin(_phase * 4.0) * 0.15
	position = Vector3(position.x, _base_y + bob, position.z)
	_beam_instance.position = Vector3(0.0, -(_base_y + bob) * 0.5, 0.0)
	_beam_instance.scale = Vector3(1.0, _base_y + bob, 1.0)
	var pulse := 1.0 + sin(_phase * 6.0) * 0.15
	_halo_instance.scale = Vector3(pulse, pulse, pulse)


## Alone dorato additivo, sempre rivolto alla camera.
static func halo() -> QuadMesh:
	if _halo == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true # altrimenti il billboard ignora la scala e l'alone non pulsa
		mat.albedo_color = Color(1.0, 0.78, 0.2)
		mat.albedo_texture = HighBeamVisuals.radial_glow()
		_halo = QuadMesh.new()
		_halo.size = Vector2(3.2, 3.2)
		_halo.material = mat
	return _halo


## Raggio verticale additivo (alto 1, scalato in base all'altezza dell'oggetto).
static func beam() -> CylinderMesh:
	if _beam == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.45, 0.34, 0.08)
		_beam = CylinderMesh.new()
		_beam.top_radius = 0.07
		_beam.bottom_radius = 0.18
		_beam.height = 1.0
		_beam.radial_segments = 8
		_beam.rings = 1
		_beam.cap_top = false
		_beam.cap_bottom = false
		_beam.material = mat
	return _beam


static func crumbs_mesh() -> ArrayMesh:
	if _crumbs_mesh == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.48
		torus.outer_radius = 0.56
		torus.rings = 12
		torus.ring_segments = 4
		_crumbs_mesh = LowPolyBuilder.new() \
			.box(Vector3(0.22, 0.16, 0.2), Vector3.ZERO, Palette.CRUMB, Vector3(10.0, 20.0, 5.0)) \
			.box(Vector3(0.16, 0.14, 0.18), Vector3(0.22, 0.08, 0.1), Palette.CRUMB_DARK, Vector3(30.0, 0.0, 15.0)) \
			.box(Vector3(0.18, 0.12, 0.14), Vector3(-0.2, -0.05, 0.12), Palette.CRUMB, Vector3(0.0, 45.0, 20.0)) \
			.box(Vector3(0.14, 0.12, 0.16), Vector3(0.05, 0.15, -0.2), Palette.CRUMB_DARK, Vector3(25.0, 10.0, 0.0)) \
			.add_primitive(torus, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)), Vector3.ZERO), Palette.GOLD, true) \
			.build()
	return _crumbs_mesh
