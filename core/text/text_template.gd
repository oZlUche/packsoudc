## 文本占位符（084，作者：事件文本要有 {char_name} 这类占位符，还要能变色）。
##
## 一段作者写的文字 → 替换 `{key}` → 给 RichTextLabel 的 BBCode。两类记号：
## - **占位符** `{key}`：从上下文字典取值（[method context_for] 按一局的状态造：角色名、章节名、点、体力、钱、信仰、对手……）。
##   上下文里没有的键**原样保留**，写错了一眼看得见，也不会吞掉别的花括号。
## - **样式码**：`{c:hp}…{/c}` 变色（名字见 [constant COLORS]，也可直接 `{c:#ff8800}`）、`{b}…{/b}` 粗体、`{i}…{/i}` 斜体。
##   Godot 原生 BBCode（`[color=…]`、`[b]`）照样能用，样式码只是给不想记十六进制的人的简写。
## 全部键与样式码记在 docs/text-placeholders.md（开发手册的材料），加一个键就补一行。
class_name TextTemplate
extends RefCounted

## 样式码里的颜色名 → 调色板
const COLORS := {
	"fg": UiPalette.FG, "dim": UiPalette.DIM, "hp": UiPalette.HP, "shield": UiPalette.SHIELD,
	"stamina": UiPalette.STAMINA, "mana": UiPalette.MANA, "heal": UiPalette.HEAL,
	"grant": UiPalette.GRANT, "receive": UiPalette.RECEIVE,
	"warn": UiPalette.STAMINA, "danger": UiPalette.HP, "good": UiPalette.HEAL,
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
		if COLORS.has(name):
			return "[color=#%s]" % (COLORS[name] as Color).to_html(false)
		if name.begins_with("#") and Color.html_is_valid(name):
			return "[color=%s]" % name
		return null
	if ctx.has(token):
		return str(ctx[token])
	return null


## 把 `{…}` 全剥掉的纯文字（Label、日志用）：占位符照替，样式码去掉
static func plain(text: String, ctx: Dictionary = {}) -> String:
	var rendered := render(text, ctx)
	var regex := RegEx.new()
	regex.compile("\\[/?(color|b|i)(=[^\\]]*)?\\]")
	return regex.sub(rendered, "", true)


## 一局现在的状态 → 占位符表。[param node] 是这段文字说的那个点（事件所在、鼠标停着的），可为 null；
## [param extra] 覆盖 / 追加（比如遭遇的敌人内容）。键的全表见 docs/text-placeholders.md
static func context_for(run: RunState, node: MapNode = null, extra: Dictionary = {}) -> Dictionary:
	var ctx := {}
	if run != null:
		ctx["char_name"] = run.character.display_name if run.character != null else "你"
		ctx["char_id"] = String(run.character_id)
		ctx["chapter_name"] = run.chapter.display_name if run.chapter != null else ""
		ctx["seed"] = run.run_seed
		ctx["vitality"] = run.vitality.current if run.vitality != null else 0
		ctx["vitality_max"] = run.vitality.maximum if run.vitality != null else 0
		ctx["money"] = run.wallet.balance if run.wallet != null else 0
		ctx["actions"] = run.travel.clock.total if run.travel != null and run.travel.clock != null else 0
		ctx["board_count"] = run.board.item_count() if run.board != null else 0
		ctx["storage_count"] = run.storage.item_count() if run.storage != null else 0
		var faith := run.active_faith()
		ctx["faith"] = faith.display_name if faith != null else "无"
		ctx["difficulty"] = run.difficulty.display_name if run.difficulty != null and "display_name" in run.difficulty else "普通"
		ctx["battles_won"] = int(run.tally.get("battles_won", 0))
		ctx["battles_lost"] = int(run.tally.get("battles_lost", 0))
	if node != null:
		ctx["node_id"] = node.id
		var type := NodeEvents.effective_type(node)
		ctx["node_type"] = String(MapNodeStyle.of(type)["label"])
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
	ctx["enemy_name"] = def.display_name
	ctx["enemy_strength"] = int(content.get("strength", 0))
	var spec := EnemyKit.spec_of(content, run.enemies, run.pool, run.items)
	var names: Array[String] = []
	for raw in content.get("items", []):
		var idef := run.items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
		names.append(idef.display_name if idef != null else String((raw as Dictionary).get("id", "?")))
	ctx["enemy_items"] = "、".join(names)
	ctx["enemy_count"] = names.size()
	if spec != null:
		ctx["enemy_hp"] = spec.max_hp_int()
		ctx["enemy_dps"] = "%.1f" % spec.rough_dps()
		ctx["battle_data"] = "%s（%d 档）　生命 %d　约 %.1f DPS　%d 件：%s" % [
			def.display_name, int(content.get("strength", 0)), spec.max_hp_int(), spec.rough_dps(), names.size(), "、".join(names)]
	else:
		ctx["battle_data"] = "%s（%d 档）" % [def.display_name, int(content.get("strength", 0))]
