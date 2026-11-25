extends SceneTree
## 测试 v8.69（PR #940）：一方声望 25 → 100 要几局。用真的告示栏（first_fill / refresh / _post）和真的接单、结案。
## 场景：开常规的阵营数 1 / 3 / 6；接单：只接目标方 / 不挑；每份每局办成的概率 1.0 / 0.67 / 0.5。每组 200 个种子。
const TARGET := &"greylamp"
const ALL := [&"greylamp", &"legion", &"society", &"growers", &"cartographers", &"pantheon"]

func _book_for(meta: MetaState, open: Array) -> void:
	var bk := meta.commissions
	for f in Commissions.factions(): bk.arrived[String(f.id)] = 0
	for fid in open:
		var f := Commissions.faction(fid)
		bk.rep[String(fid)] = 25
		if f.permit != &"": bk.entries[String(f.permit)] = {"state": CommissionBook.DONE, "times": 1, "stage": 0, "progress": 0, "keys": [], "pick": "", "seq": 0}
	Commissions.active = bk

func _one(seed_: int, open: Array, only_target: bool, p: float, extra_named: bool) -> Dictionary:
	var meta := MetaState.new()
	meta.market_seed = seed_
	_book_for(meta, open)
	var bk := meta.commissions
	NoticeBoard.first_fill(meta)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_ * 7 + 1
	var notes_done := 0
	var named := extra_named     # 灰灯 25 点的《食堂》+5，到 25 就能接，第一局办掉
	var idle := 0
	for run in 200:
		# 营地：接单（手头 3 份）
		for nid in NoticeBoard.posted(bk):
			if Commissions._taken_regular(bk) >= Commissions.SLOTS: break
			var d := Commissions.def(StringName(nid))
			if d == null: continue
			if only_target and d.faction != TARGET: continue
			Commissions.take(bk, d)
		var hand := bk.in_hand().filter(func(id: StringName) -> bool: return NoticeBoard.is_note(id))
		var tgt_hand := hand.filter(func(id: StringName) -> bool: return Commissions.def(id).faction == TARGET).size()
		if tgt_hand == 0: idle += 1
		# 这一局：手头每份按概率办成
		for id in hand:
			if rng.randf() < p:
				var d := Commissions.def(id)
				var was := d.faction == TARGET
				Commissions._complete(meta, d, null)
				if was: notes_done += 1
		if named:
			named = false
			bk.rep[String(TARGET)] = bk.rep_of(TARGET) + 5
		meta.runs += 1
		if bk.rep_of(TARGET) >= 100:
			return {"runs": run + 1, "notes": notes_done, "idle": idle}
		NoticeBoard.refresh(meta)
	return {"runs": 201, "notes": notes_done, "idle": idle}


func _initialize() -> void:
	var lines := []
	for k in [1, 3, 6]:
		var open := ALL.slice(0, k)
		for only_target in [true, false]:
			for p in [1.0, 0.67, 0.5]:
				for named in [false, true]:
					var rs := []
					var idle := 0
					for s in 200:
						var r := _one(1000 + s, open, only_target, p, named)
						rs.append(int(r["runs"])); idle += int(r["idle"])
					rs.sort()
					var sum := 0
					for x in rs: sum += x
					lines.append("开 %d 方 | %s | 每份办成 %.2f | 加《食堂》+5 %s | 局数 均 %.1f 中 %d 最少 %d 最多 %d（p10 %d p90 %d）| 手头没目标方的局 平均 %.1f" % [k, "只接灰灯" if only_target else "不挑阵营", p, "是" if named else "否", float(sum) / rs.size(), rs[100], rs[0], rs[-1], rs[20], rs[180], float(idle) / 200.0])
	for l in lines: print(l)
	# 一局的栏面样例：开 3 方，不挑，全办成
	var meta := MetaState.new(); meta.market_seed = 1000
	_book_for(meta, ALL.slice(0, 3))
	NoticeBoard.first_fill(meta)
	for run in 6:
		var post := NoticeBoard.posted(meta.commissions)
		var fs := []
		for nid in post: fs.append(String(Commissions.def(StringName(nid)).faction))
		print("样例 第 %d 局开局：栏上 %d 张 %s" % [run + 1, post.size(), str(fs)])
		for nid in post:
			if Commissions._taken_regular(meta.commissions) >= 3: break
			Commissions.take(meta.commissions, Commissions.def(StringName(nid)))
		for id in meta.commissions.in_hand():
			if NoticeBoard.is_note(id): Commissions._complete(meta, Commissions.def(id), null)
		meta.runs += 1
		NoticeBoard.refresh(meta)
	print("完 err=0")
	quit(0)
