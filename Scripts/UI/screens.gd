class_name Screens
extends Control
## Schermate a tutto schermo: titolo, pausa, game over. Gira anche col gioco in pausa.

signal start_pressed
signal resume_pressed
signal restart_pressed

var _title: Control
var _pause: Control
var _game_over: Control
var _play_button: Button
var _resume_button: Button
var _retry_button: Button
var _title_best: Label
var _over_score: Label
var _over_stats: Label
var _over_record: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_title()
	_build_pause()
	_build_game_over()
	hide_all()


func show_title(best: int) -> void:
	hide_all()
	_title_best.text = "Best: %s" % UiFormat.number(best) if best > 0 else ""
	_title.visible = true
	_play_button.grab_focus()


func show_pause() -> void:
	hide_all()
	_pause.visible = true
	_resume_button.grab_focus()


func show_game_over(session: GameSession, best: int, new_record: bool) -> void:
	hide_all()
	var score := session.score
	_over_score.text = UiFormat.number(score.score)
	_over_stats.text = "%s m flown\n%d vehicles splatted  •  best combo x%d\n%d close calls" % [
		UiFormat.number(int(score.distance)), score.hits,
		mini(score.best_combo, GameConfig.MAX_COMBO_MULTIPLIER), score.near_misses]
	_over_record.text = "NEW BEST!" if new_record else "Best: %s" % UiFormat.number(best)
	_over_record.add_theme_color_override("font_color", Palette.GOLD if new_record else Color(1.0, 1.0, 1.0, 0.8))
	_game_over.visible = true
	_retry_button.grab_focus()


func hide_all() -> void:
	_title.visible = false
	_pause.visible = false
	_game_over.visible = false
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _pause.visible and event.is_action_pressed(Actions.PAUSE):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()


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
	box.add_child(UiStyle.make_label("SQUASHED!", 64, Palette.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	_over_score = UiStyle.make_label("0", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_score)
	_over_record = UiStyle.make_label("", 28, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_record)
	_over_stats = UiStyle.make_label("", 22, Color(1.0, 1.0, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_stats)
	box.add_child(_spacer(8.0))

	_retry_button = UiStyle.make_button("TRY AGAIN")
	_retry_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(_centered(_retry_button))


## Sfondo scuro + pannello centrato che contiene box.
func _make_overlay(dim: float, box: VBoxContainer) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

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
