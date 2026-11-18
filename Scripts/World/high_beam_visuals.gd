class_name HighBeamVisuals
extends RefCounted
## Risorse condivise per gli abbaglianti: bagliore (quad billboard additivo con gradiente radiale)
## e cono di luce (cilindro additivo). Nessuna luce dinamica: costo minimo anche su mobile.

const BEAM_LENGTH := 16.0

static var _flare: QuadMesh
static var _beam: CylinderMesh
static var _glow: GradientTexture2D


static func flare() -> QuadMesh:
	if _flare == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(1.0, 0.96, 0.85)
		mat.albedo_texture = radial_glow()
		_flare = QuadMesh.new()
		_flare.size = Vector2(2.8, 2.8)
		_flare.material = mat
	return _flare


## Gradiente radiale bianco → nero: con blend additivo il nero non aggiunge nulla.
static func radial_glow() -> GradientTexture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0), Color(0.75, 0.7, 0.55), Color(0.0, 0.0, 0.0)])
		_glow = GradientTexture2D.new()
		_glow.width = 64
		_glow.height = 64
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)
		_glow.gradient = gradient
	return _glow


## Cono centrato nell'origine: punta stretta in +Y, base larga in -Y (ruotato di -90° su X punta verso +Z).
static func beam() -> CylinderMesh:
	if _beam == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.2, 0.19, 0.15)
		_beam = CylinderMesh.new()
		_beam.top_radius = 0.12
		_beam.bottom_radius = 1.9
		_beam.height = BEAM_LENGTH
		_beam.radial_segments = 10
		_beam.rings = 1
		_beam.cap_top = false
		_beam.cap_bottom = false
		_beam.material = mat
	return _beam
