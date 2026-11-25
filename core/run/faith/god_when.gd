## 388：神的牌「满足条件才入池」（牌表 `when`）里写死在代码里的那几条 —— [method LevelModule.register_when] 没登记的 key 来这里找
class_name GodWhen
extends RefCounted

## 日神【永日不落】：黑夜时长到 0
const SUN_NIGHT_ZERO := &"sun_night_zero"
## 日神【永夜难明】：白昼时长到 0
const SUN_DAY_ZERO := &"sun_day_zero"
## 396 蛮神【献祭】：剩余体力大于扣的那几点，且还有质变牌可选
const BRUTE_SACRIFICE := &"brute_sacrifice"


static func met(key: StringName, lv: LevelModule) -> bool:
	match key:
		SUN_NIGHT_ZERO:
			return SunCyclePerk.durations(lv).y <= 0.0
		SUN_DAY_ZERO:
			return SunCyclePerk.durations(lv).x <= 0.0
		BRUTE_SACRIFICE:
			return BruteRagePerk.can_sacrifice(lv)
	return false
