class_name HeroRole
extends Resource
## Defines a hero role: base stats, preferred range, and ability set.
## Used by Hero and HeroBrain for role-driven behavior and combat.

enum RoleType { TANK, DPS, ENCHANTER }

@export var role_type: RoleType = RoleType.DPS
@export var display_name: String = ""

## Base stats
@export var max_hp: float = 100.0
@export var move_speed: float = 80.0
@export var armor: float = 0.0  ## Flat damage reduction (Phase 3+)
@export var attack_power: float = 10.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0

## Preferred engagement range: 0 = melee, 1 = mid, 2 = backline
@export var preferred_range: int = 0  # 0 melee, 1 mid (~80), 2 backline (~120)
@export var preferred_range_distance: float = 40.0  ## Actual distance for preferred_range

## Ability IDs this role can use (1-2 per role for Phase 3)
@export var ability_ids: Array[String] = []


static func get_default_tank() -> HeroRole:
	var r := HeroRole.new()
	r.role_type = RoleType.TANK
	r.display_name = "Tank"
	r.max_hp = 150.0
	r.move_speed = 60.0
	r.armor = 5.0
	r.attack_power = 8.0
	r.attack_range = 35.0
	r.attack_cooldown = 1.2
	r.preferred_range = 0
	r.preferred_range_distance = 35.0
	r.ability_ids = ["taunt"]
	return r


static func get_default_dps() -> HeroRole:
	var r := HeroRole.new()
	r.role_type = RoleType.DPS
	r.display_name = "DPS"
	r.max_hp = 80.0
	r.move_speed = 90.0
	r.armor = 0.0
	r.attack_power = 18.0
	r.attack_range = 50.0
	r.attack_cooldown = 0.8
	r.preferred_range = 1
	r.preferred_range_distance = 50.0
	r.ability_ids = ["heavy_strike"]
	return r


static func get_default_enchanter() -> HeroRole:
	var r := HeroRole.new()
	r.role_type = RoleType.ENCHANTER
	r.display_name = "Enchanter"
	r.max_hp = 70.0
	r.move_speed = 75.0
	r.armor = 0.0
	r.attack_power = 6.0
	r.attack_range = 100.0
	r.attack_cooldown = 1.5
	r.preferred_range = 2
	r.preferred_range_distance = 100.0
	r.ability_ids = ["heal", "shield"]
	return r


func get_preferred_distance() -> float:
	return preferred_range_distance
