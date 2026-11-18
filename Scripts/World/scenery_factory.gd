class_name SceneryFactory
extends RefCounted
## Cielo, sole, nebbia e fondale statico (prato infinito + montagne ticinesi in lontananza).

const SUN_ENERGY := 1.1
const AMBIENT_ENERGY := 1.0
const FOG_BEGIN := 90.0
const FOG_END := 300.0
const FOG_COLOR := Color("a3bed6")

## Materiale delle montagne lontane: lo usa l'atmosfera (scure di notte, "sparite" nella nebbia).
static var mountain_material: StandardMaterial3D
## Prato infinito del fondale: l'atmosfera ne regola il riflesso (tramonto).
static var grass_material: StandardMaterial3D


static func create_environment() -> WorldEnvironment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3d7fd1")
	sky_material.sky_horizon_color = Color("a9c9e8")
	sky_material.ground_bottom_color = Color("5b7f3c")
	sky_material.ground_horizon_color = Color("a9c98f")
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Nebbia "a profondità": nitido fino a FOG_BEGIN, poi sale fino a coprire tutto a FOG_END
	# (dove nascono i mezzi, così non compaiono dal nulla). In modalità Depth fog_density è l'intensità massima.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = 1.6
	env.fog_density = 1.0
	env.fog_light_color = FOG_COLOR
	env.fog_sky_affect = 0.0 # il cielo resta saturo, non velato

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	return world_env


static func create_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color("fff3dc")
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	return sun


## Elementi lontani e fermi: la camera non avanza mai, quindi sembrano a distanza infinita.
static func create_backdrop() -> Node3D:
	var root := Node3D.new()
	root.name = "Backdrop"

	var plane := PlaneMesh.new()
	plane.size = Vector2(3000.0, 3000.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Palette.GRASS
	grass.roughness = 1.0
	SceneryFactory.grass_material = grass
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = grass
	ground.position = Vector3(0.0, -0.12, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)

	# le montagne stanno oltre la fine della nebbia: la ignorano, e il "velo" è già nei loro colori
	var mountains_mat := StandardMaterial3D.new()
	mountains_mat.vertex_color_use_as_albedo = true
	mountains_mat.vertex_color_is_srgb = true
	mountains_mat.roughness = 1.0
	mountains_mat.disable_fog = true
	# emissione sempre attiva (nera di giorno): l'atmosfera la usa per farle sparire nella nebbia senza cambiare shader
	mountains_mat.emission_enabled = true
	mountains_mat.emission = Color.BLACK
	SceneryFactory.mountain_material = mountains_mat
	var mountains := MeshInstance3D.new()
	mountains.mesh = _build_mountains()
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mountains.material_override = mountains_mat
	root.add_child(mountains)

	return root


static func _build_mountains() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var b := LowPolyBuilder.new()

	# catena sul fondo + due fianchi di valle
	for i in 9:
		_add_peak(b, rng, Vector3(-420.0 + i * 105.0 + rng.randf() * 40.0, 0.0, -430.0 - rng.randf() * 60.0), 1.2)

	for i in 6:
		var z := -180.0 - i * 50.0
		_add_peak(b, rng, Vector3(-170.0 - rng.randf() * 60.0, 0.0, z), 0.9)
		_add_peak(b, rng, Vector3(170.0 + rng.randf() * 60.0, 0.0, z), 0.9)

	return b.build()


static func _add_peak(b: LowPolyBuilder, rng: RandomNumberGenerator, base_position: Vector3, scale: float) -> void:
	var height := (110.0 + rng.randf() * 110.0) * scale
	var radius := (70.0 + rng.randf() * 50.0) * scale
	var color := Palette.MOUNTAIN if rng.randf() < 0.5 else Palette.MOUNTAIN_LIGHT
	var segments := 6 + rng.randi_range(0, 2)
	# Roccia e neve sono due pezzi che si incastrano (tronco di cono + punta) con gli stessi segmenti:
	# condividono il bordo e non si sovrappongono. Un cono di neve infilato nella montagna avrebbe facce
	# quasi coincidenti, e a 400 m di distanza lo z-buffer non le distingue (neve "a metà").
	var cap_height := height * rng.randf_range(0.24, 0.32)
	var rock_height := height - cap_height
	var snow_line_radius := radius * cap_height / height
	b.cylinder(snow_line_radius, radius, rock_height, base_position + Vector3(0.0, rock_height * 0.5, 0.0), color, segments)
	b.cone(snow_line_radius, cap_height, base_position + Vector3(0.0, rock_height, 0.0), Palette.SNOW, segments)
