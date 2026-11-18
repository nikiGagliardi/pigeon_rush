class_name Tunnel
extends Hazard
## Galleria a doppia canna: soffitto basso per tutta la lunghezza, ventilatori appesi,
## buio all'interno (gestito da Main tramite darkness_at).
## Coordinate locali: corpo da -length/2 a +length/2, portale d'ingresso sporgente verso +Z.

const CEILING_Y := 5.6
const PORTAL_DEPTH := 1.5
const FAN_START := 35.0
const FAN_SPACING := 70.0
const FAN_END_MARGIN := 20.0
const FAN_X := 2.6
const FAN_RADIUS := 0.55
const FAN_LENGTH := 3.6
const FAN_BOTTOM := CEILING_Y - 0.6 - FAN_RADIUS

const DARKNESS_RAMP := 22.0
const CAMERA_MARGIN := 0.45
const CAMERA_APPROACH := 14.0


var length: float = 0.0

var entrance_z: float:
	get:
		return position.z + length * 0.5 + PORTAL_DEPTH

var exit_z: float:
	get:
		return position.z - length * 0.5

var _mesh: MeshInstance3D
var _name_label: Label3D


func _init() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_name_label = Label3D.new()
	_name_label.font_size = 96
	_name_label.pixel_size = 0.011
	_name_label.modulate = Palette.SIGN_WHITE
	_name_label.outline_size = 0
	add_child(_name_label)


## p_name: nome sul portale, scelto dalla tratta (vedi RouteSegment.tunnel_names).
func activate(p_length: float, p_front_z: float, p_name: String) -> void:
	reset_flags()
	length = p_length
	position = Vector3(0.0, 0.0, p_front_z - p_length * 0.5 - PORTAL_DEPTH)
	_mesh.mesh = TunnelMeshes.get_mesh(p_length)
	_name_label.text = p_name
	_name_label.position = Vector3(TunnelMeshes.SIGN_X, TunnelMeshes.SIGN_Y, p_length * 0.5 + 0.2)

	var half := p_length * 0.5
	var span := GameConfig.FLY_HALF_WIDTH + 1.0
	local_boxes.clear()
	local_boxes.append(AABB(Vector3(-span, CEILING_Y, -half), Vector3(span * 2.0, 6.0, p_length + PORTAL_DEPTH)))

	var z := -half + FAN_START
	while z < half - FAN_END_MARGIN:
		for x: float in [-FAN_X, FAN_X]:
			local_boxes.append(AABB(
				Vector3(x - FAN_RADIUS - 0.05, FAN_BOTTOM, z - FAN_LENGTH * 0.5),
				Vector3((FAN_RADIUS + 0.05) * 2.0, CEILING_Y - FAN_BOTTOM, FAN_LENGTH)))
		z += FAN_SPACING

	cell_mask = Cells.band(2)


## 0 fuori, 1 in piena galleria, con rampa vicino ai portali.
func darkness_at(z: float) -> float:
	if z > entrance_z or z < exit_z:
		return 0.0
	var depth := minf(entrance_z - z, z - exit_z)
	return smoothstep(0.0, DARKNESS_RAMP, depth)


## Quota massima per la camera a coordinata z (INF se libera).
func camera_ceiling_at(z: float) -> float:
	var inside := CEILING_Y - CAMERA_MARGIN
	if z <= entrance_z and z >= exit_z:
		return inside
	if z > entrance_z and z < entrance_z + CAMERA_APPROACH:
		# scende gradualmente mentre il portale si avvicina, niente scatti
		var t := (z - entrance_z) / CAMERA_APPROACH
		return lerpf(inside, 12.0, t)
	return INF
