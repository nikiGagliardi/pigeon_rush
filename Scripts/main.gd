class_name Main
extends Node3D
## Regista del gioco: costruisce la scena da codice e orchestra l'ordine di aggiornamento
## (input → velocità → mondo → mirino/cacca → collisioni → punteggio → camera/UI).
##
## Ciclo di partita: TITLE → COUNTDOWN → PLAYING → (impatto) CRASHED → CONTINUE_OFFER → COUNTDOWN → PLAYING …
## oppure CRASHED → GAME_OVER. Un solo Continua per partita, pagato con una pubblicità a premio.

enum GameState { TITLE, COUNTDOWN, PLAYING, PAUSED, CRASHED, CONTINUE_OFFER, GAME_OVER }

const Sfx := GameAudio.Sfx

## Velocità del mondo nel menu e nel countdown di inizio partita.
const TITLE_WORLD_SPEED := GameConfig.BASE_PIGEON_SPEED * 0.6

## Dopo "Try again" la scena viene ricaricata: salta il titolo.
static var _skip_title_on_load: bool = false
## Prova automatica senza interfaccia: godot --headless --path . -- --smoke-test
static var _smoke_runs: int = 0
static var _smoke_checked: bool = false
static var _smoke_errors: PackedStringArray = PackedStringArray()
const SMOKE_SURVIVE_TIME := 150.0

var _session := GameSession.new()
var _save: SaveData
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
var _state_before_pause: GameState = GameState.PLAYING
var _crash_delay: float = 0.0
var _input_delay: float = 0.0
var _no_ammo_cooldown: float = 0.0

# countdown 3-2-1 (inizio partita e ripresa)
var _countdown_left: float = 0.0
var _countdown_digit: int = 0
var _countdown_world_speed: float = 0.0

# Continua
var _continues_used: int = 0
var _offer_left: float = 0.0
var _offer_digit: int = 0
var _ad_running: bool = false
var _invulnerable: float = 0.0
var _blink_time: float = 0.0

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
var _smoke_survive_time: float = SMOKE_SURVIVE_TIME
var _shot_key: String = ""
var _shot_key_time: float = 0.0
var _shots_taken: Dictionary[String, bool] = {}


func _ready() -> void:
	Actions.ensure_registered()
	_save = SaveData.load_or_default()
	AudioServer.set_bus_volume_linear(0, _save.sfx_volume)
	Ads.ensure(get_tree())
	# mai nelle build di release: la prova automatica ignora gli impatti
	_smoke_test = OS.is_debug_build() and OS.get_cmdline_user_args().has("--smoke-test")
	_smoke_shots = OS.get_cmdline_user_args().has("--shots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--survive="):
			_smoke_survive_time = arg.trim_prefix("--survive=").to_float() # partite più brevi per le schermate
	if _smoke_test and not _smoke_checked:
		_smoke_checked = true
		_smoke_self_checks()

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

	_hud.set_best(_save.best_score)
	_hud.pause_pressed.connect(_pause)
	_screens.start_pressed.connect(_start_game)
	_screens.resume_pressed.connect(_resume)
	_screens.restart_pressed.connect(_restart)
	_screens.retry_pressed.connect(_on_retry_pressed)
	_screens.continue_accepted.connect(_on_continue_accepted)
	_screens.continue_declined.connect(_on_continue_declined)
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
		_screens.show_title(_save.best_score)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0) # niente salti enormi dopo un lag

	match _state:
		GameState.TITLE:
			_tick_ambient(dt)
			_pigeon.tick_idle(dt)
		GameState.COUNTDOWN:
			_tick_countdown(dt)
		GameState.PLAYING:
			_tick_playing(dt)
		GameState.CRASHED:
			_tick_crashed(dt)
		GameState.CONTINUE_OFFER:
			_tick_continue_offer(dt)
		GameState.GAME_OVER:
			_tick_wreck(dt)

	_camera.tick(dt, _session.speed.boost_normalized, _session.speed.speed_normalized, _traffic.camera_ceiling(_camera.position.z))
	_apply_tunnel_lighting(_traffic.tunnel_darkness)
	_update_ambience()
	_texts.tick(dt)
	if _smoke_shots:
		_smoke_state_shots(dt)
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
	if speed.time_scale < 1.0:
		speed.time_scale += dt * GameConfig.RESUME_RAMP # ripartenza dolce dopo il countdown
	_tick_invulnerability(dt)
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

	_traffic.resolve_pigeon(_pigeon, ground_step, traffic_step, speed.approach_speed, _invulnerable > 0.0)
	if _state != GameState.PLAYING:
		return # impatto durante le collisioni

	_session.score.tick(dt, ground_step, speed.multiplier, _pigeon.position.y < GameConfig.LOW_FLY_HEIGHT)


func _tick_ambient(dt: float) -> void:
	var ground_step := TITLE_WORLD_SPEED * dt
	_road.advance(ground_step)
	_traffic.tick(dt, ground_step, ground_step, _session)
	_ambient.tick(dt, TITLE_WORLD_SPEED)


## 3-2-1: il piccione si può già spostare, ma niente punti, niente sganci e niente collisioni.
## A inizio partita il mondo scorre come nel menu, alla ripresa è fermo.
func _tick_countdown(dt: float) -> void:
	if _input_delay <= 0.0 and Input.is_action_just_pressed(Actions.PAUSE):
		_pause()
		return
	_input_delay = maxf(0.0, _input_delay - dt)

	var step := _countdown_world_speed * dt
	_road.advance(step)
	_traffic.tick(dt, step, step, _session)
	_ambient.tick(dt, _countdown_world_speed)

	var input := Input.get_vector(Actions.MOVE_LEFT, Actions.MOVE_RIGHT, Actions.MOVE_DOWN, Actions.MOVE_UP) + _touch.move_vector
	if _smoke_test:
		input = _smoke_input(dt)
	if input.length_squared() > 1.0:
		input = input.normalized()
	var limits := _traffic.get_fly_limits(_pigeon.position.z)
	_pigeon.tick(dt, input, 10.0, limits.x, limits.y)
	_touch.consume_poop() # un tocco durante il countdown non resta in coda
	_update_blink(dt)

	_countdown_left -= dt
	var digit := ceili(_countdown_left)
	if digit != _countdown_digit and digit > 0:
		_countdown_digit = digit
		_screens.show_countdown(str(digit))
		_audio.play_ui(Sfx.COUNTDOWN_BEEP)
	if _countdown_left <= 0.0:
		_begin_play()


## Dopo l'impatto: il mondo rallenta fino a fermarsi, poi pannello "Continue?" o game over.
func _tick_crashed(dt: float) -> void:
	_tick_wreck(dt)
	_crash_delay -= dt
	if _crash_delay > 0.0:
		return
	if _can_offer_continue():
		_show_continue_offer()
	else:
		_finish_run()


func _tick_continue_offer(dt: float) -> void:
	_tick_wreck(dt)
	if _ad_running:
		return # l'anello si ferma mentre gira la pubblicità

	if _smoke_test and _offer_left < GameConfig.CONTINUE_OFFER_TIME - 1.0:
		_on_continue_accepted()
		return

	_offer_left -= dt
	var digit := ceili(maxf(0.0, _offer_left))
	_screens.set_continue_progress(_offer_left / GameConfig.CONTINUE_OFFER_TIME, digit)
	if digit != _offer_digit and digit > 0:
		_offer_digit = digit
		_audio.play_ui(Sfx.UI_CLICK, -4.0, 1.5) # tic dei secondi
	if _offer_left <= 0.0:
		_finish_run()


## Mondo che rallenta e piccione che cade (impatto, offerta, game over).
func _tick_wreck(dt: float) -> void:
	var speed := _session.speed
	speed.time_scale -= dt * 0.9
	var ground_step := speed.pigeon_speed * dt
	var traffic_step := speed.approach_speed * dt

	_road.advance(ground_step)
	_traffic.tick(dt, ground_step, traffic_step, _session)
	_ambient.tick(dt, speed.pigeon_speed)
	_poop.tick(dt, ground_step, traffic_step, _traffic.vehicles)
	_pigeon.tick_crash(dt)


func _tick_invulnerability(dt: float) -> void:
	if _invulnerable <= 0.0:
		return
	_invulnerable -= dt
	_update_blink(dt)


## Lampeggio sempre più rapido verso la fine dell'invulnerabilità.
func _update_blink(dt: float) -> void:
	if _invulnerable <= 0.0:
		_pigeon.set_blink(false)
		return
	_blink_time += dt
	var period := 0.2 if _invulnerable > 0.8 else 0.1
	_pigeon.set_blink(fposmod(_blink_time, period) < period * 0.4)


## Loop d'ambiente: strada e vento crescono con la velocità, la galleria col buio.
func _update_ambience() -> void:
	var speed := _session.speed
	var tunnel := _traffic.tunnel_darkness
	match _state:
		GameState.TITLE:
			_audio.set_ambience(0.3, 0.12, 0.9, tunnel)
		GameState.COUNTDOWN:
			var moving := clampf(_countdown_world_speed / TITLE_WORLD_SPEED, 0.0, 1.0)
			_audio.set_ambience(0.1 + 0.25 * moving, 0.08 + 0.06 * moving, 0.9, tunnel)
		GameState.PLAYING:
			_audio.set_ambience(
				0.55 + 0.35 * speed.speed_normalized,
				0.2 + 0.45 * speed.speed_normalized + 0.35 * speed.boost_normalized,
				0.9 + 0.25 * speed.speed_normalized + 0.12 * speed.boost_normalized,
				tunnel)
		GameState.CRASHED, GameState.CONTINUE_OFFER, GameState.GAME_OVER:
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
	if _smoke_test and _session.elapsed < _smoke_survive_time:
		_smoke_hits += 1 # nella prova automatica si sopravvive a lungo per passare da gallerie e cantieri
		return
	# un colpo e basta: niente vite (al massimo un Continua)
	_session.crash()
	_audio.play(Sfx.CRASH)
	_camera.add_trauma(0.85)
	_feather_burst.global_position = p_position
	_feather_burst.restart()
	if _save.vibration:
		Input.vibrate_handheld(250)
	_state = GameState.CRASHED
	_crash_delay = GameConfig.CRASH_DELAY
	_touch.enabled = false
	_traffic.spawning_enabled = false


func _start_game() -> void:
	if _warmup != null and is_instance_valid(_warmup) and not _warmup.is_done:
		_warmup.finish_now()

	Ads.policy.on_run_started()
	_hud.visible = true
	_start_countdown(TITLE_WORLD_SPEED)


## world_speed: velocità del mondo durante il countdown (quella del menu all'inizio, 0 alla ripresa).
func _start_countdown(world_speed: float) -> void:
	_state = GameState.COUNTDOWN
	_countdown_left = GameConfig.COUNTDOWN_TIME
	_countdown_digit = 0
	_countdown_world_speed = world_speed
	_input_delay = 0.25 # evita che lo Spazio del menu metta subito in pausa o sganci
	_screens.hide_all()
	_touch.enabled = true
	_traffic.spawning_enabled = false


func _begin_play() -> void:
	_state = GameState.PLAYING
	_screens.show_countdown("GO!")
	_audio.play_ui(Sfx.COUNTDOWN_GO)
	# riparte alla velocità del countdown e accelera fino a quella piena (vedi RESUME_RAMP)
	var speed := _session.speed
	speed.time_scale = _countdown_world_speed / maxf(1.0, speed.base_speed * speed.multiplier)
	_traffic.spawning_enabled = true


func _pause() -> void:
	if _state != GameState.PLAYING and _state != GameState.COUNTDOWN:
		return
	_state_before_pause = _state
	_state = GameState.PAUSED
	_touch.enabled = false
	_audio.play_ui(Sfx.UI_CLICK)
	get_tree().paused = true
	_screens.show_pause()


func _resume() -> void:
	if _state != GameState.PAUSED:
		return
	get_tree().paused = false
	_state = _state_before_pause
	_input_delay = 0.25
	_screens.hide_all()
	_touch.enabled = true
	if _state == GameState.COUNTDOWN and _countdown_digit > 0:
		_screens.show_countdown(str(_countdown_digit))


func _restart() -> void:
	get_tree().paused = false
	_skip_title_on_load = true
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ Continua e fine partita

func _can_offer_continue() -> bool:
	if _continues_used >= GameConfig.CONTINUES_PER_RUN:
		return false
	var ads := Ads.service
	return ads != null and ads.is_inside_tree() and ads.is_rewarded_ready()


func _show_continue_offer() -> void:
	_state = GameState.CONTINUE_OFFER
	_offer_left = GameConfig.CONTINUE_OFFER_TIME
	_offer_digit = ceili(GameConfig.CONTINUE_OFFER_TIME)
	_ad_running = false
	_screens.show_continue(_session.score.score)


func _on_continue_accepted() -> void:
	if _state != GameState.CONTINUE_OFFER or _ad_running:
		return
	_ad_running = true
	_screens.set_continue_waiting(true)
	Ads.service.show_rewarded(_on_rewarded_done)


func _on_rewarded_done(rewarded: bool) -> void:
	_ad_running = false
	if _state != GameState.CONTINUE_OFFER:
		return
	if rewarded:
		Ads.policy.on_rewarded_shown(InterstitialPolicy.now_seconds())
		_revive()
	else:
		# pubblicità saltata: niente premio, l'offerta riprende da dove era
		_screens.set_continue_waiting(false)


func _on_continue_declined() -> void:
	if _state == GameState.CONTINUE_OFFER and not _ad_running:
		_finish_run()


## Si riparte da fermo con la strada libera davanti, punteggio e distanza conservati.
func _revive() -> void:
	_continues_used += 1
	_session.revive()
	_traffic.clear_ahead(GameConfig.REVIVE_CLEAR_DISTANCE)
	_pigeon.revive()
	_camera.snap()
	_invulnerable = GameConfig.REVIVE_INVULNERABILITY
	_blink_time = 0.0
	_start_countdown(0.0)


func _finish_run() -> void:
	_state = GameState.GAME_OVER
	_touch.enabled = false
	var score := _session.score
	var new_record := _save.record_run(score.score, int(score.distance))
	if not _smoke_test:
		_save.save() # la prova automatica non tocca il record vero
	Ads.policy.on_run_finished()
	_hud.set_best(_save.best_score)
	_screens.show_game_over(_session, _save.best_score, new_record)
	_audio.play_ui(Sfx.GAME_OVER)
	if _smoke_test:
		_smoke_finish_run()


## "Try again": qui, ogni tanto, la pubblicità a schermo intero (vedi InterstitialPolicy).
func _on_retry_pressed() -> void:
	if _state != GameState.GAME_OVER:
		return
	_screens.hide_all()
	var now := InterstitialPolicy.now_seconds()
	var ads := Ads.service
	if ads != null and ads.is_inside_tree() and Ads.policy.should_show_interstitial(now):
		Ads.policy.on_interstitial_shown(now)
		ads.show_interstitial(_restart)
	else:
		_restart()


# ------------------------------------------------------------------ prova automatica

## Volo pseudo-casuale per la prova senza interfaccia: copre corsie, quote, cantieri e gallerie.
func _smoke_input(dt: float) -> Vector2:
	_smoke_time += dt
	if _smoke_shots and _smoke_time >= _next_shot:
		# con --shots salva una schermata ogni 6 s (serve un driver video, non --headless)
		get_viewport().get_texture().get_image().save_png("user://smoke_%03d.png" % int(_next_shot))
		_next_shot += 6.0
	return Vector2(sin(_smoke_time * 0.9) + 0.3 * sin(_smoke_time * 2.3), sin(_smoke_time * 0.6) * 0.8)


## Con --shots: una schermata per ogni stato (countdown, offerta, pubblicità finta, game over).
func _smoke_state_shots(dt: float) -> void:
	var key: String = GameState.keys()[_state]
	if _state == GameState.CONTINUE_OFFER and _ad_running:
		key = "AD"
	if key != _shot_key:
		_shot_key = key
		_shot_key_time = 0.0
	_shot_key_time += dt
	if _shot_key_time < 0.4 or _shots_taken.has(key):
		return
	_shots_taken[key] = true
	get_viewport().get_texture().get_image().save_png("user://smoke_state_%s.png" % key.to_lower())


func _smoke_finish_run() -> void:
	_smoke_runs += 1
	var score := _session.score
	print("[Smoke] partita %d: %.0f s, %d m, %d punti, %d mezzi centrati, %d passaggi a filo, %d impatti ignorati, %d continua, %d mezzi attivi" % [
		_smoke_runs, _session.elapsed, int(score.distance), score.score, score.hits, score.near_misses, _smoke_hits,
		_continues_used, _traffic.vehicles.size()])
	var expected_continues := 0 if OS.get_cmdline_user_args().has("--no-ads") else GameConfig.CONTINUES_PER_RUN
	if _continues_used != expected_continues:
		_smoke_errors.append("partita %d: Continua usati %d invece di %d" % [_smoke_runs, _continues_used, expected_continues])
	if _smoke_runs < 2:
		_on_retry_pressed.call_deferred()
		return
	if _smoke_errors.is_empty():
		print("[Smoke] OK")
		get_tree().quit()
	else:
		for error in _smoke_errors:
			printerr("[Smoke] ERRORE: ", error)
		get_tree().quit(1)


## Controlli senza grafica: regole della pubblicità a schermo intero e salvataggio JSON.
func _smoke_self_checks() -> void:
	_smoke_errors.append_array(InterstitialPolicy.self_check())

	var data := SaveData.new()
	data.best_score = 12345
	data.best_distance = 6789
	data.runs_played = 42
	data.sfx_volume = 0.5
	data.vibration = false
	var parsed: Variant = JSON.parse_string(JSON.stringify(data.to_dict()))
	if not parsed is Dictionary:
		_smoke_errors.append("salvataggio: JSON non valido")
		return
	var copy := SaveData.from_dict(parsed as Dictionary)
	if copy.best_score != 12345 or copy.best_distance != 6789 or copy.runs_played != 42 \
			or not is_equal_approx(copy.sfx_volume, 0.5) or copy.vibration:
		_smoke_errors.append("salvataggio: dati diversi dopo l'andata e ritorno")
	if SaveData.from_dict({ "best_score": "x", "settings": 3 }).best_score != 0:
		_smoke_errors.append("salvataggio: valori non validi accettati")
	print("[Smoke] controlli di pubblicità e salvataggio: %s" % ("ok" if _smoke_errors.is_empty() else "%d errori" % _smoke_errors.size()))
