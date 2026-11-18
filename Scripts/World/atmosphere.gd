class_name Atmosphere
extends Node
## Meteo e ora del giorno: un preset per ogni combinazione (sole, nuvoloso, nebbia, pioggia, neve ×
## giorno, tramonto, notte) e transizioni graduali tra un preset e l'altro.
## Si somma al buio delle gallerie, che spegne sole, cielo e precipitazioni.
## Tutto passa per parametri di materiali e ambiente già esistenti: nessuno shader nuovo durante la partita.

## In galleria la luce ambiente viene dalle lampade (colore fisso), non dal cielo:
## così di notte la galleria è illuminata come di giorno invece di diventare nera.
const TUNNEL_AMBIENT := 0.42
const TUNNEL_LAMP_LIGHT := Color(0.86, 0.76, 0.58)
const TUNNEL_FOG_COLOR := Color(0.22, 0.21, 0.19)
const DRY_ROUGHNESS := 0.9
const WET_ROUGHNESS := 0.72
## Il cielo (e la sua luce ambiente) si aggiorna al massimo ogni tanto durante le transizioni: costa su mobile.
const SKY_UPDATE_INTERVAL := 0.12
## Ampiezza dell'alone del sole nel cielo (gradi), da coperto a sereno.
const SUN_GLOW_MIN := 0.6
const SUN_GLOW_MAX := 30.0


class Preset:
	var sky_top: Color
	var sky_horizon: Color
	var ground_horizon: Color
	var ground_bottom: Color
	var sun_color: Color
	var sun_energy: float
	var sun_rotation: Quaternion
	var shadow_opacity: float = 1.0
	## Alone del sole nel cielo (1 = pieno, 0 = coperto: sole nascosto dalle nuvole).
	var sun_glow: float = 1.0
	var ambient_energy: float
	var fog_color: Color
	var fog_begin: float
	var fog_end: float
	## Montagne lontane: luminosità (notte più scure) e visibilità (0 = sparite nella nebbia).
	var mountain_light: float = 1.0
	var mountain_visibility: float = 1.0
	var wetness: float = 0.0
	## Riflesso speculare di strada e prati: col sole basso davanti va ridotto, se no il fondo diventa bianco.
	var specular: float = 0.5
	var rain: float = 0.0
	var snow: float = 0.0
	var headlights: float = 0.0
	## Lampioni accesi: di notte del tutto, al tramonto appena.
	var street_lights: float = 0.0

	func copy() -> Preset:
		var p := Preset.new()
		p.sky_top = sky_top
		p.sky_horizon = sky_horizon
		p.ground_horizon = ground_horizon
		p.ground_bottom = ground_bottom
		p.sun_color = sun_color
		p.sun_energy = sun_energy
		p.sun_rotation = sun_rotation
		p.shadow_opacity = shadow_opacity
		p.sun_glow = sun_glow
		p.ambient_energy = ambient_energy
		p.fog_color = fog_color
		p.fog_begin = fog_begin
		p.fog_end = fog_end
		p.mountain_light = mountain_light
		p.mountain_visibility = mountain_visibility
		p.wetness = wetness
		p.specular = specular
		p.rain = rain
		p.snow = snow
		p.headlights = headlights
		p.street_lights = street_lights
		return p

	static func blend(a: Preset, b: Preset, t: float) -> Preset:
		var p := Preset.new()
		p.sky_top = a.sky_top.lerp(b.sky_top, t)
		p.sky_horizon = a.sky_horizon.lerp(b.sky_horizon, t)
		p.ground_horizon = a.ground_horizon.lerp(b.ground_horizon, t)
		p.ground_bottom = a.ground_bottom.lerp(b.ground_bottom, t)
		p.sun_color = a.sun_color.lerp(b.sun_color, t)
		p.sun_energy = lerpf(a.sun_energy, b.sun_energy, t)
		p.sun_rotation = a.sun_rotation.slerp(b.sun_rotation, t)
		p.shadow_opacity = lerpf(a.shadow_opacity, b.shadow_opacity, t)
		p.sun_glow = lerpf(a.sun_glow, b.sun_glow, t)
		p.ambient_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
		p.fog_color = a.fog_color.lerp(b.fog_color, t)
		p.fog_begin = lerpf(a.fog_begin, b.fog_begin, t)
		p.fog_end = lerpf(a.fog_end, b.fog_end, t)
		p.mountain_light = lerpf(a.mountain_light, b.mountain_light, t)
		p.mountain_visibility = lerpf(a.mountain_visibility, b.mountain_visibility, t)
		p.wetness = lerpf(a.wetness, b.wetness, t)
		p.specular = lerpf(a.specular, b.specular, t)
		p.rain = lerpf(a.rain, b.rain, t)
		p.snow = lerpf(a.snow, b.snow, t)
		p.headlights = lerpf(a.headlights, b.headlights, t)
		p.street_lights = lerpf(a.street_lights, b.street_lights, t)
		return p


## Condizioni verso cui si sta andando (quelle della tratta attuale).
var conditions: TrackConditions = TrackConditions.make("sun", "day")
## Intensità degli anabbaglianti per il traffico (0..1), già comprensiva delle gallerie.
var headlight_level: float = 0.0
## Intensità della luce dei lampioni (0..1), spenta in galleria.
var street_light_level: float = 0.0

var _environment: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _mountains: StandardMaterial3D
var _precipitation: Precipitation

var _from: Preset
var _to: Preset
var _current: Preset
var _blend: float = 1.0
var _duration: float = 1.0
var _sky_timer: float = 0.0
var _sky_dirty: bool = true
var _last_darkness: float = -1.0


func setup(environment: Environment, sun: DirectionalLight3D, mountains: StandardMaterial3D, precipitation: Precipitation) -> void:
	_environment = environment
	_sky = environment.sky.sky_material as ProceduralSkyMaterial
	_sun = sun
	_mountains = mountains
	_precipitation = precipitation
	_to = preset_for(conditions)
	_from = _to
	_current = _to
	_apply(0.0)


## Transizione graduale verso le condizioni date (in galleria conviene farla breve: non si vede).
func transition_to(target: TrackConditions, duration: float) -> void:
	if target.equals(conditions) and _blend >= 1.0:
		return
	conditions = target
	_from = _current.copy()
	_to = preset_for(target)
	_duration = maxf(duration, 0.01)
	_blend = 0.0


func snap_to(target: TrackConditions) -> void:
	conditions = target
	_to = preset_for(target)
	_from = _to
	_current = _to
	_blend = 1.0
	_sky_dirty = true
	_last_darkness = -1.0


## Ogni frame, con il buio della galleria (0..1).
func update(dt: float, tunnel_darkness: float) -> void:
	var changing := _blend < 1.0
	if changing:
		_blend = minf(1.0, _blend + dt / _duration)
		_current = Preset.blend(_from, _to, smoothstep(0.0, 1.0, _blend))
		_sky_dirty = true
	if not changing and absf(tunnel_darkness - _last_darkness) < 0.005 and not _sky_dirty:
		return
	_sky_timer -= dt
	_apply(tunnel_darkness)


func _apply(darkness: float) -> void:
	_last_darkness = darkness
	var p := _current
	var open_air := 1.0 - darkness

	_sun.light_color = p.sun_color
	_sun.light_energy = p.sun_energy * open_air
	_sun.quaternion = p.sun_rotation
	_sun.shadow_opacity = p.shadow_opacity

	_environment.ambient_light_energy = lerpf(p.ambient_energy, TUNNEL_AMBIENT, darkness)
	_environment.ambient_light_color = TUNNEL_LAMP_LIGHT
	_environment.ambient_light_sky_contribution = 1.0 - darkness
	_environment.fog_light_color = p.fog_color.lerp(TUNNEL_FOG_COLOR, darkness)
	# in galleria la nebbia esterna non c'è: si torna alla profondità normale
	_environment.fog_depth_begin = lerpf(p.fog_begin, SceneryFactory.FOG_BEGIN, darkness)
	_environment.fog_depth_end = lerpf(p.fog_end, SceneryFactory.FOG_END, darkness)

	if _sky_dirty and (_sky_timer <= 0.0 or _blend >= 1.0):
		_sky_dirty = false
		_sky_timer = SKY_UPDATE_INTERVAL
		_sky.sky_top_color = p.sky_top
		_sky.sky_horizon_color = p.sky_horizon
		_sky.ground_horizon_color = p.ground_horizon
		_sky.ground_bottom_color = p.ground_bottom
		_sky.sun_angle_max = lerpf(SUN_GLOW_MIN, SUN_GLOW_MAX, p.sun_glow)

	# montagne fuori dalla nebbia: la parte "sparita" diventa del colore della nebbia (emissione)
	var visible_part := p.mountain_visibility
	var light := p.mountain_light * visible_part
	_mountains.albedo_color = Color(light, light, light)
	_mountains.emission = p.fog_color * (1.0 - visible_part)

	Palette.lit().roughness = lerpf(DRY_ROUGHNESS, WET_ROUGHNESS, p.wetness)
	Palette.lit().metallic_specular = p.specular
	if SceneryFactory.grass_material != null:
		SceneryFactory.grass_material.metallic_specular = p.specular
	_precipitation.set_amounts(p.rain * open_air, p.snow * open_air)
	headlight_level = maxf(p.headlights, darkness)
	street_light_level = p.street_lights * open_air


# ------------------------------------------------------------------ preset

static func preset_for(c: TrackConditions) -> Preset:
	var p := _time_base(c.time_of_day)
	_apply_weather(p, c.weather, _time_brightness(c.time_of_day))
	return p


## Quanto sono chiari i colori del meteo a quell'ora (la nebbia di notte è quasi nera).
static func _time_brightness(time_of_day: String) -> float:
	match time_of_day:
		"sunset":
			return 0.5
		"night":
			return 0.22
	return 1.0


static func _time_base(time_of_day: String) -> Preset:
	var p := Preset.new()
	match time_of_day:
		"sunset":
			p.sky_top = Color("2f4a8c")
			p.sky_horizon = Color("f2a66a")
			p.ground_horizon = Color("3f4768")
			p.ground_bottom = Color("4d5a33")
			p.sun_color = Color("ffae6b")
			p.sun_energy = 0.9
			# sole basso davanti al piccione e di lato: controluce e ombre lunghe, ma non dritto in faccia
			p.sun_rotation = Quaternion.from_euler(Vector3(deg_to_rad(-13.0), deg_to_rad(155.0), 0.0))
			p.specular = 0.12
			p.ambient_energy = 0.7
			# nebbia del colore delle montagne in controluce (blu-viola scuro): dove finisce la strada
			# il prato sfuma nelle montagne, senza la striscia chiara all'orizzonte
			p.fog_color = Color("3f4768")
			p.fog_begin = SceneryFactory.FOG_BEGIN
			p.fog_end = SceneryFactory.FOG_END
			p.mountain_light = 0.85
			p.street_lights = 0.3
		"night":
			p.sky_top = Color("0b1430")
			p.sky_horizon = Color("24345c")
			p.ground_horizon = Color("18222f")
			p.ground_bottom = Color("0c120a")
			p.sun_color = Color("a9bcff") # luna
			p.sun_energy = 0.32
			p.sun_rotation = Quaternion.from_euler(Vector3(deg_to_rad(-60.0), deg_to_rad(-30.0), 0.0))
			p.shadow_opacity = 0.6
			p.sun_glow = 0.12
			p.ambient_energy = 0.5
			p.fog_color = Color("18223a")
			p.fog_begin = 70.0
			p.fog_end = 260.0
			p.mountain_light = 0.45
			p.headlights = 1.0
			p.street_lights = 1.0
		_:
			p.sky_top = Color("3d7fd1")
			p.sky_horizon = Color("a9c9e8")
			p.ground_horizon = Color("a9c98f")
			p.ground_bottom = Color("5b7f3c")
			p.sun_color = Color("fff3dc")
			p.sun_energy = SceneryFactory.SUN_ENERGY
			p.sun_rotation = Quaternion.from_euler(Vector3(deg_to_rad(-55.0), deg_to_rad(-35.0), 0.0))
			p.ambient_energy = SceneryFactory.AMBIENT_ENERGY
			p.fog_color = SceneryFactory.FOG_COLOR
			p.fog_begin = SceneryFactory.FOG_BEGIN
			p.fog_end = SceneryFactory.FOG_END
	return p


## Il meteo sposta il preset dell'ora: cielo e nebbia verso i suoi colori (scuriti di notte), sole più debole.
static func _apply_weather(p: Preset, weather: String, k: float) -> void:
	match weather:
		"cloudy":
			_mix_sky(p, _dim(Color("8f9aa6"), k), _dim(Color("c3c9cf"), k), 0.65)
			p.sun_energy *= 0.45
			p.sun_glow = 0.0
			p.specular = minf(p.specular, 0.25)
			p.shadow_opacity = minf(p.shadow_opacity, 0.45)
			p.ambient_energy *= 0.9
			p.fog_color = p.fog_color.lerp(_dim(Color("b4bcc4"), k), 0.6)
			p.fog_end = minf(p.fog_end, 270.0)
		"fog":
			_mix_sky(p, _dim(Color("b8bec4"), k), _dim(Color("cfd4d8"), k), 0.9)
			p.sun_energy *= 0.25
			p.sun_glow = 0.0
			p.specular = minf(p.specular, 0.2)
			p.shadow_opacity = minf(p.shadow_opacity, 0.25)
			p.fog_color = _dim(Color("cfd4d8"), k)
			p.fog_begin = 12.0
			p.fog_end = 130.0
			p.mountain_visibility = 0.0
			p.headlights = maxf(p.headlights, 0.6)
		"rain":
			_mix_sky(p, _dim(Color("616b78"), k), _dim(Color("8c95a0"), k), 0.85)
			p.sun_energy *= 0.3
			p.sun_glow = 0.0
			# cielo grigio chiaro riflesso dal suolo bagnato = fascia bianca in fondo: riflessi bassi
			p.specular = minf(p.specular, 0.15)
			p.shadow_opacity = minf(p.shadow_opacity, 0.3)
			p.ambient_energy *= 0.65
			p.fog_color = _dim(Color("78818c"), k)
			p.fog_begin = 70.0
			p.fog_end = 270.0
			p.mountain_visibility = 0.35
			p.wetness = 1.0
			p.rain = 1.0
			p.headlights = maxf(p.headlights, 0.6)
		"snow":
			_mix_sky(p, _dim(Color("a9b3bd"), k), _dim(Color("dde3e8"), k), 0.85)
			p.sun_energy *= 0.5
			p.sun_glow = 0.0
			p.specular = minf(p.specular, 0.25)
			p.shadow_opacity = minf(p.shadow_opacity, 0.5)
			p.fog_color = _dim(Color("dde3e8"), k)
			p.fog_begin = 55.0
			p.fog_end = 230.0
			p.mountain_visibility = 0.5
			p.snow = 1.0
			p.headlights = maxf(p.headlights, 0.4)


static func _mix_sky(p: Preset, top: Color, horizon: Color, amount: float) -> void:
	p.sky_top = p.sky_top.lerp(top, amount)
	p.sky_horizon = p.sky_horizon.lerp(horizon, amount)
	p.ground_horizon = p.ground_horizon.lerp(horizon, amount)
	p.ground_bottom = p.ground_bottom.lerp(_dim(top, 0.6), amount)


static func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)
