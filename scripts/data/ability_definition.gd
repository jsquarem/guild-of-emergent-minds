class_name AbilityDefinition
extends Resource
## Defines a single ability: cooldown, range, effect type. Used by combat and AI.

enum TargetType { SELF, SINGLE_ALLY, SINGLE_ENEMY, AREA_ENEMY, NONE }

@export var ability_id: String = ""
@export var display_name: String = ""
@export var cooldown: float = 5.0
@export var range: float = 0.0  ## 0 = use preferred range
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var power: float = 0.0  ## Scaling (heal amount, damage, shield)
@export var duration: float = 0.0  ## For buffs/debuffs
