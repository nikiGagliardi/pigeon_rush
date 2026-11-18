@abstract
class_name Hazard
extends Node3D
## Ostacolo che scorre verso il piccione. Le hitbox sono AABB locali (nessuna rotazione):
## collisioni manuali, deterministiche ed economiche anche su mobile.

var local_boxes: Array[AABB] = []

## Celle della griglia corsie × fasce occupate da questo ostacolo.
var cell_mask: int = 0

## Già superato il piccione (per il calcolo del passaggio a filo).
var passed_pigeon: bool = false

## Si è sovrapposto al piccione almeno una volta.
var touched_pigeon: bool = false


func box_count() -> int:
	return local_boxes.size()


## Estremo posteriore (Z minima) in coordinate mondo, usato per il despawn.
func rear_z() -> float:
	if local_boxes.is_empty():
		return position.z
	var min_z := INF
	for box: AABB in local_boxes:
		min_z = minf(min_z, box.position.z)
	return position.z + min_z


## Estremo anteriore (Z massima, verso il piccione) in coordinate mondo.
func front_z() -> float:
	if local_boxes.is_empty():
		return position.z
	var max_z := -INF
	for box: AABB in local_boxes:
		max_z = maxf(max_z, box.position.z + box.size.z)
	return position.z + max_z


## Animazioni opzionali (luci lampeggianti ecc.).
func animate(_dt: float) -> void:
	pass


## Hitbox in coordinate mondo, estesa all'indietro di sweep per non "saltare" il piccione ad alta velocità.
func world_box(index: int, sweep: float = 0.0) -> AABB:
	var local := local_boxes[index]
	var origin := position + local.position
	return AABB(Vector3(origin.x, origin.y, origin.z - sweep), Vector3(local.size.x, local.size.y, local.size.z + sweep))


func reset_flags() -> void:
	passed_pigeon = false
	touched_pigeon = false


## Distanza minima sul piano XY tra due box (0 se si sovrappongono).
static func gap_xy(a: AABB, b: AABB) -> float:
	var gx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var gy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(gx * gx + gy * gy)


static func lane_mask(lane: int, band: int) -> int:
	return Cells.of(lane, band)
