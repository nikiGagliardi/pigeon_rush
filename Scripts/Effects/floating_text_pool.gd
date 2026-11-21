class_name FloatingTextPool
extends Node3D
## Testi 3D (+punti, "Close call!", ecc.) che compaiono con un piccolo scatto e scivolano in basso, verso la
## camera, come se restassero sulla strada già passata: sotto il piccione, mai davanti a dove si guarda.


class Entry:
	var label: Label3D
	var color: Color = Color.WHITE
	var age: float = 0.0
	var size: float = 0.008
	var life: float = 1.0
	var active: bool = false


const POOL_SIZE := 12
## Metri al secondo: verso il basso e verso la camera (+Z), cioè in basso sullo schermo.
const DRIFT := Vector3(0.0, -1.1, 4.0)
## Lo scatto iniziale: parte al 70% della grandezza e arriva al 100% in questo tempo.
const POP_TIME := 0.12

var _entries: Array[Entry] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 64
		label.outline_size = 14
		label.pixel_size = 0.008
		label.visible = false
		add_child(label)
		var entry := Entry.new()
		entry.label = label
		_entries.append(entry)


func spawn(text: String, color: Color, p_position: Vector3, scale_factor: float = 1.0, life: float = 0.75) -> void:
	var entry := _get_free()
	entry.active = true
	entry.age = 0.0
	entry.life = life
	entry.color = color
	entry.size = 0.008 * scale_factor

	var label := entry.label
	label.text = text
	label.pixel_size = entry.size * 0.7
	label.position = p_position
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.visible = true


func tick(dt: float) -> void:
	for entry: Entry in _entries:
		if not entry.active:
			continue
		entry.age += dt
		var t := entry.age / entry.life
		if t >= 1.0:
			entry.active = false
			entry.label.visible = false
			continue
		var label := entry.label
		label.position += DRIFT * dt
		label.pixel_size = entry.size * (0.7 + 0.3 * minf(entry.age / POP_TIME, 1.0))
		var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		label.modulate = Color(entry.color, alpha)
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85 * alpha)


func _get_free() -> Entry:
	var oldest: Entry = null
	for entry: Entry in _entries:
		if not entry.active:
			return entry
		if oldest == null or entry.age > oldest.age:
			oldest = entry
	return oldest
