class_name LandmarkSpawner
extends Node3D
## Fa comparire il luogo tipico della tratta (RouteSegment.landmark) laggiù in fondo, nella nebbia, e lo fa
## scorrere con la strada finché non è dietro la camera. Uno per volta: le tratte sono lunghe almeno 800 m.

## Distanza davanti a cui compare: oltre la fine della nebbia normale (300 m), così non "spunta" dal nulla.
const SPAWN_AHEAD := 330.0
## Dietro la camera: i più grandi (colline, castelli) restano visibili di lato ancora per un po'.
const DESPAWN_Z := 140.0

var _instance: MeshInstance3D
var _shown_key: String = ""


func _ready() -> void:
	_instance = MeshInstance3D.new()
	_instance.visible = false
	add_child(_instance)


## Da chiamare ogni frame con il percorso della partita (o un'anteprima nel titolo).
func update(route: RouteTracker) -> void:
	if _instance.visible:
		return
	var next := route.landmark_ahead(SPAWN_AHEAD)
	if next.is_empty():
		return
	var key := str(next[2])
	if key == _shown_key:
		return
	_shown_key = key
	var id := next[0] as StringName
	_instance.mesh = LandmarkMeshes.get_mesh(id)
	_instance.material_override = SceneryFactory.mountain_material if LandmarkMeshes.FAR.has(id) else null
	_instance.position = Vector3(0.0, 0.0, -float(next[1]))
	_instance.visible = true


func advance(step: float) -> void:
	if not _instance.visible:
		return
	_instance.position.z += step
	if _instance.position.z > DESPAWN_Z:
		_instance.visible = false


## Nuova partita o anteprima: niente luoghi rimasti dalla precedente.
func clear() -> void:
	_instance.visible = false
	_shown_key = ""
