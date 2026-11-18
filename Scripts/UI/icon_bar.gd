class_name IconBar
extends Control
## Barra di icone disegnate (munizioni, segmenti boost): nessuna texture necessaria.

enum IconShape { CIRCLE, POOP, SEGMENT }

var max_value: int = 3
var shape: IconShape = IconShape.CIRCLE
var on_color: Color = Color.WHITE
var off_color: Color = Color(1.0, 1.0, 1.0, 0.2)
var icon_size: float = 26.0
var gap: float = 6.0

var _value: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(max_value * (icon_size + gap) - gap, icon_size)


func set_value(value: int) -> void:
	if value == _value:
		return
	_value = value
	queue_redraw()


func _draw() -> void:
	for i in max_value:
		var color := on_color if i < _value else off_color
		var left := i * (icon_size + gap)
		var center := Vector2(left + icon_size * 0.5, icon_size * 0.5)
		match shape:
			IconShape.CIRCLE:
				draw_circle(center, icon_size * 0.42, color)
			IconShape.SEGMENT:
				draw_rect(Rect2(left, icon_size * 0.3, icon_size, icon_size * 0.4), color)
			IconShape.POOP:
				# tre "gocce" impilate, con contorno scuro per leggibilità su qualsiasi sfondo
				var s := icon_size
				var outline := Color(0.0, 0.0, 0.0, color.a * 0.6)
				draw_circle(center + Vector2(0.0, 0.2 * s), 0.4 * s, outline)
				draw_circle(center + Vector2(0.0, 0.2 * s), 0.34 * s, color)
				draw_circle(center + Vector2(0.0, -0.04 * s), 0.29 * s, outline)
				draw_circle(center + Vector2(0.0, -0.04 * s), 0.24 * s, color)
				draw_circle(center + Vector2(0.02 * s, -0.25 * s), 0.18 * s, outline)
				draw_circle(center + Vector2(0.02 * s, -0.25 * s), 0.13 * s, color)
