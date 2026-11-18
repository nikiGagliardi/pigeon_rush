class_name Palette
extends RefCounted
## Colori e materiali condivisi. I mesh low-poly usano vertex color: 1 materiale = meno draw call.

# Strada
const ASPHALT := Color("45484e")
const ASPHALT_DARK := Color("3a3d42")
const LINE_WHITE := Color("eeeeee")
const CONCRETE := Color("c9c6bd")
const CONCRETE_DARK := Color("9e9a90")
const METAL := Color("a9b0b8")
const GRASS := Color("6e9b4a")
const LAMP := Color("fff2c4")

# Natura
const TREE_DARK := Color("3f6b3a")
const TREE_MID := Color("4d7d40")
const TREE_LIGHT := Color("6a9a4c")
const TRUNK := Color("6b4a2f")
const ROCK := Color("8d8a84")
const MOUNTAIN := Color("7f92a8") # già "velate" di azzurro: sono lontane
const MOUNTAIN_LIGHT := Color("8fa1b6")
const SNOW := Color("f4f7fb")

# Veicoli
const GLASS := Color("2b3d52")
const TIRE := Color("1e1e1e")
const TRIM := Color("2f3640")
const HEADLIGHT := Color("fff6d5")
const TAILLIGHT := Color("ff2a2a")
const INDICATOR := Color("ffe600") # giallo: si distingue dai fari bianchi
const DESTINATION_DISPLAY := Color("ffb020")
const CHROME := Color("c8d0d8")
const SEAT := Color("5a1f1f")

# Gallerie
const TUNNEL_WALL := Color("b9b5aa")
const TUNNEL_TILE := Color("dcd8cc")
const TUNNEL_CEILING := Color("5f5f5f")
const TUNNEL_LAMP := Color("ffe3a6")
const SOS_GREEN := Color("22c55e")
const AMBER := Color("ffb020")
const SIGN_BLUE := Color("1f4e9c")

# Cantiere
const WORKS_YELLOW := Color("f2c300")
const WORKS_ORANGE := Color("ff6a00")
const WORKS_RED := Color("d62828")
const MILLED_ASPHALT := Color("2f3134")
const MACHINE_YELLOW := Color("f2b705")
const PANEL_BLACK := Color("1a1a1a")

# Segnaletica svizzera (autostrada = verde)
const SIGN_GREEN := Color("00843d")
const SIGN_WHITE := Color("ffffff")

# Piccione
const PIGEON_BODY := Color("7d8796")
const PIGEON_HEAD := Color("8a94a3")
const PIGEON_NECK := Color("4f7a6a")
const PIGEON_NECK_PURPLE := Color("6b4f7a")
const PIGEON_WING := Color("8f99a8")
const PIGEON_WING_BAR := Color("3e4552")
const PIGEON_TAIL := Color("4a5260")
const PIGEON_BELLY := Color("8e98a6")
const PIGEON_CHEST := Color("8a8798")
const PIGEON_RUMP := Color("a7b0bc")
const PIGEON_SECONDARY := Color("7f8998")
const PIGEON_PRIMARY_DARK := Color("3e4552")
const PIGEON_PRIMARY_MID := Color("58616e")
const PIGEON_PRIMARY_LIGHT := Color("707a88")
const PIGEON_TAIL_BAND := Color("2f343d")
const BEAK := Color("4a4343")
const BEAK_TIP := Color("2e2a2a")
const CERE := Color("e8e4dc")
const EYE_RING := Color("c9a39b")
const EYE := Color("ff8c1a")
const PUPIL := Color("111111")
const FOOT := Color("e07a7a")

# Gameplay
const POOP := Color("f3f1e8")
const POOP_SHADE := Color("cfc9b6")
const RETICLE := Color("ffd400")
const CRUMB := Color("e1b866")
const CRUMB_DARK := Color("c8963e")
const GOLDEN_CRUMB := Color("ffc61a")
const GOLDEN_CRUMB_LIGHT := Color("fff1a8")
const GOLD := Color("ffd54a")
const DANGER := Color("ff5a4f")
const INFO := Color("7fe3ff")

static var _lit: StandardMaterial3D
static var _unlit: StandardMaterial3D
static var _shadow_blob: StandardMaterial3D


## Materiale illuminato con vertex color (flat shading arriva dalle normali per faccia).
static func lit() -> StandardMaterial3D:
	if _lit == null:
		_lit = StandardMaterial3D.new()
		_lit.vertex_color_use_as_albedo = true
		_lit.vertex_color_is_srgb = true
		_lit.roughness = 0.9
	return _lit


## Materiale non illuminato: fari, lampioni, mirino.
static func unlit() -> StandardMaterial3D:
	if _unlit == null:
		_unlit = StandardMaterial3D.new()
		_unlit.vertex_color_use_as_albedo = true
		_unlit.vertex_color_is_srgb = true
		_unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _unlit


static func shadow_blob() -> StandardMaterial3D:
	if _shadow_blob == null:
		_shadow_blob = StandardMaterial3D.new()
		_shadow_blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_blob.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_blob.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	return _shadow_blob

