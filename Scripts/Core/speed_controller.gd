class_name SpeedController
extends RefCounted
## Velocità del piccione: base che cresce nel tempo + boost cumulabili ottenuti centrando i mezzi.
## Ogni stack dura GameConfig.BOOST_STACK_DURATION secondi, poi ne scade uno alla volta.

var base_speed: float = GameConfig.BASE_PIGEON_SPEED
var boost_stacks: int = 0

## Usato per rallentare il mondo al game over (0..1).
var time_scale: float = 1.0:
	set(value):
		time_scale = clampf(value, 0.0, 1.0)

var multiplier: float:
	get:
		return 1.0 + boost_stacks * GameConfig.BOOST_PER_STACK

var pigeon_speed: float:
	get:
		return base_speed * multiplier * time_scale

var approach_speed: float:
	get:
		return pigeon_speed + GameConfig.TRAFFIC_SPEED * time_scale

var boost_normalized: float:
	get:
		return float(boost_stacks) / GameConfig.MAX_BOOST_STACKS

var stack_progress: float:
	get:
		return 0.0 if boost_stacks == 0 else _stack_timer / GameConfig.BOOST_STACK_DURATION

var speed_normalized: float:
	get:
		return (base_speed - GameConfig.BASE_PIGEON_SPEED) / (GameConfig.MAX_BASE_PIGEON_SPEED - GameConfig.BASE_PIGEON_SPEED)

var _stack_timer: float = 0.0


func tick(dt: float) -> void:
	base_speed = minf(GameConfig.MAX_BASE_PIGEON_SPEED, base_speed + GameConfig.SPEED_RAMP * dt)
	if boost_stacks <= 0:
		return
	_stack_timer -= dt
	if _stack_timer <= 0.0:
		boost_stacks -= 1
		_stack_timer = GameConfig.BOOST_STACK_DURATION if boost_stacks > 0 else 0.0


func add_boost(stacks: int) -> void:
	boost_stacks = mini(GameConfig.MAX_BOOST_STACKS, boost_stacks + stacks)
	_stack_timer = GameConfig.BOOST_STACK_DURATION


func clear_boost() -> void:
	boost_stacks = 0
	_stack_timer = 0.0
