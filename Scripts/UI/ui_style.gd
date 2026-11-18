class_name UiStyle
extends RefCounted
## Helper per creare controlli con stile coerente (tutto da codice, nessun .tres).

const PANEL_BG := Color(0.07, 0.09, 0.14, 0.9)
const ACCENT := Color("ffd54a")
const ACCENT_DARK := Color("e0a800")
const TEXT_DARK := Color("1d1d1d")


static func make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", maxi(4, int(font_size / 6.0)))
	return label


static func make_button(text: String, font_size: int = 34) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340.0, 84.0)
	button.pressed.connect(_play_click)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", TEXT_DARK)
	button.add_theme_color_override("font_focus_color", TEXT_DARK)
	button.add_theme_stylebox_override("normal", flat(ACCENT, 18))
	button.add_theme_stylebox_override("hover", flat(ACCENT.lightened(0.15), 18))
	button.add_theme_stylebox_override("pressed", flat(ACCENT_DARK, 18))

	var focus := flat(Color(0.0, 0.0, 0.0, 0.0), 18)
	focus.draw_center = false
	focus.border_color = Color.WHITE
	focus.set_border_width_all(4)
	button.add_theme_stylebox_override("focus", focus)
	return button


static func flat(color: Color, radius: int, margin: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", flat(PANEL_BG, 26, 44.0))
	return panel


static func _play_click() -> void:
	if GameAudio.instance != null:
		GameAudio.instance.play_ui(GameAudio.Sfx.UI_CLICK)
