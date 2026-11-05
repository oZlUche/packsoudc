## 282（作者 2026-11-05 12:42 / 12:48）：局内商店店主、集市散货摊摊主、铁匠 —— 点头像说一句；台词留空给作者；
## 十句内不重复；条件句不开放时不出；铁匠铺满级、哪儿都没有破晓时，点铁匠走一次专属对话、给【破晓的信物】
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Shop := preload("res://tests/ui/test_shop_keys.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _fake(n: int) -> NpcDef:
	var def := NpcDef.new()
	def.id = &"fake"
	for i in n:
		var l := NpcLine.new()
		l.id = StringName("l%d" % i)
		def.lines.append(l)
	return def


static func run_content(t: TestCase) -> void:
	t.begin("282 · 三个 NPC 都在、头像在；名字与台词全空（作者写）；铁匠的专属对话要铁匠铺 3 级、哪儿都没有破晓，给的是独一道具【破晓的信物】")
	var db := _db()
	for id in NpcDef.IDS:
		var def := NpcChatter.get_def(id)
		t.not_null(def, "%s 在" % id)
		if def == null:
			continue
		t.not_null(NpcBadge.face_of(def), "%s 有头像" % id)
		t.eq(def.display_name, "", "%s 名字空着" % id)
		t.check(not def.lines.is_empty() and def.lines.all(func(l: NpcLine) -> bool: return l.text == "" and String(l.texts.get("en", "")) == ""), "%s 台词全空（%d 句）" % [id, def.lines.size()])
		t.check(def.lines.all(func(l: NpcLine) -> bool: return NpcLine.KINDS.has(l.kind)), "种类只有世界观 / 指引")
	var smith := NpcChatter.get_def(NpcDef.BLACKSMITH)
	t.eq(smith.specials.size(), 1, "铁匠一段专属对话")
	var sp := smith.specials[0]
	t.eq(sp.give, &"poxiao_token", "给破晓的信物")
	var token := db.get_def(&"poxiao_token")
	t.check(token != null and token.is_unique() and token.shape.cells.size() == 1, "1×1 独一道具")
	t.check(sp.requires.any(func(c): return c is FacilityAtLeast and (c as FacilityAtLeast).facility == &"smithy" and (c as FacilityAtLeast).level == 3), "铁匠铺 3 级")
	t.check(sp.requires.any(func(c): return c is OwnedNowhere and (c as OwnedNowhere).ids.has(&"poxiao") and (c as OwnedNowhere).ids.has(&"poxiao_token")), "哪儿都没有破晓与信物")
	t.check(NpcChatter.get_def(NpcDef.SHOPKEEPER).specials.is_empty() and NpcChatter.get_def(NpcDef.STALL_KEEPER).specials.is_empty(), "店主、摊主没有专属对话")


static func run_recent_ten(t: TestCase) -> void:
	t.begin("282 · 掷句（作者 12:48）：可以重复，只保证十句内不重复；开放的不够十一句时从最早说过的那句放开")
	var meta := MetaState.new()
	var def := _fake(15)
	var rng := _rng(3)
	var said: Array[String] = []
	for i in 200:
		said.append(String(NpcChatter.next_line(def, meta, rng).id))
	var ok := true
	for i in range(10, said.size()):
		if said.slice(i - 10, i).has(said[i]):
			ok = false
	t.check(ok, "15 句：每一句都不在前 10 句里")
	t.check(said.slice(0, 15).size() == 15, "掷了 200 次")
	var counts := {}
	for s in said:
		counts[s] = int(counts.get(s, 0)) + 1
	t.eq(counts.size(), 15, "15 句都说到了（会重复）")
	t.eq(NpcChatter.recent(meta, &"fake").size(), NpcChatter.RECENT, "只记最近 10 句")
	var few := _fake(4)
	few.id = &"few"
	var seq: Array[String] = []
	for i in 40:
		seq.append(String(NpcChatter.next_line(few, meta, rng).id))
	var cyc := true
	for i in range(4, seq.size()):
		if seq.slice(i - 3, i).has(seq[i]):
			cyc = false
	t.check(cyc, "只有 4 句：每句都和前 3 句不同（放开最早说过的）")
	var one := _fake(1)
	one.id = &"one"
	t.eq([String(NpcChatter.next_line(one, meta, rng).id), String(NpcChatter.next_line(one, meta, rng).id)], ["l0", "l0"], "只有 1 句：照说")
	t.eq(NpcChatter.next_line(_fake(0), meta, rng), null, "一句都没有：null")


static func run_requires(t: TestCase) -> void:
	t.begin("282 · 条件句：条件不满足不出，满足了进池")
	var meta := MetaState.new()
	var def := _fake(1)
	var gated := NpcLine.new()
	gated.id = &"gated"
	var cond := HasFlag.new()
	cond.flag = &"npc282_test"
	gated.requires.append(cond)
	def.lines.append(gated)
	t.eq(NpcChatter.open_lines(def, meta).map(func(l: NpcLine) -> String: return String(l.id)), ["l0"], "旗标没立：只有 l0")
	meta.set_flag(&"npc282_test")
	t.eq(NpcChatter.open_lines(def, meta).size(), 2, "立了：两句")


static func run_poxiao_start(t: TestCase) -> void:
	t.begin("282 · 破晓的起点：铁匠铺不到 3 级只闲聊；3 级点铁匠 = 专属对话一次 + 信物进仓库；再点回到闲聊；已有破晓不触发")
	var db := _db()
	var meta := MetaState.new(GameFlow.load_meta_rules())
	var rng := _rng(5)
	var r := NpcChatter.talk(NpcDef.BLACKSMITH, meta, db, rng)
	t.eq(r.get("special", &""), &"", "1 级：闲聊")
	meta.facility_levels[&"smithy"] = 3
	r = NpcChatter.talk(NpcDef.BLACKSMITH, meta, db, rng)
	t.eq([r.get("special", &""), r.get("given", &"")], [&"poxiao_start", &"poxiao_token"], "3 级：专属对话、给信物")
	t.eq(meta.warehouse.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"poxiao_token").size(), 1, "信物在仓库")
	t.check(NpcChatter.done(meta, &"poxiao_start"), "记作做过")
	r = NpcChatter.talk(NpcDef.BLACKSMITH, meta, db, rng)
	t.eq(r.get("special", &""), &"", "再点：闲聊")
	var other := MetaState.new(GameFlow.load_meta_rules())
	other.facility_levels[&"smithy"] = 3
	other.warehouse.try_add(ItemInstance.create(db.get_def(&"poxiao")), true)
	t.eq(NpcChatter.talk(NpcDef.BLACKSMITH, other, db, rng).get("special", &""), &"", "仓库里已有破晓：不触发")
	t.check(not NpcChatter.done(other, &"poxiao_start"), "也没记作做过（以后没了破晓还能触发）")


static func run_save(t: TestCase) -> void:
	t.begin("282 · 存档：最近说过的句与做过的专属对话跟局外存档走；老档没有 = 都没说过")
	var meta := MetaState.new()
	meta.npc_said["blacksmith"] = ["lore_1", "guide_2"]
	meta.npc_done["poxiao_start"] = true
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(meta.to_dict())), _db())
	t.eq(back.npc_said, {"blacksmith": ["lore_1", "guide_2"]}, "说过的句")
	t.eq(back.npc_done, {"poxiao_start": true}, "做过的专属对话")
	var d := meta.to_dict()
	d.erase("npc_said")
	d.erase("npc_done")
	var old := MetaState.from_dict(d, _db())
	t.check(old.npc_said.is_empty() and old.npc_done.is_empty(), "老档：空")


static func frame_pages(t: TestCase, root: Window) -> void:
	t.begin("282 · 三页都站着人：铁匠铺、集市散货摊、局内商店；点头像弹纸条（台词空着写「……」），点外面收起")
	var f := W178._flow()
	var s: Control = W178._screen(f, root)
	s.show_tab("smithy")
	var smithy = s.smithy_panel()
	var b: NpcBadge = smithy.npc
	t.check(b != null and b.slot.picture != null, "铁匠铺：铁匠头像")
	if b != null:
		b.talk()
		t.check(b.is_open() and b.line_label.text == UiText.t("npc.more"), "点了：纸条，台词空着写「……」")
		t.check(b.note.theme_type_variation == UiTheme.PANEL_HOME_CHIP, "纸条是浅羊皮签")
		b.close()
		t.check(not b.is_open(), "收起")
	s.show_tab("market")
	var market = s.market_panel()
	t.check(market.npc != null and market.npc.slot.picture != null, "集市：散货摊摊主")
	s.free()
	W178._cleanup()
	var opened := Shop._open(root)
	var screen = opened["screen"]
	t.check(screen.npc != null and screen.npc.slot.picture != null, "局内商店：店主")
	screen.queue_free()
