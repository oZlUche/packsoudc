## 报告 303 顺带：`Array[StringName].sort()` 按名字在进程里第一次出现的先后排（指针），不是字典序 ——
## 喂给随机数或要「顺序稳定」的几处改用 [Ids]（v5.65 改了候选表，这里是剩下的）
extends RefCounted


static func run_text_order(t: TestCase) -> void:
	t.begin("303 · 排序按 id 文本：属性表、资源池、套装、注册表类型名、赐福候选信仰都是字典序（名字先出现的不排前面）")
	var late := StringName("zz_sort_303")     # 先造 zz，再造 aa：按指针排就是 zz 在前
	var early := StringName("aa_sort_303")
	var st := StatSet.new()
	st.set_base(late, 1)
	st.set_base(early, 1)
	var ks := st.keys()
	t.check(ks.find(early) < ks.find(late), "StatSet.keys 字典序")
	var names := RegistryLookup.type_names(RunRegistry.TABLES, &"event_outcome")
	var sorted := names.duplicate()
	sorted.sort_custom(func(a, b): return String(a) < String(b))
	t.eq(names, sorted, "注册表类型名字典序")
	var items := ItemDatabase.new()
	items.load_dir()
	var faiths: Array = [&"sun", &"nature", &"hunt", &"earth", &"brute", &"skill"]
	for base in items.ids():
		var got := Blessings.faiths_with_variant(items, base, faiths)
		var want := got.duplicate()
		want.sort_custom(func(a, b): return String(a) < String(b))
		if got != want:
			t.check(false, "%s 的赐福候选没按字典序：%s" % [base, got])
			return
	t.check(true, "赐福候选信仰都是字典序")
