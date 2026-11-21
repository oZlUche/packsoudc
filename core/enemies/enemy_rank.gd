## Report 365 (author 2026-11-21): enemy rank by the run's difficulty level (A0..A12).
## Metal of the portrait coin + frame, and the age prefix on beast names, share one split:
##   normal enemies: A0 bronze, A1-A3 silver, A4+ gold
##   elites:         A0-A3 silver, A4+ gold
##   bosses and A12 guards: always gold
class_name EnemyRank
extends RefCounted

const BRONZE := 0
const SILVER := 1
const GOLD := 2
const METAL_NAMES := ["bronze", "silver", "gold"]
## First difficulty level at which normal enemies turn silver / everyone turns gold
const SILVER_FROM := 1
const GOLD_FROM := 4


## [param level] the difficulty level (DifficultyDef.level, 0 = normal); [param node_type] battle / elite / core
static func metal(level: int, node_type: StringName = &"battle", guard := false) -> int:
	if guard or node_type == &"core":
		return GOLD
	if level >= GOLD_FROM:
		return GOLD
	if node_type == &"elite" or level >= SILVER_FROM:
		return SILVER
	return BRONZE


static func metal_name(m: int) -> String:
	return METAL_NAMES[clampi(m, 0, METAL_NAMES.size() - 1)]


## Beasts only: the age prefix for this metal ("" for anything else)
static func prefix(def: EnemyDef, m: int) -> String:
	if def == null or def.species != &"beast":
		return ""
	return UiText.t("enemy.rank_prefix." + metal_name(m))


## The name shown on the nameplate: beasts get the age prefix
static func display_name(def: EnemyDef, m: int) -> String:
	return prefix(def, m) + Names.of(def)
