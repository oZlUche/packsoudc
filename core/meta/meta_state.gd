## 局外（跨 run）的状态（架构文档 8 节、15 节第 4 项，M6）：仓库、钱、累计分数、几局几撤几败、最近几局的账。
##
## 一局里的东西在 [RunState]，跨局的在这里 —— 两者互不引用：一局结束了由 [RunResult] 算账，
## 本类的 [method absorb] 决定什么留下。**保留规则只在那一个方法里**（15 节第 4 项现在的假设：
## 撤离 = 棋盘上的全进仓库、钱全带出；战败 = 全失），作者改主意时改那一处。
##
## 仓库是个 [ItemStash]（列表，3.4）：跨局的东西没有「摆在哪」可言。仓库有自己的 uid 空间 ——
## 每局的 uid 计数从 1 重来，直接收进来会撞号，进来时重新编号；将来从仓库带进一局时再造新实例。
class_name MetaState
extends RefCounted

const SAVE_VERSION := 1
const WAREHOUSE_ID := 100
## 最近几局的账留几条
const HISTORY_MAX := 20

signal changed()

var warehouse: ItemStash = null
## 撤离带出来的钱累计。局外货币怎么花（15 节第 4 项）还没定，先攒着
var funds: int = 0
## 累计背出去的价值（6.4）
var score: int = 0
var runs: int = 0
var extractions: int = 0
var deaths: int = 0
var best_value: int = 0
## 最近几局的 [RunResult.to_dict]，新的在前
var history: Array[Dictionary] = []
var _next_uid: int = 1


func _init() -> void:
	warehouse = ItemStash.new(WAREHOUSE_ID, 0)


## 一局结束了进来。返回这次进了什么：{"items": 件数, "value": 价值, "funds": 钱}
func absorb(result: RunResult) -> Dictionary:
	var got := {"items": 0, "value": 0, "funds": 0}
	if result == null:
		return got
	runs += 1
	if result.is_extracted():
		extractions += 1
		for inst in result.carried:
			# 一局的棋盘已经作废，实例直接收进来；重新编号避免与早先几局的撞上
			inst.uid = _next_uid
			_next_uid += 1
			if warehouse.insert(inst):
				got["items"] = int(got["items"]) + 1
		funds += result.balance
		score += result.value
		best_value = maxi(best_value, result.value)
		got["value"] = result.value
		got["funds"] = result.balance
	else:
		deaths += 1
	history.push_front(result.to_dict())
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)
	changed.emit()
	return got


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"warehouse": warehouse.to_dict(),
		"next_uid": _next_uid,
		"funds": funds, "score": score, "runs": runs, "extractions": extractions, "deaths": deaths,
		"best_value": best_value,
		"history": history.duplicate(true),
	}


## 读回来。版本不对返回 null；仓库里定义被删的道具由 ItemStash.from_dict 告警后丢弃
static func from_dict(d: Dictionary, items: ItemDatabase) -> MetaState:
	if int(d.get("version", -1)) != SAVE_VERSION:
		return null
	var m := MetaState.new()
	var w = d.get("warehouse", null)
	if w is Dictionary:
		m.warehouse = ItemStash.from_dict(w, items)
		m.warehouse.id = WAREHOUSE_ID
	m._next_uid = int(d.get("next_uid", 1))
	for inst in m.warehouse.items():
		m._next_uid = maxi(m._next_uid, (inst as ItemInstance).uid + 1)
	m.funds = int(d.get("funds", 0))
	m.score = int(d.get("score", 0))
	m.runs = int(d.get("runs", 0))
	m.extractions = int(d.get("extractions", 0))
	m.deaths = int(d.get("deaths", 0))
	m.best_value = int(d.get("best_value", 0))
	for row in d.get("history", []):
		if row is Dictionary:
			m.history.append(MapGraph.normalize(row))
	return m
