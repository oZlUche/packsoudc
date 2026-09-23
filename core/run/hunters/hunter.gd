## 一个在图上活着的猎手（069）：在哪、是哪一种、领地、状态。纯状态，跟着存档；行为在 [HunterSystem] 与构件里。
class_name Hunter
extends RefCounted

var uid: int = 0
var def_id: StringName = &""
var node_id: int = -1
var home_id: int = -1
var alive: bool = true
## 领地：能走的点。空 = 整张图
var territory: Array[int] = []
## 还有几步不追（逃跑成功、退走之后）
var cooldown: int = 0
## 驻守（输了被赶走之后它不动）
var guarding: bool = false
## 玩家现在在它的感知范围内（进入那一刻提示一次）
var sensed: bool = false


func to_dict() -> Dictionary:
	return {"uid": uid, "def": String(def_id), "node": node_id, "home": home_id, "alive": alive,
		"territory": territory.duplicate(), "cooldown": cooldown, "guarding": guarding, "sensed": sensed}


static func from_dict(d: Dictionary) -> Hunter:
	var h := Hunter.new()
	h.uid = int(d.get("uid", 0))
	h.def_id = StringName(String(d.get("def", "")))
	h.node_id = int(d.get("node", -1))
	h.home_id = int(d.get("home", -1))
	h.alive = bool(d.get("alive", true))
	for id in d.get("territory", []):
		h.territory.append(int(id))
	h.cooldown = int(d.get("cooldown", 0))
	h.guarding = bool(d.get("guarding", false))
	h.sensed = bool(d.get("sensed", false))
	return h
