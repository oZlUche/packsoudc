## 129（作者定）：负重分级 —— 负重超过上限的倍数决定第几级，每级减战斗属性（不碰伤害：只减急速、耐力回复、耐力上限），最后一级走路翻倍。
##
## 作者原话：「设计多个递进的负重等级，负重达到某个阈值时触发，第一级小幅度降低战斗属性，第二级中幅度降低战斗属性，
## 第三级将从节点移动花费的时间翻倍」；补充：「不要直接降低伤害，可以降低耐力恢复、上限和急速」。
## 作者数据，走内容管线：`data/authoring/encumbrance_rules/*.json` → `data/encumbrance_rules/*.tres`，章节按 id 引用（空 = 不算负重）。
## 负重本身（棋盘上的重量之和、上限）在 [RunState]；这里只回答「这个负重、这个上限，是第几级、减什么」
class_name EncumbranceRules
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 按 `over` 从小到大排；级数 = 命中的最后一行的下标 + 1，一行都没命中 = 0（轻装）
@export var levels: Array[EncumbranceLevel] = []


## [param weight] 负重、[param capacity] 上限 → 第几级（0 = 轻装）。上限 ≤ 0 = 不算负重
func level_of(weight: int, capacity: int) -> int:
	if capacity <= 0:
		return 0
	var lv := 0
	for i in levels.size():
		if float(weight) > float(capacity) * levels[i].over:
			lv = i + 1
	return lv


## 第 [param level] 级那一行（0 级 / 越界 null）
func row(level: int) -> EncumbranceLevel:
	if level <= 0 or level > levels.size():
		return null
	return levels[level - 1]


func name_of(level: int) -> String:
	var r := row(level)
	return Names.of(r) if r != null else UiText.t("run.load_light")


func travel_mult_of(level: int) -> int:
	var r := row(level)
	return maxi(1, r.travel_mult) if r != null else 1


## 这一级的战斗减益，按 [param baseline] 折成真值：`{"items": 给每件参战道具的（急速）, "baseline": 给角色基线的（耐力回复 / 上限）}`
func combat_mods(level: int, baseline: CombatantBaseline) -> Dictionary:
	var out := {"items": [] as Array[StatModifier], "baseline": [] as Array[StatModifier]}
	var r := row(level)
	if r == null:
		return out
	var base := baseline if baseline != null else CombatantBaseline.default_baseline()
	for m in r.mods:
		var key := String(m.stat)
		if key.begins_with(BattleStats.MAX_PREFIX) or key.begins_with(BattleStats.REGEN_PREFIX):
			var real := StatModifier.new()
			real.stat = m.stat
			real.mode = m.mode
			real.amount = m.amount if m.is_mult() else m.amount * base.value_of(m.stat, BattleStats.default_value(m.stat))
			(out["baseline"] as Array[StatModifier]).append(real)
		else:
			(out["items"] as Array[StatModifier]).append(m)
	return out


## 这一级减了什么，一句话（「急速 −10%、耐力回复 −10%、走一步倒计时 −2」）
func effect_text(level: int) -> String:
	var r := row(level)
	if r == null:
		return ""
	var parts: Array[String] = []
	for m in r.mods:
		var what := Glossary.stat_name(m.stat)
		if m.amount == 0.0:
			continue
		var pct := roundi(m.amount) if m.is_mult() else roundi(m.amount * 100.0)     # 加算的上限 / 回复按基线比例写，所以也显示成百分数
		parts.append("%s %s%d%%" % [what, "+" if pct > 0 else "−", absi(pct)])
	if r.travel_mult > 1:
		parts.append(UiText.t("run.load_step_cost") % r.travel_mult)
	return UiText.t("hud.buff_sep").join(parts)
