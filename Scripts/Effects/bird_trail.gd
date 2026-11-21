class_name BirdTrail
extends MeshInstance3D
## Scia dietro l'uccello (negozio, categoria TRAIL): nastri orizzontali che partono dalle punte delle ali o
## dalla coda e sfumano all'indietro. Il mondo scorre verso +Z e il piccione resta fermo, quindi ogni frame
## i punti già registrati scivolano indietro di quanto è avanzata la strada e se ne aggiunge uno nuovo.
## Un ImmediateMesh rifatto ogni frame (poche decine di triangoli), un materiale unlit: niente particelle.
##
## In gioco vive nel mondo (tick); nel negozio è figlia dell'uccello in anteprima e mostra una scia ferma
## (build_demo), così gira insieme a lui.

## Stile: emettitori (coordinate del modello), larghezza di ogni nastro, lunghezza in metri, colori, additiva.
class Style:
	var anchors: Array[Vector3] = []
	var width: float = 0.04
	var length: float = 3.5
	## Colore per nastro (uno per emettitore) oppure lungo la scia (gradient, dalla testa alla coda).
	var colors: Array[Color] = []
	var gradient: Array[Color] = []
	var alpha: float = 0.75
	var additive: bool = false
	## 0 = stessa larghezza fino in fondo, 1 = si stringe fino a zero.
	var taper: float = 0.3

const MAX_SAMPLES := 40
## Punte delle ali del piccione (le altre specie le scalano con apertura e corpo).
const WINGTIP := Vector3(0.62, 0.08, 0.12)
const TAIL := Vector3(0.0, 0.03, 0.46)

var style_id: StringName = BirdCatalog.NONE
## false sopra uno sfondo trasparente (icone del negozio): niente fusione additiva, che lì sparirebbe.
var additive_allowed: bool = true
var _style: Style = null
var _immediate := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
## Campioni: per ognuno la posizione di ogni emettitore.
var _samples: Array[PackedVector3Array] = []
var _wing_reach: float = 1.0
var _body_scale := Vector3.ONE


func _init() -> void:
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	material_override = _material


## Scia e proporzioni dell'aspetto scelto (le punte delle ali seguono specie e apertura alare).
func set_look(look: BirdLook) -> void:
	var species := BirdCatalog.species(look.species)
	_wing_reach = species.wing_scale
	_body_scale = species.body_scale
	set_style(look.trail)


func set_style(id: StringName) -> void:
	style_id = id
	_style = style_for(id)
	if _style != null and not additive_allowed:
		_style.additive = false
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if _style != null and _style.additive else BaseMaterial3D.BLEND_MODE_MIX
	clear()


func clear() -> void:
	_samples.clear()
	_immediate.clear_surfaces()


## Un frame di gioco: la scia scorre indietro di ground_step, poi un campione nuovo dalla posa del modello.
func tick(ground_step: float, model: Transform3D) -> void:
	if _style == null:
		return
	var shift := Vector3(0.0, 0.0, ground_step)
	for i in _samples.size():
		var sample := _samples[i]
		for k in sample.size():
			sample[k] = sample[k] + shift
		_samples[i] = sample
	var fresh := PackedVector3Array()
	for anchor: Vector3 in _style.anchors:
		fresh.append(model * _scaled(anchor))
	_samples.push_front(fresh)
	# via i campioni oltre la lunghezza della scia (dal primo, che è sull'uccello)
	var head_z := fresh[0].z
	while _samples.size() > 2 and (_samples.size() > MAX_SAMPLES or _samples[-1][0].z - head_z > _style.length):
		_samples.pop_back()
	_rebuild()


## Scia ferma per il negozio, nelle coordinate dell'uccello: una curva morbida all'indietro.
func build_demo(look: BirdLook, demo_length: float = 1.8, width_scale: float = 1.0) -> void:
	set_look(look)
	if _style == null:
		return
	_style.width *= width_scale
	var steps := 18
	for i in steps:
		var t := float(i) / (steps - 1)
		var sample := PackedVector3Array()
		var offset := Vector3(sin(t * 3.0) * 0.12, -sin(t * 2.2) * 0.08, t * demo_length)
		for anchor: Vector3 in _style.anchors:
			sample.append(_scaled(anchor) + offset)
		_samples.append(sample)
	var real_length := _style.length
	_style.length = demo_length
	_rebuild()
	_style.length = real_length


func _scaled(anchor: Vector3) -> Vector3:
	var reach := _wing_reach if absf(anchor.x) > 0.3 else 1.0
	return Vector3(anchor.x * reach, anchor.y, anchor.z) * _body_scale


func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _samples.size() < 2:
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := _samples.size()
	var head_z := _samples[0][0].z
	for e in _style.anchors.size():
		for i in count - 1:
			var a := _samples[i][e]
			var b := _samples[i + 1][e]
			var ta := clampf((a.z - head_z) / _style.length, 0.0, 1.0)
			var tb := clampf((b.z - head_z) / _style.length, 0.0, 1.0)
			var ca := _color(e, ta)
			var cb := _color(e, tb)
			var wa := _style.width * (1.0 - ta * _style.taper)
			var wb := _style.width * (1.0 - tb * _style.taper)
			var a0 := a + Vector3(-wa, 0.0, 0.0)
			var a1 := a + Vector3(wa, 0.0, 0.0)
			var b0 := b + Vector3(-wb, 0.0, 0.0)
			var b1 := b + Vector3(wb, 0.0, 0.0)
			_vertex(a0, ca)
			_vertex(b0, cb)
			_vertex(a1, ca)
			_vertex(a1, ca)
			_vertex(b0, cb)
			_vertex(b1, cb)
	_immediate.surface_end()


func _vertex(p: Vector3, color: Color) -> void:
	_immediate.surface_set_color(color)
	_immediate.surface_add_vertex(p)


## Colore di un nastro a una certa distanza (0 = sull'uccello, 1 = in fondo): sfuma fino a sparire.
func _color(emitter: int, t: float) -> Color:
	var color: Color
	if not _style.gradient.is_empty():
		var x := t * (_style.gradient.size() - 1)
		var i := mini(int(x), _style.gradient.size() - 2)
		color = _style.gradient[i].lerp(_style.gradient[i + 1], x - i)
	else:
		color = _style.colors[emitter % _style.colors.size()]
	var fade := 1.0 - t
	if _style.additive:
		return Color(color.r * fade, color.g * fade, color.b * fade, 1.0) * _style.alpha
	color.a = _style.alpha * fade * fade
	return color


static func style_for(id: StringName) -> Style:
	var s := Style.new()
	match id:
		&"contrail":
			s.anchors = [Vector3(-WINGTIP.x, WINGTIP.y, WINGTIP.z), WINGTIP]
			s.width = 0.04
			s.length = 3.5
			s.colors = [Color("ffffff")]
			s.alpha = 0.9
		&"neon_trail":
			s.anchors = [Vector3(-WINGTIP.x, WINGTIP.y, WINGTIP.z), WINGTIP]
			s.width = 0.045
			s.length = 4.0
			s.colors = [Color("33e8ff")]
			s.alpha = 1.0
			s.additive = true
			s.taper = 0.6
		&"comet":
			s.anchors = [TAIL]
			s.width = 0.2
			s.length = 4.0
			s.gradient = [Color("fff6c2"), Color("ffc02e"), Color("ff6a1a"), Color("c81e1e")]
			s.alpha = 1.0
			s.additive = true
			s.taper = 1.0
		&"rainbow_trail":
			for k in 6:
				s.anchors.append(TAIL + Vector3((k - 2.5) * 0.075, 0.0, 0.0))
				s.colors.append(Color.from_hsv(k / 6.0 * 0.83, 0.75, 1.0))
			s.width = 0.0375
			s.length = 5.0
			s.alpha = 0.85
			s.taper = 0.0
		_:
			return null
	return s
