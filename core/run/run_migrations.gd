## 一局存档的版本迁移链（098，架构文档 7.2）。和 [MetaMigrations] 同一套做法、同一条规矩，只是对象是 [RunState]。
##
## 作者定：**一局档走同一条链，但允许作废** —— 升不上去就按「不认识」处理（备份后从零开始，玩家丢的只是这一局，
## 局外的仓库、图鉴、战绩都还在）。
##
## 升版时在这里加一步：[const STEPS] 加一行 `老版本: "_vn_to_vn1"`，`upgrade` 的 `match` 里接上，
## 并在 `tests/fixtures/` 留一份那一版的冻结样本（`tests/test_save_migration.gd` 会扫）。
class_name RunMigrations
extends RefCounted

## 有哪几步：from_version → 方法名（文档与自检用；分派走 match，不走反射）
const STEPS := {1: "_v1_to_v2", 2: "_v2_to_v3"}


## 尽量升到 [constant RunState.SAVE_VERSION]。不改入参（深拷一份）。
## 升不上去就把能升到哪算哪，版本号照实写在 `version` 里，调用方按「不认识」处理
static func upgrade(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("version", -1))
	while v < RunState.SAVE_VERSION and STEPS.has(v):
		match v:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			_:
				push_error("RunMigrations: STEPS 里有 v%d 但 match 没接上" % v)
				return d
		v += 1
		d["version"] = v
	if int(d.get("version", -1)) != RunState.SAVE_VERSION:
		push_warning("RunMigrations: 没有 v%s → v%d 的迁移，这一局作废（局外进度不受影响）" % [str(d.get("version", "?")), RunState.SAVE_VERSION])
	return d


## v2 → v3（105）：祈祷攒的火焰加成从「次数 × 旧公式」变成标准轴 `fire_damage` 的层数。
##
## 老档只记了祈祷次数（`modules.altar.rituals.pray_fire`），层数要按曲线补算出来 ——
## 补的是**现在**的曲线（[AltarPrayFirePerk] 的默认斐波那契），所以老档祈祷 4 次读回来就是 7 层。
## 旧公式（10 × n^0.7）不保留：曲线换了是作者有意的改动（105 第四节），不是存档要兼容的东西
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	var mods: Dictionary = (d.get("modules", {}) as Dictionary).duplicate(true) if d.get("modules", {}) is Dictionary else {}
	var altar: Dictionary = mods.get("altar", {}) if mods.get("altar", {}) is Dictionary else {}
	var rituals: Dictionary = altar.get("rituals", {}) if altar.get("rituals", {}) is Dictionary else {}
	var times := int(rituals.get(AltarPrayFirePerk.KEY, 0))
	if times > 0:
		var perk := AltarPrayFirePerk.new()     # 默认曲线：gains 为空 = 斐波那契
		var stacks := 0
		for n in range(1, times + 1):
			stacks += perk.gain_at(n)
		var axes: Dictionary = altar.get("axis_bonus", {}) if altar.get("axis_bonus", {}) is Dictionary else {}
		axes[String(StatAxes.FIRE_DAMAGE)] = int(axes.get(String(StatAxes.FIRE_DAMAGE), 0)) + stacks
		altar["axis_bonus"] = axes
		mods["altar"] = altar
		d["modules"] = mods
	return d


## v1 → v2（101 第 0 / 1 刀）：一局的子系统搬成了 [RunModule]，它们的状态从顶层键挪进了 `modules[id]`。
## 这一步把老档里的顶层键搬过去（搬完删掉旧键，免得两处对不上）。
## 现在只有保险箱（`safe` / `safe_locked` → `modules.safe`）；后面每搬一个子系统，这里多几行
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var mods: Dictionary = (d.get("modules", {}) as Dictionary).duplicate(true) if d.get("modules", {}) is Dictionary else {}
	if d.has("safe") or d.has("safe_locked"):
		var safe: Dictionary = mods.get("safe", {}) if mods.get("safe", {}) is Dictionary else {}
		safe["inventory"] = d.get("safe", null)
		safe["locked"] = bool(d.get("safe_locked", false))
		mods["safe"] = safe
		d.erase("safe")
		d.erase("safe_locked")
	if d.has("carry_in_value"):
		var cd: Dictionary = mods.get("countdown", {}) if mods.get("countdown", {}) is Dictionary else {}
		cd["carry_value"] = int(d.get("carry_in_value", 0))
		mods["countdown"] = cd
		d.erase("carry_in_value")
	if d.has("faith_rituals") or d.has("faith_stat_bonus") or d.has("altar_used"):
		var al: Dictionary = mods.get("altar", {}) if mods.get("altar", {}) is Dictionary else {}
		al["rituals"] = d.get("faith_rituals", {})
		al["stat_bonus"] = d.get("faith_stat_bonus", {})
		al["used"] = d.get("altar_used", [])
		mods["altar"] = al
		d.erase("faith_rituals")
		d.erase("faith_stat_bonus")
		d.erase("altar_used")
	var buffs: Dictionary = d.get("buffs", {}) if d.get("buffs", {}) is Dictionary else {}
	if buffs.has("map"):
		var bm: Dictionary = mods.get("buff", {}) if mods.get("buff", {}) is Dictionary else {}
		bm["map"] = buffs.get("map", [])
		mods["buff"] = bm
		buffs.erase("map")
		d["buffs"] = buffs
	if d.has("node_storages"):
		var ns: Dictionary = mods.get("node_storage", {}) if mods.get("node_storage", {}) is Dictionary else {}
		ns["nodes"] = d.get("node_storages", {})
		mods["node_storage"] = ns
		d.erase("node_storages")
	d["modules"] = mods
	return d
