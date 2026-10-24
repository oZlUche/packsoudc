## 171 §3（作者定）：增益 / 受益句由字段生成 ——「【增益】武器增伤 15%」：条件来自标签（OR 写「XX、YY」、AND 连写「XXYY」），
## 效果名来自属性的句式名 / buff 的解说或名字，数值是基础轴的简单换算（乘算 10%、加算 +5）。旧的「增益槽 ×N：给站在那儿的邻居…」删掉。
extends RefCounted


static func _mult(stat: StringName, amount: float) -> StatModifier:
	return StatModifier.make(stat, StatModifier.Mode.MULT, amount)


static func _add(stat: StringName, amount: float) -> StatModifier:
	return StatModifier.make(stat, StatModifier.Mode.ADD, amount)


static func run_grant_sentence(t: TestCase) -> void:
	t.begin("171 · 增益句：武器增伤 10%（单个条件）/ 防具、盾（OR）/ 帝国武器（AND）/ AND 在前接 OR / 都空写邻居；多条效果用、连")
	var saved := UiText.lang
	UiText.lang = "zh"
	var adj := AdjacencyProfile.new()
	adj.grant_cells = [Vector2i(1, 0)] as Array[Vector2i]
	adj.grant_mods = [_mult(&"damage", 10.0)] as Array[StatModifier]
	adj.grant_filter = [&"weapon"] as Array[StringName]
	t.eq(AdjacencyText.grant(adj), "武器增伤 10%", "单个条件")
	adj.grant_filter = [&"armor", &"shield"] as Array[StringName]
	t.eq(AdjacencyText.grant(adj), "防具、盾增伤 10%", "OR：XX、YY")
	adj.grant_filter = [] as Array[StringName]
	adj.grant_filter_all = [&"imperial", &"weapon"] as Array[StringName]
	t.eq(AdjacencyText.grant(adj), "帝国武器增伤 10%", "AND：XXYY 连写")
	adj.grant_filter = [&"armor", &"shield"] as Array[StringName]
	adj.grant_filter_all = [&"imperial"] as Array[StringName]
	t.eq(AdjacencyText.grant(adj), "帝国防具、盾增伤 10%", "AND 组在前，接 OR 组")
	adj.grant_filter = [] as Array[StringName]
	adj.grant_filter_all = [] as Array[StringName]
	adj.grant_mods = [_mult(&"damage", 10.0), _mult(&"haste", 5.0), _add(&"max_armor", 5.0)] as Array[StatModifier]
	t.eq(AdjacencyText.grant(adj), "邻居增伤 10%、加速 5%、护甲 +5", "条件都空写邻居；多条用、连；加算带加号")
	adj.grant_mods = [_add(&"damage", 3.0)] as Array[StatModifier]
	t.eq(AdjacencyText.grant(adj), "邻居伤害 +3", "伤害的加算还叫伤害")
	UiText.lang = saved


static func run_grant_accepts(t: TestCase) -> void:
	t.begin("171 · AND 条件真的生效：grant_filter_all 要全部带上；编译与棋盘画的点亮一致")
	var adj := AdjacencyProfile.new()
	adj.grant_filter_all = [&"imperial", &"weapon"] as Array[StringName]
	var both := ItemDef.new()
	both.tags = [&"weapon", &"imperial", &"melee"] as Array[StringName]
	var one := ItemDef.new()
	one.tags = [&"weapon"] as Array[StringName]
	t.check(adj.grant_accepts(both), "两个都带：吃得到")
	t.check(not adj.grant_accepts(one), "只带一个：吃不到")
	adj.grant_filter = [&"melee"] as Array[StringName]
	t.check(adj.grant_accepts(both), "AND + OR 都满足：吃得到")
	adj.grant_filter = [&"ranged"] as Array[StringName]
	t.check(not adj.grant_accepts(both), "OR 不满足：吃不到")


static func run_rule_and_buff_sentence(t: TestCase) -> void:
	t.begin("171 · 附加规则的句子：提到的 buff 有专属解说写解说，没有写名字；受益句主语是自己")
	var buff := BuffDef.new()
	buff.id = &"probe_rage"
	buff.display_name = "探针怒"
	var apply := ApplyStatus.new()
	apply.buff = buff
	var rule := AbilityRule.new()
	rule.trigger = OnItemFired.new()
	rule.cadence = Always.new()
	rule.effects = [apply]
	t.check(AdjacencyText.rule_phrase(rule).contains("探针怒"), "没解说：写名字（%s）" % AdjacencyText.rule_phrase(rule))
	buff.has_blurb = true
	buff.blurb = "越打越凶"
	var with_blurb := AdjacencyText.rule_phrase(rule)
	t.check(with_blurb.contains("越打越凶") and not with_blurb.contains("探针怒"), "有解说：写解说（%s）" % with_blurb)
	var adj := AdjacencyProfile.new()
	adj.receive_cells = [Vector2i(1, 0)] as Array[Vector2i]
	adj.receive_filter = [&"shield"] as Array[StringName]
	adj.receive_mods = [_add(&"max_armor", 5.0)] as Array[StatModifier]
	t.eq(AdjacencyText.receive(adj), "挨着盾时 护甲 +5", "受益句：挨着盾时 护甲 +5")
	adj.receive_cells = [Vector2i(1, 0), Vector2i(-1, 0)] as Array[Vector2i]
	t.eq(AdjacencyText.receive(adj), "每挨着一件盾 护甲 +5", "不止一个受益格：每挨着一件（几格几份）")


static func run_tooltip_uses_sentence(t: TestCase) -> void:
	t.begin("171 · 道具悬浮窗：蛮神的护符写「【增益】武器增伤 15%」，不再写「增益槽 ×N：给站在那儿的邻居」")
	var db := ItemDatabase.new()
	db.load_dir()
	var charm := ItemInstance.create(db.get_def(&"charm_brute"))
	var text := Glossary.strip_bbcode(ItemTooltip.describe(charm))
	t.check(text.contains("武器增伤 15%"), "写成「武器增伤 15%」：%s" % text)
	t.check(not text.contains("增益槽 ×") and not text.contains("给站在那儿的邻居"), "旧句子删了")
	var full := ItemTooltip.describe_full(charm)
	t.check(String(full["body"]).contains("term:增益槽"), "行首是增益图标（链到「增益槽」词条）")
	t.check((full["terms"] as Dictionary).has("增益槽"), "图标的词条在 terms 里")
