## 147：随身道具（【随身】标签、放在腰带里）**怎么用**：什么时候能用、用了做什么。点一下就消耗。
##
## 有它的道具不上棋盘（不参战、不占背包），导入器要求它带 `belt` 标签、没有 `combat`、只占 1 格
class_name BeltUse
extends Resource

## 什么时候能用：地图上 / 战前准备屏 / 都行
enum When { MAP, PREBATTLE, ANY }

@export var when: When = When.MAP
## 用了做什么（按顺序）。都能用才用，任何一个说不行就整件不用
@export var effects: Array[BeltEffect] = []


## 地图上能不能用
func on_map() -> bool:
	return when == When.MAP or when == When.ANY


## 战前准备屏上能不能用
func on_prebattle() -> bool:
	return when == When.PREBATTLE or when == When.ANY


## 「战前准备屏上：……」这一句（悬浮窗、图鉴）
func describe() -> String:
	var parts: Array[String] = []
	for e in effects:
		if e != null:
			parts.append(e.describe())
	var at: String = {When.MAP: "地图上", When.PREBATTLE: "战前准备屏上", When.ANY: "地图上或战前准备屏上"}[when]
	return "%s用：%s" % [at, "；".join(parts)]
