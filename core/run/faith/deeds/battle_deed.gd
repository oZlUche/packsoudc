## 进行战斗：每打一场给 amount 点；[member won_only] = 只算打赢的；
## 104：[member by_type] 按节点类型给（狩猎之神「普通 +5、精英 +20、BOSS +50」：`{"battle": 5, "elite": 20, "core": 50}`），
## 非空时只看它（表里没有的类型不给），载荷的 node_type 由 [RunState.battle_summary] 填；猎手战记作 `hunter`（它不是节点类型）
class_name BattleDeed
extends FaithDeed

@export var won_only: bool = false
@export var by_type: Dictionary = {}

const TYPE_NAMES := {"battle": {"zh": "普通", "en": "Normal"}, "elite": {"zh": "精英", "en": "Elite"}, "hunter": {"zh": "猎手", "en": "Hunter"}, "core": {"zh": "BOSS", "en": "Boss"}}


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	if won_only and not bool(payload.get("won", false)):
		return 0
	if by_type.is_empty():
		return amount
	return int(by_type.get(String(payload.get("node_type", "")), 0))


func describe() -> String:
	if not by_type.is_empty():
		var parts: Array[String] = []
		for k in by_type:
			parts.append("%s +%d" % [UiText.pick(TYPE_NAMES.get(String(k), null), String(k)), int(by_type[k])])
		return (UiText.t("deed.battle_won_by_type") if won_only else UiText.t("deed.battle_by_type")) % UiText.t("hud.buff_sep").join(parts)
	return (UiText.t("deed.battle_won") if won_only else UiText.t("deed.battle_fought")) % amount
