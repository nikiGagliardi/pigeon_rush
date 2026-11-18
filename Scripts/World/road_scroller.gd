class_name RoadScroller
extends Node3D
## Nastro di segmenti di strada riciclati: quando uno supera la camera torna in fondo con una variante casuale.

var _segments: Array[MeshInstance3D] = []
var _variants: Array[ArrayMesh] = []


func _ready() -> void:
	_variants = RoadMeshes.variants()
	var length := GameConfig.SEGMENT_LENGTH
	for i in GameConfig.SEGMENT_COUNT:
		var segment := MeshInstance3D.new()
		segment.mesh = _variants.pick_random()
		segment.position = Vector3(0.0, 0.0, GameConfig.DESPAWN_Z - length * 0.5 - i * length)
		add_child(segment)
		_segments.append(segment)


func advance(step: float) -> void:
	var length := GameConfig.SEGMENT_LENGTH
	for segment: MeshInstance3D in _segments:
		var p := segment.position
		p.z += step
		if p.z - length * 0.5 > GameConfig.DESPAWN_Z:
			p.z -= GameConfig.SEGMENT_COUNT * length
			segment.mesh = _variants.pick_random()
		segment.position = p
