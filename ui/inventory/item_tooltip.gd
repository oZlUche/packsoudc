## 道具的悬浮说明（084，作者定）：名、稀有度、标签、效果；有增益 / 受益 / 装载槽的写槽的效果；包写包的格数与包体加成；信仰道具写按阶解锁的加成。
## 087：说明里的名词是**词条**（[Glossary]）：主文字只写词，悬浮窗钉住后停在词上开子窗看具体效果（170 §3，原来的侧边小窗取消）。
##
## 170（作者定）：版式 A —— 分三块：头（名字粗体 18、副行稀有度 · 标签、说明斜体）/ 正文（一行一条，行首图标）/ 脚注（金币、秤砣、套装）。
## 武器写「每 X 秒造成 Y 点伤害，消耗 Z 耐力」，不写出手、冷却、DPS、格数；带色的字一律描边（深底白字）。
## 171：增益 / 受益 / 装载句由字段生成（[AdjacencyText]）。
##
## 纯文字（BBCode），画是 [HoverTip] 的事。周期与伤害从编译结果取：一件在棋盘上就按它此刻的邻接 / 包体加成算，
## 不在棋盘上（地上、战利品）就单独编一遍 —— 和真打出来的是同一份编译（4.2）
class_name ItemTooltip
extends RefCounted

## 稀有度的名字，下标即稀有度；颜色见 [ItemPainter.RARITY_COLORS]（白 / 绿 / 蓝 / 紫 / 金 / 红）
const RARITY_NAMES := ["普通", "优良", "稀有", "史诗", "传说", "神话"]
## 170：各层字号（定稿各大一号：名字 19、副行 13、说明 14、正文 15、脚注 13）
const NAME_SIZE := 19
const SUB_SIZE := 13
const DESC_SIZE := 14
const BODY_SIZE := 15
const FOOT_SIZE := 13
## 170：行首图标（缺图退回的文字）；图标本身链到格位的词条，钉住后停上去能看解释
const ICONS := {"grant": "【增益】", "receive": "【受益】", "load": "【装载】", "enchant": "【附魔】", "coin": "值 ", "weight": "重 "}
const ICON_TERMS := {"grant": "增益槽", "receive": "受益槽", "load": "装载槽"}

## 096（作者定）：信仰状态的探针 —— 局里由 [GameFlow] 接上，返回 `{"active": 激活的信仰 id, "tier": 阶, "points": 信力}`；
## 没接（基地、沙盒、测试）返回空字典。信仰加成的词条按它上色：**生效的白、没生效的灰**；没有探针一律按原色写
static var faith_probe: Callable = Callable()
const DIM_HEX := "8b93a1"
static var _sets: SetDatabase = null


## 现在的信仰状态；没探针 / 不在局里是空
static func faith_status() -> Dictionary:
	if not faith_probe.is_valid():
		return {}
	var v: Variant = faith_probe.call()
	return v if v is Dictionary else {}


## 096：这一条信仰加成现在生效没有：这件的神正激活着，且按 mode 算出至少一份
static func bonus_lit(def: ItemDef, b: FaithBonus, status: Dictionary) -> bool:
	if status.is_empty() or def == null or b == null:
		return false
	var active := StringName(String(status.get("active", "")))
	if active == &"" or def.faith_tag() != FaithTags.PREFIX + String(active):
		return false
	return b.times_for(int(status.get("tier", 0)), int(status.get("points", 0))) > 0


## 107（作者定）：这件道具的信仰现在是不是激活的 —— 信仰相关的行按它上色（亮 = 生效、灰 = 休眠或还没激活）。
## 局外（没探针）一律按没激活算，局外本来就不上色
static func faith_lit(def: ItemDef, status: Dictionary) -> bool:
	if status.is_empty() or def == null or not def.has_faith():
		return false
	var active := StringName(String(status.get("active", "")))
	return active != &"" and def.faith_tag() == FaithTags.PREFIX + String(active)


## [param board] 给了且道具在上面就按棋盘编译；否则单独编。只要文字（三块连起来）；分块与词条见 [method describe_full]
static func describe(inst: ItemInstance, board: GridInventory = null) -> String:
	return String(describe_full(inst, board)["text"])


## 170：行内图标（链到格位词条的包一层 url）
static func icon(id: String) -> String:
	var img := UiTheme.tip_icon(id, String(ICONS.get(id, "")))
	if ICON_TERMS.has(id):
		return "[url=term:%s]%s[/url]" % [ICON_TERMS[id], img]
	return img


## 087 / 170：分块的文字 + 词条。返回
## `{"head": 名字 / 副行 / 说明, "body": 正文, "foot": 脚注左边（金币、秤砣）, "set": 套装名, "text": 三块连起来, "terms": {id: {"name", "text"}}}`。
## 词条在文字里是 `[url=term:<id>]` 包着的下划线词（[method Glossary.mark]），悬浮窗钉住后停上去按 id 查 `terms` 开子窗。
## 词条 = 固定词条（[Glossary.TERMS]）+ 这件道具会施加的 buff（说明按定义生成）+ 弹词条的标签
static func describe_full(inst: ItemInstance, board: GridInventory = null) -> Dictionary:
	if inst == null or inst.def == null:
		return {"head": "", "body": "", "foot": "", "set": "", "text": "", "terms": {}}
	var def := inst.def
	var rarity_style := "@%s%d" % [TextTemplate.RARITY_STYLE, clampi(def.rarity, 0, RARITY_NAMES.size() - 1)]
	# --- 头：名字（粗体 19、稀有度色）/ 副行（稀有度名 · 标签，按大类排，171）/ 说明（斜体）
	# 170 定稿：只有名字和稀有度名描边；标签、说明、正文、脚注里带色的字都不描（作者对比过后定的）
	var name_line := UiTheme.outline("[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [NAME_SIZE, rarity_style, Names.of_item(inst)])
	var shown_tags := TagRegistry.shown(def.tags)     # 107 后续（作者定）：内部标签（快攻 / 重击 / 重型）不给玩家看
	var listed: Array = []
	for t in TagRegistry.sorted_by_category(shown_tags):     # 171：用途 → 属性 → 材料 → 归属；来源类不列
		if TagRegistry.category_of(StringName(String(t))) != "source":
			listed.append(t)
	var sub := UiTheme.outline("[color=%s]%s[/color]" % [rarity_style, rarity_name(def.rarity)])
	if not listed.is_empty():
		sub += "[color=@tip_meta] · %s[/color]" % " · ".join(_names(listed))     # 096：标签按当前语言显示名字
	var head_rest: Array[String] = ["[font_size=%d]%s[/font_size]" % [SUB_SIZE, sub]]
	var desc := Names.description_of(def)     # 104：说明里的 {字段} 按这件道具自己的字段填
	if desc != "":
		head_rest.append("[font_size=%d][i][color=@tip_desc]%s[/color][/i][/font_size]" % [DESC_SIZE, desc])
	# --- 正文
	var lines: Array[String] = []
	if def.is_bag:
		var size := def.shape.size_rotated(0) if def.shape != null else Vector2i.ZERO
		lines.append("包：%d×%d，放进去的东西才参战" % [size.x, size.y] + ("；只收 %s" % "、".join(_names(def.bag_accept_tags)) if not def.bag_accept_tags.is_empty() else ""))
		for m in def.bag_mods:
			lines.append("　包里的东西：%s" % Glossary.mod_text(m))
	var spec := spec_for(inst, board)
	var compiled: CompiledItem = spec.item_of(inst.uid) if spec != null else null
	if compiled == null and spec != null and not spec.items.is_empty():
		compiled = spec.items[0]     # 单独编的那块棋盘上只有它的副本
	var use_stats: StatSet = spec.stats_with_opening(compiled) if compiled != null else null
	var weapon := def.tags.has(&"weapon")
	# 087（作者定）：没有「主武器」—— 包里每一件武器都各自出手，这里每件都按自己的规则写
	if def.combat != null:
		for key in def.combat.base_stats:
			if weapon and String(key) == "damage":
				continue     # 170：武器的伤害写在武器句里
			lines.append("%s [b]%s[/b]" % [Glossary.stat_name(StringName(String(key))), str(def.combat.base_stats[key])])
		for r in def.combat.rules:
			var rule := r as AbilityRule
			if rule == null:
				continue
			var sentence := ""
			if weapon and rule.cadence is CycleCadence:
				sentence = cycle_sentence(rule, use_stats, compiled.loaded if compiled != null else [] as Array[Dictionary])     # 175：法杖轮读
			elif weapon:
				sentence = weapon_sentence(rule, use_stats)
			if sentence != "":
				lines.append(sentence)
				continue
			var line := Glossary.rule_text(rule, true)     # 142：耐力下面单写
			var st := _stamina_of(rule, use_stats)
			if st > 0.0:
				line += "，消耗 [b]%s[/b] 耐力" % _num(st)
			lines.append(line)
	# 108（作者定）：别人挂到我身上的规则（邻居的增益规则、信仰附魔、晶石的供给）—— 只在棋盘上才有，来源名放句尾
	var attached_buffs := {}
	var loaded := {}     # 171 §4：装进来的晶石已经有自己的装载行，它挂的供给规则不再另写一行「附加」
	if spec != null and board != null:
		for c in spec.loads:
			var crystal: ItemInstance = board.get_item(int(c)) if int(spec.loads[c]) == inst.uid else null
			if crystal != null:
				loaded[crystal.def.id] = true
	if compiled != null:
		for a in compiled.attached:
			var idx := int(a["rule_index"])
			if idx < 0 or idx >= compiled.rules.size():
				continue
			var ar := compiled.rules[idx] as AbilityRule
			Glossary.buffs_in_rules([ar], attached_buffs)
			if StringName(String(a["origin"])) == Forge.ORIGIN:     # 175 第三批：附魔单写一行
				lines.append("%s[color=@grant]%s[/color]" % [icon("enchant"), AdjacencyText.rule_phrase(ar)])
				continue
			if loaded.has(StringName(String(a["origin"]))):
				continue
			lines.append("[color=@grant]附加：%s ← %s[/color]" % [AdjacencyText.rule_phrase(ar), origin_name(StringName(String(a["origin"])), board)])
	# 171 §4：装载槽 —— 装了几颗晶石写几行（空槽不写；同一颗占两个槽一行）
	lines.append_array(load_lines(inst, board, spec, use_stats))
	var reacts := reactions_line(spec, compiled)     # 175：可引发的反应（按棋盘上别的道具带的元素）
	if reacts != "":
		lines.append(reacts)
	if def.is_token():     # 175 第三批：铸牌 —— 那一句附魔、怎么用
		var tok := Forge.enchant_of(inst)
		var said := Forge.sentence(tok)
		lines.append("%s[color=@grant]%s[/color]" % [icon("enchant"), said if said != "" else "（这枚铸牌的附魔已失效）"])
		lines.append("[color=@dim]拖到一件武器上放手：附魔（永久；武器原有的附魔被覆盖）[/color]")
	for e in def.effects:
		var d: String = e.describe() if e != null and e.has_method("describe") else ""
		lines.append("效果：%s" % (d if d != "" else _type_name(e)))
	if def.wear != null:     # 148：耐久 —— 剩几次、用完就碎
		lines.append(wear_line(inst))
	if def.adjacency != null:
		var adj := def.adjacency
		var g := AdjacencyText.grant(adj)
		if g != "":
			lines.append("%s[color=@grant]%s[/color]" % [icon("grant"), g])
		var rv := AdjacencyText.receive(adj)
		if rv != "":
			lines.append("%s[color=@receive]%s[/color]" % [icon("receive"), rv])
		if adj.has_feed():     # 148：供给 —— 站在谁的装载槽上就给谁；171：晶石自己写装在哪
			var line := AdjacencyText.feed(adj)
			if inst.is_broken():
				lines.append("%s[color=@dim]%s（破碎：不再供给）[/color]" % [icon("load"), line])
			else:
				lines.append("%s[color=@grant]%s[/color]" % [icon("load"), line])
				lines.append(load_status_line(inst, board, spec))
	var status := faith_status() if def.has_faith() else {}
	for fb in def.faith_bonuses:
		var b := fb as FaithBonus
		if b != null:
			var line := "信力 " + b.describe()
			# 096（作者定）：局里按状态上色 —— 生效的白、没生效（没激活 / 阶不够 / 别的神）的灰；局外原色
			if not status.is_empty():
				line = "[color=#%s]%s[/color]" % [UiPalette.FG.to_html(false) if bonus_lit(def, b, status) else DIM_HEX, line]
			lines.append(line)
	# 107（作者定）：**状态就是颜色**：这件道具的信仰激活着就亮色，休眠或还没激活就全灰
	if def.is_anchor():
		# 099（作者定）：切信仰不进菜单 —— 右键一下，或者在棋盘里把它重新落下
		var line := "信物：%s" % ("当前信仰" if faith_lit(def, status) else "右键：奉为主信仰")
		lines.append("[color=#%s]%s[/color]" % [UiPalette.FG.to_html(false) if faith_lit(def, status) else DIM_HEX, line])
	# --- 脚注：金币、秤砣（170：不写格数），右边套装名
	var foot := "[font_size=%d][color=@tip_meta]%s%d　%s%d[/color][/font_size]" % [FOOT_SIZE, icon("coin"), ItemValue.of_instance(inst), icon("weight"), ItemWeight.of(def)]     # 129：重
	var set_name := set_name_of(def.set_id)
	# --- 词条：这件道具会施加的 buff（id → 按定义生成的说明）+ 固定词条 + 弹词条的标签
	var extra := Glossary.tag_terms(listed)     # 096：登记了说明的标签也是词条
	var item_buffs := Glossary.buffs_in_item(def)
	item_buffs.merge(attached_buffs)     # 108：挂到我身上的规则施加的 buff（弓身上的【中毒】）也是词条
	for id in item_buffs:
		var bd: BuffDef = item_buffs[id]
		if Names.of(bd) != "":
			extra[Names.of(bd)] = {"id": String(id), "text": Glossary.describe_buff(bd)}
	var rest := "\n".join(head_rest) + "\n" + "\n".join(lines)
	var found := Glossary.terms_in(rest, extra)
	var terms := {}
	for f in found:
		terms[String(f["id"])] = {"name": f["name"], "text": f["text"]}
	for k in ICON_TERMS.values():     # 行首图标链到格位的词条
		if rest.contains("term:" + k):
			terms[k] = {"name": k, "text": Glossary.term_text(k)}
	var head := name_line + "\n" + Glossary.mark("\n".join(head_rest), found)
	var body := "[font_size=%d][color=@tip_fg]%s[/color][/font_size]" % [BODY_SIZE, Glossary.mark("\n".join(lines), found)]
	var text := head + "\n" + body + "\n" + foot + ("　套装：%s" % set_name if set_name != "" else "")
	return {"head": head, "body": body, "foot": foot, "set": set_name, "text": text, "terms": terms}


## 170（作者定）：武器句「每 X 秒造成 Y 点伤害，消耗 Z 耐力」—— X = 编译后的实际周期，Y = 伤害面板，Z = 每次出手的耐力；
## 规则还施加 buff 就接「，附带【中毒】」。不是按周期自己出手、不造成伤害的规则返回空（照普通规则写）
static func weapon_sentence(rule: AbilityRule, stats: StatSet) -> String:
	if rule == null or not (rule.cadence is CooldownCadence) or not (rule.trigger is OnSchedule):
		return ""
	var hz := rule.cadence.estimated_hz(stats) if stats != null else 1.0 / maxf(0.01, (rule.cadence as CooldownCadence).seconds)
	if hz <= 0.0:
		return ""
	var dmg := 0.0
	var type := &""
	var extras: Array[String] = []
	for e in rule.effects:
		if e is DealDamage:
			dmg += (e as CombatEffect).estimated_damage(stats) if stats != null else (e as DealDamage).amount
			if (e as DealDamage).damage_type != DamageTypes.PHYSICAL:
				type = (e as DealDamage).damage_type
	if dmg <= 0.0:
		return ""
	var buffs := {}
	Glossary.buffs_in_rules([rule], buffs)
	for id in buffs:
		extras.append("【%s】" % (buffs[id] as BuffDef).sentence_text())
	var line := "每 [b]%s[/b] 秒造成 [b]%s[/b] 点%s伤害" % [_num(1.0 / hz, 1), _num(dmg), Glossary.damage_type_name(type) if type != &"" else ""]
	var st := _stamina_of(rule, stats)
	if st > 0.0:
		line += "，消耗 [b]%s[/b] 耐力" % _num(st)
	if not extras.is_empty():
		line += "，附带%s" % "".join(extras)
	return line


## 175：「可引发：爆燃、燃血」—— 这件带的元素 × 同一块棋盘上（别的道具和它自己）带的元素，反应表里有的；不带元素、或凑不成反应的不写
static func reactions_line(spec: CombatantSpec, compiled: CompiledItem) -> String:
	if spec == null or compiled == null:
		return ""
	var mine := ReactionResolver.elements_of_item(compiled)
	if mine.is_empty():
		return ""
	var pool: Array = mine.duplicate()
	for it in spec.items:
		if (it as CompiledItem).source_uid == compiled.source_uid:
			continue
		for el in ReactionResolver.elements_of_item(it):
			if not pool.has(el):
				pool.append(el)
	var names: Array[String] = []
	for def in ReactionResolver.reactions_between(mine, pool):
		names.append("【%s】" % Names.of(def))
	if names.is_empty():
		return ""
	return "[color=@grant]可引发：%s[/color]" % "".join(names)


## 171 §4：法杖的装载行 ——「【装载】Ⅰ 明亮的火焰魔晶石　剩 N 次」，一颗晶石一行（175：按轮读的顺时针顺序，罗马数字是第几颗；
## 伤害与冷却写在上面的轮读句里）。不轮读的宿主按 uid 排、不标序号
static func load_lines(inst: ItemInstance, board: GridInventory, spec: CombatantSpec, _stats: StatSet) -> Array[String]:
	var out: Array[String] = []
	if spec == null or inst.def.adjacency == null or not inst.def.adjacency.has_load() or board == null:
		return out
	var uids: Array = []
	var compiled := spec.item_of(inst.uid)
	if compiled != null and not compiled.loaded.is_empty():
		for e in compiled.loaded:
			uids.append(int(e["uid"]))
	else:
		for c in spec.loads:
			if int(spec.loads[c]) == inst.uid:
				uids.append(int(c))
		uids.sort()
	var numbered := compiled != null and not compiled.loaded.is_empty()
	for i in uids.size():
		var crystal := board.get_item(uids[i])
		if crystal == null:
			continue
		var head := "%s " % TextTemplate.roman(i + 1) if numbered else ""
		var parts: Array[String] = [head + Names.of_item(crystal)]
		if crystal.def.wear != null:
			parts.append("剩 [b]%d[/b] 次" % crystal.charges())
		out.append("%s[color=@grant]%s[/color]" % [icon("load"), "　".join(parts)])
	return out


## 175（作者定）：法杖的轮读句 —— 没放晶石「没放晶石：物理 Y，每 Z 秒」；一颗「装载一颗：火 Y，每 Z 秒」；
## 几颗「装载 N 颗，顺时针：火 Y → 冰 Y；颗间 X 秒，一轮后歇 Z 秒」。Y 含暴击期望、晶石加的伤害；X / Z 已除急速
static func cycle_sentence(rule: AbilityRule, stats: StatSet, loaded: Array[Dictionary]) -> String:
	var cad := rule.cadence as CycleCadence
	var p := cad.periods(stats)
	var base := 0.0
	var base_type := DamageTypes.PHYSICAL
	for e in rule.effects:
		if e is DealDamage:
			base += (e as CombatEffect).estimated_damage(stats) if stats != null else (e as DealDamage).amount
			base_type = (e as DealDamage).damage_type
	var raw := StatMath.to_float(stats.total_of(BattleStats.DAMAGE)) if stats != null else 0.0
	var crit := base / raw if raw > 0.0 else 1.0     # 暴击期望的倍数，晶石加的那部分一样吃
	var line := ""
	if loaded.is_empty():
		line = "没放晶石：%s [b]%s[/b]，每 [b]%s[/b] 秒" % [_short_type(base_type), _num(base), _num(p.y, 1)]
	else:
		var shots: Array[String] = []
		for e in loaded:
			var dmg := base + StatMath.to_float(int(e.get("damage", 0))) * crit
			shots.append("%s [b]%s[/b]" % [_short_type(StringName(e.get("type", base_type))), _num(dmg)])
		if loaded.size() == 1:
			line = "装载一颗：%s，每 [b]%s[/b] 秒" % [shots[0], _num(p.y, 1)]
		else:
			line = "装载 %d 颗，顺时针：%s；颗间 [b]%s[/b] 秒，一轮后歇 [b]%s[/b] 秒" % [loaded.size(), " → ".join(shots), _num(p.x, 1), _num(p.y, 1)]
	var st := _stamina_of(rule, stats)
	if st > 0.0:
		line += "，每下消耗 [b]%s[/b] 耐力" % _num(st)
	return line


## 元素伤害写一个字（火 / 冰 / 雷），别的写伤害类型名
static func _short_type(type: StringName) -> String:
	var el := ReactionResolver.element_of_type(type)
	return ReactionResolver.element_name(el) if el != &"" else Glossary.damage_type_name(type)


## 171 §4：晶石自己的那一行 ——「装在：魔法杖」/「装在：魔法杖（另一把法杖的装载槽也压着它：后放的优先）」/「闲置：没放在法杖的装载槽上」
static func load_status_line(inst: ItemInstance, board: GridInventory, spec: CombatantSpec) -> String:
	var host := -1
	if board != null and board.has_item(inst.uid):
		# 晶石自己没有战斗档（编不出 spec）：直接问装载归属
		var loads := spec.loads if spec != null else BattleCompiler.load_assignments(board)
		host = int(loads.get(inst.uid, -1))
	if host < 0:
		return "[color=@dim]闲置：没放在法杖的装载槽上[/color]"
	var staff := board.get_item(host)
	var line := "装在：%s" % (Names.of_item(staff) if staff != null else "?")
	if BattleCompiler.load_claimants(board, inst.uid).size() > 1:
		line += "（另一把法杖的装载槽也压着它：后放的优先）"
	return line


## 170：数字给人看 —— 整数不带小数，别的保留 [param digits] 位
static func _num(v: float, digits: int = 1) -> String:
	if TextTemplate.is_whole(v):
		return str(roundi(v))
	return String.num(v, digits)


## 套装的名字（套装库里查；没有就原 id）
static func set_name_of(id: StringName) -> String:
	if id == &"":
		return ""
	if _sets == null:
		_sets = SetDatabase.new()
		_sets.load_dir()
	var d := _sets.get_def(id)
	return Names.of(d) if d != null and Names.of(d) != "" else String(id)


## 148：耐久那一行（「耐久 2 / 3：每供给一场少一次，用完就碎」；碎了写不再供给）
static func wear_line(inst: ItemInstance) -> String:
	var w := inst.def.wear
	if inst.is_broken():
		return "[color=#%s]耐久 0 / %d：破碎了，不再供给，卖价打折[/color]" % [DIM_HEX, w.max_charges]
	return "耐久 %d / %d：每供给一场少一次，用完就碎" % [inst.charges(), w.max_charges]


## 这条规则每次出手花多少耐力（面板数或属性值）
static func _stamina_of(rule: AbilityRule, stats: StatSet) -> float:
	var total := 0.0
	for c in rule.costs:
		var rc := c as ResourceCost
		if rc == null or rc.resource_key != BattleStats.RES_STAMINA:
			continue
		if rc.amount_stat != &"" and stats != null and stats.has(rc.amount_stat):
			total += StatMath.to_float(stats.total_of(rc.amount_stat))
		else:
			total += rc.amount
	return total


## 108：附加规则的来源给人看 —— `faith:<id>` 写神名，道具 id 写道具名（在棋盘上找得到就用它的名字，否则原词）
static func origin_name(origin: StringName, board: GridInventory = null) -> String:
	var fid := FaithTags.id_of_tag(origin)
	if fid != &"":
		var god: FaithDef = FaithDef.load_all().get(fid, null)
		return Names.of(god) if god != null else String(fid)
	if board != null:
		for inst in board.items():
			var item := inst as ItemInstance
			if item.def != null and item.def.id == origin:
				return Names.of(item.def)
	return String(origin)


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


## 这件道具所在的编译结果：在 [param board] 上就编整块棋盘；否则单独编一遍（放在一块刚好装下它的棋盘上，副本是那块棋盘上唯一的一件）
static func spec_for(inst: ItemInstance, board: GridInventory) -> CombatantSpec:
	if inst == null or inst.def == null or inst.def.combat == null:
		return null
	if board != null and board.has_item(inst.uid):
		return BattleCompiler.compile_board(board)
	var size := inst.def.shape.size_rotated(0) if inst.def.shape != null else Vector2i.ONE
	var scratch := GridInventory.new(size, 0, false)
	var copy := ItemInstance.create(inst.def, 0)
	if not scratch.place(copy, Vector2i.ZERO, 0):
		return null
	return BattleCompiler.compile_board(scratch)


## 这件道具现在的编译结果（一件）
static func compiled_for(inst: ItemInstance, board: GridInventory) -> CompiledItem:
	var spec := spec_for(inst, board)
	if spec == null or spec.items.is_empty():
		return null
	var mine := spec.item_of(inst.uid)
	return mine if mine != null else spec.items[0]


static func _mods(mods: Array) -> String:
	return Glossary.mods_text(mods) if not mods.is_empty() else "无"


## 096：标签给人看（数据里的名字，按当前语言）
static func _names(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for t in tags:
		out.append(Glossary.tag_name(t))
	return out




static func _type_name(obj: Object) -> String:
	return String(ContentSchema.registry_name_of(obj)) if obj != null else "?"
