## 平衡检测方案（2026-11-10）§5：一场战斗的诊断包 —— 开打那一刻双方的完整编译结果、随机数的种子和状态、时限、加时规则，
## 再加上当时打出来的结果摘要（[member expected]），离线重跑一遍就能比对（`tools/reproduce_battle.gd`）。
##
## 存成文本资源（`.diag.tres`）：规则子资源原样写进去，外部的 buff 定义等按路径引用。回放存档（`.replay.json`）不受影响。
## 重跑只调 [BattleSim]，不结算、不碰存档、不发奖励
class_name BattleDiagPack
extends Resource

const FORMAT := 1
const EXT := ".diag.tres"

@export var format: int = FORMAT
## 构建、引擎、局 / 战斗标识、章节、点、对手、来源、时间……（[BattleDiagnostics] 填）
@export var meta: Dictionary = {}
## 两方，[BattleInputCodec] 编的
@export var sides: Array[Dictionary] = []
## 两方共用的规则表
@export var rules: Array[AbilityRule] = []
@export var rng_seed: int = 0
## 开打前随机数的状态（同一个随机数先抽了敌人、配了装再拿来打的时候，只有种子不够）
@export var rng_state: int = 0
@export var time_limit: float = BattleSim.DEFAULT_TIME_LIMIT
@export var overtime: OvertimeRules = null
## 当时的结果摘要：[method summary]
@export var expected: Dictionary = {}


## 开打前抓一份（只读深拷贝，之后对 [param a] / [param b] 的改动不影响它）
static func capture(a: CombatantSpec, b: CombatantSpec, rng: RandomNumberGenerator, limit: float, p_overtime: OvertimeRules,
		p_meta: Dictionary = {}) -> BattleDiagPack:
	var pack := BattleDiagPack.new()
	var index := {}
	pack.sides = [BattleInputCodec.encode(a, pack.rules, index), BattleInputCodec.encode(b, pack.rules, index)] as Array[Dictionary]
	pack.rng_seed = rng.seed
	pack.rng_state = rng.state
	pack.time_limit = limit
	pack.overtime = p_overtime
	pack.meta = p_meta.duplicate(true)
	return pack


## 按包里的输入重跑一遍
func rerun() -> BattleResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	rng.state = rng_state
	return BattleSim.run(BattleInputCodec.decode(sides[0], rules), BattleInputCodec.decode(sides[1], rules), rng, time_limit, overtime)


## 能不能重跑：格式认得、两方都在、规则表里没有读不出来的空位
func problems() -> Array[String]:
	var out: Array[String] = []
	if format != FORMAT:
		out.append("format %d（只认 %d）" % [format, FORMAT])
	if sides.size() != 2:
		out.append("应有两方，实际 %d" % sides.size())
	for i in rules.size():
		if rules[i] == null or not rules[i].is_valid():
			out.append("规则 %d 读不出来或不完整（缺资源？）" % i)
	return out


## 一场结果的摘要：胜方、时长、两方最终资源、事件条数、规范化事件的摘要与逐条文本（找第一处不同用）
static func summary(result: BattleResult) -> Dictionary:
	var lines: Array[String] = []
	for e in result.log:
		lines.append(event_line(e))
	return {"winner": result.winner, "duration": result.duration, "final": JSON.from_native(result.final),
		"events": lines.size(), "digest": "\n".join(lines).sha256_text().substr(0, 16), "lines": lines}


## 一条事件的规范文本：时刻、哪一方、名字、payload（键排序）
static func event_line(e: BattleEvent) -> String:
	return "%d|%d|%s|%s" % [e.time, e.side, String(e.name), JSON.stringify(JSON.from_native(e.payload), "", true)]


## 和 [param want]（[method summary] 的产物）比：一样返回空；不一样返回 {field, index?, want, got}，事件只报第一处不同
static func compare(want: Dictionary, got: Dictionary) -> Dictionary:
	for k in ["winner", "duration"]:
		if want.get(k) != got.get(k):
			return {"field": k, "want": want.get(k), "got": got.get(k)}
	var wl: Array = want.get("lines", [])
	var gl: Array = got.get("lines", [])
	for i in mini(wl.size(), gl.size()):
		if String(wl[i]) != String(gl[i]):
			return {"field": "event", "index": i, "want": wl[i], "got": gl[i]}
	if wl.size() != gl.size():
		return {"field": "events", "want": wl.size(), "got": gl.size()}
	if JSON.stringify(want.get("final"), "", true) != JSON.stringify(got.get("final"), "", true):
		return {"field": "final", "want": want.get("final"), "got": got.get("final")}
	return {}
