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
## Ordine delle schede nel negozio.
const CATEGORIES: Array[String] = [CATEGORY_BIRD, CATEGORY_FEATHERS, CATEGORY_HEAD, CATEGORY_FACE, CATEGORY_NECK]
const CATEGORY_TITLES := {
	CATEGORY_BIRD: "BIRD", CATEGORY_FEATHERS: "FEATHERS", CATEGORY_HEAD: "HEAD",
	CATEGORY_FACE: "FACE", CATEGORY_NECK: "NECK",
}

## Valori di default (sempre posseduti). "none" = niente accessorio in quella categoria.
const PIGEON := &"pigeon"
const CLASSIC := &"classic"
const NONE := &"none"
const FREE: Array[StringName] = [&"pigeon", &"classic", &"none"]

## id → [categoria, nome mostrato]
const ITEMS := {
	&"pigeon": [CATEGORY_BIRD, "Pigeon"],
	&"crow": [CATEGORY_BIRD, "Crow"],
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
}


static func knows(id: StringName) -> bool:
	return ITEMS.has(id)


static func category_of(id: StringName) -> String:
	return str(ITEMS[id][0]) if ITEMS.has(id) else ""


static func name_of(id: StringName) -> String:
	if id == NONE:
		return "None"
	return str(ITEMS[id][1]) if ITEMS.has(id) else str(id)


static func ids_in(category: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if ITEMS[id][0] == category:
			out.append(id)
	return out


# ------------------------------------------------------------------ specie

## Proporzioni della specie. Tutte stanno nello stesso ingombro del piccione: la hitbox non cambia.
class Species:
	var id: StringName
	var body_scale := Vector3.ONE
	var head_scale: float = 1.0
	var beak_length: float = 0.15
	var beak_radius: float = 0.038
	var has_cere: bool = true
	## Ventaglio della coda: gradi tra una penna e l'altra, e quanto è più lunga quella centrale.
	var tail_spread: float = 9.0
	var tail_center_extra: float = 0.0
	## Grandezza degli accessori rispetto a quelli disegnati per il piccione.
	var accessory_scale: float = 1.0


static func species(id: StringName) -> Species:
	var s := Species.new()
	s.id = id
	if id == &"crow":
		s.body_scale = Vector3(0.96, 0.94, 1.08)
		s.head_scale = 1.04
		s.beak_length = 0.21
		s.beak_radius = 0.05
		s.has_cere = false
		s.tail_spread = 6.0
		s.tail_center_extra = 0.08
		s.accessory_scale = 1.04
	else:
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
	if species_id == &"crow":
		return {
			"body": Color("23262d"), "belly": Color("2a2d35"), "chest": Color("262a31"), "neck": Color("2c3550"),
			"neck2": Color("3a2f52"), "head": Color("23262d"), "rump": Color("2d3039"), "wing": Color("272b33"),
			"bar": Color("1b1e24"), "primary_dark": Color("14161a"), "primary_mid": Color("1b1e23"),
			"primary_light": Color("23262c"), "secondary": Color("1f2228"), "tail": Color("1c1f25"),
			"tail_band": Color("15171b"), "beak": Color("4a4e57"), "beak_tip": Color("2a2c31"),
			"cere": Color("1c1c1e"), "eye_ring": Color("2a2d35"), "eye": Color("2b1d14"), "pupil": Color("0a0a0a"),
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


static func _merge(into: Dictionary, hex: Dictionary) -> void:
	for key: String in hex:
		into[key] = Color(str(hex[key]))
