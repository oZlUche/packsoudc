## 一局存档的版本迁移链（098，架构文档 7.2）。和 [MetaMigrations] 同一套做法、同一条规矩，只是对象是 [RunState]。
##
## 作者定：**一局档走同一条链，但允许作废** —— 升不上去就按「不认识」处理（备份后从零开始，玩家丢的只是这一局，
## 局外的仓库、图鉴、战绩都还在）。
##
## 升版时在这里加一步 `_vn_to_vn1`，`upgrade` 的 `match` 里接上，
## 并在 `tests/fixtures/` 留一份那一版的冻结样本（`tests/test_save_migration.gd` 会扫）。
class_name RunMigrations
extends RefCounted

## v6 那一版祈愿的默认上限（372 起祈愿删了，只有迁移还认它）
const PRAYER_CAP_V6 := 100
## 372 v7 → v8：老信力折成经验值的倍数（老门槛 20 / 60 / 120 ≈ 新的第 5 / 10 / 15 级 42 / 117 / 217 点）
const XP_PER_DEVOTION := 2.0


## 尽量升到 [constant RunState.SAVE_VERSION]。不改入参（深拷一份）。
## 升不上去就把能升到哪算哪，版本号照实写在 `version` 里，调用方按「不认识」处理
static func upgrade(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("version", -1))
	while v < RunState.SAVE_VERSION:
		match v:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			3:
				d = _v3_to_v4(d)
			4:
				d = _v4_to_v5(d)
			5:
				d = _v5_to_v6(d)
			6:
				d = _v6_to_v7(d)
			7:
				d = _v7_to_v8(d)
			_:
				break     # 没有这一步的迁移：停在这一版，下面照实报
		v += 1
		d["version"] = v
	if int(d.get("version", -1)) != RunState.SAVE_VERSION:
		push_warning("RunMigrations: 没有 v%s → v%d 的迁移，这一局作废（局外进度不受影响）" % [str(d.get("version", "?")), RunState.SAVE_VERSION])
	return d


## v5 → v6（信仰重构 B，交接方案 §8.2 第 3、4 条）：一个池子的信力 P 拆成信力（成长）与祈愿（消费）：
## devotion = P，prayer = min(P, 上限)。这是一次明确的兼容补偿：不恢复历史上花掉的，不从日志猜总收益。
## 上限按当时的默认值（[constant PRAYER_CAP_V6]；迁移看不到信仰定义）。已经有 `faith_progress` 的档不动 ——
## 重复迁移不会因为祈愿花掉了再补齐
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	if d.get("faith_progress", null) is Dictionary:
		d.erase("faith_power")
		return d
	var old: Dictionary = d.get("faith_power", {}) if d.get("faith_power", {}) is Dictionary else {}
	var out := {}
	for key in old:
		var raw: Variant = old[key]
		var p := maxi(0, int(raw)) if (raw is int or raw is float) else 0
		out[String(key)] = {"devotion": p, "prayer": mini(p, PRAYER_CAP_V6)}
	d["faith_progress"] = out
	d.erase("faith_power")
	return d


## v4 → v5（信仰重构 A，2026-11-19）：信仰从「棋盘上最后置入的信物说了算」改成玩家显式选择（`faith_selection`）。
## 迁移这一步看不到道具定义（谁是信物要读 [ItemDef]），所以只标一句 `derive`：[method RunState.from_dict] 在棋盘恢复、
## 内容对账之后按旧规则推一次，下次存档写成真正的选择。已经有选择的档不动（重复迁移结果一样）
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	if not (d.get("faith_selection", null) is Dictionary):
		d["faith_selection"] = {"derive": true}
	return d


## v3 → v4（140）：猎手 134 之前的单档写法（`loss_outcomes` 合成的 `default` 档）删了。
## 老档里记着那一档的猎手改成不记（读回来按现行 `loss_options` 的第一档）；等着选的、不带档名的猎手遭遇丢掉 ——
## 猎手还在原处，下一步够得着就按现行的档重新生成那一屏
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	var hs: Dictionary = d.get("hunters", {}) if d.get("hunters", {}) is Dictionary else {}
	for row in hs.get("hunters", []):
		if row is Dictionary and String((row as Dictionary).get("loss", "")) == "default":
			(row as Dictionary)["loss"] = ""
	var ev: Dictionary = d.get("events", {}) if d.get("events", {}) is Dictionary else {}
	var pending: Dictionary = ev.get("pending", {}) if ev.get("pending", {}) is Dictionary else {}
	var eid := String(pending.get("event", ""))
	if eid.begins_with(HunterSystem.ENCOUNTER_PREFIX) and not eid.contains("/"):
		ev["pending"] = {}
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


## v6 → v7（342 B3）：加这一局的材料倾向 —— 老档出征时没有这一项，按无倾向
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	if not d.has("material_bias"):
		d["material_bias"] = ""
	return d


## v7 → v8（372，2026-11-22）：信仰和升级合成一个系统。每位神 {devotion 信力, prayer 祈愿} → 这一局一池经验值（`modules.level.xp`）：
## 取所奉那一位的信力（没奉神取最多的那一位），乘 [constant XP_PER_DEVOTION]；祈愿整个丢掉（作者 18:30：祈愿删掉）。
## 折出来的等级当欠着的选牌，回到地图就选。已经有 `modules.level` 的档不动
static func _v7_to_v8(d: Dictionary) -> Dictionary:
	var mods: Dictionary = d.get("modules", {}) if d.get("modules", {}) is Dictionary else {}
	var prog: Dictionary = d.get("faith_progress", {}) if d.get("faith_progress", {}) is Dictionary else {}
	d.erase("faith_progress")
	if mods.get("level", null) is Dictionary:
		d["modules"] = mods
		return d
	var sel := ""
	var fs: Variant = d.get("faith_selection", null)
	if fs is Dictionary:
		sel = String((fs as Dictionary).get("selected_id", ""))
	var best := 0
	for key in prog:
		var row: Variant = prog[key]
		var dv: Variant = (row as Dictionary).get("devotion", 0) if row is Dictionary else 0
		var p := maxi(0, int(dv)) if (dv is int or dv is float) else 0
		if sel != "" and String(key) == sel:
			best = p
			break
		best = maxi(best, p)
	mods["level"] = {"xp": float(best) * XP_PER_DEVOTION}
	d["modules"] = mods
	return d
