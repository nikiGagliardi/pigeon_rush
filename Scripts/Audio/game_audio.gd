class_name GameAudio
extends Node3D
## Audio del gioco: pool di player 2D e 3D, quattro loop d'ambiente (strada, vento, galleria, pioggia),
## tuoni casuali col temporale e i bus.
## Bus: World (effetti di gioco, riverbero attivo in galleria), Ambience (loop), UI (menu).
## I player sono figli di questo nodo: con il gioco in pausa si fermano da soli, tranne quello della UI.
## L'ascoltatore è la camera corrente. I file sono in res://Audio/sfx, generati da Tools/synth_sfx.py.

## Effetti sonori, nello stesso ordine di FILE_NAMES e BASE_DB.
enum Sfx {
	HORN_CAR, HORN_CAR_DOUBLE, HORN_CAR_ANGRY, HORN_TRUCK, PASSBY_CAR, PASSBY_TRUCK,
	FLAP, POOP_DROP, SPLAT, CRASH, PICKUP, COMBO, LOCK_ON, NEAR_MISS,
	INDICATOR_TICK, INDICATOR_TOCK, WORKS_BEEP, COUNTDOWN_BEEP, COUNTDOWN_GO, UI_CLICK, GAME_OVER,
	THUNDER,
}

## Pioggia al massimo (prima 0.8: copriva tutto il resto).
const RAIN_LEVEL := 0.4
## Vento con la neve piena.
const SNOW_WIND_MUFFLE := 0.6
const WORLD_BUS := &"World"
const AMBIENCE_BUS := &"Ambience"
const UI_BUS := &"UI"

# --- volumi da ritoccare a orecchio (dB) ---
const WORLD_BUS_DB := 0.0
const AMBIENCE_BUS_DB := -3.0
const UI_BUS_DB := -4.0

const POOL_2D := 10
const POOL_3D := 14

## Volume base di ogni effetto, nello stesso ordine di Sfx.
const BASE_DB: Array[float] = [
	-2.0, # HORN_CAR
	-2.0, # HORN_CAR_DOUBLE
	-1.0, # HORN_CAR_ANGRY
	-1.0, # HORN_TRUCK
	-5.0, # PASSBY_CAR
	-3.0, # PASSBY_TRUCK
	-12.0, # FLAP
	-6.0, # POOP_DROP
	-2.0, # SPLAT
	0.0, # CRASH
	-3.0, # PICKUP
	-4.0, # COMBO
	-9.0, # LOCK_ON
	-4.0, # NEAR_MISS
	-6.0, # INDICATOR_TICK
	-6.0, # INDICATOR_TOCK
	-4.0, # WORKS_BEEP
	-3.0, # COUNTDOWN_BEEP
	-2.0, # COUNTDOWN_GO
	-6.0, # UI_CLICK
	-2.0, # GAME_OVER
	-3.0, # THUNDER
]

const FILE_NAMES: Array[String] = [
	"horn_car", "horn_car_double", "horn_car_angry", "horn_truck", "passby_car", "passby_truck",
	"flap", "poop_drop", "splat", "crash", "pickup", "combo", "lock_on", "near_miss",
	"indicator_tick", "indicator_tock", "works_beep", "countdown_beep", "countdown_go", "ui_click", "game_over",
	"thunder",
]


class SpatialSlot:
	var player: AudioStreamPlayer3D
	var follow: Node3D = null
	var offset: Vector3 = Vector3.ZERO


class Pending:
	var sound: Sfx
	var follow: Node3D = null
	var position: Vector3 = Vector3.ZERO
	var volume_db: float = 0.0
	var pitch: float = 1.0
	var delay: float = 0.0
	var unit_size: float = 10.0
	var max_distance: float = 160.0
	var is_3d: bool = false


static var instance: GameAudio = null

var _streams: Array[AudioStream] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[SpatialSlot] = []
var _pending: Array[Pending] = []
var _ui_player: AudioStreamPlayer
var _next_2d: int = 0
var _next_3d: int = 0

# loop d'ambiente
var _road: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _tunnel: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _rain_level: float = 0.0
var _rain_target: float = 0.0
## Con la neve il vento si attutisce (1 = normale).
var _wind_muffle: float = 1.0
var _wind_muffle_target: float = 1.0
var _thunder_timer: float = 8.0
var _thunder_allowed: bool = false
var _rng := RandomNumberGenerator.new()
var _road_level: float = 0.0
var _wind_level: float = 0.0
var _tunnel_level: float = 0.0
var _wind_pitch: float = 1.0
var _road_target: float = 0.0
var _wind_target: float = 0.0
var _tunnel_target: float = 0.0
var _wind_pitch_target: float = 1.0

var _world_bus_index: int = -1
var _reverb_on: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_ensure_buses()

	for i in FILE_NAMES.size():
		_streams.append(_load_stream(FILE_NAMES[i], i == Sfx.WORKS_BEEP))

	for i in POOL_2D:
		var player := AudioStreamPlayer.new()
		player.bus = WORLD_BUS
		add_child(player)
		_players_2d.append(player)

	for i in POOL_3D:
		var slot := SpatialSlot.new()
		slot.player = create_spatial_player(WORLD_BUS)
		add_child(slot.player)
		_players_3d.append(slot)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = UI_BUS
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_player)

	_road = _create_loop("road_loop")
	_wind = _create_loop("wind_loop")
	_tunnel = _create_loop("tunnel_loop")
	_rain = _create_loop("rain_loop")
	_rng.randomize()


func _process(delta: float) -> void:
	_tick_pending(delta)
	_tick_followers()
	_tick_ambience(delta)


## Player 3D già configurato (usato anche per sorgenti fisse come il cicalino del cantiere).
static func create_spatial_player(bus: StringName, unit_size: float = 10.0, max_distance: float = 160.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.attenuation_filter_cutoff_hz = 12000.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED # il Doppler è già nei file di passaggio
	return player


func stream(sound: Sfx) -> AudioStream:
	return _streams[sound]


## Effetto non posizionale (eventi del piccione, punteggio).
func play(sound: Sfx, volume_db: float = 0.0, pitch: float = 1.0, delay: float = 0.0) -> void:
	if delay > 0.0:
		var pending := Pending.new()
		pending.sound = sound
		pending.volume_db = volume_db
		pending.pitch = pitch
		pending.delay = delay
		_pending.append(pending)
		return

	var s := _streams[sound]
	if s == null:
		return

	var player := _players_2d[_next_2d]
	for n in POOL_2D:
		var candidate := _players_2d[(_next_2d + n) % POOL_2D]
		if not candidate.playing:
			player = candidate
			break
	_next_2d = (_next_2d + 1) % POOL_2D
	player.stream = s
	player.volume_db = BASE_DB[sound] + volume_db
	player.pitch_scale = pitch
	player.play()


## Effetto posizionale. Con follow la sorgente segue il nodo (veicolo) finché suona;
## in quel caso p_position è un offset rispetto al nodo.
func play_at(sound: Sfx, follow: Node3D, p_position: Vector3, volume_db: float = 0.0, pitch: float = 1.0,
		unit_size: float = 10.0, max_distance: float = 160.0, delay: float = 0.0) -> void:
	if delay > 0.0:
		var pending := Pending.new()
		pending.sound = sound
		pending.follow = follow
		pending.position = p_position
		pending.volume_db = volume_db
		pending.pitch = pitch
		pending.delay = delay
		pending.unit_size = unit_size
		pending.max_distance = max_distance
		pending.is_3d = true
		_pending.append(pending)
		return

	var s := _streams[sound]
	if s == null:
		return

	var slot := _players_3d[_next_3d]
	for n in POOL_3D:
		var candidate := _players_3d[(_next_3d + n) % POOL_3D]
		if not candidate.player.playing:
			slot = candidate
			break
	_next_3d = (_next_3d + 1) % POOL_3D

	var player := slot.player
	slot.follow = follow
	slot.offset = p_position if follow != null else Vector3.ZERO
	player.global_position = follow.global_position + p_position if follow != null else p_position
	player.stream = s
	player.volume_db = BASE_DB[sound] + volume_db
	player.pitch_scale = pitch
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.play()


## Suoni dei menu: funzionano anche col gioco in pausa.
func play_ui(sound: Sfx, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _streams[sound]
	if s == null:
		return
	_ui_player.stream = s
	_ui_player.volume_db = BASE_DB[sound] + volume_db
	_ui_player.pitch_scale = pitch
	_ui_player.play()


## Livelli (0..1) dei loop d'ambiente: vengono raggiunti con una dissolvenza morbida.
func set_ambience(road: float, wind: float, wind_pitch: float, tunnel: float) -> void:
	_road_target = clampf(road, 0.0, 1.0)
	_wind_target = clampf(wind, 0.0, 1.0)
	_wind_pitch_target = wind_pitch
	_tunnel_target = clampf(tunnel, 0.0, 1.0)
	_set_reverb(tunnel > 0.3)


## Pioggia (0..1): loop di sottofondo (sotto la strada e il vento), attutito in galleria; tuoni ogni 10-24 s
## solo all'aperto e durante il volo. Neve (0..1): niente pioggia, vento più ovattato.
func set_weather(rain: float, snow: float, tunnel_darkness: float, flying: bool) -> void:
	_rain_target = clampf(rain, 0.0, 1.0) * lerpf(RAIN_LEVEL, RAIN_LEVEL * 0.2, tunnel_darkness)
	_thunder_allowed = rain > 0.5 and flying and tunnel_darkness < 0.5
	_wind_muffle_target = lerpf(1.0, SNOW_WIND_MUFFLE, clampf(snow, 0.0, 1.0) * (1.0 - tunnel_darkness))


func _tick_thunder(dt: float) -> void:
	if not _thunder_allowed:
		return
	_thunder_timer -= dt
	if _thunder_timer > 0.0:
		return
	_thunder_timer = _rng.randf_range(10.0, 24.0)
	play(Sfx.THUNDER, _rng.randf_range(-12.0, -4.0), _rng.randf_range(0.8, 1.1))


func _tick_pending(dt: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var pending := _pending[i]
		pending.delay -= dt
		if pending.delay > 0.0:
			continue
		_pending.remove_at(i)
		if not pending.is_3d:
			play(pending.sound, pending.volume_db, pending.pitch)
		elif pending.follow == null or (is_instance_valid(pending.follow) and pending.follow.visible):
			# se nel frattempo il veicolo è tornato nel pool, il suono non parte più
			play_at(pending.sound, pending.follow, pending.position, pending.volume_db, pending.pitch, pending.unit_size, pending.max_distance)


func _tick_followers() -> void:
	for slot: SpatialSlot in _players_3d:
		if slot.follow == null:
			continue
		# il veicolo è tornato nel pool: la sorgente resta dov'era
		if not slot.player.playing or not is_instance_valid(slot.follow) or not slot.follow.visible:
			slot.follow = null
			continue
		slot.player.global_position = slot.follow.global_position + slot.offset


func _tick_ambience(dt: float) -> void:
	_road_level = move_toward(_road_level, _road_target, dt * 0.8)
	_wind_level = move_toward(_wind_level, _wind_target, dt * 0.8)
	_tunnel_level = move_toward(_tunnel_level, _tunnel_target, dt * 1.5)
	_wind_pitch = move_toward(_wind_pitch, _wind_pitch_target, dt * 0.5)
	_rain_level = move_toward(_rain_level, _rain_target, dt * 0.4)
	_wind_muffle = move_toward(_wind_muffle, _wind_muffle_target, dt * 0.3)
	_apply_loop(_rain, _rain_level, 1.0)
	_tick_thunder(dt)
	_apply_loop(_road, _road_level, 1.0)
	_apply_loop(_wind, _wind_level * _wind_muffle, _wind_pitch)
	_apply_loop(_tunnel, _tunnel_level, 1.0)


static func _apply_loop(player: AudioStreamPlayer, level: float, pitch: float) -> void:
	if level <= 0.001:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(level)
	player.pitch_scale = maxf(0.05, pitch)
	if not player.playing and player.stream != null:
		player.play()


func _create_loop(file_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AMBIENCE_BUS
	player.stream = _load_stream(file_name, true)
	player.volume_db = -80.0
	add_child(player)
	return player


static func _load_stream(file_name: String, loop: bool) -> AudioStream:
	var path := "res://Audio/sfx/%s.wav" % file_name
	if not ResourceLoader.exists(path):
		push_warning("[Audio] manca %s" % path)
		return null
	var s: AudioStream = load(path)
	var wav := s as AudioStreamWAV
	if loop and wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# i loop sono già "senza cucitura" nel file: si ripete tutto, dall'inizio alla fine
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s


## I bus restano nell'AudioServer anche dopo il ricaricamento della scena: si creano una volta sola.
func _ensure_buses() -> void:
	_world_bus_index = _ensure_bus(WORLD_BUS, WORLD_BUS_DB)
	_ensure_bus(AMBIENCE_BUS, AMBIENCE_BUS_DB)
	_ensure_bus(UI_BUS, UI_BUS_DB)

	if AudioServer.get_bus_effect_count(_world_bus_index) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.55
		reverb.damping = 0.35
		reverb.spread = 0.8
		reverb.hipass = 0.15
		reverb.dry = 1.0
		reverb.wet = 0.28
		reverb.predelay_msec = 40.0
		AudioServer.add_bus_effect(_world_bus_index, reverb)

	_reverb_on = true
	_set_reverb(false)


static func _ensure_bus(bus_name: StringName, volume_db: float) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, volume_db)
	return index


func _set_reverb(on: bool) -> void:
	if on == _reverb_on or _world_bus_index < 0:
		return
	_reverb_on = on
	AudioServer.set_bus_effect_enabled(_world_bus_index, 0, on)
