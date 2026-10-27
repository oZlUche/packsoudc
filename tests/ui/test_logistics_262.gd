## 262（作者 14:19）：集市、铁匠铺默认就有（1 级），和出售并成「后勤」一页；科技「集市」「铁匠铺」改义为「高级货物」「高级配方」（铺子再升一级）；
## 左列三个页签（仓库 / 后勤 / 书架），后勤选中时底下滑出三颗分页小键（待定 1 选 A）；老档 v3 的两项科技级数沿用、3 压 2
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const T110 := preload("res://tests/meta/test_tech.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")


static func run_default_level(t: TestCase) -> void:
	t.begin("262 · 没点科技：集市、铁匠铺都是 1 级；高级货物 1 级 = 集市 2 级（6 格）；科技面板说的是铺子下一级")
	var m := T110._meta()
	t.eq(m.facility_level(Market.ID), MetaState.BASE_FACILITY_LEVEL, "集市 1 级")
	t.eq(m.facility_level(Smithy.ID), 1, "铁匠铺 1 级")
	var db := T110._db()
	var rules := Market.load_rules()
	Market.restock(m, rules, db, BagPool.standard())
	t.eq(m.market_stock.size(), 4, "没点科技就有 4 格货")
	var techs := GameFlow.load_techs()
	m.tech_levels["market"] = 1
	TechService.derive(m, techs)
	Market.restock(m, rules, db, BagPool.standard())
	t.eq(m.market_stock.size(), 6, "高级货物 1 级：6 格")
	var def := TechService.find(techs, &"market")
	t.eq(def.effect.describe_level(1), Market.describe_level(rules, 2), "科技第 1 级的效果 = 集市第 2 级")
	var smithy := TechService.find(techs, &"smithy")
	t.eq(smithy.effect.describe_level(2), Smithy.describe_level(3), "高级配方第 2 级 = 铁匠铺第 3 级")
	t.eq(def.max_level(), 2, "高级货物两级")
	t.eq(smithy.max_level(), 2, "高级配方两级")


static func run_migrate_v3(t: TestCase) -> void:
	t.begin("262 · 老档 v3 → v4：高级货物 / 高级配方的级数沿用（铺子白得一级），3 压到 2；读回来集市 3 级、铁匠铺 2 级")
	var text := FileAccess.get_file_as_string("res://tests/fixtures/meta_v3.json")
	var raw: Dictionary = JSON.parse_string(text)
	t.eq(int(raw["version"]), 3, "样本是 v3")
	t.eq(int(raw["tech_levels"]["market"]), 3, "样本里集市点到 3 级")
	var up := MetaMigrations.upgrade(raw)
	t.eq(int(up["version"]), MetaState.SAVE_VERSION, "升到当前版本")
	t.eq(int(up["tech_levels"]["market"]), 2, "3 压到 2")
	t.eq(int(up["tech_levels"]["smithy"]), 1, "1 级照旧")
	t.eq(int(raw["tech_levels"]["market"]), 3, "不改入参")
	var m := MetaSave.from_text(text, T110._db(), GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.not_null(m, "v3 的档读得回来")
	if m != null:
		t.eq(Market.level(m), 3, "集市 3 级")
		t.eq(Smithy.level(m), 2, "铁匠铺 2 级")


static func frame_logistics_tab(t: TestCase, root: Window) -> void:
	t.begin("262 · 左列三个页签；「后勤」下三颗小键只在选中时露；第一次落集市、之后落上次的分页；出售露右列仓库、集市 / 铁匠铺收起；老名字是别名")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	var s: Control = W178._screen(f, root)
	t.eq(s._tab_btns.keys(), ["warehouse", "logistics", "shelf"], "仓库 / 后勤 / 书架（262 §七：科技并进书架）")
	t.eq((s._tab_btns["logistics"] as Button).text, UiText.t("meta.tab_logistics"), "页签写「后勤」")
	var subs: Dictionary = s.sub_tab_buttons()
	t.eq(subs.keys(), ["market", "smithy", "sell"], "三颗分页小键：集市 / 铁匠铺 / 出售")
	t.eq((subs["sell"] as Button).text, UiText.t("meta.tab_sell"), "分页名复用原来的字")
	t.check(not (subs["market"] as Button).is_visible_in_tree(), "在家：小键收着")
	s.toggle_tab("logistics")
	t.check(s.tab() == "logistics" and s.sub_tab() == "market", "第一次进后勤：集市")
	t.check(subs.values().all(func(b: Button) -> bool: return b.is_visible_in_tree()), "选中后勤：三颗小键露出来")
	t.check((subs["market"] as Button).button_pressed and not (subs["sell"] as Button).button_pressed, "集市那颗按下")
	t.check((s._pages["market"] as Control).visible and not (s._pages["smithy"] as Control).visible, "中列是集市")
	t.check(not s._right.visible, "集市：右列仓库收起")
	(subs["sell"] as Button).pressed.emit()
	t.check(s.tab() == "logistics" and s.sub_tab() == "sell", "点出售小键：后勤 / 出售")
	t.check(s._right.visible, "出售：右列仓库露出来")
	t.check((s._tab_btns["logistics"] as Button).button_pressed, "后勤页签还按着")
	s.show_tab("smithy")
	t.check(s.tab() == "logistics" and s.sub_tab() == "smithy" and not s._right.visible, "别名 smithy → 后勤 / 铁匠铺，右列收起")
	s.toggle_tab("warehouse")
	t.check(not (subs["market"] as Button).is_visible_in_tree(), "换到仓库：小键收回")
	t.eq(s.sub_tab(), "", "不在后勤：没有分页")
	s.toggle_tab("logistics")
	t.eq(s.sub_tab(), "smithy", "再进后勤：落上次看的铁匠铺")
	s.toggle_tab("logistics")
	t.eq(s.tab(), "home", "再点一次选中的后勤：回家")
	s.show_tab("logistics")
	t.check(s.escape() and s.tab() == "home", "Esc 回家")
	var left: Control = (s._tab_btns["logistics"] as Button).get_parent()
	s.show_tab("sell")
	t.eq(Bare.audit(left, "logistics262"), [] as Array[String], "左列没有裸字")
	s.queue_free()
	W178._cleanup()
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for tier in [&"small", &"medium", &"large"]:
			UiTheme.with_text_size(tier, func():
				var sc: Control = W178._screen(f, root)
				sc.show_tab("logistics")
				var col: Control = (sc._tab_btns["logistics"] as Button).get_parent()
				var room: float = 1000.0 - 2.0 * sc.MARGIN
				t.check(col.get_combined_minimum_size().y <= room, "%s %s：左列（后勤展开）%.0f 高放得进 %.0f" % [lang, tier, col.get_combined_minimum_size().y, room])
				var sub_w := 0.0
				for b in (sc.sub_tab_buttons() as Dictionary).values():
					sub_w = maxf(sub_w, (b as Button).get_combined_minimum_size().x + sc.SUB_TAB_INDENT)
				t.check(sub_w <= sc.LEFT_W, "%s %s：分页小键 %.0f 宽放得进左列 %.0f" % [lang, tier, sub_w, sc.LEFT_W])
				sc.free())
	UiText.lang = "zh"
	W178._cleanup()
