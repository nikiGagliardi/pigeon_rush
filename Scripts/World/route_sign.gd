class_name RouteSign
extends Node3D
## Cartello verde a bordo strada all'ingresso di una tratta: "WELCOME TO / TICINO / Bellinzona → Biasca".
## Solo scenografia (nessuna hitbox): sta oltre il guardrail esterno, fuori dall'area di volo.
## Compare all'orizzonte e passa accanto al piccione proprio quando parte il banner dell'HUD.

## Al di là del guardrail esterno (-7 m), lontano dall'area di volo (±4.6 m).
const SIGN_X := -10.4
const PANEL_WIDTH := 6.0
const PANEL_HEIGHT := 3.2
const PANEL_CENTER_Y := 4.7
const POST_HEIGHT := 6.3
const TEXT_MARGIN := 0.45
const LABEL_Z := 0.13

static var _mesh: ArrayMesh

var _body: MeshInstance3D
var _header: Label3D
var _title: Label3D
var _footer: Label3D


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh


func _init() -> void:
	_body = MeshInstance3D.new()
	_body.mesh = mesh()
	add_child(_body)
	# stesse dimensioni di carattere delle altre etichette 3D: l'atlante del font è già pronto (AssetWarmup)
	_header = _make_label(64, PANEL_CENTER_Y + 0.95)
	_title = _make_label(96, PANEL_CENTER_Y + 0.05)
	_footer = _make_label(64, PANEL_CENTER_Y - 0.95)


## z: posizione sulla strada (il piccione è a Z = 0). header può essere vuoto.
func activate(header: String, title: String, footer: String, z: float) -> void:
	position = Vector3(SIGN_X, 0.0, z)
	_set_text(_header, header, 0.009)
	_set_text(_title, title, 0.0125)
	_set_text(_footer, footer, 0.0085)
	# senza intestazione il titolo sale un po' per restare centrato
	_title.position.y = PANEL_CENTER_Y + (0.05 if not header.is_empty() else 0.35)


func _make_label(font_size: int, y: float) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.outline_size = 0
	label.modulate = Palette.SIGN_WHITE
	label.position = Vector3(0.0, y, LABEL_Z)
	add_child(label)
	return label


## Testo ridotto se non entra nel pannello (nomi lunghi come "San Bernardino → Roveredo").
static func _set_text(label: Label3D, text: String, pixel_size: float) -> void:
	label.text = text
	label.visible = not text.is_empty()
	if text.is_empty():
		return
	var width_px := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.font_size).x
	var max_width := PANEL_WIDTH - TEXT_MARGIN * 2.0
	label.pixel_size = minf(pixel_size, max_width / maxf(width_px, 1.0))


static func _build() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var post_x := PANEL_WIDTH * 0.5 - 0.7
	for x: float in [-post_x, post_x]:
		b.cylinder(0.12, 0.12, POST_HEIGHT, Vector3(x, POST_HEIGHT * 0.5, -0.12), Palette.METAL, 8)
	# bordo bianco dietro, pannello verde davanti (più spesso verso il piccione: niente z-fighting)
	b.box(Vector3(PANEL_WIDTH + 0.24, PANEL_HEIGHT + 0.24, 0.12), Vector3(0.0, PANEL_CENTER_Y, 0.0), Palette.SIGN_WHITE)
	b.box(Vector3(PANEL_WIDTH, PANEL_HEIGHT, 0.12), Vector3(0.0, PANEL_CENTER_Y, 0.05), Palette.SIGN_GREEN)
	# piccolo plinto di cemento ai piedi dei pali
	for x: float in [-post_x, post_x]:
		b.box(Vector3(0.5, 0.3, 0.5), Vector3(x, 0.15, -0.12), Palette.CONCRETE_DARK)
	return b.build()
