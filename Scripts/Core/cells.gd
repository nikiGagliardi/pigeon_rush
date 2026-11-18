class_name Cells
extends RefCounted
## Griglia 3 corsie × 3 fasce di altezza codificata come bitmask.
## Serve allo spawner per garantire sempre un varco raggiungibile.

const CELL_COUNT := GameConfig.LANE_COUNT * GameConfig.BAND_COUNT
const ALL := (1 << CELL_COUNT) - 1


static func of(lane: int, band_i: int) -> int:
	return 1 << (lane * GameConfig.BAND_COUNT + band_i)


static func band(band_index: int) -> int:
	var mask := 0
	for lane in GameConfig.LANE_COUNT:
		mask |= of(lane, band_index)
	return mask


static func count_of(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		m &= m - 1
		count += 1
	return count


static func has(mask: int, lane: int, band_index: int) -> bool:
	return (mask & of(lane, band_index)) != 0


## Espande la maschera alle celle adiacenti (±1 corsia, ±1 fascia, diagonali incluse).
static func dilate(mask: int) -> int:
	var result := 0
	for lane in GameConfig.LANE_COUNT:
		for b in GameConfig.BAND_COUNT:
			if not has(mask, lane, b):
				continue
			for dl in range(-1, 2):
				for db in range(-1, 2):
					var l := lane + dl
					var bb := b + db
					if l >= 0 and l < GameConfig.LANE_COUNT and bb >= 0 and bb < GameConfig.BAND_COUNT:
						result |= of(l, bb)
	return result
