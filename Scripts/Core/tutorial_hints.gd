class_name TutorialHints
extends RefCounted
## Suggerimenti delle prime partite: ognuno compare una volta sola, nel momento in cui serve
## (il primo mirino, il primo colpo, le munizioni che finiscono...). Quelli già visti sono in SaveData.
## "SHOW TIPS AGAIN" nelle impostazioni li azzera.

const FLY := "fly"
const DROP := "drop"
const BOOST := "boost"
const NEAR_MISS := "near_miss"
const CRUMBS := "crumbs"
const LOW_FLY := "low_fly"

## Secondi di volo prima del suggerimento sul volo radente (quando i comandi sono già chiari).
const LOW_FLY_AFTER := 25.0
## Munizioni sotto cui si spiegano le briciole.
const CRUMBS_BELOW := 3

var _save: SaveData
var _touch: bool


func _init(save: SaveData, touch: bool) -> void:
	_save = save
	_touch = touch


func is_seen(id: String) -> bool:
	return _save.hints_seen.has(id)


## Testo del suggerimento se non è ancora stato mostrato (e lo segna come visto), altrimenti "".
## Il salvataggio su file avviene a fine partita, insieme al record.
func take(id: String) -> String:
	if is_seen(id):
		return ""
	var text := text_for(id)
	if text.is_empty():
		return ""
	_save.hints_seen.append(id)
	return text


func reset() -> void:
	_save.hints_seen.clear()


func text_for(id: String) -> String:
	match id:
		FLY:
			return "Drag on the left side to fly" if _touch else "Fly with WASD or the arrow keys"
		DROP:
			return "Yellow ring = target! Tap the right side to drop" if _touch \
				else "Yellow ring = target! Press Space to drop"
		BOOST:
			return "Splat! Every hit makes you faster"
		NEAR_MISS:
			return "Close call! Near misses score points and keep your combo"
		CRUMBS:
			return "Running low? Grab the crumbs to refill your poop"
		LOW_FLY:
			return "Fly low over the road for ×1.5 distance points"
	return ""
