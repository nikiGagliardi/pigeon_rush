class_name IndicatorVisuals
extends RefCounted
## Risorse condivise per le frecce: lampadina gialla + piccolo bagliore additivo visibile da lontano.

static var _lamp: BoxMesh
static var _flare: QuadMesh


static func lamp() -> BoxMesh:
	if _lamp == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Palette.INDICATOR
		_lamp = BoxMesh.new()
		_lamp.size = Vector3(0.24, 0.14, 0.08)
		_lamp.material = mat
	return _lamp


static func flare() -> QuadMesh:
	if _flare == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(1.0, 0.9, 0.05)
		mat.albedo_texture = HighBeamVisuals.radial_glow()
		_flare = QuadMesh.new()
		_flare.size = Vector2(1.3, 1.3)
		_flare.material = mat
	return _flare
