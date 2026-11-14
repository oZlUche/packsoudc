## 合成（314 起唯一的一种）：拿起一件、松手在能和它合成的另一件上（棋盘或地上）先开确认窗（[method fuse_preview]），
## 按「合成」才合（[method fuse]），成品落在被压那件的位置。拿起时能合的那几件标小锤（[method partner_ok]）。
## 不再看贴不贴着；也不是松手立刻合（114 那种已删）。
##
## 101 第 1 刀：配方表、配对规则、合成那一下全在这里，[RunState] 不认识合成。取它用 [method of]。
class_name CraftingModule
extends RunModule

const ID := &"crafting"

## 合成了一次：`detail = {"ok": true, "log": [几句话], "output": 产物 id, "recipe": 配方 id, "where": "board" / "storage"}`
signal done(detail: Dictionary)

## 配方表（内容，持有方给；没有就是这一局不合成）。[GameFlow] 在接管一局时赋上，
## 开局也可以由 `module_inputs[&"crafting"]["recipes"]` 给
var recipes: Array[RecipeDef] = []


## 这一局的合成模块（没装返回 null）
static func of(run: RunState) -> CraftingModule:
	return run.module(ID) as CraftingModule if run != null else null


func id() -> StringName:
	return ID


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if recipes.is_empty():
		var given: Variant = run.module_input(ID).get("recipes", null)
		if given is Array:
			for r in (given as Array):
				if r is RecipeDef:
					recipes.append(r as RecipeDef)


## 305（方案 §6.2）：玩家对这两件合成什么知道多少 —— 2 = 自己合成过这张配方；1 = 没合成过、但认识成品；0 = 都不知道（成品打问号）。没配方 = -1
## 312：赐福版按原件配，认识按原件家族算（[method RunState.has_met]）
func known_level(a: ItemDef, b: ItemDef) -> int:
	var r := RecipeDef.find(recipes, FusionResolve.base_of(a), FusionResolve.base_of(b)) if a != null and b != null else null
	if r == null or _run == null:
		return -1
	return _known(r.id, r.output)


func _known(recipe_id: StringName, output: StringName) -> int:
	if _run.knows_recipe(recipe_id):
		return 2
	return 1 if _run.has_met(output) else 0


## 312：这两件实际合成什么（[method FusionResolve.resolve]，带上这一局的道具库、神表、当前信仰）；没配方 = 空
func resolve(a: ItemDef, b: ItemDef) -> Dictionary:
	if _run == null:
		return {}
	var faiths: Array = _run.faith_defs.keys()
	Ids.sort(faiths)
	return FusionResolve.resolve(recipes, a, b, _run.items, faiths, _run.active_faith_id())


## 314：[param a]（手上那件）和 [param b]（被压那件）能不能合 —— 有配方、数据对（禁忌待办也算：照样标、弹窗说一句）、两件都吃得掉
func partner_ok(a: ItemInstance, b: ItemInstance) -> bool:
	if a == null or b == null or a == b or a.def == null or b.def == null or _run == null:
		return false
	if not Fusion.spendable(_run.board, a) or not Fusion.spendable(_run.board, b):
		return false
	var res := resolve(a.def, b.def)
	return not res.is_empty() and String(res["status"]) != FusionResolve.INVALID


## 这件在哪：棋盘、地上；都不在 = null
func home_of(uid: int) -> ItemContainer:
	if _run == null:
		return null
	if _run.board != null and _run.board.has_item(uid):
		return _run.board
	if _run.storage != null and _run.storage.has_item(uid):
		return _run.storage
	return null


## 305：合之前看一眼：`{"a", "b": 两件 ItemInstance, "output": 成品 ItemDef（禁忌待办时是原件成品，只用来占位）,
## "known": [method known_level], "resolution": [method resolve]}`；合不了 / 数据不对 = 空。[param b] 是被压的那件
func preview(a: ItemInstance, b: ItemInstance) -> Dictionary:
	if not partner_ok(a, b):
		return {}
	var res := resolve(a.def, b.def)
	var shown := StringName(res["output_id"]) if String(res["status"]) == FusionResolve.READY else StringName(res["base_output_id"])
	var out_def := _run.items.get_def(shown) if _run.items != null else null
	if out_def == null:
		return {}
	return {"a": a, "b": b, "output": out_def, "known": _known(StringName(res["recipe_id"]), out_def.id), "resolution": res}


## 同上，按 uid 在棋盘、地上找
func fuse_preview(a_uid: int, b_uid: int) -> Dictionary:
	var ha := home_of(a_uid)
	var hb := home_of(b_uid)
	return preview(ha.get_item(a_uid), hb.get_item(b_uid)) if ha != null and hb != null else {}


## 按 uid 合（两件都在棋盘或地上）：见 [method fuse_items]
func fuse(a_uid: int, b_uid: int, expect: StringName = &"") -> Dictionary:
	var ha := home_of(a_uid)
	var hb := home_of(b_uid)
	if ha == null or hb == null:
		return {"ok": false, "output": "", "where": "", "log": []}
	return fuse_items(ha.get_item(a_uid), ha, hb.get_item(b_uid), hb, expect)


## 314：合 —— [param a]（手上那件，已回到 [param a_home]）压在 [param b]（在 [param b_home]：棋盘或地上）上，两件消耗，
## 成品落在 b 的位置：棋盘上先在 b 的格里、再加上 a 在棋盘上的格、再盖住 b 的某一格、再在棋盘上找空；地上落在 b 那一处。放不下原样不动（`"reason": "no_room"`）。
## 312：成品按 [method resolve]；禁忌待办 / 数据不对不合；[param expect] 给了（确认窗上显示的成品 id）而现在解析出来不一样 = 不合（`"changed": true`），让界面重开。
## 返回 `{"ok", "output": 产物 id, "recipe": 配方 id, "where": "board" / "storage", "log": [几句话]}`，成了发一次 [signal done]
func fuse_items(a: ItemInstance, a_home: ItemContainer, b: ItemInstance, b_home: ItemContainer, expect: StringName = &"") -> Dictionary:
	var failed := {"ok": false, "output": "", "where": "", "log": []}
	if _run == null or a_home == null or b_home == null or a == null or b == null:
		return failed
	if not a_home.has_item(a.uid) or not b_home.has_item(b.uid) or not partner_ok(a, b):
		return failed
	var res := resolve(a.def, b.def)
	if String(res["status"]) != FusionResolve.READY:
		return failed
	if expect != &"" and StringName(res["output_id"]) != expect:
		failed["changed"] = true
		return failed
	var out_def := _run.items.get_def(StringName(res["output_id"])) if _run.items != null else null
	if out_def == null:
		return failed
	var names := [Names.of(a.def), Names.of(b.def), Names.of(out_def)]
	var out := ItemInstance.create(out_def, b.rotation)
	carry_basis(out, [a, b])     # 319：成品接着两件的本金
	var where := ""
	if b_home == _run.board:
		where = "board" if _land_on_board(a, a_home, b, out) else ""
	elif b_home == _run.storage:
		var spot := _run.storage.spot_of(b.uid)
		var at := _run.storage.index_of(b.uid)
		_run.storage.remove(b.uid)
		a_home.remove(a.uid)
		where = "storage" if _run.storage.insert(out, at, spot) else ""
	if where == "":
		failed["reason"] = "no_room"
		return failed
	return _settle(StringName(res["recipe_id"]), out_def, where, [UiText.t("craft.done") % names])


## 319：[param from] 里有本金的（带进来的、买来的），成品记它们本金之和；都没有就不记（全是这一局得的）
static func carry_basis(out: ItemInstance, from: Array) -> void:
	var total := 0
	var any := false
	for inst in from:
		if inst is ItemInstance and (inst as ItemInstance).has_basis():
			any = true
			total += (inst as ItemInstance).basis()
	if any and out != null:
		out.set_basis(total)


## 成品落进棋盘：拿掉 b（a 在棋盘上也拿掉），先落在 b 的格里，再加上 a 的格，再盖住 b 的某一格往四周伸，再随便找空；都不行两件原样放回
func _land_on_board(a: ItemInstance, a_home: ItemContainer, b: ItemInstance, out: ItemInstance) -> bool:
	var board := _run.board
	var a_on := a_home == board
	var homes := [[b, b.origin, b.rotation]]
	if a_on:
		homes.append([a, a.origin, a.rotation])
	board.begin_batch()
	board.remove(b.uid)
	if a_on:
		board.remove(a.uid)
	var ok := false
	for freed in ([[b], [b, a]] if a_on else [[b]]):
		var spot := Fusion.landing(board, freed, out.def)
		if not spot.is_empty() and board.place(out, spot["origin"], int(spot["rot"])):
			ok = true
			break
	if not ok:
		var cover := Fusion.covering(board, b, out.def)
		ok = not cover.is_empty() and board.place(out, cover["origin"], int(cover["rot"]))
	if not ok:
		ok = board.try_add(out, true)
	if not ok:
		for h in homes:
			board.place(h[0], h[1], h[2])
		board.end_batch()
		return false
	board.end_batch()
	if not a_on:
		a_home.remove(a.uid)
	return true


## 合成成了的那笔账：记一次合成、学到这张配方、认识成品（落在地上也算），发 [signal done]
func _settle(recipe_id: StringName, out_def: ItemDef, where: String, lines: Array) -> Dictionary:
	var detail := {"ok": true, "output": String(out_def.id), "recipe": String(recipe_id), "where": where, "log": lines}
	_run.tally["crafts"] = int(_run.tally.get("crafts", 0)) + 1     # 224：结算账单「合成」
	_run.lore.learn_recipe(recipe_id)     # 305
	_run.lore.meet(out_def.id)
	done.emit(detail)
	return detail
