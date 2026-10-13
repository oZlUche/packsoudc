## 编译金样（报告 105 第八节第 1 条）：**改代码之前**先把 `compile_player()` 的结果逐字段录下来，
## 等信仰效果搬进编译器之后同样的输入再编一遍，逐字段相等 —— 这是整次搬家的主验收。
##
## 棋盘是固定的（一个皮革包 + 一把短剑 + 一份口粮 + 那位神的信物），`run_seed` 与时钟也是固定的，
## 信仰点到最高阶；蛮神的再在神坛上献祭 2 次生命上限。日神的金样在 **0 次祈祷**下录
## （火焰加成为 0，改成火焰轴之后两边一致）。
##
## 棋盘上只放一把武器，所以日神的「随机挑 3 把」挑的就是全部 —— 金样不依赖抽法。
## 抽法本身可复现是另一条验收（105 第八节第 2 条），在 `test_compile_input.gd` 里。
##
## **有意重录的记录**：2026-10-02（105 第十节）日神 3 级从「给挑中的武器加 −20% 耐力消耗乘区」
## 改成「开战获得 5 层灵巧（耐力消耗 ×97%^层数）」，所以日神那份的短剑少了 `stamina_cost` 的 −2000 乘区、
## 多了 `axes: {stamina_cost: 5}`；同一次给四份都加了 `axes` 字段（其余三份都是空的，数值一个没动）。
##
## **133 有意重录**（2026-10-05）：乘区只剩一个，每项属性的 `mult: [EMPOWER, SHARP, ELEMENT, HASTE]` 换成一个 `percent`（四个乘区之和）。
## 四份金样里没有一项属性同时吃到两个乘区，所以 total / base / flat 逐项不变 —— 重录前后逐项对过终值（方案里说的「弓 + 箭 + 符号 1.38 → 1.35」
## 不在这四份金样的棋盘上，那一组的变化由 test_stat_math 的「两条乘算相加」覆盖）。
##
## **142 有意重录**（2026-10-08）：力量的符号并进蛮神的护符，蛮神那份的护符多了开战血怒的规则、挨着它的短剑吃到增益槽的伤害 +15%；
## 其余三份没动。
##
## **143 有意重录**（2026-10-08）：短剑成了 4 格的异形、伤害 5 → 10，四份里短剑的伤害都翻倍；包换了大小，uid 跟着挪。
##
## **154 有意重录**（2026-10-11）：自由模式各环加了宝箱点（权重 1），同一个种子的图变了、开局造的敌人件数跟着变，四份只有 uid 挪了（+7），数值一条没动。
##
## **165 有意重录**（2026-10-13）：开局摆敌人用的是草稿实例，uid 计数原样还回去（随机摆会重来几次，不还就跟着摆法挪），四份只有 uid 挪了，数值一条没动。
##
## 录制：`RECORD_GOLDEN=1 bash tools/test.sh 金样` 会把 `tests/fixtures/compile_golden/<信仰>.json`
## 重写一遍（并断言失败，提醒别把录制开关留在 CI 里）。平时跑是**比对**。
extends RefCounted

const DIR := "res://tests/fixtures/compile_golden"
const SEED := 20261002
const CLOCK := 7

## 信仰 id → 那位神的信物
const ANCHORS := {
	&"brute": &"charm_brute",
	&"sun": &"charm_sun",
	&"nature": &"charm_nature",
	&"earth": &"charm_earth",
}
## 固定棋盘：先摆包（棋盘要包），再按这个顺序 try_add（first fit 稳定）
const BAG := &"bag_leather"
const FILL: Array[StringName] = [&"shortsword", &"ration"]
## 蛮神：神坛献祭生命上限的次数
const SACRIFICES := 2


static func _recording() -> bool:
	return OS.get_environment("RECORD_GOLDEN") != ""


static func run_compile_golden(t: TestCase) -> void:
	t.begin("编译金样（105 第八节 1）：四位主神最高阶、固定棋盘与种子，compile_player() 逐件逐字段对上金样")
	var c := TestSupport.content()
	for faith in [&"brute", &"sun", &"nature", &"earth"]:
		var run := _run_for(c, faith as StringName)
		if run == null:
			t.check(false, "%s：开局" % faith)
			continue
		var got := _shot(run)
		var path := "%s/%s.json" % [DIR, faith]
		if _recording():
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				t.check(false, "%s：写不进金样" % faith)
				continue
			f.store_string(JSON.stringify(got, "\t", false))
			f.close()
			t.check(false, "%s：录好了金样（RECORD_GOLDEN 不要留在 CI 里）" % faith)
			continue
		var want := _load(path)
		if want.is_empty():
			t.check(false, "%s：没有金样，先用 RECORD_GOLDEN=1 录一份（%s）" % [faith, path])
			continue
		_compare(t, String(faith), want, got)


## 这位神的那一局：固定种子、固定棋盘、点满到最高阶
static func _run_for(c: Dictionary, faith: StringName) -> RunState:
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var items: ItemDatabase = c["items"]
	var run := RunState.start(chapter, SEED, items, c["enemies"], c["sets"])
	if run == null:
		return null
	run.faith_defs = FaithDef.load_all()
	run.player_baseline = CombatantBaseline.with_hp(100.0)
	# 固定棋盘：清掉开局发的，按清单重摆
	run.board.clear()
	run.board.place(ItemInstance.create(items.get_def(BAG)), Vector2i(0, 0), 0)
	var order: Array[StringName] = FILL.duplicate()
	order.append(StringName(ANCHORS[faith]))
	for id in order:
		var def := items.get_def(id)
		if def == null:
			continue
		var inst := ItemInstance.create(def)
		if not run.board.try_add(inst, true):
			push_error("金样：%s 放不上棋盘" % id)
	# 时钟与阶
	if run.travel != null and run.travel.clock != null:
		run.travel.clock.total = CLOCK
	run.faith_power.add_points(faith, 1_000_000)
	if faith == &"brute":
		var altar := AltarModule.of(run)
		var perk := altar.perk(&"altar_sacrifice_hp") if altar != null else null
		for _i in SACRIFICES:
			if perk != null:
				perk.altar_apply(run, null)
	return run


## 一份编译结果的快照：max_hp、undying_sec、每件 {uid, def_id, stats, rules}、set_rules
## 轴层数：键排序后转成字符串键，JSON 往返稳定
static func _axes(axes: Dictionary) -> Dictionary:
	var out := {}
	for axis in StatAxes.ORDER:
		if axes.has(axis) and int(axes[axis]) != 0:
			out[String(axis)] = int(axes[axis])
	return out


static func _shot(run: RunState) -> Dictionary:
	var spec := run.compile_player()
	var out := {
		"faith": String(run.active_faith_id()),
		"tier": run.active_faith_tier(),
		"max_hp": spec.max_hp,
		"undying_sec": spec.undying_sec,
		# 105 第十节：开战就带的标准轴层数也是编译产物（日神 3 级的 5 层灵巧在这里）
		"axes": _axes(spec.axes),
		"baseline": _stats(spec.baseline),
		"set_rules": _rules(spec.set_rules),
		"items": [],
	}
	for it in spec.items:
		var item := it as CompiledItem
		(out["items"] as Array).append({
			"uid": item.source_uid,
			"def_id": String(item.def_id),
			"stats": _stats(item.stats),
			"rules": _rules(item.rules),
		})
	return out


## 一套属性：键 → {total, base, flat, percent}（133：乘区只剩一个，`mult: [四个乘区]` 换成一个 `percent`）。
## 只记终值不够 —— 食物翻倍动的是 `base`，乘算动的是 percent，分开记才看得出搬家有没有换落点
static func _stats(set: StatSet) -> Dictionary:
	var out := {}
	if set == null:
		return out
	for key in set.keys():
		var v := set.ensure(StringName(String(key)))
		out[String(key)] = {"total": v.total(), "base": v.base, "flat": v.flat, "percent": v.percent}
	return out


## 一串规则：每条 [扳机类名, 节奏类名, 效果类名…]
static func _rules(rules: Array) -> Array:
	var out: Array = []
	for r in rules:
		var rule := r as AbilityRule
		if rule == null:
			continue
		var row: Array = [String(ContentSchema.class_name_of(rule.trigger)), String(ContentSchema.class_name_of(rule.cadence))]
		for e in rule.effects:
			row.append(String(ContentSchema.class_name_of(e)))
		out.append(row)
	return out


static func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	return parsed as Dictionary if parsed is Dictionary else {}


## 逐字段比：先比整体骨架，再逐件比属性与规则（JSON 来回一趟数都是 float，比之前先对齐）
static func _compare(t: TestCase, faith: String, want: Dictionary, got: Dictionary) -> void:
	t.eq(int(got["tier"]), int(want["tier"]), "%s：阶一样（%d）" % [faith, int(want["tier"])])
	t.eq(int(got["max_hp"]), int(want["max_hp"]), "%s：max_hp 一样" % faith)
	t.eq(float(got["undying_sec"]), float(want["undying_sec"]), "%s：undying_sec 一样" % faith)
	t.check(_same_stats(want.get("baseline", {}), got.get("baseline", {})), "%s：基线逐属性一样" % faith)
	t.check(JSON.stringify(want.get("set_rules", [])) == JSON.stringify(got.get("set_rules", [])), "%s：套装规则一样" % faith)
	var wi: Array = want.get("items", [])
	var gi: Array = got.get("items", [])
	t.eq(gi.size(), wi.size(), "%s：件数一样（%d 件）" % [faith, wi.size()])
	if gi.size() != wi.size():
		return
	for i in wi.size():
		var w: Dictionary = wi[i]
		var g: Dictionary = gi[i]
		t.eq(int(g["uid"]), int(w["uid"]), "%s：第 %d 件 uid 一样" % [faith, i])
		t.eq(String(g["def_id"]), String(w["def_id"]), "%s：第 %d 件是 %s" % [faith, i, String(w["def_id"])])
		t.check(_same_stats(w.get("stats", {}), g.get("stats", {})),
			"%s：%s 逐属性一样（base / flat / 乘算都比）" % [faith, String(w["def_id"])])
		t.check(JSON.stringify(w.get("rules", [])) == JSON.stringify(g.get("rules", [])),
			"%s：%s 的规则一样（%s）" % [faith, String(w["def_id"]), JSON.stringify(g.get("rules", []))])


static func _same_stats(want: Dictionary, got: Dictionary) -> bool:
	if want.size() != got.size():
		push_error("金样：属性个数不一样 期望 %s 实得 %s" % [want.keys(), got.keys()])
		return false
	for key in want:
		if not got.has(key):
			push_error("金样：少了属性 %s" % key)
			return false
		var w: Dictionary = want[key]
		var g: Dictionary = got[key]
		for field in ["total", "base", "flat", "percent"]:
			if int(w.get(field, 0)) != int(g.get(field, 0)):
				push_error("金样：%s.%s 期望 %d 实得 %d" % [key, field, int(w.get(field, 0)), int(g.get(field, 0))])
				return false
	return true
