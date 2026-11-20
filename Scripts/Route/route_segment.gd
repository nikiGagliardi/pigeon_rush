class_name RouteSegment
extends RefCounted
## Una tratta dell'anello: nome, lunghezza nel gioco e "carattere" (traffico, strutture, meteo possibili).
## Le lunghezze reali sono accorciate circa 1:30.

var id: StringName
## Nome mostrato nel banner e nel game over, es. "Bellinzona → Biasca".
var name: String
## Zona, es. "Leventina": titolo del banner quando non si cambia cantone.
var region: String
## Cantone in cui si entra: "WELCOME TO …" quando cambia rispetto alla tratta prima.
var canton: String
var length: float

## Più alto = file di traffico più fitte (divide la distanza tra le file).
var traffic: float = 1.0
## Moltiplica la quota di camion e bus.
var heavy: float = 1.0

# pesi relativi delle strutture (non serve che sommino a 1)
var tunnel_weight: float = 0.16
var works_weight: float = 0.16
var gantry_weight: float = 0.42
var overpass_weight: float = 0.26

## Nomi sui portali delle gallerie di questa tratta.
var tunnel_names: PackedStringArray = PackedStringArray(["Tunnel"])

## Meteo possibili (Fase 4): uno viene scelto a caso dal seed della partita, per tratta e per giro.
var weathers: PackedStringArray = PackedStringArray(["sun"])

## Paesaggi in sequenza: fino a landscape_until[i] (0..1 della tratta) c'è landscape_themes[i].
var landscape_until: PackedFloat32Array = PackedFloat32Array([1.0])
var landscape_themes: Array[LandscapeMeshes.Landscape] = [LandscapeMeshes.Landscape.ALPINE]

## Luogo tipico (LandmarkMeshes) e punto della tratta (0..1) in cui lo si affianca. Vuoto = nessuno.
var landmark: StringName = &""
var landmark_at: float = 0.5


static func make(p_id: StringName, p_name: String, p_region: String, p_canton: String, p_length: float) -> RouteSegment:
	var segment := RouteSegment.new()
	segment.id = p_id
	segment.name = p_name
	segment.region = p_region
	segment.canton = p_canton
	segment.length = p_length
	return segment


func with_traffic(p_traffic: float, p_heavy: float) -> RouteSegment:
	traffic = p_traffic
	heavy = p_heavy
	return self


func with_structures(tunnel: float, works: float, gantry: float, overpass: float) -> RouteSegment:
	tunnel_weight = tunnel
	works_weight = works
	gantry_weight = gantry
	overpass_weight = overpass
	return self


func with_tunnels(names: Array[String]) -> RouteSegment:
	tunnel_names = PackedStringArray(names)
	return self


func with_weathers(list: Array[String]) -> RouteSegment:
	weathers = PackedStringArray(list)
	return self


## stages: coppie [fino_a, tema], es. [[0.65, Landscape.TICINO], [1.0, Landscape.TOWN]].
func with_landscape(stages: Array) -> RouteSegment:
	landscape_until = PackedFloat32Array()
	landscape_themes.clear()
	for stage: Array in stages:
		landscape_until.append(float(stage[0]))
		landscape_themes.append(stage[1] as LandscapeMeshes.Landscape)
	return self


func with_landmark(p_landmark: StringName, at: float) -> RouteSegment:
	landmark = p_landmark
	landmark_at = at
	return self


## Paesaggio a un punto della tratta (0..1).
func landscape_at(progress: float) -> LandscapeMeshes.Landscape:
	for i in landscape_until.size():
		if progress <= landscape_until[i]:
			return landscape_themes[i]
	return landscape_themes[landscape_themes.size() - 1]
