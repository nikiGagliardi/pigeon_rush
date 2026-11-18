class_name Screens
extends Control
## Schermate a tutto schermo: titolo, pausa, "Continue?", game over e countdown. Gira anche col gioco in pausa.

signal start_pressed
signal daily_pressed
signal resume_pressed
## Ricomincia dalla pausa (partita abbandonata).
signal restart_pressed
## "Try again" dal game over (partita conclusa: qui può arrivare la pubblicità a schermo intero).
signal retry_pressed
signal continue_accepted
signal continue_declined

var _title: Control
var _pause: Control
var _continue: Control
var _game_over: Control
var _countdown: Label
var _play_button: Button
var _resume_button: Button
var _watch_button: Button
var _retry_button: Button
var _title_best: Label
var _title_daily: Label
var _daily_button: Button
var _over_title: Label
var _over_route: Label
var _continue_score: Label
var _continue_ring: CountdownRing
var _over_score: Label
var _over_stats: Label
var _over_record: Label
var _over_world: Label
var _countdown_tween: Tween
var _leaderboard: LeaderboardPanel
var _leaderboard_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_title()
	_build_pause()
	_build_continue()
	_build_game_over()
	_build_countdown()
	_leaderboard = LeaderboardPanel.new()
	add_child(_leaderboard)
	_leaderboard.closed.connect(_on_leaderboard_closed)
	hide_all()


## daily_info: riga sotto il pulsante della sfida giornaliera (tratta di partenza e record del giorno).
func show_title(best: int, daily_info: String) -> void:
	hide_all()
	_title_best.text = "Best: %s" % UiFormat.number(best) if best > 0 else ""
	_title_daily.text = daily_info
	_title.visible = true
	_play_button.grab_focus()


## Dal titolo: classifica mondiale a tutto schermo; "BACK" riporta al titolo.
func show_leaderboard() -> void:
	_title.visible = false
	_leaderboard.open()


func _on_leaderboard_closed() -> void:
	_title.visible = true
	_leaderboard_button.grab_focus()


func show_pause() -> void:
	hide_all()
	_pause.visible = true
	_resume_button.grab_focus()


## best e new_record si riferiscono alla modalità della partita (normale o sfida del giorno).
func show_game_over(session: GameSession, best: int, new_record: bool) -> void:
	hide_all()
	var daily := session.setup.is_daily()
	_over_title.text = "DAILY CHALLENGE" if daily else "SQUASHED!"
	_over_title.add_theme_color_override("font_color", UiStyle.ACCENT if daily else Palette.DANGER)
	_over_route.text = "Reached: %s" % session.route.reached_label()
	var score := session.score
	_over_score.text = UiFormat.number(score.score)
	_over_stats.text = "%s m flown\n%d vehicles splatted  •  best combo x%d\n%d close calls" % [
		UiFormat.number(int(score.distance)), score.hits,
		mini(score.best_combo, GameConfig.MAX_COMBO_MULTIPLIER), score.near_misses]
	if daily:
		_over_record.text = "NEW DAILY BEST!" if new_record else "Today's best: %s" % UiFormat.number(best)
	else:
		_over_record.text = "NEW BEST!" if new_record else "Best: %s" % UiFormat.number(best)
	_over_record.add_theme_color_override("font_color", Palette.GOLD if new_record else Color(1.0, 1.0, 1.0, 0.8))
	set_online_result("")
	_game_over.visible = true
	_retry_button.grab_focus()


## Riga della classifica mondiale nel game over ("WORLD #1,234  •  THIS WEEK #56"). Vuota = nascosta.
func set_online_result(text: String, color: Color = Color(1.0, 1.0, 1.0, 0.75)) -> void:
	_over_world.text = text
	_over_world.visible = not text.is_empty()
	_over_world.add_theme_color_override("font_color", color)


func show_continue(score: int) -> void:
	hide_all()
	_continue_score.text = "%s points so far" % UiFormat.number(score)
	set_continue_progress(1.0, ceili(GameConfig.CONTINUE_OFFER_TIME))
	_watch_button.disabled = false
	_continue.visible = true
	_watch_button.grab_focus()


## left01: tempo rimasto (1 → 0); seconds: numero al centro dell'anello.
func set_continue_progress(left01: float, seconds: int) -> void:
	_continue_ring.progress = left01
	_continue_ring.label = str(seconds)


## Mentre gira la pubblicità il pannello resta sotto, ma non si può premere due volte.
func set_continue_waiting(waiting: bool) -> void:
	_watch_button.disabled = waiting
	if not waiting and _continue.visible:
		_watch_button.grab_focus()


## Numero del countdown con un piccolo "pop". Testo vuoto = nasconde.
func show_countdown(text: String) -> void:
	if _countdown_tween != null:
		_countdown_tween.kill()
	_countdown.text = text
	_countdown.visible = not text.is_empty()
	if text.is_empty():
		return
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2.ONE * 1.6
	_countdown.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_countdown_tween = create_tween()
	_countdown_tween.tween_property(_countdown, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_countdown_tween.tween_property(_countdown, "modulate:a", 0.0, 0.5).set_delay(0.25)


func hide_all() -> void:
	_title.visible = false
	_pause.visible = false
	_continue.visible = false
	_game_over.visible = false
	if _leaderboard != null:
		_leaderboard.visible = false
	show_countdown("")
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _pause.visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
	elif _continue.visible and not _watch_button.disabled and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		continue_declined.emit()


func _build_title() -> void:
	var box := VBoxContainer.new()
	_title = _make_overlay(0.25, box)
	box.add_child(UiStyle.make_label("PIGEON RUSH", 76, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiStyle.make_label("Wrong way down the motorway. Dodge, splat, speed up!", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(10.0))

	_play_button = UiStyle.make_button("PLAY")
	_play_button.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(_centered(_play_button))

	_title_best = UiStyle.make_label("", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title_best)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_daily_button = UiStyle.make_button("DAILY CHALLENGE", 28)
	_daily_button.custom_minimum_size = Vector2(340.0, 64.0)
	_daily_button.pressed.connect(func() -> void: daily_pressed.emit())
	row.add_child(_daily_button)
	_leaderboard_button = UiStyle.make_button("LEADERBOARD", 28)
	_leaderboard_button.custom_minimum_size = Vector2(300.0, 64.0)
	_leaderboard_button.pressed.connect(show_leaderboard)
	row.add_child(_leaderboard_button)
	_title_daily = UiStyle.make_label("", 20, Color(1.0, 1.0, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title_daily)
	box.add_child(_spacer(6.0))

	var help := "Left side: drag to fly  •  Right side: tap to drop" if TouchControls.is_touch_device() \
		else "WASD / arrows: fly  •  Space: drop  •  Esc: pause\nGamepad: left stick  •  A / right trigger"
	box.add_child(UiStyle.make_label(help, 20, Color(1.0, 1.0, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiStyle.make_label("One hit and you're out! Splat vehicles to fly faster, grab crumbs to refill your poop.", 18,
		Color(1.0, 1.0, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER))


func _build_pause() -> void:
	var box := VBoxContainer.new()
	_pause = _make_overlay(0.5, box)
	box.add_child(UiStyle.make_label("PAUSED", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(8.0))

	_resume_button = UiStyle.make_button("RESUME")
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(_centered(_resume_button))

	var restart := UiStyle.make_button("RESTART")
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(_centered(restart))


func _build_game_over() -> void:
	var box := VBoxContainer.new()
	_game_over = _make_overlay(0.45, box)
	_over_title = UiStyle.make_label("SQUASHED!", 64, Palette.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_title)
	_over_score = UiStyle.make_label("0", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_score)
	_over_record = UiStyle.make_label("", 28, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_record)
	_over_world = UiStyle.make_label("", 24, Color(1.0, 1.0, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_world)
	_over_route = UiStyle.make_label("", 26, Palette.INFO, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_route)
	_over_stats = UiStyle.make_label("", 22, Color(1.0, 1.0, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_stats)
	box.add_child(_spacer(8.0))

	_retry_button = UiStyle.make_button("TRY AGAIN")
	_retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	box.add_child(_centered(_retry_button))


func _build_continue() -> void:
	var box := VBoxContainer.new()
	_continue = _make_overlay(0.45, box)
	box.add_child(UiStyle.make_label("CONTINUE?", 64, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_continue_score = UiStyle.make_label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_continue_score)

	_continue_ring = CountdownRing.new()
	_continue_ring.custom_minimum_size = Vector2(150.0, 150.0)
	box.add_child(_centered(_continue_ring))

	_watch_button = UiStyle.make_button("WATCH AD & FLY ON")
	_watch_button.pressed.connect(func() -> void: continue_accepted.emit())
	box.add_child(_centered(_watch_button))

	var decline := UiStyle.make_button("NO THANKS", 26)
	decline.custom_minimum_size = Vector2(260.0, 64.0)
	decline.pressed.connect(func() -> void:
		if not _watch_button.disabled:
			continue_declined.emit())
	box.add_child(_centered(decline))
	box.add_child(UiStyle.make_label("One continue per run", 18, Color(1.0, 1.0, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER))


func _build_countdown() -> void:
	_countdown = UiStyle.make_label("", 150, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_countdown)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Sfondo scuro + pannello centrato che contiene box.
func _make_overlay(dim: float, box: VBoxContainer) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := UiStyle.make_panel()
	center.add_child(panel)

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return root


static func _centered(child: Control) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(child)
	return holder


static func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Anello che si svuota col tempo dell'offerta, con i secondi al centro.
class CountdownRing extends Control:
	const WIDTH := 12.0

	var progress: float = 1.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()

	var label: String = "":
		set(value):
			if value == label:
				return
			label = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - WIDTH
		draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.18), WIDTH, true)
		if progress > 0.0:
			var start := -PI * 0.5
			# rosso negli ultimi istanti
			var color := UiStyle.ACCENT if progress > 0.3 else Palette.DANGER
			draw_arc(center, radius, start, start + TAU * progress, 64, color, WIDTH, true)
		var font := get_theme_default_font()
		var font_size := 64
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
		draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 10, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
