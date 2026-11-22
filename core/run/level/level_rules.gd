## 372（作者定）：局内成长的规矩 —— 经验值从哪来、几点升一级、每级出几张牌、牌池里有哪些牌。
##
## 经验值就是原来的信力（作者 2026-11-21 22:02 改名）：打赢战斗、第一次进更深一环、神坛献祭与祷告、各位神喜欢的事都涨它，
## 只涨不花；够了升一级，每级从三张牌里挑一张（[LevelModule]）。撤离或阵亡后全部清零。
## 数都是报告 372 第三节的建议初值，作者改 json 不动代码。
##
## 走内容管线：`data/authoring/base_rules/level.json` → `data/base_rules/level.tres`（[method load_rules]）。
## 牌本身是一局的 buff（`data/authoring/run_buffs/card_*.json`，scope MAP）：效果、名字都在那里；这里只记牌在池里的身份
class_name LevelRules
extends Resource

const ID := &"level"
## 牌的三类（报告 372 第三节第 3 小节）
const KIND_STAT := &"stat"
const KIND_WEAPON := &"weapon"
const KIND_EXPLORE := &"explore"
const KINDS: Array[StringName] = [KIND_STAT, KIND_WEAPON, KIND_EXPLORE]
## 出牌条件（[member cards] 的 `requires`）：背包里得有武器 / 得有会施加元素的道具
const REQ_WEAPON := &"weapon"
const REQ_ELEMENT := &"element"
## 元素回响三张牌（作者 18:53）：本体、间隔减少、层数增加（`echo` 那一格）
const ECHO_BODY := &"body"
const ECHO_FASTER := &"faster"
const ECHO_STACKS := &"stacks"
## 一次性的「下一次搜索多翻一件」（`oneshot` 那一格）
const ONESHOT_SEARCH := &"search"

@export var id: StringName = &""
@export var display_name: String = ""
## 等级上限（作者定 30）
@export var level_cap: int = 30
## 从第 n 级升第 n+1 级要 [member cost_base] + n × [member cost_step] 点（作者定 8 + n）
@export var cost_base: int = 8
@export var cost_step: int = 1
## 经验值的难度系数（作者 18:30：越难涨得越快，所有途径都算）：1 + 档 × 这个（A0 为 1，A12 为 1.6）
@export var difficulty_step: float = 0.05
## 打赢一场给几点：battle 普通 / elite 精英 / hunter 猎手 / core 首领；别的（搜索遭遇）按普通
@export var battle: Dictionary = {}
## 第一次到达更深一环（地图节点的 [member MapNode.tier]）给几点，每多一环一次
@export var depth: int = 8
## 神坛献祭：每座神坛最多换几点（献祭本身的换算照各位神的规矩）
@export var offering_cap: int = 20
## 神坛祷告（作者 18:30）：一次给几点、每座神坛最多几次（占的那一个行动点写在休息点事件的选项里：`pass_time`）。奉不奉神都能做
@export var prayer: int = 5
@export var prayers_per_altar: int = 3
## 每级出几张牌
@export var choices: int = 3
## 【无信者】（不奉神）逢这个数的倍数级多选一次通用牌（作者 18:30）
@export var extra_pick_every: int = 5
## 元素回响（作者 18:53）：本体每 [member echo_seconds] 秒一次、多 1 层；「间隔减少」每张减 1 秒，到 [member echo_min_seconds] 为止；「层数增加」每张多 1 层
@export var echo_seconds: int = 8
@export var echo_min_seconds: int = 3
## 牌池：牌的 id（= `run_buffs` 里那份 buff 的 id）→ {kind: 三类之一, weight: 出牌权重（默认 1）, requires: 出牌条件（可空）,
## after: 拿过这张之后才进池, once: 拿过就不再出, echo: 元素回响的哪一张, oneshot: 一次性效果}
@export var cards: Dictionary = {}

static var _rules: LevelRules = null


## 资产里的规矩（没导入时用默认）
static func load_rules() -> LevelRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(ID)) as LevelRules
		if _rules == null:
			_rules = LevelRules.new()
	return _rules


## 从第 [param n] 级升到下一级要几点
func cost_at(n: int) -> int:
	return maxi(1, cost_base + cost_step * n)


## 到第 [param level] 级累计要几点（1 级 = 0）
func total_for(level: int) -> int:
	var sum := 0
	for n in range(1, clampi(level, 1, level_cap)):
		sum += cost_at(n)
	return sum


## 累计 [param xp] 点是第几级（封顶 [member level_cap]）
func level_of(xp: float) -> int:
	var lv := 1
	var need := 0.0
	while lv < level_cap:
		need += cost_at(lv)
		if xp + 0.0001 < need:
			break
		lv += 1
	return lv


## 难度系数（[param tier] = [member DifficultyDef.level]）
func mult(tier: int) -> float:
	return 1.0 + difficulty_step * float(maxi(0, tier))


## 打赢一场这一类给几点
func battle_xp(kind: StringName) -> int:
	return int(battle.get(String(kind), battle.get("battle", 0)))


## 一张牌的那一行（不在池里 = 空）
func card(card_id: StringName) -> Dictionary:
	var c: Variant = cards.get(String(card_id), null)
	return c as Dictionary if c is Dictionary else {}


func card_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys := cards.keys()
	keys.sort()
	for k in keys:
		out.append(StringName(String(k)))
	return out


func kind_of(card_id: StringName) -> StringName:
	return StringName(String(card(card_id).get("kind", "")))


func weight_of(card_id: StringName) -> float:
	return float(card(card_id).get("weight", 1.0))
