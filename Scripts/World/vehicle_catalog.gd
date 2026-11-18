class_name VehicleCatalog
extends RefCounted
## Tipi di mezzo e loro caratteristiche.

enum Kind { CAR, VAN, TRUCK, BUS, CABRIO, CLEAN_CAR }


class Spec:
	## Lunghezza lungo Z.
	var length: float
	## Larghezza lungo X.
	var width: float
	## Altezza dell'hitbox.
	var height: float
	## Base della zona bersaglio per la cacca.
	var target_bottom: float
	## Cima della zona bersaglio (tetto o abitacolo).
	var target_top: float
	## Punti base del colpo (moltiplicati dalla combo).
	var points: int
	## Stack di boost assegnati.
	var boost: int
	## Testo extra mostrato al colpo (vuoto = nessuno).
	var hit_label: String
	## Se occupa anche la fascia media (furgoni, camion, bus).
	var blocks_mid: bool
	## Distanza laterale dei fari dal centro.
	var headlight_x: float
	## Altezza dei fari.
	var headlight_y: float

	func _init(p_length: float, p_width: float, p_height: float, p_target_bottom: float, p_target_top: float,
			p_points: int, p_boost: int, p_hit_label: String, p_blocks_mid: bool, p_headlight_x: float, p_headlight_y: float) -> void:
		length = p_length
		width = p_width
		height = p_height
		target_bottom = p_target_bottom
		target_top = p_target_top
		points = p_points
		boost = p_boost
		hit_label = p_hit_label
		blocks_mid = p_blocks_mid
		headlight_x = p_headlight_x
		headlight_y = p_headlight_y


static var CAR := Spec.new(4.3, 1.85, 1.48, 0.95, 1.48, 100, 1, "", false, 0.62, 0.72)
static var VAN := Spec.new(5.2, 2.0, 2.3, 1.7, 2.3, 120, 1, "", true, 0.66, 0.92)
static var TRUCK := Spec.new(13.0, 2.5, 4.0, 3.2, 4.0, 150, 1, "Truck splatted!", true, 0.85, 1.0)
static var BUS := Spec.new(12.0, 2.55, 3.55, 2.9, 3.55, 140, 1, "Bus splatted!", true, 0.9, 0.78)
static var CABRIO := Spec.new(4.4, 1.85, 1.2, 0.6, 1.35, 300, 2, "Right in the convertible!", false, 0.62, 0.72)
static var CLEAN_CAR := Spec.new(4.3, 1.85, 1.48, 0.95, 1.48, 250, 2, "Freshly washed!", false, 0.62, 0.72)


static func get_spec(kind: Kind) -> Spec:
	match kind:
		Kind.VAN:
			return VAN
		Kind.TRUCK:
			return TRUCK
		Kind.BUS:
			return BUS
		Kind.CABRIO:
			return CABRIO
		Kind.CLEAN_CAR:
			return CLEAN_CAR
		_:
			return CAR
