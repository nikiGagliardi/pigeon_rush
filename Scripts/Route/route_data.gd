class_name RouteData
extends RefCounted
## L'anello: Roveredo → Bellinzona → Gottardo → Lucerna → Zurigo → Walensee → Coira → San Bernardino → Roveredo.
## Circa 400 km veri, 13,2 km nel gioco. Le prime tratte sono corte: il primo cartello arriva presto.

const Landscape := LandscapeMeshes.Landscape

static var _segments: Array[RouteSegment] = []


static func segments() -> Array[RouteSegment]:
	if _segments.is_empty():
		_segments = _build()
	return _segments


static func count() -> int:
	return segments().size()


static func get_segment(index: int) -> RouteSegment:
	return segments()[posmod(index, count())]


## Tratte da cui può partire una partita normale: tutte tranne la galleria del Gottardo
## (countdown al buio in un tunnel di 900 m non è un bell'inizio).
static func normal_starts() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in count():
		if get_segment(i).id != &"gotthard":
			out.append(i)
	return out


static func total_length() -> float:
	var total := 0.0
	for segment: RouteSegment in segments():
		total += segment.length
	return total


static func _build() -> Array[RouteSegment]:
	var list: Array[RouteSegment] = []

	list.append(RouteSegment.make(&"roveredo_bellinzona", "Roveredo → Bellinzona", "Mesolcina", "Graubünden", 800.0) \
		.with_traffic(0.85, 0.8).with_structures(0.10, 0.12, 0.50, 0.28) \
		.with_tunnels(["Roveredo Tunnel"]) \
		.with_weathers(["sun", "sun", "cloudy", "rain"]) \
		.with_landscape([[0.88, Landscape.TICINO], [1.0, Landscape.TOWN]]) \
		.with_landmark(&"bellinzona", 0.8))

	list.append(RouteSegment.make(&"bellinzona_biasca", "Bellinzona → Biasca", "Riviera", "Ticino", 1100.0) \
		.with_traffic(1.0, 1.1).with_structures(0.10, 0.20, 0.45, 0.25) \
		.with_tunnels(["Riviera Tunnel"]) \
		.with_weathers(["sun", "sun", "cloudy", "rain"]) \
		.with_landscape([[0.12, Landscape.TOWN], [1.0, Landscape.RIVIERA]]))

	list.append(RouteSegment.make(&"leventina", "Biasca → Airolo", "Leventina", "Ticino", 1400.0) \
		.with_traffic(1.0, 1.2).with_structures(0.30, 0.12, 0.38, 0.20) \
		.with_tunnels(["Stalvedro Tunnel", "Leventina Tunnel"]) \
		.with_weathers(["sun", "cloudy", "fog", "rain"]) \
		.with_landscape([[0.55, Landscape.TICINO], [1.0, Landscape.ALPINE]]) \
		.with_landmark(&"leventina_church", 0.35))

	# galleria a doppia canna come le altre, ma quasi solo gallerie
	list.append(RouteSegment.make(&"gotthard", "Gotthard Tunnel", "Gotthard", "Ticino", 900.0) \
		.with_traffic(0.9, 1.4).with_structures(0.85, 0.05, 0.10, 0.0) \
		.with_tunnels(["Gotthard Tunnel"]) \
		.with_weathers(["sun", "cloudy"]) \
		.with_landscape([[1.0, Landscape.ALPINE]]))

	list.append(RouteSegment.make(&"uri_lucerne", "Göschenen → Lucerne", "Lake Lucerne", "Uri", 1800.0) \
		.with_traffic(1.05, 1.1).with_structures(0.25, 0.15, 0.40, 0.20) \
		.with_tunnels(["Seelisberg Tunnel", "Sonnenberg Tunnel"]) \
		.with_weathers(["rain", "fog", "cloudy", "sun"]) \
		.with_landscape([[0.3, Landscape.ALPINE], [0.88, Landscape.LAKE], [1.0, Landscape.TOWN]]) \
		.with_landmark(&"lucerne", 0.8))

	list.append(RouteSegment.make(&"lucerne_zurich", "Lucerne → Zurich", "Mittelland", "Lucerne", 1800.0) \
		.with_traffic(1.0, 1.0).with_structures(0.06, 0.30, 0.40, 0.24) \
		.with_tunnels(["Uetliberg Tunnel"]) \
		.with_weathers(["fog", "cloudy", "sun", "rain"]) \
		.with_landscape([[0.1, Landscape.TOWN], [0.8, Landscape.PLATEAU], [1.0, Landscape.CITY]]) \
		.with_landmark(&"zurich", 0.8))

	list.append(RouteSegment.make(&"zurich_walensee", "Zurich → Walensee", "Walensee", "Zurich", 2000.0) \
		.with_traffic(1.0, 1.0).with_structures(0.22, 0.20, 0.38, 0.20) \
		.with_tunnels(["Kerenzerberg Tunnel", "Walensee Tunnel"]) \
		.with_weathers(["cloudy", "rain", "sun", "fog"]) \
		.with_landscape([[0.12, Landscape.CITY], [0.4, Landscape.LAKE], [0.55, Landscape.PLATEAU], [1.0, Landscape.LAKE]]) \
		.with_landmark(&"churfirsten", 0.75))

	list.append(RouteSegment.make(&"rhine_valley", "Sargans → Thusis", "Rhine Valley", "Graubünden", 1600.0) \
		.with_traffic(1.0, 1.1).with_structures(0.14, 0.18, 0.43, 0.25) \
		.with_tunnels(["Rhine Valley Tunnel"]) \
		.with_weathers(["sun", "cloudy", "rain", "snow"]) \
		.with_landscape([[0.5, Landscape.RIVIERA], [0.66, Landscape.TOWN], [1.0, Landscape.ALPINE]]) \
		.with_landmark(&"sargans", 0.14))

	list.append(RouteSegment.make(&"san_bernardino", "San Bernardino → Roveredo", "San Bernardino", "Graubünden", 1800.0) \
		.with_traffic(1.1, 1.2).with_structures(0.30, 0.12, 0.40, 0.18) \
		.with_tunnels(["San Bernardino Tunnel"]) \
		.with_weathers(["snow", "sun", "fog", "cloudy"]) \
		.with_landscape([[0.55, Landscape.ALPINE], [1.0, Landscape.TICINO]]) \
		.with_landmark(&"mesocco", 0.76))

	return list
