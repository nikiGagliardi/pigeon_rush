class_name RouteData
extends RefCounted
## L'anello: Roveredo → Bellinzona → Gottardo → Lucerna → Zurigo → Walensee → Coira → San Bernardino → Roveredo.
## Circa 400 km veri, 13,2 km nel gioco. Le prime tratte sono corte: il primo cartello arriva presto.

static var _segments: Array[RouteSegment] = []


static func segments() -> Array[RouteSegment]:
	if _segments.is_empty():
		_segments = _build()
	return _segments


static func count() -> int:
	return segments().size()


static func get_segment(index: int) -> RouteSegment:
	return segments()[posmod(index, count())]


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
		.with_weathers(["sun", "sun", "cloudy", "rain"]))

	list.append(RouteSegment.make(&"bellinzona_biasca", "Bellinzona → Biasca", "Riviera", "Ticino", 1100.0) \
		.with_traffic(1.0, 1.1).with_structures(0.10, 0.20, 0.45, 0.25) \
		.with_tunnels(["Riviera Tunnel"]) \
		.with_weathers(["sun", "sun", "cloudy", "rain"]))

	list.append(RouteSegment.make(&"leventina", "Biasca → Airolo", "Leventina", "Ticino", 1400.0) \
		.with_traffic(1.0, 1.2).with_structures(0.30, 0.12, 0.38, 0.20) \
		.with_tunnels(["Stalvedro Tunnel", "Leventina Tunnel"]) \
		.with_weathers(["sun", "cloudy", "fog", "rain"]))

	# galleria a doppia canna come le altre, ma quasi solo gallerie
	list.append(RouteSegment.make(&"gotthard", "Gotthard Tunnel", "Gotthard", "Ticino", 900.0) \
		.with_traffic(0.9, 1.4).with_structures(0.85, 0.05, 0.10, 0.0) \
		.with_tunnels(["Gotthard Tunnel"]) \
		.with_weathers(["sun", "cloudy"]))

	list.append(RouteSegment.make(&"uri_lucerne", "Göschenen → Lucerne", "Lake Lucerne", "Uri", 1800.0) \
		.with_traffic(1.05, 1.1).with_structures(0.25, 0.15, 0.40, 0.20) \
		.with_tunnels(["Seelisberg Tunnel", "Sonnenberg Tunnel"]) \
		.with_weathers(["rain", "fog", "cloudy", "sun"]))

	list.append(RouteSegment.make(&"lucerne_zurich", "Lucerne → Zurich", "Mittelland", "Lucerne", 1800.0) \
		.with_traffic(1.2, 1.0).with_structures(0.06, 0.30, 0.40, 0.24) \
		.with_tunnels(["Uetliberg Tunnel"]) \
		.with_weathers(["fog", "cloudy", "sun", "rain"]))

	list.append(RouteSegment.make(&"zurich_walensee", "Zurich → Walensee", "Walensee", "Zurich", 2000.0) \
		.with_traffic(1.15, 1.0).with_structures(0.22, 0.20, 0.38, 0.20) \
		.with_tunnels(["Kerenzerberg Tunnel", "Walensee Tunnel"]) \
		.with_weathers(["cloudy", "rain", "sun", "fog"]))

	list.append(RouteSegment.make(&"rhine_valley", "Sargans → Thusis", "Rhine Valley", "Graubünden", 1600.0) \
		.with_traffic(1.0, 1.1).with_structures(0.14, 0.18, 0.43, 0.25) \
		.with_tunnels(["Rhine Valley Tunnel"]) \
		.with_weathers(["sun", "cloudy", "rain", "snow"]))

	list.append(RouteSegment.make(&"san_bernardino", "San Bernardino → Roveredo", "San Bernardino", "Graubünden", 1800.0) \
		.with_traffic(0.95, 1.2).with_structures(0.30, 0.12, 0.40, 0.18) \
		.with_tunnels(["San Bernardino Tunnel"]) \
		.with_weathers(["snow", "sun", "fog", "cloudy"]))

	return list
