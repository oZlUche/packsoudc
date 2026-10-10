## 战斗的内部日志（117，作者定）：「用于检查和内部阅读，不需要展示给玩家，尽可能详细并带有时间 tag」。
##
## 和 [member BattleResult.log] 是两件东西：
## [codeblock]
## BattleResult.log   回放要的事件（VIEW_EVENTS），与掩码无关，玩家看
## BattleTrace        全量：每条事件（不管有没有人听）、规则出手 / 跳过与原因、伤害管线每一级、
##                    每次取随机数、buff 叠层 / 到期、时间轮、每 5 秒的快照 —— 只给作者和 AI 线程查数值
## [endcodeblock]
## 挂在 [member BattleContext.trace] 上，**默认 null**：关着时每个记录点只有一行 `if trace != null`，不建任何对象。
## 记录本身不碰战斗状态、不取随机数，所以开不开 trace 同一场打出来逐条一样（测试守着）。
##
## 每条 `{seq, t（定点秒）, side, kind, data}`。时间 tag 是模拟内的定点秒（整场开战一瞬算完，逐条记现实时间没有意义），
## 现实时间只在 [member header] 里写一次。写文件是 [BattleTraceWriter] 的事，这里只收集与排版
class_name BattleTrace
extends RefCounted

## 快照的节拍（定点秒）
const SNAPSHOT_EVERY := 5 * StatMath.ONE

const EVENT := "event"
const RULE_FIRE := "rule_fire"
const RULE_SKIP := "rule_skip"
const DAMAGE := "damage_pipeline"
const RNG := "rng"
const BUFF := "buff"
const SCHEDULE := "schedule"
const SNAPSHOT := "snapshot"

## 文件头：现实时间、种子、章节、点、敌人、双方道具名表与棋盘、时限……由调用方（[NodeEvents]、沙盒）填
var header: Dictionary = {}
## 全部条目，按发生顺序
var entries: Array[Dictionary] = []
## 下一次快照的时刻
var next_snapshot: int = 0


func record(t: int, side: int, kind: String, data: Dictionary = {}) -> void:
	entries.append({"seq": entries.size(), "t": t, "side": side, "kind": kind, "data": data})


## 某一类的全部条目
func of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if String(e["kind"]) == kind:
			out.append(e)
	return out


#region 文件格式
## `.jsonl`：第一行是文件头（`{"kind": "header", ...}`），之后一行一条
func to_jsonl() -> String:
	var lines := PackedStringArray()
	var head := header.duplicate()
	head["kind"] = "header"
	lines.append(JSON.stringify(head))
	for e in entries:
		lines.append(JSON.stringify(e))
	return "\n".join(lines) + "\n"


## 读回 `.jsonl`：`{header, entries}`。坏行跳过（数一下放进 `bad`）
static func parse_jsonl(text: String) -> Dictionary:
	var head := {}
	var out: Array[Dictionary] = []
	var bad := 0
	var json := JSON.new()
	for line in text.split("\n", false):
		var parsed = json.data if json.parse(line) == OK else null
		if not (parsed is Dictionary):
			bad += 1
			continue
		if String(parsed.get("kind", "")) == "header":
			head = parsed
		else:
			out.append(parsed)
	return {"header": head, "entries": out, "bad": bad}


## `.txt`：人读，文件头几行 + 一行一条
func to_text() -> String:
	return "\n".join(format_lines(header, entries)) + "\n"


## 排版：文件头 + 每条一行，例 `[  3.200s] S0 fire    小刀#3 …`。`.txt` 与 `replay_log` 命令行共用
static func format_lines(head: Dictionary, list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("# 战斗日志　%s" % String(head.get("when", "")))
	for key in ["run_seed", "chapter", "node", "enemy", "rng_seed", "time_limit"]:
		if head.has(key):
			out.append("# %s: %s" % [key, str(head[key])])
	var names: Array = head.get("names", [{}, {}])
	for side in 2:
		var row := PackedStringArray()
		var table: Dictionary = names[side] if side < names.size() and names[side] is Dictionary else {}
		var uids: Array = table.keys()
		uids.sort_custom(func(a, b) -> bool: return int(a) < int(b))
		for uid in uids:
			row.append("%s#%s" % [String(table[uid]), str(uid)])
		out.append("# S%d 道具: %s" % [side, "、".join(row)])
	out.append("# 数值：event 行的载荷是定点原值（÷%d），其余各行已换算；时间是模拟内的秒" % StatMath.ONE)
	out.append("")
	for e in list:
		out.append(format_entry(e, names))
	return out


## 一条的一行
static func format_entry(e: Dictionary, names: Array = []) -> String:
	var side := int(e.get("side", -1))
	var who := "S%d" % side if side >= 0 else "--"
	var kind := String(e.get("kind", ""))
	var d: Dictionary = e.get("data", {})
	var body := ""
	match kind:
		EVENT:
			body = "event   %s %s" % [String(d.get("name", "")), _kv(d.get("payload", {}), names, side)]
		RULE_FIRE:
			body = "fire    %s ← %s%s%s" % [_rule(d, names, side), String(d.get("trigger", "")), _paid(d.get("costs", [])),
				("　下次就绪 %ss" % _sec(int(d["ready_at"]))) if d.has("ready_at") else ""]
		RULE_SKIP:
			body = "skip    %s %s" % [_rule(d, names, side), _reason(d)]
		DAMAGE:
			body = "damage  %s" % _pipeline(d, names)
		RNG:
			body = "rng     %s %d ∈ [%d, %d]%s" % [String(d.get("purpose", "")), int(d.get("value", 0)),
				int(d.get("lo", 0)), int(d.get("hi", 0)), ("　≤ %d → %s" % [int(d["need"]), "中" if bool(d.get("hit", false)) else "不中"]) if d.has("need") else ""]
		BUFF:
			body = "buff    %s %s%d → %d 层%s" % [String(d.get("buff", "")), "+" if int(d.get("delta", 0)) >= 0 else "",
				int(d.get("delta", 0)), int(d.get("stacks", 0)), _buff_tail(d)]
		SCHEDULE:
			body = "tick    本刻结算 %d 条自发规则（时间轮还剩 %d 条）" % [int(d.get("rules", 0)), int(d.get("heap", 0))]
		SNAPSHOT:
			body = "snap    %s %s" % [String(d.get("label", "")), _snap(d.get("state", {}))]
		_:
			body = "%s %s" % [kind, str(d)]
	return "[%8ss] %s %s" % [_sec(int(e.get("t", 0))), who, body]


## 摘要（`replay_log --summary`）：双方总伤害、每件道具出手 / 跳过次数、暴击率、buff 总层数
static func summarize(head: Dictionary, list: Array) -> PackedStringArray:
	var names: Array = head.get("names", [{}, {}])
	var dealt := [0, 0]
	var fires := [{}, {}]
	var skips := [{}, {}]
	var crits := [0, 0]
	var hits := [0, 0]
	var stacks := [{}, {}]
	for e in list:
		var side := int(e.get("side", -1))
		var d: Dictionary = e.get("data", {})
		match String(e.get("kind", "")):
			DAMAGE:
				var src := int(d.get("source_side", -1))
				if src >= 0 and src <= 1 and src != int(d.get("victim", -1)) and int(d.get("hp_lost", 0)) > 0:
					dealt[src] += int(d.get("hp_lost", 0))
				if src >= 0 and src <= 1 and bool(d.get("direct", false)):
					hits[src] += 1
					if bool(d.get("crit", false)):
						crits[src] += 1
			RULE_FIRE:
				if side >= 0 and side <= 1 and int(d.get("uid", 0)) != 0:
					var k := _rule(d, names, side)
					fires[side][k] = int(fires[side].get(k, 0)) + 1
			RULE_SKIP:
				if side >= 0 and side <= 1 and int(d.get("uid", 0)) != 0:
					var k2 := _rule(d, names, side)
					skips[side][k2] = int(skips[side].get(k2, 0)) + 1
			BUFF:
				if side >= 0 and side <= 1 and int(d.get("delta", 0)) > 0:
					var b := String(d.get("buff", ""))
					stacks[side][b] = int(stacks[side].get(b, 0)) + int(d.get("delta", 0))
	var out := PackedStringArray()
	out.append("# 摘要　%s　%s" % [String(head.get("when", "")), String(head.get("enemy", ""))])
	for side in 2:
		out.append("S%d　造成伤害 %s　直接命中 %d 次、暴击 %d 次（%s）" % [side, _num(dealt[side]), hits[side], crits[side],
			("%.0f%%" % (100.0 * crits[side] / hits[side])) if hits[side] > 0 else "—"])
		for k in fires[side]:
			out.append("　出手 %s × %d" % [k, int(fires[side][k])])
		for k in skips[side]:
			out.append("　跳过 %s × %d" % [k, int(skips[side][k])])
		for b in stacks[side]:
			out.append("　buff %s 共叠 %d 层" % [b, int(stacks[side][b])])
	return out
#endregion


#region 排版小件
## 定点秒 → `3.200`
static func _sec(t: int) -> String:
	return "%.3f" % StatMath.to_float(t)


## 定点数 → 去掉多余的 0（`5`、`1.5`、`0.07`）
static func _num(v: int) -> String:
	var s := "%.4f" % StatMath.to_float(v)
	s = s.rstrip("0")
	return s.rstrip(".") if s.ends_with(".") else s


static func _item(uid: int, names: Array, side: int) -> String:
	if uid == 0:
		return "（非道具）"
	var table: Dictionary = names[side] if side >= 0 and side < names.size() and names[side] is Dictionary else {}
	var n = table.get(uid, table.get(str(uid), null))
	return "%s#%d" % [String(n), uid] if n != null else "#%d" % uid


static func _rule(d: Dictionary, names: Array, side: int) -> String:
	var s := _item(int(d.get("uid", 0)), names, side)
	if String(d.get("buff", "")) != "":
		s += "[buff %s]" % String(d["buff"])
	return s


static func _reason(d: Dictionary) -> String:
	match String(d.get("reason", "")):
		"cost":
			var c: Dictionary = d.get("cost", {})
			if c.has("resource"):
				return "%s 不够（%s / %s）" % [String(c["resource"]), _num(int(c.get("have", 0))), _num(int(c.get("need", 0)))]
			return "条件不成立（%s）" % String(c.get("cost", "?"))
		"cadence":
			return "频率没放行"
	return String(d.get("reason", ""))


## 出手付了什么：资源消耗写「耐力 −8（余 12）」，别的条件不写
static func _paid(costs: Variant) -> String:
	var out := ""
	if costs is Array:
		for c in costs:
			if c is Dictionary and (c as Dictionary).has("resource"):
				out += "　%s −%s（余 %s）" % [String(c["resource"]), _num(int(c.get("need", 0))), _num(int(c.get("have", 0)))]
	return out


static func _pipeline(d: Dictionary, names: Array) -> String:
	var src := int(d.get("source_side", -1))
	var parts := PackedStringArray()
	parts.append("%s → S%d %s raw %s" % [_item(int(d.get("uid", 0)), names, src) if src >= 0 else "无主",
		int(d.get("victim", -1)), String(d.get("type", "")), _num(int(d.get("raw_in", 0)))])
	if bool(d.get("crit", false)):
		parts.append("暴击（已乘进 raw）")
	if int(d.get("raw", 0)) != int(d.get("raw_in", 0)):
		parts.append("火焰加成 → %s" % _num(int(d["raw"])))
	if int(d.get("absorbed", 0)) != 0:
		parts.append("护盾 −%s" % _num(int(d["absorbed"])))
	if bool(d.get("cancelled", false)):
		parts.append("受伤前效果取消")
	if int(d.get("percent", 0)) != 0:
		parts.append("受伤前 %+.0f%%" % (100.0 * StatMath.to_float(int(d["percent"]))))
	if int(d.get("flat", 0)) != 0:
		parts.append("受伤前 %s" % _num(int(d["flat"])))
	if bool(d.get("inverted", false)):
		parts.append("反转成治疗")
	if int(d.get("block", 0)) != 0:
		parts.append("格挡 %s" % _num(-int(d["block"])))
	if int(d.get("taken", StatMath.ONE)) != StatMath.ONE:
		parts.append("受到伤害 ×%s" % _num(int(d["taken"])))
	parts.append("最终 %s（血 %s → %s）" % [_num(int(d.get("final", 0))), _num(int(d.get("hp_before", 0))), _num(int(d.get("hp_after", 0)))])
	if not bool(d.get("direct", false)):
		parts.append("非直接")
	return " → ".join(parts)


static func _buff_tail(d: Dictionary) -> String:
	var tail := ""
	if String(d.get("reason", "")) != "":
		tail += "（%s）" % String(d["reason"])
	if int(d.get("expires_at", -1)) >= 0:
		tail += "　到期 %ss" % _sec(int(d["expires_at"]))
	return tail


static func _snap(state: Dictionary) -> String:
	var parts := PackedStringArray()
	for s in state.get("sides", []):
		var sd: Dictionary = s
		var res := PackedStringArray()
		var pool: Dictionary = sd.get("resources", {})
		for k in pool:
			var v: Array = pool[k]
			res.append("%s %s/%s" % [String(k), str(v[0]), str(v[1])])
		var buffs: Dictionary = sd.get("buffs", {})
		parts.append("S%d %s%s" % [int(sd.get("side", 0)), " ".join(res), ("　buff " + str(buffs)) if not buffs.is_empty() else ""])
	return " | ".join(parts)


static func _kv(payload: Variant, names: Array, side: int) -> String:
	if not (payload is Dictionary):
		return str(payload)
	var parts := PackedStringArray()
	for k in payload:
		var v = payload[k]
		if String(k) == "uid" and int(v) != 0:
			var owner := side
			if (payload as Dictionary).has("source_side"):
				owner = int(payload["source_side"])
			parts.append("uid=%s" % _item(int(v), names, owner))
		else:
			parts.append("%s=%s" % [String(k), str(v)])
	return " ".join(parts)
#endregion
