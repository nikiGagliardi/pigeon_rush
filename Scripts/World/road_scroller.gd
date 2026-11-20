class_name RoadScroller
extends Node3D
## Nastro di segmenti di strada riciclati: quando uno supera la camera torna in fondo con una variante casuale
## del paesaggio che ci sarà laggiù (theme, aggiornato da main con RouteTracker.landscape_ahead).

## Distanza davanti al piccione a cui ricompare un segmento riciclato: il paesaggio va scelto per quel punto.
const RECYCLE_AHEAD := GameConfig.SEGMENT_COUNT * GameConfig.SEGMENT_LENGTH - GameConfig.DESPAWN_Z - GameConfig.SEGMENT_LENGTH * 0.5

## Paesaggio dei segmenti riciclati da adesso in poi.
var theme: LandscapeMeshes.Landscape = LandscapeMeshes.Landscape.TICINO

var _segments: Array[MeshInstance3D] = []
var _lights: Array[Node3D] = [] # luce dei lampioni di ogni segmento (solo di notte)
var _lights_on: bool = false


func _ready() -> void:
	var length := GameConfig.SEGMENT_LENGTH
	for i in GameConfig.SEGMENT_COUNT:
		var segment := MeshInstance3D.new()
		segment.mesh = _random_variant(theme)
		segment.position = Vector3(0.0, 0.0, GameConfig.DESPAWN_Z - length * 0.5 - i * length)
		add_child(segment)
		_segments.append(segment)
		_lights.append(_make_lights(segment))


## Ridipinge tutti i segmenti con il paesaggio giusto per la loro distanza (inizio partita, titolo).
## theme_at: Callable(metri_davanti: float) -> LandscapeMeshes.Landscape.
func retheme(theme_at: Callable) -> void:
	for segment: MeshInstance3D in _segments:
		segment.mesh = _random_variant(theme_at.call(maxf(0.0, -segment.position.z)))
	theme = theme_at.call(RECYCLE_AHEAD)


static func _random_variant(p_theme: LandscapeMeshes.Landscape) -> ArrayMesh:
	return RoadMeshes.build_variant(p_theme, randi() % RoadMeshes.VARIANT_COUNT)


## Luce dei lampioni (0..1), dall'atmosfera: accesa di notte, debole al tramonto, spenta in galleria.
func set_street_lights(level: float) -> void:
	RoadMeshes.set_street_light_level(level)
	var on := level > 0.02
	if on == _lights_on:
		return
	_lights_on = on
	for lights: Node3D in _lights:
		lights.visible = on


func _make_lights(segment: MeshInstance3D) -> Node3D:
	var lights := Node3D.new()
	lights.visible = false
	var pools := MeshInstance3D.new()
	pools.mesh = RoadMeshes.night_pools()
	pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.add_child(pools)
	for x: float in RoadMeshes.lamp_xs():
		var flare := MeshInstance3D.new()
		flare.mesh = RoadMeshes.lamp_flare()
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flare.position = Vector3(x, RoadMeshes.LAMP_Y - 0.15, 0.0)
		lights.add_child(flare)
	segment.add_child(lights)
	return lights


func advance(step: float) -> void:
	var length := GameConfig.SEGMENT_LENGTH
	for segment: MeshInstance3D in _segments:
		var p := segment.position
		p.z += step
		if p.z - length * 0.5 > GameConfig.DESPAWN_Z:
			p.z -= GameConfig.SEGMENT_COUNT * length
			segment.mesh = _random_variant(theme)
		segment.position = p
