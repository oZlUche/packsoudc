## 305（合成与锻造改造 A，方案 §6.1）：玩家**知道**什么 —— 两个集合，各管各的：
## - 配方（[member recipes]）：自己合成成功过一次的合成配方 id。取消、预览、拿到成品、铁匠打造都不算
## - 道具（[member items]）：认识的道具 id —— 进过自己背包 / 仓库，或自己造出来（造出来落在地上也算）。只看见（敌人、商品、没捡的掉落）不算
## 和图鉴计数（[member MetaState.codex]，带出才加、参与计分）分开，图鉴不因此虚增。
## 一局里学到的先记在这一局（[member RunState.lore]，和物品变动同一份存档一次写盘），一局结束并进局外（[method MetaState.absorb]）；
## 并集天然幂等，两次写盘之间断了也不用恢复
class_name Lore
extends RefCounted

var recipes: Dictionary = {}     # String -> true
var items: Dictionary = {}       # String -> true


func learn_recipe(id: StringName) -> void:
	if id != &"":
		recipes[String(id)] = true


func meet(id: StringName) -> void:
	if id != &"":
		items[String(id)] = true


func knows_recipe(id: StringName) -> bool:
	return recipes.has(String(id))


func has_met(id: StringName) -> bool:
	return items.has(String(id))


## 并进来（只加不减）
func merge(other: Lore) -> void:
	if other == null:
		return
	for k in other.recipes:
		recipes[k] = true
	for k in other.items:
		items[k] = true


func is_empty() -> bool:
	return recipes.is_empty() and items.is_empty()


## 存档：两个排好序的 id 列表（同一份知识逐字节相同）
func to_dict() -> Dictionary:
	var r: Array = recipes.keys()
	var i: Array = items.keys()
	r.sort()
	i.sort()
	return {"recipes": r, "items": i}


static func from_dict(d: Variant) -> Lore:
	var out := Lore.new()
	if d is Dictionary:
		for k in (d as Dictionary).get("recipes", []):
			out.recipes[String(k)] = true
		for k in (d as Dictionary).get("items", []):
			out.items[String(k)] = true
	return out
