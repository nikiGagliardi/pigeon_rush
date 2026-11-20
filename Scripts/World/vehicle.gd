class_name Vehicle
extends Hazard
## Veicolo contromano. Viaggia a velocità piccione + traffico.

const Kind := VehicleCatalog.Kind

const FLASH_ON_TIME := 0.14
const FLASH_OFF_TIME := 0.12

# cambio corsia: freccia → manovra
const SIGNAL_TIME := 1.5
const BLINK_PERIOD := 0.5
const MAX_STEER_YAW := 0.1 # ~6°

## Bagliori delle luci di ingombro: il camion ne ha di più (VehicleMeshes.truck_marker_positions).
const MAX_MARKERS := 15

enum LaneChangeState { NONE, SIGNALING, MOVING }

var kind: Kind = Kind.CAR
var spec: VehicleCatalog.Spec = VehicleCatalog.CAR
var lane: int = 0
var is_hit: bool = false
## Ha già lampeggiato in questo passaggio (un avvertimento per veicolo).
var has_flashed: bool = false
## Il suono di passaggio è già partito in questo passaggio.
var passby_played: bool = false

var is_heavy: bool:
	get:
		return kind == Kind.TRUCK or kind == Kind.BUS

var is_changing_lane: bool:
	get:
		return _lane_state != LaneChangeState.NONE

## Corsia di destinazione durante un cambio corsia, altrimenti la corsia attuale.
var target_lane: int:
	get:
		return _target_lane if is_changing_lane else lane

## Durata della manovra: i mezzi pesanti sono più lenti.
var move_time: float:
	get:
		return 1.8 if is_heavy else 1.3

var _body: MeshInstance3D
var _splat: MeshInstance3D
var _high_beams: Node3D
var _flares: Array[MeshInstance3D] = []
var _beams: Array[MeshInstance3D] = []
var _low_beams: Node3D
var _low_parts: Array[MeshInstance3D] = [] # per lato: cono, bagliore
## Bagliori delle luci di ingombro (camion, bus): accesi con gli anabbaglianti, i superflui nascosti.
var _markers: Array[MeshInstance3D] = []
var _indicators: Array[Node3D] = [] # 0 = sinistra (-X), 1 = destra (+X)
var _indicator_parts: Array[MeshInstance3D] = [] # per freccia: anteriore, laterale, bagliore

var _flashes_left: int = 0
var _flash_timer: float = 0.0
var _flash_on: bool = false

var _lane_state: LaneChangeState = LaneChangeState.NONE
var _target_lane: int = 0
var _from_x: float = 0.0
var _to_x: float = 0.0
var _lane_timer: float = 0.0
var _move_progress: float = 0.0
var _blink: float = 0.0


func _init() -> void:
	_body = MeshInstance3D.new()
	add_child(_body)
	_splat = MeshInstance3D.new()
	_splat.mesh = VehicleMeshes.splat()
	_splat.visible = false
	_splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splat)

	_high_beams = Node3D.new()
	_high_beams.visible = false
	add_child(_high_beams)
	_low_beams = Node3D.new()
	_low_beams.visible = false
	add_child(_low_beams)
	for i in 2:
		var flare := MeshInstance3D.new()
		flare.mesh = HighBeamVisuals.flare()
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var beam := MeshInstance3D.new()
		beam.mesh = HighBeamVisuals.beam()
		beam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_high_beams.add_child(flare)
		_high_beams.add_child(beam)
		_flares.append(flare)
		_beams.append(beam)

		var low_beam := MeshInstance3D.new()
		low_beam.mesh = HighBeamVisuals.low_beam()
		low_beam.rotation_degrees = Vector3(-90.0 + HighBeamVisuals.LOW_BEAM_PITCH, 0.0, 0.0)
		low_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var low_flare := MeshInstance3D.new()
		low_flare.mesh = HighBeamVisuals.low_flare()
		low_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_low_parts.append_array([low_beam, low_flare])

		# freccia: lampadina sull'angolo anteriore + ripetitore laterale + bagliore
		var indicator := Node3D.new()
		indicator.visible = false
		var front := MeshInstance3D.new()
		front.mesh = IndicatorVisuals.lamp()
		var side := MeshInstance3D.new()
		side.mesh = IndicatorVisuals.lamp()
		side.scale = Vector3(0.4, 0.8, 1.2)
		var glow := MeshInstance3D.new()
		glow.mesh = IndicatorVisuals.flare()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_low_beams.add_child(low_beam)
		_low_beams.add_child(low_flare)
		indicator.add_child(front)
		indicator.add_child(side)
		indicator.add_child(glow)
		_indicator_parts.append_array([front, side, glow])
		add_child(indicator)
		_indicators.append(indicator)

	for i in MAX_MARKERS:
		var marker := MeshInstance3D.new()
		marker.mesh = HighBeamVisuals.marker_flare()
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		_low_beams.add_child(marker)
		_markers.append(marker)


func activate(p_kind: Kind, variant: int, p_lane: int, x: float, z: float) -> void:
	kind = p_kind
	spec = VehicleCatalog.get_spec(p_kind)
	lane = p_lane
	is_hit = false
	has_flashed = false
	passby_played = false
	_flashes_left = 0
	_high_beams.visible = false
	reset_flags()

	_body.mesh = VehicleMeshes.get_mesh(p_kind, variant)
	_splat.visible = false
	position = Vector3(x, 0.0, z)
	rotation = Vector3.ZERO
	_lane_state = LaneChangeState.NONE
	_indicators[0].visible = false
	_indicators[1].visible = false
	_place_indicators()

	local_boxes.clear()
	local_boxes.append(AABB(Vector3(-spec.width * 0.5, 0.0, -spec.length * 0.5), Vector3(spec.width, spec.height, spec.length)))
	cell_mask = _lane_cells(p_lane)

	# fari alla posizione giusta per questo tipo di mezzo
	var front := spec.length * 0.5
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_flares[i].position = Vector3(side * spec.headlight_x, spec.headlight_y, front + 0.2)
		_beams[i].position = Vector3(side * spec.headlight_x, spec.headlight_y, front + HighBeamVisuals.BEAM_LENGTH * 0.5)
		var half := HighBeamVisuals.LOW_BEAM_LENGTH * 0.5
		var pitch := deg_to_rad(HighBeamVisuals.LOW_BEAM_PITCH)
		_low_parts[i * 2].position = Vector3(side * spec.headlight_x, spec.headlight_y - sin(pitch) * half, front + cos(pitch) * half)
		_low_parts[i * 2 + 1].position = Vector3(side * spec.headlight_x, spec.headlight_y, front + 0.15)
	_place_markers()


## Bagliori arancio sulle luci di ingombro: di notte e con la pioggia camion e bus non sembrano auto.
func _place_markers() -> void:
	var used := 0
	match kind:
		Kind.TRUCK:
			var positions := VehicleMeshes.truck_marker_positions()
			for i in positions.size():
				var size := 0.7 if i >= VehicleMeshes.TRUCK_FRONT_MARKERS else 1.0
				_set_marker(used, positions[i] + Vector3(0.0, 0.0, 0.05), Vector3(size, size, 1.0))
				used += 1
		Kind.BUS:
			var display := VehicleMeshes.BUS_DISPLAY_SIZE
			_set_marker(used, Vector3(0.0, VehicleMeshes.BUS_DISPLAY_Y, spec.length * 0.5 + 0.1),
				Vector3(display.x + 1.0, display.y + 0.6, 1.0))
			used += 1
			for p: Vector3 in VehicleMeshes.bus_marker_positions():
				_set_marker(used, p + Vector3(0.0, 0.0, 0.05), Vector3(0.8, 0.8, 1.0))
				used += 1
	for i in range(used, MAX_MARKERS):
		_markers[i].visible = false


func _set_marker(index: int, at: Vector3, size: Vector3) -> void:
	var marker := _markers[index]
	marker.position = at
	marker.scale = size
	marker.visible = true


## Avvia un cambio corsia: prima la freccia, poi la manovra.
func start_lane_change(p_target_lane: int) -> void:
	_target_lane = p_target_lane
	_from_x = position.x
	_to_x = GameConfig.lane_x(p_target_lane) + (position.x - GameConfig.lane_x(lane)) # conserva la piccola variazione nella corsia
	_lane_state = LaneChangeState.SIGNALING
	_lane_timer = SIGNAL_TIME
	_blink = 0.0


func tick_lane_change(dt: float) -> void:
	if _lane_state == LaneChangeState.NONE:
		return

	# la freccia lampeggia sia durante l'avviso sia durante la manovra
	_blink += dt
	var side := 1 if _to_x > _from_x else 0
	var on := fposmod(_blink, BLINK_PERIOD) < BLINK_PERIOD * 0.5
	if on != _indicators[side].visible:
		_indicators[side].visible = on
		# tic-tac della freccia: si sente piano e da lontano, utile come avviso
		if GameAudio.instance != null:
			GameAudio.instance.play_at(GameAudio.Sfx.INDICATOR_TICK if on else GameAudio.Sfx.INDICATOR_TOCK, self, Vector3.ZERO, 0.0, 1.0, 40.0, 300.0)

	if _lane_state == LaneChangeState.SIGNALING:
		_lane_timer -= dt
		if _lane_timer <= 0.0:
			_lane_state = LaneChangeState.MOVING
			_move_progress = 0.0
		return

	_move_progress = minf(1.0, _move_progress + dt / move_time)
	var eased := smoothstep(0.0, 1.0, _move_progress)
	position = Vector3(lerpf(_from_x, _to_x, eased), position.y, position.z)

	# leggera sterzata: il muso punta verso la corsia di destinazione e poi si raddrizza
	var steer := sin(_move_progress * PI) * MAX_STEER_YAW * (1.0 if _to_x > _from_x else -1.0)
	rotation = Vector3(0.0, steer, 0.0)

	# a metà manovra il mezzo "appartiene" già alla nuova corsia
	if eased >= 0.5 and lane != _target_lane:
		lane = _target_lane
		cell_mask = _lane_cells(lane)

	if _move_progress >= 1.0:
		_lane_state = LaneChangeState.NONE
		rotation = Vector3.ZERO
		_indicators[0].visible = false
		_indicators[1].visible = false


## Lampeggia con gli abbaglianti count volte.
## Anabbaglianti accesi (notte, nebbia, pioggia, gallerie): l'intensità è comune, vedi HighBeamVisuals.
func set_low_beams(on: bool) -> void:
	_low_beams.visible = on


func flash_high_beams(count: int) -> void:
	has_flashed = true
	_flashes_left = count
	_flash_on = true
	_flash_timer = FLASH_ON_TIME
	_high_beams.visible = true


func tick_lights(dt: float) -> void:
	if _flashes_left <= 0:
		return
	_flash_timer -= dt
	if _flash_timer > 0.0:
		return
	if _flash_on:
		_flash_on = false
		_flashes_left -= 1
		_high_beams.visible = false
		_flash_timer = FLASH_OFF_TIME
	else:
		_flash_on = true
		_high_beams.visible = true
		_flash_timer = FLASH_ON_TIME


## Zona del tetto (o abitacolo) che conta come bersaglio, in coordinate mondo.
func target_box(pad_xz: float, pad_top: float) -> AABB:
	var s := spec
	return AABB(
		position + Vector3(-s.width * 0.5 - pad_xz, s.target_bottom, -s.length * 0.5 - pad_xz),
		Vector3(s.width + pad_xz * 2.0, s.target_top - s.target_bottom + pad_top, s.length + pad_xz * 2.0))


## True se il piccione, restando dov'è, verrebbe investito da questo mezzo.
func is_in_path(pigeon: AABB) -> bool:
	var half_width := spec.width * 0.5
	var overlap_x := pigeon.end.x > position.x - half_width - 0.2 and pigeon.position.x < position.x + half_width + 0.2
	var below_roof := pigeon.position.y < spec.height + 0.2
	return overlap_x and below_roof


func mark_passby() -> void:
	passby_played = true


func mark_hit(world_point: Vector3) -> void:
	is_hit = true
	var local := world_point - position
	var s := spec
	var y := 1.36 if kind == Kind.CABRIO else s.target_top + 0.02
	_splat.position = Vector3(
		clampf(local.x, -s.width * 0.3, s.width * 0.3),
		y,
		clampf(local.z, -s.length * 0.35, s.length * 0.35))
	_splat.rotation = Vector3(0.0, randf() * TAU, 0.0)
	_splat.visible = true


func _lane_cells(p_lane: int) -> int:
	return Hazard.lane_mask(p_lane, 0) | (Hazard.lane_mask(p_lane, 1) if spec.blocks_mid else 0)


func _place_indicators() -> void:
	var front := spec.length * 0.5
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var corner_x := side * (spec.width * 0.5 - 0.1)
		var y := spec.headlight_y
		_indicator_parts[i * 3].position = Vector3(corner_x, y, front + 0.04)
		_indicator_parts[i * 3 + 1].position = Vector3(side * (spec.width * 0.5 + 0.03), y + 0.1, front - 0.7)
		_indicator_parts[i * 3 + 2].position = Vector3(corner_x, y, front + 0.25)
