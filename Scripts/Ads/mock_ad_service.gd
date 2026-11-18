class_name MockAdService
extends AdService
## Pubblicità finta: un riquadro a schermo intero di AD_DURATION secondi, con l'audio del gioco spento.
## Quella a premio si può saltare (niente premio), quella a schermo intero si chiude da sola.
## Avvio con "-- --no-ads" per simulare la mancanza di pubblicità (niente pannello "Continue?").

const AD_DURATION := 2.0
const INTERSTITIAL_CLOSE_AFTER := 1.0

enum AdKind { NONE, REWARDED, INTERSTITIAL }

var _kind: AdKind = AdKind.NONE
var _elapsed: float = 0.0
var _on_done: Callable
var _no_fill: bool = false

var _layer: CanvasLayer
var _title: Label
var _timer_label: Label
var _bar: ProgressBar
var _close: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_no_fill = OS.get_cmdline_user_args().has("--no-ads")
	_build_overlay()


func is_rewarded_ready() -> bool:
	return not _no_fill and _kind == AdKind.NONE


func show_rewarded(on_done: Callable) -> void:
	if not is_rewarded_ready():
		on_done.call(false)
		return
	_open(AdKind.REWARDED, on_done, "Rewarded ad (test)", "SKIP")


func show_interstitial(on_done: Callable) -> void:
	if _no_fill or _kind != AdKind.NONE:
		on_done.call()
		return
	_open(AdKind.INTERSTITIAL, on_done, "Interstitial ad (test)", "CLOSE")


func _process(delta: float) -> void:
	if _kind == AdKind.NONE:
		return
	_elapsed += delta
	_bar.value = minf(_elapsed / AD_DURATION, 1.0) * 100.0
	_timer_label.text = "%d" % ceili(maxf(0.0, AD_DURATION - _elapsed))
	if _kind == AdKind.INTERSTITIAL:
		_close.visible = _elapsed >= INTERSTITIAL_CLOSE_AFTER
	if _elapsed >= AD_DURATION:
		_finish(true)


func _open(kind: AdKind, on_done: Callable, title: String, close_text: String) -> void:
	_kind = kind
	_elapsed = 0.0
	_on_done = on_done
	_title.text = title
	_close.text = close_text
	_close.visible = kind == AdKind.REWARDED
	_bar.value = 0.0
	_timer_label.text = "%d" % ceili(AD_DURATION)
	_layer.visible = true
	# come un vero SDK: il gioco tace mentre gira la pubblicità
	AudioServer.set_bus_mute(0, true)


## completed: la pubblicità è arrivata alla fine (per quella a premio vale come premio).
func _finish(completed: bool) -> void:
	var kind := _kind
	var callback := _on_done
	_kind = AdKind.NONE
	_on_done = Callable()
	_layer.visible = false
	AudioServer.set_bus_mute(0, false)
	if not callback.is_valid():
		return
	if kind == AdKind.REWARDED:
		callback.call(completed)
	else:
		callback.call()


func _on_close_pressed() -> void:
	if _kind == AdKind.NONE:
		return
	# saltare quella a premio = niente premio; chiudere quella a schermo intero è sempre permesso
	_finish(_kind == AdKind.INTERSTITIAL)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.visible = false
	add_child(_layer)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP # niente tocchi al gioco sotto
	_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.97)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	box.add_child(UiStyle.make_label("ADVERTISEMENT", 30, Color(1.0, 1.0, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	_title = UiStyle.make_label("", 52, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_timer_label = UiStyle.make_label("", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_timer_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(520.0, 18.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", UiStyle.flat(Color(1.0, 1.0, 1.0, 0.15), 9, 0.0))
	_bar.add_theme_stylebox_override("fill", UiStyle.flat(UiStyle.ACCENT, 9, 0.0))
	box.add_child(_bar)

	# pulsante in alto a destra, come negli SDK veri
	_close = UiStyle.make_button("SKIP", 26)
	_close.custom_minimum_size = Vector2(170.0, 64.0)
	_close.pressed.connect(_on_close_pressed)
	root.add_child(_close)
	_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_close.offset_left = -24.0 - _close.custom_minimum_size.x
	_close.offset_right = -24.0
	_close.offset_top = 24.0
	_close.offset_bottom = 24.0 + _close.custom_minimum_size.y
