class_name GameConfig
extends RefCounted
## Costanti di gameplay. Unità: metri e secondi.
## Convenzione assi: il piccione guarda verso -Z e resta a Z = 0;
## il mondo (strada, mezzi, cartelli) scorre verso +Z.

# --- Strada ---
const LANE_COUNT := 3
const LANE_WIDTH := 3.6
const ROAD_HALF_WIDTH := LANE_COUNT * LANE_WIDTH * 0.5

# --- Area di volo (abbastanza stretta da sovrapporsi alle corsie esterne) ---
const FLY_HALF_WIDTH := 4.6
const FLY_MIN_Y := 0.6
const FLY_MAX_Y := 7.0
const PIGEON_START_Y := 3.0
const PIGEON_HALF_EXTENTS := Vector3(0.4, 0.22, 0.45)

# --- Fasce di altezza per la griglia "varco garantito" ---
const BAND_COUNT := 3

# --- Mondo ---
const SPAWN_Z := -300.0
const DESPAWN_Z := 25.0
const SEGMENT_LENGTH := 40.0
const SEGMENT_COUNT := 10

# --- Velocità ---
const TRAFFIC_SPEED := 20.0
const BASE_PIGEON_SPEED := 16.0
const MAX_BASE_PIGEON_SPEED := 30.0
const SPEED_RAMP := 0.11
const MAX_BOOST_STACKS := 5
const BOOST_PER_STACK := 0.12
const BOOST_STACK_DURATION := 3.5

# --- Movimento piccione ---
const MAX_LATERAL_SPEED := 13.0
const MAX_VERTICAL_SPEED := 9.0
const FLY_ACCELERATION := 55.0

# --- Cacca ---
const MAX_AMMO := 10
const START_AMMO := 6
const CRUMBS_AMMO := 3
const POOP_COOLDOWN := 0.22
const POOP_GRAVITY := 32.0
const POOP_INITIAL_DOWN := 6.0
const LOCK_MIN_AHEAD := 2.0
const LOCK_MAX_AHEAD := 32.0

# --- Punteggio ---
const COMBO_WINDOW := 3.5
const MAX_COMBO_MULTIPLIER := 5
const NEAR_MISS_DISTANCE := 0.9
const NEAR_MISS_POINTS := 50
const LOW_FLY_HEIGHT := 2.0
const LOW_FLY_BONUS := 1.5

# --- Difficoltà ---
const DIFFICULTY_RAMP_TIME := 150.0
const START_GRACE := 2.0

# --- Ciclo di partita e Continua ---
const COUNTDOWN_TIME := 3.0
## Il mondo riparte dolcemente dopo il countdown (time_scale da 0 o dal menu fino a 1 in circa 0,8 s).
const RESUME_RAMP := 1.25
## Pausa dopo l'impatto prima del pannello "Continue?" o del game over.
const CRASH_DELAY := 1.3
const CONTINUE_OFFER_TIME := 5.0
const CONTINUES_PER_RUN := 1
## Alla ripresa spariscono traffico e strutture fino a questa distanza davanti al piccione.
const REVIVE_CLEAR_DISTANCE := 70.0
const REVIVE_INVULNERABILITY := 2.5


static func lane_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) * 0.5) * LANE_WIDTH


static func band_center_y(band: int) -> float:
	match band:
		0:
			return 1.3
		1:
			return 3.2
		_:
			return 5.4
