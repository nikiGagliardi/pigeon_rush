class_name Hud
extends Control
## HUD costruito da codice. Legge lo stato della sessione ogni frame e aggiorna i testi solo se cambiano.

signal pause_pressed

const FONT_COLOR := &"font_color"

var _score: Label
var _distance: Label
var _best: Label
var _combo: Label
var _speed: Label
var _lock: Label
var _low_fly: Label
var _ammo_count: Label
var _ammo: IconBar
var _boost: IconBar
var _ammo_panel: PanelContainer

var _last_score: int = -1
var _last_distance: int = -1
var _last_combo: int = -1
var _last_boost: int = -1
var _last_ammo: int = -1
var _combo_pop: float = 0.0
var _ammo_pop: float = 0.0
var _empty_blink: float = 0.0
var _ammo_text_color: Color = Color.WHITE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- in alto a sinistra: punteggio ---
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 0)
	_score = UiStyle.make_label("0", 48, Color.WHITE)
	_distance = UiStyle.make_label("0 m", 24, Color(1.0, 1.0, 1.0, 0.9))
	_best = UiStyle.make_label("", 20, Palette.GOLD)
	left.add_child(_score)
	left.add_child(_distance)
	left.add_child(_best)
	add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 22)

	# --- in alto a destra: pausa e boost ---
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)

	var pause := Button.new()
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.custom_minimum_size = Vector2(64.0, 56.0)
	pause.add_theme_font_size_override("font_size", 26)
	pause.add_theme_stylebox_override("normal", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.35), 12))
	pause.add_theme_stylebox_override("hover", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.5), 12))
	pause.add_theme_stylebox_override("pressed", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.6), 12))
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	var pause_row := HBoxContainer.new()
	pause_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_row.alignment = BoxContainer.ALIGNMENT_END
	pause_row.add_child(pause)
	right.add_child(pause_row)

	var boost_row := HBoxContainer.new()
	boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boost_row.alignment = BoxContainer.ALIGNMENT_END
	boost_row.add_theme_constant_override("separation", 10)
	boost_row.add_child(UiStyle.make_label("BOOST", 18, Color(1.0, 1.0, 1.0, 0.8)))
	_boost = IconBar.new()
	_boost.max_value = GameConfig.MAX_BOOST_STACKS
	_boost.shape = IconBar.IconShape.SEGMENT
	_boost.on_color = Palette.INFO
	_boost.icon_size = 30.0
	_boost.gap = 4.0
	boost_row.add_child(_boost)
	right.add_child(boost_row)

	_speed = UiStyle.make_label("", 20, Palette.INFO, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_speed)

	add_child(right)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 22)

	# --- centro in alto: combo ---
	_combo = UiStyle.make_label("", 44, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_combo)
	_combo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_combo.pivot_offset = Vector2(0.0, 30.0)

	# --- centro in basso: suggerimenti + pannello munizioni ---
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)
	_lock = UiStyle.make_label("TARGET LOCKED! Drop now", 30, Palette.RETICLE, HORIZONTAL_ALIGNMENT_CENTER)
	_low_fly = UiStyle.make_label("LOW FLYING  x1.5", 22, Palette.INFO, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_lock)
	bottom.add_child(_low_fly)
	bottom.add_child(_build_ammo_panel())
	add_child(bottom)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_lock.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_low_fly.modulate = Color(1.0, 1.0, 1.0, 0.0)


func set_best(best: int) -> void:
	_best.text = "Best %s" % UiFormat.number(best) if best > 0 else ""


func refresh(dt: float, session: GameSession, locked: bool, low_flying: bool) -> void:
	var score := session.score
	if score.score != _last_score:
		_last_score = score.score
		_score.text = UiFormat.number(_last_score)

	var metres := int(score.distance)
	if metres != _last_distance:
		_last_distance = metres
		_distance.text = "%s m" % UiFormat.number(metres)

	_refresh_ammo(dt, session.ammo)

	var stacks := session.speed.boost_stacks
	_boost.set_value(stacks)
	if stacks != _last_boost:
		_last_boost = stacks
		_speed.text = "SPEED x%s" % UiFormat.multiplier(session.speed.multiplier) if stacks > 0 else ""

	var combo := score.combo
	if combo != _last_combo:
		if combo > _last_combo and combo >= 2:
			_combo_pop = 1.0
		_last_combo = combo
		_combo.text = "COMBO x%d" % score.combo_multiplier if combo >= 2 else ""

	_combo_pop = maxf(0.0, _combo_pop - dt * 4.0)
	var pop_scale := 1.0 + _combo_pop * 0.35
	_combo.scale = Vector2(pop_scale, pop_scale)
	var combo_alpha := 0.5 + 0.5 * clampf(score.combo_time_left * 2.0, 0.0, 1.0) if combo >= 2 else 0.0
	_combo.modulate = Color(1.0, 1.0, 1.0, combo_alpha)

	_fade_to(_lock, 1.0 if locked and session.ammo > 0 else 0.0, dt)
	_fade_to(_low_fly, 1.0 if low_flying else 0.0, dt)


## Pannello ben visibile con le cacche disponibili: icone + "6/10".
func _build_ammo_panel() -> Control:
	_ammo_panel = PanelContainer.new()
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.0, 0.0, 0.0, 0.45), 16, 10.0))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiStyle.make_label("POOP", 22, Color(1.0, 1.0, 1.0, 0.85)))
	_ammo = IconBar.new()
	_ammo.max_value = GameConfig.MAX_AMMO
	_ammo.shape = IconBar.IconShape.POOP
	_ammo.on_color = Palette.POOP
	_ammo.off_color = Color(1.0, 1.0, 1.0, 0.15)
	_ammo.icon_size = 30.0
	_ammo.gap = 4.0
	row.add_child(_ammo)
	_ammo_count = UiStyle.make_label("", 30, Color.WHITE)
	_ammo_count.custom_minimum_size = Vector2(78.0, 0.0)
	row.add_child(_ammo_count)
	_ammo_panel.add_child(row)

	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_ammo_panel)
	return holder


func _refresh_ammo(dt: float, ammo: int) -> void:
	if ammo != _last_ammo:
		if ammo > _last_ammo and _last_ammo >= 0:
			_ammo_pop = 1.0 # ricarica dalle briciole
		_last_ammo = ammo
		_ammo.set_value(ammo)
		_ammo_count.text = "%d/%d" % [ammo, GameConfig.MAX_AMMO]

	_ammo_pop = maxf(0.0, _ammo_pop - dt * 3.0)

	if ammo == 0:
		# vuoto: lampeggia in rosso
		_empty_blink += dt
		var on := fposmod(_empty_blink, 0.5) < 0.25
		_set_ammo_text_color(Palette.DANGER if on else Color.WHITE)
		_ammo_panel.modulate = Color(1.0, 0.6 if on else 1.0, 0.6 if on else 1.0)
	else:
		_empty_blink = 0.0
		_set_ammo_text_color(Palette.CRUMB if _ammo_pop > 0.0 else Color.WHITE)
		var glow := 1.0 + _ammo_pop * 0.4
		var tint := Color(glow, glow, glow)
		if _ammo_panel.modulate != tint:
			_ammo_panel.modulate = tint


## Cambia il colore solo se serve: ogni override del tema forza un nuovo layout del testo.
func _set_ammo_text_color(color: Color) -> void:
	if color == _ammo_text_color:
		return
	_ammo_text_color = color
	_ammo_count.add_theme_color_override(FONT_COLOR, color)


static func _fade_to(control: Control, alpha: float, dt: float) -> void:
	var current := control.modulate.a
	var next := move_toward(current, alpha, dt * 6.0)
	if not is_equal_approx(current, next):
		control.modulate = Color(1.0, 1.0, 1.0, next)
