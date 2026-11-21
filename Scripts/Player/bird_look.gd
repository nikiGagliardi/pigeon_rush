class_name BirdLook
extends RefCounted
## Cosa indossa il giocatore: specie, piumaggio, un accessorio per testa, faccia e collo, la scia e lo stile
## della cacca (id di BirdCatalog; "none" = niente scia, cacca classica).
## Salvato in SaveData; il gioco lo controlla contro gli oggetti posseduti prima di usarlo.

var species: StringName = BirdCatalog.PIGEON
var plumage: StringName = BirdCatalog.CLASSIC
var head: StringName = BirdCatalog.NONE
var face: StringName = BirdCatalog.NONE
var neck: StringName = BirdCatalog.NONE
var trail: StringName = BirdCatalog.NONE
var splat: StringName = BirdCatalog.NONE


static func from_dict(d: Dictionary) -> BirdLook:
	var look := BirdLook.new()
	look.species = _valid(d.get("species", ""), BirdCatalog.CATEGORY_BIRD, BirdCatalog.PIGEON)
	look.plumage = _valid(d.get("plumage", ""), BirdCatalog.CATEGORY_FEATHERS, BirdCatalog.CLASSIC)
	look.head = _valid(d.get("head", ""), BirdCatalog.CATEGORY_HEAD, BirdCatalog.NONE)
	look.face = _valid(d.get("face", ""), BirdCatalog.CATEGORY_FACE, BirdCatalog.NONE)
	look.neck = _valid(d.get("neck", ""), BirdCatalog.CATEGORY_NECK, BirdCatalog.NONE)
	look.trail = _valid(d.get("trail", ""), BirdCatalog.CATEGORY_TRAIL, BirdCatalog.NONE)
	look.splat = _valid(d.get("splat", ""), BirdCatalog.CATEGORY_SPLAT, BirdCatalog.NONE)
	return look


func to_dict() -> Dictionary:
	return {"species": str(species), "plumage": str(plumage), "head": str(head), "face": str(face), "neck": str(neck),
		"trail": str(trail), "splat": str(splat)}


func duplicate_look() -> BirdLook:
	return BirdLook.from_dict(to_dict())


## L'id indossato in una categoria.
func get_item(category: String) -> StringName:
	match category:
		BirdCatalog.CATEGORY_BIRD:
			return species
		BirdCatalog.CATEGORY_FEATHERS:
			return plumage
		BirdCatalog.CATEGORY_HEAD:
			return head
		BirdCatalog.CATEGORY_FACE:
			return face
		BirdCatalog.CATEGORY_NECK:
			return neck
		BirdCatalog.CATEGORY_TRAIL:
			return trail
		BirdCatalog.CATEGORY_SPLAT:
			return splat
	return BirdCatalog.NONE


func set_item(category: String, id: StringName) -> void:
	match category:
		BirdCatalog.CATEGORY_BIRD:
			species = id
		BirdCatalog.CATEGORY_FEATHERS:
			plumage = id
		BirdCatalog.CATEGORY_HEAD:
			head = id
		BirdCatalog.CATEGORY_FACE:
			face = id
		BirdCatalog.CATEGORY_NECK:
			neck = id
		BirdCatalog.CATEGORY_TRAIL:
			trail = id
		BirdCatalog.CATEGORY_SPLAT:
			splat = id


## Toglie quello che non si possiede più (o non si è mai posseduto): torna ai valori gratuiti.
func keep_owned(owned: Array) -> void:
	for category: String in BirdCatalog.CATEGORIES:
		var id := get_item(category)
		if not BirdCatalog.FREE.has(id) and not owned.has(str(id)):
			var fallback := BirdCatalog.PIGEON if category == BirdCatalog.CATEGORY_BIRD else (
				BirdCatalog.CLASSIC if category == BirdCatalog.CATEGORY_FEATHERS else BirdCatalog.NONE)
			set_item(category, fallback)


static func _valid(value: Variant, category: String, fallback: StringName) -> StringName:
	var id := StringName(str(value))
	if id == BirdCatalog.NONE and category in BirdCatalog.NONE_CATEGORIES:
		return id
	return id if BirdCatalog.category_of(id) == category else fallback
