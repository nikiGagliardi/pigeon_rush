class_name Overpass
extends Hazard
## Cavalcavia: blocca tutta la parte alta, si passa solo sotto.


func _init() -> void:
	var deck := MeshInstance3D.new()
	deck.mesh = StructureMeshes.overpass()
	add_child(deck)


func activate(z: float) -> void:
	reset_flags()
	position = Vector3(0.0, 0.0, z)
	local_boxes.clear()
	var span := GameConfig.FLY_HALF_WIDTH + 1.0
	var half := StructureMeshes.OVERPASS_DEPTH * 0.5
	local_boxes.append(AABB(Vector3(-span, StructureMeshes.OVERPASS_DECK_BOTTOM, -half), Vector3(span * 2.0, 4.0, StructureMeshes.OVERPASS_DEPTH)))
	cell_mask = Cells.band(2)
