## 112（作者定）：序章文案不写死名字 —— 带类型的占位符自带颜色（{char} {item:} {enemy:} {ui:} {zone:} {key:}），
## 名字读定义；写错 id 导入报错；序章两张图的事件与规则卡全部替换干净，不露花括号。
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_typed_placeholders(t: TestCase) -> void:
	t.begin("112 · 带类型的占位符：换成名字、颜色跟着类型、plain 剥干净")
	var db := _db()
	var ctx := {"char_name": "阿岚", "_items": db}
	t.eq(TextTemplate.render("{char}", ctx), "[color=@hp]阿岚[/color]", "{char}：角色名、hp 色")
	t.eq(TextTemplate.plain("{char}来了", {}), "你来了", "没角色是「你」")
	var knife := db.get_def(&"knife")
	t.eq(TextTemplate.render("{item:knife}", ctx), "[color=@rarity%d][b]%s[/b][/color]" % [knife.rarity, Names.of(knife)], "{item:}：名字、按稀有度、粗体")
	t.eq(TextTemplate.plain("拿起{item:knife}", ctx), "拿起" + Names.of(knife), "plain 只剩名字")
	var steel := db.get_def(&"steel_ingot")
	t.check(TextTemplate.render("{item:steel_ingot}", ctx).begins_with("[color=@rarity2]"), "蓝色的建材用 rarity2")
	t.check(TextTemplate.render("{enemy:brute}", ctx).begins_with("[color=@danger][b]"), "{enemy:}：danger 色")
	t.eq(TextTemplate.plain("{enemy:brute}", ctx), "蛮兵", "敌人名读定义")
	t.eq(TextTemplate.render("{ui:开战}", ctx), "[color=@good][b]开战[/b][/color]", "{ui:}：good 色")
	t.eq(TextTemplate.render("{zone:地上}", ctx), "[color=@grant][b]地上[/b][/color]", "{zone:}：grant 色")
	t.eq(TextTemplate.render("{key:R}", ctx), "[color=@dim][b]R[/b][/color]", "{key:}：dim 色")
	t.eq(TextTemplate.render("{item_stat:longsword:damage}", ctx), "[color=@fg][b]12[/b][/color]", "{item_stat:} 也上色")
	t.eq(TextTemplate.plain("{item_stat:poison_vial:seconds}", ctx), "6", "{item_stat:} 能读规则节奏的 seconds")
	t.eq(TextTemplate.render("{item:no_such}", ctx), "{item:no_such}", "不存在的 id 原样保留（一眼看得见）")
	t.eq(TextTemplate.render("{char_name}", ctx), "阿岚", "{char_name} 仍是不上色的裸值")

	var old := UiText.lang
	UiText.lang = "en"
	t.eq(TextTemplate.plain("{zone:地上}", ctx), "Ground", "英文界面：区域名换英文")
	t.eq(TextTemplate.plain("{item:knife}", ctx), Names.of(knife, "en"), "英文界面：道具名跟语言")
	UiText.lang = old

	var resolved := UiPalette.resolve_styles(TextTemplate.render("{item:steel_ingot}", ctx))
	t.check(resolved.contains("#" + ItemPainter.rarity_color(steel).to_html(false)), "界面把稀有度色换成真颜色：%s" % resolved)
	t.check(not resolved.contains("@"), "不留颜色名")
	t.eq(TextTemplate.refs("{item:knife}和{enemy:brute}、{item_stat:longsword:damage}").size(), 3, "refs 找到三处引用")


static func run_import_checks_refs(t: TestCase) -> void:
	t.begin("112 · 导入：事件 / 规则卡里引用的道具、敌人得存在")
	var ctx := ContentImporter.Context.new()
	ctx.register_item(_db().get_def(&"knife"))
	var e := EnemyDef.new()
	e.id = &"brute"
	ctx.register_enemy(e)
	var report := ImportReport.new()
	ContentImporter.check_text_refs("拿着{item:knife}去打{enemy:brute}", "text", ctx, report)
	t.check(report.ok(), "都存在：不报")
	ContentImporter.check_text_refs("{item:knfie}", "text", ctx, report)
	t.check(not report.ok(), "道具 id 写错：报错")
	var r2 := ImportReport.new()
	ContentImporter.check_text_refs("{enemy:brutee}", "text", ctx, r2)
	t.check(not r2.ok() and r2.to_text().contains("brutee"), "敌人 id 写错：报错并点名")


## 序章两张图的事件：这些名字不再写死
const HARDCODED := ["蛮兵", "制式短剑", "弯刀", "塔盾", "板甲", "长剑", "毒药瓶", "涂毒匕首", "护身符", "长条包", "战锤"]


static func run_tutorial_events_clean(t: TestCase) -> void:
	t.begin("112 · 序章事件与规则卡：全部占位符都换得掉，名字不写死，汉字数没了")
	var defs := EventPlacer.load_all()
	var ctx := {"char_name": "阿岚", "vitality": 5, "loss_cost": 1, "_items": _db()}
	var n := 0
	for id in defs:
		if not String(id).begins_with("tut"):
			continue
		n += 1
		var def := defs[id] as EventDef
		for field in [def.title, def.text]:
			var shown := TextTemplate.plain(field, ctx)
			t.check(not shown.contains("{") and not shown.contains("}"), "%s 没有漏换的记号：%s" % [id, shown.left(40)])
			for word in HARDCODED:
				t.check(not field.contains(word), "%s 里「%s」不写死" % [id, word])
		for opt in def.options:
			t.check(not TextTemplate.plain((opt as EventOption).label, ctx).contains("{"), "%s 选项没漏换" % id)
		for digits in ["三秒一下", "二十多点", "十二点", "六秒一次", "输两场"]:
			t.check(not def.text.contains(digits), "%s 不再写死「%s」" % [id, digits])
	t.eq(n, 37, "三张序章 37 条事件都查了（113 加了序章三的 12 条）")
	var ch := load(ContentPaths.asset_file("chapters", "prologue_2")) as ChapterDef
	for line in ch.rules:
		var shown := TextTemplate.plain(line, ctx)
		t.check(not shown.contains("{"), "规则卡没漏换：%s" % shown)
	t.check(TextTemplate.plain(ch.rules[1], ctx).contains(Names.of(_db().get_def(&"poison_vial"))), "规则卡里的毒药瓶是读出来的名字")
	var heavy := defs[&"tut2_battle_heavy"] as EventDef
	t.eq(TextTemplate.plain(heavy.title, ctx), "重击手", "标题按敌人定义的名字")
	t.check(TextTemplate.plain(heavy.text, ctx).contains("2.5 秒一下"), "战锤的节奏按数据：%s" % TextTemplate.plain(heavy.text, ctx).left(30))
