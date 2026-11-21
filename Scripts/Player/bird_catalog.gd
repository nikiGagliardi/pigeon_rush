class_name BirdCatalog
extends RefCounted
## Aspetti dell'uccello che il gioco sa disegnare: specie, piumaggi e accessori, per id.
## Prezzi, disponibilità e chi possiede cosa li decide il server (catalogo del negozio): un id che il server
## non vende non compare in negozio, un id che il server vende ma il gioco non conosce viene ignorato.
## Gli id gratuiti (FREE) sono di tutti, anche offline.

const CATEGORY_BIRD := "bird"
const CATEGORY_FEATHERS := "feathers"
const CATEGORY_HEAD := "head"
const CATEGORY_FACE := "face"
const CATEGORY_NECK := "neck"
const CATEGORY_TRAIL := "trail"
const CATEGORY_SPLAT := "splat"
## Ordine delle schede nel negozio.
const CATEGORIES: Array[String] = [CATEGORY_BIRD, CATEGORY_FEATHERS, CATEGORY_HEAD, CATEGORY_FACE, CATEGORY_NECK,
	CATEGORY_TRAIL, CATEGORY_SPLAT]
const CATEGORY_TITLES := {
	CATEGORY_BIRD: "BIRD", CATEGORY_FEATHERS: "FEATHERS", CATEGORY_HEAD: "HEAD",
	CATEGORY_FACE: "FACE", CATEGORY_NECK: "NECK", CATEGORY_TRAIL: "TRAIL", CATEGORY_SPLAT: "SPLAT",
}
## Categorie in cui "none" è un valore valido (niente accessorio, niente scia, cacca classica).
const NONE_CATEGORIES: Array[String] = [CATEGORY_HEAD, CATEGORY_FACE, CATEGORY_NECK, CATEGORY_TRAIL, CATEGORY_SPLAT]

## Valori di default (sempre posseduti). "none" = niente accessorio in quella categoria.
const PIGEON := &"pigeon"
const CLASSIC := &"classic"
const NONE := &"none"
const FREE: Array[StringName] = [&"pigeon", &"classic", &"none"]

## id → [categoria, nome mostrato]
const ITEMS := {
	&"pigeon": [CATEGORY_BIRD, "Pigeon"],
	&"seagull": [CATEGORY_BIRD, "Seagull"],
	&"chicken": [CATEGORY_BIRD, "Chicken"],
	&"owl": [CATEGORY_BIRD, "Owl"],
	&"eagle": [CATEGORY_BIRD, "Eagle"],
	&"crow": [CATEGORY_BIRD, "Crow"],
	&"flying_pig": [CATEGORY_BIRD, "Flying pig"],
	&"unicorn": [CATEGORY_BIRD, "Unicorn"],
	&"classic": [CATEGORY_FEATHERS, "Classic"],
	&"dove": [CATEGORY_FEATHERS, "Dove"],
	&"night": [CATEGORY_FEATHERS, "Night"],
	&"swiss": [CATEGORY_FEATHERS, "Swiss"],
	&"rainbow": [CATEGORY_FEATHERS, "Rainbow"],
	&"gold": [CATEGORY_FEATHERS, "Gold"],
	&"cap": [CATEGORY_HEAD, "Cap"],
	&"alpine_hat": [CATEGORY_HEAD, "Alpine hat"],
	&"cowboy_hat": [CATEGORY_HEAD, "Cowboy hat"],
	&"helmet": [CATEGORY_HEAD, "Racing helmet"],
	&"crown": [CATEGORY_HEAD, "Crown"],
	&"sunglasses": [CATEGORY_FACE, "Sunglasses"],
	&"goggles": [CATEGORY_FACE, "Aviator goggles"],
	&"scarf": [CATEGORY_NECK, "Red scarf"],
	&"cowbell": [CATEGORY_NECK, "Cowbell"],
	&"contrail": [CATEGORY_TRAIL, "Contrail"],
	&"neon_trail": [CATEGORY_TRAIL, "Neon"],
	&"comet": [CATEGORY_TRAIL, "Comet"],
	&"rainbow_trail": [CATEGORY_TRAIL, "Rainbow"],
	&"bubblegum": [CATEGORY_SPLAT, "Bubblegum"],
	&"neon_splat": [CATEGORY_SPLAT, "Neon"],
	&"swiss_splat": [CATEGORY_SPLAT, "Swiss"],
	&"rainbow_splat": [CATEGORY_SPLAT, "Rainbow"],
}


static func knows(id: StringName) -> bool:
	return ITEMS.has(id)


static func category_of(id: StringName) -> String:
	return str(ITEMS[id][0]) if ITEMS.has(id) else ""


static func name_of(id: StringName, category: String = "") -> String:
	if id == NONE:
		return "Classic" if category == CATEGORY_SPLAT else "None"
	return str(ITEMS[id][1]) if ITEMS.has(id) else str(id)


static func ids_in(category: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if ITEMS[id][0] == category:
			out.append(id)
	return out


# ------------------------------------------------------------------ specie

## Forma della specie. Tutte stanno nello stesso ingombro del piccione: la hitbox non cambia.
class Species:
	var id: StringName
	## Costruzione: &"bird" (uccello), &"pig" (maiale volante), &"unicorn".
	var kind: StringName = &"bird"
	var body_scale := Vector3.ONE
	var head_scale: float = 1.0
	## Spostamento del perno della testa rispetto a quello del piccione (coordinate del corpo).
	var head_offset := Vector3.ZERO
	## Becco: &"pigeon", &"fierce" (corvo), &"hook" (aquila), &"owl", &"chicken", &"gull".
	var beak: StringName = &"pigeon"
	var beak_length: float = 0.15
	var beak_radius: float = 0.038
	var has_cere: bool = true
	## Ventaglio della coda: gradi tra una penna e l'altra, quanto è più lunga quella centrale, lunghezza.
	var tail_spread: float = 9.0
	var tail_center_extra: float = 0.0
	var tail_length: float = 1.0
	## Coda della gallina: penne all'insù.
	var tail_up: bool = false
	var wing_scale: float = 1.0
	## Spostamento delle spalle rispetto a quelle del piccione (maiale e unicorno le hanno sulla schiena).
	var shoulder_offset := Vector3.ZERO
	## Grandezza degli accessori rispetto a quelli disegnati per il piccione, e spostamento degli agganci
	## (testa e faccia nelle coordinate della testa, collo in quelle del corpo).
	var accessory_scale: float = 1.0
	var socket_head_offset := Vector3.ZERO
	var socket_face_offset := Vector3.ZERO
	var socket_neck_offset := Vector3.ZERO
	## Look "cattivo": forme a faccette, becco squadrato e uncinato, sopracciglia aggrottate,
	## ciuffi sulla nuca, gola arruffata, remiganti a dita e coda a penne dritte.
	var fierce: bool = false
	## Sopracciglia aggrottate senza il resto del look "cattivo" (aquila).
	var brow: bool = false


static func species(id: StringName) -> Species:
	var s := Species.new()
	s.id = id
	match id:
		&"crow":
			s.body_scale = Vector3(0.96, 0.94, 1.08)
			s.head_scale = 1.04
			s.beak = &"fierce"
			s.beak_length = 0.2
			s.beak_radius = 0.036
			s.has_cere = false
			s.tail_spread = 6.0
			s.tail_center_extra = 0.08
			s.accessory_scale = 1.04
			s.fierce = true
		&"seagull":
			s.body_scale = Vector3(0.94, 0.9, 1.1)
			s.beak = &"gull"
			s.beak_length = 0.19
			s.beak_radius = 0.034
			s.has_cere = false
			s.tail_spread = 7.0
			s.wing_scale = 1.1
		&"chicken":
			s.body_scale = Vector3(1.06, 1.06, 0.92)
			s.head_scale = 0.92
			s.head_offset = Vector3(0.0, 0.04, 0.02)
			s.beak = &"chicken"
			s.beak_length = 0.09
			s.beak_radius = 0.04
			s.has_cere = false
			s.tail_up = true
			s.wing_scale = 0.88
			s.socket_head_offset = Vector3(0.0, 0.05, 0.02) # sopra la cresta
		&"owl":
			s.body_scale = Vector3(1.04, 1.0, 0.95)
			s.head_scale = 1.22
			s.head_offset = Vector3(0.0, -0.03, 0.06)
			s.beak = &"owl"
			s.beak_length = 0.06
			s.beak_radius = 0.03
			s.has_cere = false
			s.tail_spread = 8.0
			s.tail_length = 0.6
			s.accessory_scale = 1.08
			s.socket_face_offset = Vector3(0.0, 0.0, -0.05)
		&"eagle":
			s.body_scale = Vector3(1.0, 0.96, 1.08)
			s.head_scale = 1.05
			s.beak = &"hook"
			s.beak_length = 0.14
			s.beak_radius = 0.05
			s.has_cere = false
			s.tail_spread = 7.0
			s.wing_scale = 1.08
			s.brow = true
		&"flying_pig":
			s.kind = &"pig"
			s.head_offset = Vector3(0.0, -0.06, 0.02)
			s.head_scale = 1.1
			s.wing_scale = 0.62
			s.shoulder_offset = Vector3(0.0, 0.13, 0.0)
			s.has_cere = false
			s.accessory_scale = 1.08
			s.socket_head_offset = Vector3(0.0, -0.035, 0.07)
			s.socket_face_offset = Vector3(0.0, -0.04, -0.03)
			s.socket_neck_offset = Vector3(0.0, -0.03, 0.04)
		&"unicorn":
			s.kind = &"unicorn"
			s.head_offset = Vector3(0.0, 0.1, -0.06)
			s.head_scale = 1.0
			s.has_cere = false
			s.wing_scale = 0.95
			s.shoulder_offset = Vector3(-0.02, 0.1, 0.06)
			s.socket_head_offset = Vector3(0.0, -0.075, 0.15) # dietro al corno
			s.socket_face_offset = Vector3(0.0, -0.065, 0.085)
			s.socket_neck_offset = Vector3(0.0, 0.07, -0.02)
		_:
			s.id = PIGEON
	return s


# ------------------------------------------------------------------ piumaggi

## Colori di un piumaggio per una specie. "classic" = i colori naturali della specie.
static func plumage(species_id: StringName, plumage_id: StringName) -> Dictionary:
	var p := _natural(species_id)
	match plumage_id:
		&"dove":
			_merge(p, {
				"body": "eeeeea", "belly": "fbfbf8", "chest": "f4f2ee", "neck": "eef1f0", "neck2": "ece8f2",
				"head": "f4f4f1", "rump": "fafaf7", "wing": "f0f0ec", "bar": "d4d4cf", "primary_dark": "cfcfca",
				"primary_mid": "dcdcd7", "primary_light": "e6e6e1", "secondary": "e2e2dd", "tail": "ebebe6",
				"tail_band": "d2d2cc", "beak": "e8a06a", "cere": "f6d6c4", "eye": "3a2414", "eye_ring": "f2c6b4",
			})
		&"night":
			_merge(p, {
				"body": "2b2f38", "belly": "343944", "chest": "2f3440", "neck": "2e6b5e", "neck2": "4e3a6a",
				"head": "30353f", "rump": "3a3f4b", "wing": "353a45", "bar": "15181d", "primary_dark": "15181d",
				"primary_mid": "1d2128", "primary_light": "262b33", "secondary": "2a2e37", "tail": "23272f",
				"tail_band": "101216", "beak": "2a2a2a", "eye": "ff7b00",
			})
		&"swiss":
			_merge(p, {
				"body": "d52b1e", "belly": "e04a3e", "chest": "c8251a", "neck": "f4f4f4", "neck2": "e8e8e8",
				"head": "d52b1e", "rump": "e85a50", "wing": "d52b1e", "bar": "d52b1e", "primary_dark": "9e1f16",
				"primary_mid": "b8261b", "primary_light": "c92a1e", "secondary": "c42619", "tail": "b8261b",
				"tail_band": "f4f4f4",
			})
			p["cross"] = true # croce bianca sulle ali
		&"rainbow":
			_merge(p, {"neck": "18d1b0", "neck2": "c13fff"})
			p["rainbow_tail"] = true
		&"gold":
			_merge(p, {
				"body": "d9a520", "belly": "e8bf4a", "chest": "cf9a18", "neck": "ffd54a", "neck2": "f0b429",
				"head": "e0ad2a", "rump": "f2c75a", "wing": "e3b23a", "bar": "a87a12", "primary_dark": "9c7010",
				"primary_mid": "b8861a", "primary_light": "d19f2a", "secondary": "c8961f", "tail": "b8861a",
				"tail_band": "8c620c", "beak": "f6e7b0",
			})
	return p


static func _natural(species_id: StringName) -> Dictionary:
	match species_id:
		&"seagull":
			return _hex({
				"body": "eef1f4", "belly": "f8f9fa", "chest": "f4f6f8", "neck": "f2f4f6", "neck2": "eceff2",
				"head": "f6f7f8", "rump": "e9edf0", "wing": "aab4bf", "bar": "aab4bf", "primary_dark": "1e2126",
				"primary_mid": "2a2e35", "primary_light": "8f9aa6", "secondary": "9aa5b1", "tail": "eef1f4",
				"tail_band": "e2e6ea", "beak": "f2c230", "beak_tip": "f2c230", "beak_spot": "d6312a", "cere": "f2c230",
				"eye_ring": "e3b13a", "eye": "f1e7a2", "pupil": "111111", "foot": "f0a39a",
			})
		&"chicken":
			return _hex({
				"body": "b4592b", "belly": "c26a35", "chest": "bd6230", "neck": "d9893f", "neck2": "c87536",
				"head": "c46b33", "rump": "a5502a", "wing": "9c4a25", "bar": "7e3a1d", "primary_dark": "4a2a1a",
				"primary_mid": "6b3a20", "primary_light": "8a4a26", "secondary": "8c4424", "tail": "2b2a33",
				"tail_band": "1d3a33", "beak": "f2b632", "beak_tip": "d99a22", "comb": "e0302a", "cere": "e0302a",
				"eye_ring": "e9b07a", "eye": "e8a33a", "pupil": "111111", "foot": "f2b632",
			})
		&"owl":
			return _hex({
				"body": "8a6a48", "belly": "d8c4a0", "chest": "c9b088", "neck": "9b7a55", "neck2": "a5855f",
				"head": "8f6f4c", "rump": "7e6042", "wing": "7a5c3e", "bar": "5e4430", "primary_dark": "4e3826",
				"primary_mid": "6a4e35", "primary_light": "8a6c4c", "secondary": "735639", "tail": "6e5238",
				"tail_band": "4e3826", "beak": "3a3330", "beak_tip": "2a2421", "face": "e8dcc2", "cere": "3a3330",
				"eye_ring": "1e1a17", "eye": "ff9a1a", "pupil": "111111", "foot": "c9b088",
			})
		&"eagle":
			return _hex({
				"body": "4a3426", "belly": "54392a", "chest": "50372a", "neck": "f3f1ea", "neck2": "e9e6dc",
				"head": "f5f3ec", "rump": "56402f", "wing": "4e3829", "bar": "3a291e", "primary_dark": "1e1612",
				"primary_mid": "2b2019", "primary_light": "3a2b21", "secondary": "433024", "tail": "f3f1ea",
				"tail_band": "e4e0d4", "beak": "f2c230", "beak_tip": "c9951a", "cere": "f2c230",
				"eye_ring": "e3b13a", "eye": "f3d24a", "pupil": "111111", "foot": "f2c230",
			})
		&"flying_pig":
			return _hex({
				"body": "f4a9b8", "belly": "f7bcc8", "chest": "f6b3c1", "neck": "f4a9b8", "neck2": "f4a9b8",
				"head": "f6b1bf", "rump": "f2a0b0", "snout": "ec8a9f", "nostril": "b8566d", "ear": "e98ea3",
				"wing": "fbfbf8", "bar": "fbfbf8", "primary_dark": "e6e8ec", "primary_mid": "eef0f3",
				"primary_light": "f6f7f9", "secondary": "f2f3f5", "tail": "ec8a9f", "tail_band": "ec8a9f",
				"beak": "ec8a9f", "beak_tip": "b8566d", "cere": "ec8a9f", "eye_ring": "f6b1bf", "eye": "2a1d18",
				"pupil": "111111", "foot": "9c6b5e",
			})
		&"unicorn":
			return _hex({
				"body": "f8f6fb", "belly": "ffffff", "chest": "f6f3fa", "neck": "f8f6fb", "neck2": "f1edf7",
				"head": "faf8fc", "rump": "f3f0f8", "wing": "fdfcff", "bar": "fdfcff", "primary_dark": "d9cdf2",
				"primary_mid": "e6ddf7", "primary_light": "f1ecfb", "secondary": "eee8fa", "tail": "f7a8d8",
				"tail_band": "a8d8f7", "mane": "c9a8f7", "mane2": "f7a8d8", "mane3": "a8e6f7", "horn": "f2c94c",
				"beak": "e9dff5", "beak_tip": "c9b8e3", "cere": "e9dff5", "eye_ring": "e9dff5", "eye": "5a3a8a",
				"pupil": "111111", "foot": "b9a6d6",
			})
	if species_id == &"crow":
		return {
			"body": Color("23262d"), "belly": Color("2a2d35"), "chest": Color("262a31"), "neck": Color("262b3a"),
			"neck2": Color("2b2735"), "head": Color("23262d"), "rump": Color("2d3039"), "wing": Color("272b33"),
			"bar": Color("1b1e24"), "primary_dark": Color("14161a"), "primary_mid": Color("1b1e23"),
			"primary_light": Color("23262c"), "secondary": Color("1f2228"), "tail": Color("1c1f25"),
			"tail_band": Color("15171b"), "beak": Color("4a4e57"), "beak_tip": Color("2a2c31"),
			"cere": Color("1c1c1e"), "eye_ring": Color("1a1c21"), "eye": Color("d9a728"), "pupil": Color("0a0a0a"),
			"foot": Color("1c1c1e"),
		}
	return {
		"body": Palette.PIGEON_BODY, "belly": Palette.PIGEON_BELLY, "chest": Palette.PIGEON_CHEST,
		"neck": Palette.PIGEON_NECK, "neck2": Palette.PIGEON_NECK_PURPLE, "head": Palette.PIGEON_HEAD,
		"rump": Palette.PIGEON_RUMP, "wing": Palette.PIGEON_WING, "bar": Palette.PIGEON_PRIMARY_DARK,
		"primary_dark": Palette.PIGEON_PRIMARY_DARK, "primary_mid": Palette.PIGEON_PRIMARY_MID,
		"primary_light": Palette.PIGEON_PRIMARY_LIGHT, "secondary": Palette.PIGEON_SECONDARY,
		"tail": Palette.PIGEON_TAIL, "tail_band": Palette.PIGEON_TAIL_BAND, "beak": Palette.BEAK,
		"beak_tip": Palette.BEAK_TIP, "cere": Palette.CERE, "eye_ring": Palette.EYE_RING, "eye": Palette.EYE,
		"pupil": Palette.PUPIL, "foot": Palette.FOOT,
	}


static func _hex(hex: Dictionary) -> Dictionary:
	var out := {}
	for key: String in hex:
		out[key] = Color(str(hex[key]))
	return out


static func _merge(into: Dictionary, hex: Dictionary) -> void:
	for key: String in hex:
		into[key] = Color(str(hex[key]))
