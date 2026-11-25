extends SceneTree
const G := preload("res://tests/run/test_god_cards_388.gd")
func _one(label: String, cards: Dictionary) -> void:
	var run := G._start(53, &"skill")
	var lv := LevelModule.of(run)
	TestSupport.put(run.board, run.items.get_def(&"knife"))
	for k in cards: lv.taken[k] = cards[k]
	var me := run.compile_player()
	var foe := BattleCompiler.compile(GridInventory.new(Vector2i(4, 4)), CompileInput.new())
	foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
	var rng := RandomNumberGenerator.new(); rng.seed = 956
	var br := BattleSim.run(me, foe, rng, 20.0)
	var f := 0; var sk := 0; var mx := 0
	for e in br.log:
		if e.side != 0: continue
		if e.name == BattleEvent.ITEM_FIRED: f += 1
		if e.name == BattleEvent.ITEM_SKIPPED: sk += 1
		if e.name == BattleEvent.STATUS_STACKED and String(e.payload.get("buff", "")) == "skill_momentum": mx = maxi(mx, e.get_int(&"stacks"))
	print("D956 %s：出手 %d 跳过 %d 连击最多 %d" % [label, f, sk, mx])
	run.dispose()
func _init() -> void:
	_one("无牌", {})
	var all := {"god_skill_guard": 1, "god_skill_poise": 1, "god_skill_see": 1, "god_skill_ready": 1, "god_skill_steady": 1, "god_skill_parry": 1, "god_skill_zanshin": 1}
	_one("英文那一局的 7 张", all)
	for k in all: _one("只有 " + k, {k: 1})
	quit(0)
