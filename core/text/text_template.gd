## 文本占位符（084，作者：事件文本要有 {char_name} 这类占位符，还要能变色）。
##
## 一段作者写的文字 → 替换 `{key}` → 给 RichTextLabel 的 BBCode。两类记号：
## - **占位符** `{key}`：从上下文字典取值（[method context_for] 按一局的状态造：角色名、章节名、点、体力、钱、信仰、对手……）。
##   上下文里没有的键**原样保留**，写错了一眼看得见，也不会吞掉别的花括号。
## - **样式码**：`{c:hp}…{/c}` 变色（名字见 [constant STYLE_NAMES]，也可直接 `{c:#ff8800}`）、`{b}…{/b}` 粗体、`{i}…{/i}` 斜体。
##   Godot 原生 BBCode（`[color=…]`、`[b]`）照样能用，样式码只是给不想记十六进制的人的简写。
## 全部键与样式码记在 docs/text-placeholders.md（开发手册的材料），加一个键就补一行。
class_name TextTemplate
extends RefCounted

## 认得的颜色**名**（101 第 5 刀）：这一层只产出名字，名字对应哪个颜色是界面的事 ——
## 表在 [constant UiPalette.STYLE_COLORS]，渲染前由 [method UiPalette.resolve_styles] 换成十六进制。
## 文本层不认识调色板（core 不依赖 ui）
const STYLE_NAMES := ["fg", "dim", "hp", "armor", "stamina", "mana", "heal", "grant", "receive",
	"warn", "danger", "good", "faith"]
## 颜色名在 BBCode 里的前缀：`[color=@hp]`。界面查表换掉；没换的话 Godot 当成无效颜色，不会崩
const STYLE_PREFIX := "@"
## 112：道具名按稀有度上色用的颜色名前缀（`@rarity0`～`@rarity5`），界面按 [ItemPainter] 的稀有度色换
const RARITY_STYLE := "rarity"

## 112（作者定）：**带类型的占位符，颜色跟着类型走** —— 作者只写一个记号，不用手工包 `{c:…}`。
## 前缀 → 颜色名（`item` 例外：按那件道具的稀有度）。全表见 docs/text-placeholders.md
const TYPED_STYLES := {
	"char": "hp",
	"enemy": "danger",
	"ui": "good",
	"zone": "grant",
	"key": "dim",
	"item_stat": "fg",
	"faith": "faith",     # 113
}
## 112：`{ui:…}` `{zone:…}` 的英文（界面切到英文时换；没登记的照原文）
const TERMS_EN := {
	"搜索": "Search", "开战": "Fight", "战前准备": "Pre-battle", "迎战": "Fight", "撤离": "Extract",
	"地上": "Ground", "仓库": "Warehouse", "棋盘": "Board", "包": "Bag",
}


## 替换占位符与样式码。[param ctx] 的值用 str() 转成文字
static func render(text: String, ctx: Dictionary = {}) -> String:
	if text == "":
		return ""
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch != "{":
			out += ch
			i += 1
			continue
		var close := text.find("}", i + 1)
		if close < 0:
			out += text.substr(i)
			break
		var token := text.substr(i + 1, close - i - 1)
		var replaced: Variant = _expand(token, ctx)
		out += replaced if replaced != null else "{" + token + "}"
		i = close + 1
	return out


## 一个记号展开成什么；不认识返回 null（调用方原样保留）
static func _expand(token: String, ctx: Dictionary) -> Variant:
	match token:
		"b":
			return "[b]"
		"/b":
			return "[/b]"
		"i":
			return "[i]"
		"/i":
			return "[/i]"
		"/c":
			return "[/color]"
	if token.begins_with("c:"):
		var name := token.substr(2)
		if STYLE_NAMES.has(name):
			return "[color=%s%s]" % [STYLE_PREFIX, name]
		if name.begins_with("#") and Color.html_is_valid(name):
			return "[color=%s]" % name
		return null
	# 104：`{key|abs}` 取绝对值、`{key|signed}` 带正负号（「伤害 {amount|signed}%」→「伤害 -10%」）
	var filter := ""
	var bar := token.find("|")
	if bar > 0:
		filter = token.substr(bar + 1)
		token = token.substr(0, bar)
	var v: Variant = null
	if token.begins_with("item_stat:"):
		v = _item_stat(token, ctx)
		if v == null:
			return null
		var shown: Variant = _format(v, filter)
		return _paint(String(shown), String(TYPED_STYLES["item_stat"])) if shown != null else null
	if filter == "":
		var typed: Variant = _typed(token, ctx)
		if typed != null:
			return typed
	if ctx.has(token):
		v = ctx[token]
	if v == null:
		return null
	return _format(v, filter)


## 112：带类型的占位符 → 上了色、加粗的文字；不是这一类返回 null
static func _typed(token: String, ctx: Dictionary) -> Variant:
	if token == "char":
		var name := String(ctx.get("char_name", ""))
		return _paint(name if name != "" else "你", String(TYPED_STYLES["char"]), false)
	var colon := token.find(":")
	if colon <= 0:
		return null
	var kind := token.substr(0, colon)
	var arg := token.substr(colon + 1)
	if arg == "":
		return null
	match kind:
		"item":
			var def := _items_of(ctx).get_def(StringName(arg))
			if def == null:
				return null
			return _paint(Names.of(def), "%s%d" % [RARITY_STYLE, clampi(def.rarity, 0, 5)])
		"enemy":
			var e := _enemies_of(ctx).enemy(StringName(arg))
			if e == null:
				return null
			return _paint(Names.of(e), String(TYPED_STYLES["enemy"]))
		"ui", "zone":
			var word := String(TERMS_EN.get(arg, arg)) if UiText.lang == "en" else arg
			return _paint(word, String(TYPED_STYLES[kind]))
		"key":
			return _paint(arg, String(TYPED_STYLES["key"]))
		"faith":
			var f := _faiths_of(ctx).get(StringName(arg), null) as FaithDef
			return _paint(Names.of(f), String(TYPED_STYLES["faith"])) if f != null else null
		"faith_threshold", "faith_deed", "faith_offer", "faith_perk":
			var n: Variant = _faith_stat(kind, arg, ctx)
			return _paint(String(_format(n, "")), String(TYPED_STYLES["item_stat"])) if n != null else null
	return null


## 113：信仰定义里的数。`{faith_threshold:<神>:<阶>}` 第几阶的阈值；`{faith_deed:<神>:<行为类型>:<字段>}`、
## `{faith_perk:<神>:<效果类型>:<字段>}` 按注册表名找构件；`{faith_offer:<神>:<标签>:<字段>}` 找认这个标签的献祭规则。
## 字段的查找和 `{item_stat}` 同一套反射（[method _find_field]），只是起点换成那一个构件
static func _faith_stat(kind: String, arg: String, ctx: Dictionary) -> Variant:
	var parts := arg.split(":")
	var def := _faiths_of(ctx).get(StringName(parts[0]), null) as FaithDef
	if def == null:
		return null
	match kind:
		"faith_threshold":
			if parts.size() != 2 or not parts[1].is_valid_int():
				return null
			var n := int(parts[1])
			return def.thresholds[n - 1] if n >= 1 and n <= def.thresholds.size() else null
		"faith_deed", "faith_perk":
			if parts.size() != 3:
				return null
			var pool: Array = def.deeds if kind == "faith_deed" else def.perks
			for part in pool:
				if part != null and String(ContentSchema.registry_name_of(part)) == parts[1]:
					return _find_field(part, parts[2], 0)
		"faith_offer":
			if parts.size() != 3:
				return null
			for r in def.offerings:
				if r != null and (r as OfferingRule).tags.has(StringName(parts[1])):
					return _find_field(r, parts[2], 0)
	return null


static func _paint(text: String, style: String, bold: bool = true) -> String:
	var inner := "[b]%s[/b]" % text if bold else text
	return "[color=%s%s]%s[/color]" % [STYLE_PREFIX, style, inner]


## 编译好的正则按模式缓存：模式都是常量，每次调用 RegEx.new().compile 是白做。core/text 与 core/authoring 的文本工具共用
static var _regex_cache: Dictionary = {}


static func cached_regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var re := RegEx.new()
		re.compile(pattern)
		_regex_cache[pattern] = re
	return _regex_cache[pattern]


## 剥掉全部 BBCode 标签（`[b]` `[color=…]` `[url=…]`……，凡 `[字母…]`），只留文字：搜索、测试比对纯文字用。
## [method plain] 只剥样式码对应的三种，Label 里 `[url]` 之类要不要留是那边的事
static func strip_bbcode(text: String) -> String:
	return cached_regex("\\[/?[a-zA-Z][^\\]]*\\]").sub(text, "", true)


## 112：正文里引用了哪些道具 / 敌人 / 信仰（113 加 `{faith…:}`；`{item:id}` `{enemy:id}` `{item_stat:id:字段}`）→ [{kind, id}]。导入器拿它查 id
static func refs(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var regex := cached_regex("\\{(item|enemy|item_stat|faith|faith_threshold|faith_deed|faith_offer|faith_perk):([^:}|]+)")
	for m in regex.search_all(text):
		var k := m.get_string(1)
		out.append({"kind": "enemy" if k == "enemy" else ("faith" if k.begins_with("faith") else "item"), "id": m.get_string(2)})
	return out


## 这个 float 是不是整数值（`5.0` 是、`5.01` 不是）。「整数值的 float 显示成整数」的判定都走它，各处怎么写非整数各自定
static func is_whole(v: float) -> bool:
	return is_equal_approx(v, roundf(v))


## 数 → 文字：整数值的 float 写成整数（`5.0` → `5`），其余照 str()。describe() 拼句用（Godot 的 % 不认 %g）
static func num(v: float) -> String:
	return str(int(v)) if is_whole(v) else str(snappedf(v, 0.01))


## 值 → 文字：整数值的 float 写成整数；[param filter] 不认识返回 null（整个记号原样保留）
static func _format(v: Variant, filter: String) -> Variant:
	var num := v is int or v is float
	if filter != "" and not num:
		return null
	match filter:
		"":
			pass
		"abs":
			v = absf(v) if v is float else absi(v)
		"signed":
			var t: Variant = _format(v, "")
			return ("+" + String(t)) if float(v) > 0.0 else String(t)
		_:
			return null
	if v is float and is_whole(v):
		return str(int(v))
	return str(v)


## 104：`{item_stat:<道具 id>:<字段>}` —— 教程文本引用**别的道具**的数（「塔盾每下减 4」）。从道具定义里找：
## 先 `combat` 再整份定义，深度优先；遇到 `stat` 是这个名字的属性修饰取它的 `amount`，否则取同名的数值字段 / 字典键
## （`base_stats` 的 `block`、伤害修正的 `flat`）。道具库用 ctx 的 `_items`（[method context_for] 放进去），没有就自己读一份。
## 153 补充一：旧字段名 `max_shield` 当 `max_armor` 找（护盾改名护甲）
static func _item_stat(token: String, ctx: Dictionary) -> Variant:
	var parts := token.split(":")
	if parts.size() != 3:
		return null
	if parts[2] == "max_shield":
		parts[2] = String(BattleStats.MAX_ARMOR)
	var def := _items_of(ctx).get_def(StringName(parts[1]))
	if def == null:
		return null
	var found: Variant = _find_field(def.combat, parts[2], 0)
	return found if found != null else _find_field(def, parts[2], 0)


static var _items_cache: ItemDatabase = null
static var _enemies_cache: EnemyDatabase = null


## 道具库：ctx 的 `_items`（[method context_for] 放进去），没有就自己读一份
static func _items_of(ctx: Dictionary) -> ItemDatabase:
	var db: Variant = ctx.get("_items", null)
	return db if db is ItemDatabase else _default_items()


static var _faiths_cache: Dictionary = {}


## 113：信仰定义 id → FaithDef：ctx 的 `_faiths`，没有就自己读一份
static func _faiths_of(ctx: Dictionary) -> Dictionary:
	var d: Variant = ctx.get("_faiths", null)
	if d is Dictionary and not (d as Dictionary).is_empty():
		return d
	if _faiths_cache.is_empty():
		_faiths_cache = FaithDef.load_all()
	return _faiths_cache


static func _enemies_of(ctx: Dictionary) -> EnemyDatabase:
	var db: Variant = ctx.get("_enemies", null)
	if db is EnemyDatabase:
		return db
	if _enemies_cache == null:
		_enemies_cache = EnemyDatabase.new()
		_enemies_cache.load_all()
	return _enemies_cache


static func _default_items() -> ItemDatabase:
	if _items_cache == null:
		_items_cache = ItemDatabase.new()
		_items_cache.load_dir()
	return _items_cache


static func _find_field(obj: Variant, key: String, depth: int) -> Variant:
	if depth > 12 or obj == null:
		return null
	if obj is Array:
		for e in obj:
			var r: Variant = _find_field(e, key, depth + 1)
			if r != null:
				return r
		return null
	if not (obj is Object):
		return null
	if obj is StatModifier and String((obj as StatModifier).stat) == key:
		return (obj as StatModifier).amount
	for p in ContentSchema.properties_of(obj):
		var name := String(p["name"])
		var v: Variant = (obj as Object).get(name)
		if name == key and (v is int or v is float) and not (v is bool):
			return v
		if v is Dictionary and (v as Dictionary).has(key):
			var x: Variant = (v as Dictionary)[key]
			if (x is int or x is float) and not (x is bool):
				return x
	for p in ContentSchema.properties_of(obj):
		var v: Variant = (obj as Object).get(String(p["name"]))
		if v is Array or (v is Object and v is Resource):
			var r: Variant = _find_field(v, key, depth + 1)
			if r != null:
				return r
	return null


## 把 `{…}` 全剥掉的纯文字（Label、日志用）：占位符照替，样式码去掉
static func plain(text: String, ctx: Dictionary = {}) -> String:
	return cached_regex("\\[/?(color|b|i)(=[^\\]]*)?\\]").sub(render(text, ctx), "", true)


## 一局现在的状态 → 占位符表。[param node] 是这段文字说的那个点（事件所在、鼠标停着的），可为 null；
## [param extra] 覆盖 / 追加（比如遭遇的敌人内容）。键的全表见 docs/text-placeholders.md
static func context_for(run: RunState, node: MapNode = null, extra: Dictionary = {}) -> Dictionary:
	var ctx := {}
	if run != null:
		ctx["char_name"] = Names.of(run.character) if run.character != null else "你"
		ctx["char_id"] = String(run.character_id)
		ctx["chapter_name"] = Names.of(run.chapter) if run.chapter != null else ""
		ctx["seed"] = run.run_seed
		ctx["vitality"] = run.vitality.current if run.vitality != null else 0
		ctx["vitality_max"] = run.vitality.maximum if run.vitality != null else 0
		ctx["money"] = run.wallet.balance if run.wallet != null else 0
		ctx["actions"] = run.travel.clock.total if run.travel != null and run.travel.clock != null else 0
		ctx["board_count"] = run.board.item_count() if run.board != null else 0
		ctx["storage_count"] = run.storage.item_count() if run.storage != null else 0
		var faith := run.active_faith()
		ctx["faith"] = Names.of(faith) if faith != null else "无"
		# 113：激活信仰现在的信力与阶（没激活 0 / 0）
		ctx["faith_points"] = run.faith_power.points_of(faith.id) if faith != null and run.faith_power != null else 0
		ctx["faith_tier"] = maxi(0, run.active_faith_tier()) if faith != null else 0
		if not run.faith_defs.is_empty():
			ctx["_faiths"] = run.faith_defs
		ctx["difficulty"] = run.difficulty.display_name if run.difficulty != null and "display_name" in run.difficulty else "普通"
		ctx["battles_won"] = int(run.tally.get("battles_won", 0))
		ctx["battles_lost"] = int(run.tally.get("battles_lost", 0))
		ctx["_items"] = run.items     # {item_stat:…} {item:…} 用；以下划线开头的键不是给作者写的
		if run.enemies != null:
			ctx["_enemies"] = run.enemies     # 112：{enemy:…} 用
		# 112：输一场普通战斗扣几点体力（节点规则的 loss_cost.battle）
		ctx["loss_cost"] = int(run.node_rules.loss_cost.get("battle", 1)) if run.node_rules != null else 1
	if node != null:
		ctx["node_id"] = node.id
		var type := NodeEvents.effective_type(node)
		ctx["node_type"] = NodeText.label_of(type)
		ctx["node_danger"] = node.danger
		ctx["extract_fee"] = PaidExtracts.fee_of(node) if NodeEvents.effective_type(node) == &"extract" else 0
		var content: Dictionary = node.content
		if EnemyKit.has_enemy(content):
			_enemy_into(ctx, content, run)
	for key in extra:
		ctx[String(key)] = extra[key]
	if extra.has("enemy_content") and extra["enemy_content"] is Dictionary and run != null:
		_enemy_into(ctx, extra["enemy_content"], run)
	return ctx


## 对手的占位符：{enemy_name} {enemy_strength} {enemy_hp} {enemy_dps} {enemy_items} {enemy_count} {battle_data}
static func _enemy_into(ctx: Dictionary, content: Dictionary, run: RunState) -> void:
	if run == null or run.enemies == null:
		return
	var def := run.enemies.enemy(StringName(String(content.get("enemy", ""))))
	if def == null:
		return
	ctx["enemy_name"] = Names.of(def)
	ctx["enemy_strength"] = int(content.get("strength", 0))
	var spec := EnemyKit.spec_of(content, run.enemies, run.pool, run.items)
	var names: Array[String] = []
	for raw in content.get("items", []):
		var idef := run.items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
		names.append(Names.of(idef) if idef != null else String((raw as Dictionary).get("id", "?")))
	ctx["enemy_items"] = "、".join(names)
	ctx["enemy_count"] = names.size()
	if spec != null:
		ctx["enemy_hp"] = spec.max_hp_int()
		ctx["enemy_dps"] = "%.1f" % spec.rough_dps()
		ctx["battle_data"] = "%s（%d 档）　生命 %d　约 %.1f DPS　%d 件：%s" % [
			Names.of(def), int(content.get("strength", 0)), spec.max_hp_int(), spec.rough_dps(), names.size(), "、".join(names)]
	else:
		ctx["battle_data"] = "%s（%d 档）" % [Names.of(def), int(content.get("strength", 0))]
