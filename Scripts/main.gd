class_name Main
extends Node3D
## Regista del gioco: costruisce la scena da codice e orchestra l'ordine di aggiornamento
## (input → velocità → mondo → mirino/cacca → collisioni → punteggio → camera/UI).

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER }

const Sfx := GameAudio.Sfx

## Dopo "Try again" la scena viene ricaricata: salta il titolo.
static var _skip_title_on_load: bool = false
## Prova automatica senza interfaccia: godot --headless --path . -- --smoke-test
static var _smoke_runs: int = 0
const SMOKE_SURVIVE_TIME := 150.0

var _session := GameSession.new()
var _rng := RandomNumberGenerator.new()

var _sun: DirectionalLight3D
var _environment: Environment
var _applied_darkness: float = -1.0

var _pigeon: PigeonController
var _camera: ChaseCamera
var _road: RoadScroller
var _traffic: TrafficSpawner
var _ambient: AmbientTraffic
var _poop: PoopSystem
var _texts: FloatingTextPool
var _feather_burst: CPUParticles3D
var _hud: Hud
var _touch: TouchControls
var _screens: Screens
var _warmup: AssetWarmup
var _audio: GameAudio

var _state: GameState = GameState.TITLE
var _best: int = 0
var _new_record: bool = false
var _game_over_delay: float = 0.0
var _input_delay: float = 0.0
var _no_ammo_cooldown: float = 0.0

# audio: limiti di frequenza per non affollare il mix
var _horn_cooldown: float = 0.0
var _lock_sound_cooldown: float = 0.0
var _flap_cooldown: float = 0.0
var _climbing: bool = false
var _last_lock: Vehicle = null

var _smoke_test: bool = false
var _smoke_time: float = 0.0
var _smoke_hits: int = 0
var _smoke_shots: bool = false
var _next_shot: float = 3.0


func _ready() -> void:
	Actions.ensure_registered()
	_best = SaveData.load_best()
	_smoke_test = OS.get_cmdline_user_args().has("--smoke-test")
	_smoke_shots = OS.get_cmdline_user_args().has("--shots")

	var world_environment := SceneryFactory.create_environment()
	_environment = world_environment.environment
	add_child(world_environment)
	_sun = SceneryFactory.create_sun()
	add_child(_sun)
	add_child(SceneryFactory.create_backdrop())

	# prima del traffico: veicoli e cantieri cercano GameAudio.instance
	_audio = GameAudio.new()
	add_child(_audio)

	_road = RoadScroller.new()
	add_child(_road)

	_traffic = TrafficSpawner.new()
	add_child(_traffic)

	_ambient = AmbientTraffic.new()
	add_child(_ambient)

	_pigeon = PigeonController.new()
	add_child(_pigeon)

	_poop = PoopSystem.new()
	add_child(_poop)

	_texts = FloatingTextPool.new()
	add_child(_texts)

	_feather_burst = EffectsFactory.create_feather_burst()
	add_child(_feather_burst)

	_camera = ChaseCamera.new()
	_camera.target = _pigeon
	add_child(_camera)
	_camera.make_current()
	_camera.snap()

	# prepara mesh e shader durante il menu: niente scatti alla prima galleria/cantiere
	_warmup = AssetWarmup.new()
	_camera.add_child(_warmup)

	var ui := CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)
	_touch = TouchControls.new()
	ui.add_child(_touch)
	_screens = Screens.new()
	ui.add_child(_screens)

	_hud.set_best(_best)
	_hud.pause_pressed.connect(_pause)
	_screens.start_pressed.connect(_start_game)
	_screens.resume_pressed.connect(_resume)
	_screens.restart_pressed.connect(_restart)
	_traffic.pigeon_hit.connect(_on_pigeon_hit)
	_traffic.near_miss.connect(_on_near_miss)
	_traffic.pickup_collected.connect(_on_pickup_collected)
	_traffic.vehicle_warned.connect(_on_vehicle_warned)
	_traffic.vehicle_passing.connect(_on_vehicle_passing)
	_poop.vehicle_hit.connect(_on_vehicle_hit)
	_poop.road_hit.connect(_on_poop_road_hit)

	if _skip_title_on_load or _smoke_test:
		_skip_title_on_load = false
		_start_game()
	else:
		_hud.visible = false
		_screens.show_title(_best)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0) # niente salti enormi dopo un lag

	match _state:
		GameState.TITLE:
			_tick_ambient(dt)
			_pigeon.tick_idle(dt)
		GameState.PLAYING:
			_tick_playing(dt)
		GameState.GAME_OVER:
			_tick_game_over(dt)

	_camera.tick(dt, _session.speed.boost_normalized, _session.speed.speed_normalized, _traffic.camera_ceiling(_camera.position.z))
	_apply_tunnel_lighting(_traffic.tunnel_darkness)
	_update_ambience()
	_texts.tick(dt)
	_touch.ammo = _session.ammo
	_hud.refresh(dt, _session, _poop.locked_target != null, _pigeon.position.y < GameConfig.LOW_FLY_HEIGHT)


func _notification(what: int) -> void:
	# su mobile: app in background = pausa automatica
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()


func _tick_playing(dt: float) -> void:
	# _input_delay evita che lo stesso Esc che ha chiuso la pausa la riapra subito
	if _input_delay <= 0.0 and Input.is_action_just_pressed(Actions.PAUSE):
		_pause()
		return

	_input_delay = maxf(0.0, _input_delay - dt)
	_no_ammo_cooldown = maxf(0.0, _no_ammo_cooldown - dt)
	_horn_cooldown = maxf(0.0, _horn_cooldown - dt)
	_lock_sound_cooldown = maxf(0.0, _lock_sound_cooldown - dt)
	_flap_cooldown = maxf(0.0, _flap_cooldown - dt)

	_session.tick(dt)
	var speed := _session.speed
	var ground_step := speed.pigeon_speed * dt
	var traffic_step := speed.approach_speed * dt

	var input := Input.get_vector(Actions.MOVE_LEFT, Actions.MOVE_RIGHT, Actions.MOVE_DOWN, Actions.MOVE_UP) + _touch.move_vector
	if _smoke_test:
		input = _smoke_input(dt)
	if input.length_squared() > 1.0:
		input = input.normalized()
	var limits := _traffic.get_fly_limits(_pigeon.position.z)
	_pigeon.tick(dt, input, 10.0 + speed.boost_normalized * 8.0, limits.x, limits.y)
	_play_flap_on_climb(input.y)

	_road.advance(ground_step)
	_traffic.tick(dt, ground_step, traffic_step, _session)
	_ambient.tick(dt, speed.pigeon_speed)

	_poop.update_lock(dt, _pigeon, _traffic.vehicles, speed.approach_speed)
	_play_lock_sound()
	var poop_pressed := _touch.consume_poop() or Input.is_action_just_pressed(Actions.POOP)
	if _smoke_test:
		poop_pressed = _poop.locked_target != null
	if poop_pressed and _input_delay <= 0.0:
		_try_poop()
	_poop.tick(dt, ground_step, traffic_step, _traffic.vehicles)

	_traffic.resolve_pigeon(_pigeon, ground_step, traffic_step, speed.approach_speed)
	if _state != GameState.PLAYING:
		return # game over durante le collisioni

	_session.score.tick(dt, ground_step, speed.multiplier, _pigeon.position.y < GameConfig.LOW_FLY_HEIGHT)


func _tick_ambient(dt: float) -> void:
	var ambient_speed := GameConfig.BASE_PIGEON_SPEED * 0.6
	var ground_step := ambient_speed * dt
	_road.advance(ground_step)
	_traffic.tick(dt, ground_step, ground_step, _session)
	_ambient.tick(dt, ambient_speed)


func _tick_game_over(dt: float) -> void:
	var speed := _session.speed
	speed.time_scale -= dt * 0.9
	var ground_step := speed.pigeon_speed * dt
	var traffic_step := speed.approach_speed * dt

	_road.advance(ground_step)
	_traffic.tick(dt, ground_step, traffic_step, _session)
	_ambient.tick(dt, speed.pigeon_speed)
	_poop.tick(dt, ground_step, traffic_step, _traffic.vehicles)
	_pigeon.tick_crash(dt)

	if _game_over_delay <= 0.0:
		return

	_game_over_delay -= dt
	if _game_over_delay <= 0.0:
		_screens.show_game_over(_session, _best, _new_record)
		_audio.play_ui(Sfx.GAME_OVER)
		if _smoke_test:
			_smoke_finish_run()


## Loop d'ambiente: strada e vento crescono con la velocità, la galleria col buio.
func _update_ambience() -> void:
	var speed := _session.speed
	var tunnel := _traffic.tunnel_darkness
	match _state:
		GameState.TITLE:
			_audio.set_ambience(0.3, 0.12, 0.9, tunnel)
		GameState.PLAYING:
			_audio.set_ambience(
				0.55 + 0.35 * speed.speed_normalized,
				0.2 + 0.45 * speed.speed_normalized + 0.35 * speed.boost_normalized,
				0.9 + 0.25 * speed.speed_normalized + 0.12 * speed.boost_normalized,
				tunnel)
		GameState.GAME_OVER:
			_audio.set_ambience(0.0, 0.0, 0.7, tunnel * 0.5)


## Battito d'ali quando il piccione inizia a salire.
func _play_flap_on_climb(input_y: float) -> void:
	var climbing := input_y > 0.5
	if climbing and not _climbing and _flap_cooldown <= 0.0:
		_audio.play(Sfx.FLAP, 0.0, 0.9 + _rng.randf() * 0.2)
		_flap_cooldown = 0.3
	_climbing = climbing


func _play_lock_sound() -> void:
	var locked := _poop.locked_target
	if locked != null and locked != _last_lock and _lock_sound_cooldown <= 0.0:
		_audio.play(Sfx.LOCK_ON)
		_lock_sound_cooldown = 0.25
	_last_lock = locked


## In galleria sole e luce ambiente si spengono: restano visibili lampade e fari (unlit).
func _apply_tunnel_lighting(darkness: float) -> void:
	if absf(darkness - _applied_darkness) < 0.005:
		return
	_applied_darkness = darkness
	_sun.light_energy = lerpf(SceneryFactory.SUN_ENERGY, 0.0, darkness)
	_environment.ambient_light_energy = lerpf(SceneryFactory.AMBIENT_ENERGY, 0.3, darkness)
	_environment.fog_light_color = SceneryFactory.FOG_COLOR.lerp(SceneryFactory.TUNNEL_FOG_COLOR, darkness)


func _try_poop() -> void:
	if _session.ammo <= 0:
		_audio.play(Sfx.UI_CLICK, 0.0, 0.6) # "clic a vuoto"
		if _no_ammo_cooldown <= 0.0:
			_texts.spawn("Out of poop! Grab some crumbs", Palette.DANGER, _pigeon.position + Vector3(0.0, 1.2, -2.0), 0.6, 1.2)
			_no_ammo_cooldown = 1.2
		return

	if _poop.try_drop(_pigeon, _session, _session.speed.approach_speed):
		_audio.play(Sfx.POOP_DROP, 0.0, 0.95 + _rng.randf() * 0.15)


## Il mezzo davanti lampeggia: clacson (tromba per camion e bus).
func _on_vehicle_warned(vehicle: Vehicle) -> void:
	if _horn_cooldown > 0.0:
		return
	_horn_cooldown = 0.6
	var sound: Sfx
	var pitch: float
	if vehicle.is_heavy:
		sound = Sfx.HORN_TRUCK
		pitch = 0.97 + _rng.randf() * 0.06
	else:
		sound = Sfx.HORN_CAR if _rng.randf() < 0.5 else Sfx.HORN_CAR_DOUBLE
		pitch = 0.92 + _rng.randf() * 0.1
	_audio.play_at(sound, vehicle, Vector3(0.0, 1.0, vehicle.spec.length * 0.5), 0.0, pitch, 25.0, 220.0)


func _on_vehicle_passing(vehicle: Vehicle) -> void:
	var sound := Sfx.PASSBY_TRUCK if vehicle.is_heavy else Sfx.PASSBY_CAR
	_audio.play_at(sound, vehicle, Vector3.ZERO, 0.0, 0.95 + _rng.randf() * 0.1, 20.0, 120.0)


func _on_poop_road_hit(p_position: Vector3) -> void:
	_audio.play_at(Sfx.SPLAT, null, p_position, -10.0, 1.3, 6.0, 60.0)


func _on_vehicle_hit(vehicle: Vehicle, p_position: Vector3) -> void:
	var points := _session.score.register_hit(vehicle.spec.points)
	_session.speed.add_boost(vehicle.spec.boost)

	_texts.spawn("+%d" % points, Palette.GOLD, p_position + Vector3(0.0, 1.0, 0.0), 1.2)
	if not vehicle.spec.hit_label.is_empty():
		_texts.spawn(vehicle.spec.hit_label, Color.WHITE, p_position + Vector3(0.0, 2.2, 0.0), 0.7, 1.1)

	_camera.add_trauma(0.12)

	_audio.play(Sfx.SPLAT)
	var combo := _session.score.combo
	if combo >= 2:
		_audio.play(Sfx.COMBO, 0.0, 1.0 + 0.06 * (mini(combo, GameConfig.MAX_COMBO_MULTIPLIER) - 2), 0.08)

	# l'autista non la prende bene
	if _rng.randf() < 0.7:
		var horn := Sfx.HORN_TRUCK if vehicle.is_heavy else Sfx.HORN_CAR_ANGRY
		_audio.play_at(horn, vehicle, Vector3(0.0, 1.0, 0.0), 0.0, 0.95 + _rng.randf() * 0.05, 20.0, 160.0, 0.35)


func _on_near_miss(p_position: Vector3) -> void:
	var points := _session.score.register_near_miss()
	_audio.play(Sfx.NEAR_MISS)
	_texts.spawn("Close call! +%d" % points, Palette.INFO, p_position + Vector3(0.0, 0.9, -2.5), 0.7)


func _on_pickup_collected(kind: Pickup.PickupKind, _p_position: Vector3) -> void:
	var text_position := _pigeon.position + Vector3(0.0, 1.0, -2.5)
	match kind:
		Pickup.PickupKind.CRUMBS:
			_session.add_ammo(GameConfig.CRUMBS_AMMO)
			_audio.play(Sfx.PICKUP)
			_session.score.add_points(20)
			_texts.spawn("+%d poop" % GameConfig.CRUMBS_AMMO, Palette.CRUMB, text_position, 0.8)


func _on_pigeon_hit(p_position: Vector3) -> void:
	if _state != GameState.PLAYING:
		return
	if _smoke_test and _session.elapsed < SMOKE_SURVIVE_TIME:
		_smoke_hits += 1 # nella prova automatica si sopravvive a lungo per passare da gallerie e cantieri
		return
	# un colpo e basta: niente vite, niente invulnerabilità
	_session.crash()
	_audio.play(Sfx.CRASH)
	_camera.add_trauma(0.85)
	_feather_burst.global_position = p_position
	_feather_burst.restart()
	Input.vibrate_handheld(250)
	_enter_game_over()


func _start_game() -> void:
	if _warmup != null and is_instance_valid(_warmup) and not _warmup.is_done:
		_warmup.finish_now()

	_state = GameState.PLAYING
	_input_delay = 0.25 # evita che lo Spazio del menu sganci subito
	_session.speed.time_scale = 1.0
	_screens.hide_all()
	_hud.visible = true
	_touch.enabled = true
	_traffic.spawning_enabled = true


func _pause() -> void:
	if _state != GameState.PLAYING:
		return
	_state = GameState.PAUSED
	_touch.enabled = false
	_audio.play_ui(Sfx.UI_CLICK)
	get_tree().paused = true
	_screens.show_pause()


func _resume() -> void:
	if _state != GameState.PAUSED:
		return
	get_tree().paused = false
	_state = GameState.PLAYING
	_input_delay = 0.25
	_screens.hide_all()
	_touch.enabled = true


func _restart() -> void:
	get_tree().paused = false
	_skip_title_on_load = true
	get_tree().reload_current_scene()


func _enter_game_over() -> void:
	_state = GameState.GAME_OVER
	_touch.enabled = false
	_traffic.spawning_enabled = false
	_game_over_delay = 1.3

	var score := _session.score.score
	_new_record = score > _best
	if _new_record:
		_best = score
		SaveData.save_best(score)


# ------------------------------------------------------------------ prova automatica

## Volo pseudo-casuale per la prova senza interfaccia: copre corsie, quote, cantieri e gallerie.
func _smoke_input(dt: float) -> Vector2:
	_smoke_time += dt
	if _smoke_shots and _smoke_time >= _next_shot:
		# con --shots salva una schermata ogni 6 s (serve un driver video, non --headless)
		get_viewport().get_texture().get_image().save_png("user://smoke_%03d.png" % int(_next_shot))
		_next_shot += 6.0
	return Vector2(sin(_smoke_time * 0.9) + 0.3 * sin(_smoke_time * 2.3), sin(_smoke_time * 0.6) * 0.8)


func _smoke_finish_run() -> void:
	_smoke_runs += 1
	var score := _session.score
	print("[Smoke] partita %d: %.0f s, %d m, %d punti, %d mezzi centrati, %d passaggi a filo, %d impatti ignorati, %d mezzi attivi" % [
		_smoke_runs, _session.elapsed, int(score.distance), score.score, score.hits, score.near_misses, _smoke_hits, _traffic.vehicles.size()])
	if _smoke_runs >= 2:
		print("[Smoke] OK")
		get_tree().quit()
	else:
		_restart()
