class_name SignGantry
extends Hazard
## Portale con cartelli verdi svizzeri. Trave in alto su tutta la larghezza + pannelli su 1-3 corsie.

const DESTINATIONS: Array[String] = [
	"Bellinzona", "Lugano", "Chiasso", "Locarno", "S. Bernardino", "Gottardo", "Chur",
	"Zürich", "Milano", "Airolo", "Biasca", "Roveredo", "Mesocco", "Luzern", "Basel",
]

var _panels: MeshInstance3D
var _labels: Array[Label3D] = []


func _init() -> void:
	var frame := MeshInstance3D.new()
	frame.mesh = StructureMeshes.gantry_frame()
	add_child(frame)
	_panels = MeshInstance3D.new()
	add_child(_panels)

	for i in GameConfig.LANE_COUNT:
		var label := Label3D.new()
		label.font_size = 72
		label.pixel_size = 0.005
		label.modulate = Palette.SIGN_WHITE
		label.outline_size = 0
		label.position = Vector3(GameConfig.lane_x(i), (StructureMeshes.PANEL_TOP + StructureMeshes.PANEL_BOTTOM) * 0.5, 0.08)
		label.visible = false
		add_child(label)
		_labels.append(label)


## lane_bits: corsie con pannello (bit 0..2), mai 0.
func activate(lane_bits: int, z: float, rng: RandomNumberGenerator) -> void:
	reset_flags()
	position = Vector3(0.0, 0.0, z)
	_panels.mesh = StructureMeshes.panels(lane_bits)

	local_boxes.clear()
	var span := GameConfig.FLY_HALF_WIDTH + 1.0
	local_boxes.append(AABB(
		Vector3(-span, StructureMeshes.GANTRY_BEAM_BOTTOM, -0.5),
		Vector3(span * 2.0, StructureMeshes.GANTRY_BEAM_TOP - StructureMeshes.GANTRY_BEAM_BOTTOM, 1.0)))

	cell_mask = 0
	for lane in GameConfig.LANE_COUNT:
		var has_panel := (lane_bits & (1 << lane)) != 0
		_labels[lane].visible = has_panel
		if not has_panel:
			continue
		var x := GameConfig.lane_x(lane)
		local_boxes.append(AABB(
			Vector3(x - StructureMeshes.PANEL_WIDTH * 0.5, StructureMeshes.PANEL_BOTTOM, -0.45),
			Vector3(StructureMeshes.PANEL_WIDTH, StructureMeshes.PANEL_TOP - StructureMeshes.PANEL_BOTTOM, 0.9)))
		cell_mask |= Hazard.lane_mask(lane, 2)
		var destination := DESTINATIONS[rng.randi_range(0, DESTINATIONS.size() - 1)]
		_labels[lane].text = "%s\n%d km" % [destination, rng.randi_range(3, 94)]
