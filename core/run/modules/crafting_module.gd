## 合成（114，作者定）：**拖到上面立刻合** —— 一局里把一件道具拖到棋盘上另一件上面（正好只压着这一件）、两件有配方，
## 两件消失、产物立刻出现在被压那件的位置。放不下自动找位，再不行到地上并提醒。
## 不再有 087 的「相邻即合 / 走到下一个点结算」：相邻是增益槽 / 受益槽的事，挨着放不该把东西变掉。
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


## 这两件能合成什么：配方里有就返回产物的定义；没有 null
func output_of(a: ItemDef, b: ItemDef) -> ItemDef:
	if a == null or b == null or _run == null or _run.items == null:
		return null
	var r := RecipeDef.find(recipes, a.id, b.id)
	return _run.items.get_def(r.output) if r != null else null


## 305（方案 §6.2）：玩家对这两件合成什么知道多少 —— 2 = 自己合成过这张配方；1 = 没合成过、但认识成品；0 = 都不知道（成品打问号）。没配方 = -1
## [param adjacent] = 拼接配方（贴着点锤），否则拖合
func known_level(a: ItemDef, b: ItemDef, adjacent: bool = false) -> int:
	var r := RecipeDef.find(recipes, a.id, b.id, adjacent) if a != null and b != null else null
	if r == null or _run == null:
		return -1
	return _known(r.id, r.output)


func _known(recipe_id: StringName, output: StringName) -> int:
	if _run.knows_recipe(recipe_id):
		return 2
	return 1 if _run.has_met(output) else 0


## 305：点锤之后、合之前看一眼：`{"a", "b": 两件 ItemInstance, "output": 成品 ItemDef, "known": [method known_level]}`；拼不了 = 空
func fuse_preview(a_uid: int, b_uid: int) -> Dictionary:
	if _run == null or _run.board == null or _run.items == null:
		return {}
	for p in Fusion.pairs(_run.board, recipes):
		if (int(p["a"]) == a_uid and int(p["b"]) == b_uid) or (int(p["a"]) == b_uid and int(p["b"]) == a_uid):
			var a := _run.board.get_item(a_uid)
			var b := _run.board.get_item(b_uid)
			var out_def := _run.items.get_def(StringName(p["output"]))
			if out_def == null:
				return {}
			return {"a": a, "b": b, "output": out_def, "known": _known(StringName(p["recipe"]), out_def.id)}
	return {}


## 140：这两件的配方说明（作者写的 `note`，拖到搭档上时预览旁边那行小字）；没有配方或没写返回空串
func note_of(a: ItemDef, b: ItemDef) -> String:
	if a == null or b == null:
		return ""
	var r := RecipeDef.find(recipes, a.id, b.id)
	return Names.pick(r.notes, r.note) if r != null else ""


## 114（作者定）：**拖到上面立刻合** —— 手上的 [param a]（拖拽中，不在任何容器里）压在棋盘上的 [param b_uid] 那件上、
## 两件有配方：b 拆下，产物落在 b 的位置（b 的朝向），放不下自动找位，再不行到地上并提醒。a 就此消耗。
## 返回 `{"ok": bool, "output": 产物 id, "where": "board" / "storage", "log": [几句话]}`；不成（没配方、b 不在棋盘上、产物没地方去）
## 时棋盘原样不动、a 仍在调用方手上。成了发一次 [signal done]
func craft(a: ItemInstance, b_uid: int) -> Dictionary:
	var failed := {"ok": false, "output": "", "where": "", "log": []}
	var board: GridInventory = _run.board if _run != null else null
	if board == null or a == null or a.def == null:
		return failed
	var b := board.get_item(b_uid)
	if b == null or b.def == null or a.is_locked_by_player() or not Fusion.spendable(board, b):
		return failed     # 305：锁定的、扎根的、随身之物不被合掉
	var r := RecipeDef.find(recipes, a.def.id, b.def.id)
	var out_def := _run.items.get_def(r.output) if r != null and _run.items != null else null
	if out_def == null:
		return failed
	var home := b.origin
	var rot := b.rotation
	var out := ItemInstance.create(out_def, rot)
	var where := ""
	board.begin_batch()
	board.remove(b.uid)
	if board.place(out, home, rot) or board.try_add(out, true):
		where = "board"
	elif _run.storage != null and _run.storage.admit(out):
		where = "storage"
	else:
		board.place(b, home, rot)     # 产物没地方去：整件事作废
		board.end_batch()
		return failed
	board.end_batch()
	var lines: Array = [UiText.t("craft.done") % [Names.of(a.def), Names.of(b.def), Names.of(out_def)]]
	if where == "storage":
		lines.append(UiText.t("craft.to_ground"))
	return _settle(r.id, out_def, where, lines)


## 279 拼接：棋盘上贴着、能拼的每一对（[method Fusion.pairs]）；没棋盘 / 没配方 = 空
func fusion_pairs() -> Array[Dictionary]:
	if _run == null or _run.board == null:
		return [] as Array[Dictionary]
	return Fusion.pairs(_run.board, recipes)


## 279 拼接（待定 2：点锤合）：棋盘上贴着的 [param a_uid]、[param b_uid] 两件有拼接配方 —— 两件消失，产物落在两件原来的占格里；
## 落不下在棋盘上找位，再不行到地上并提醒。不贴着、没配方、产物没地方去：棋盘原样不动。返回与 [method craft] 同样的字典，成了发一次 [signal done]
func fuse(a_uid: int, b_uid: int) -> Dictionary:
	var failed := {"ok": false, "output": "", "where": "", "log": []}
	var board: GridInventory = _run.board if _run != null else null
	if board == null:
		return failed
	var pair: Dictionary = {}
	for p in Fusion.pairs(board, recipes):
		if (int(p["a"]) == a_uid and int(p["b"]) == b_uid) or (int(p["a"]) == b_uid and int(p["b"]) == a_uid):
			pair = p
			break
	if pair.is_empty():
		return failed
	var a := board.get_item(a_uid)
	var b := board.get_item(b_uid)
	var out_def := _run.items.get_def(StringName(pair["output"])) if _run.items != null else null
	if out_def == null:
		return failed
	var names := [Names.of(a.def), Names.of(b.def), Names.of(out_def)]
	var where := "board"
	if Fusion.fuse(board, a_uid, b_uid, out_def) == null:
		var out := ItemInstance.create(out_def, 0)
		if _run.storage == null or not _run.storage.admit(out):
			return failed
		board.begin_batch()
		board.remove(a_uid)
		board.remove(b_uid)
		board.end_batch()
		where = "storage"
	var lines: Array = [UiText.t("craft.done") % names]
	if where == "storage":
		lines.append(UiText.t("craft.to_ground"))
	return _settle(StringName(pair["recipe"]), out_def, where, lines)


## 两种合成成了的同一笔账：记一次合成、学到这张配方、认识成品（落在地上也算），发 [signal done]
func _settle(recipe_id: StringName, out_def: ItemDef, where: String, lines: Array) -> Dictionary:
	var detail := {"ok": true, "output": String(out_def.id), "recipe": String(recipe_id), "where": where, "log": lines}
	_run.tally["crafts"] = int(_run.tally.get("crafts", 0)) + 1     # 224：结算账单「合成」
	_run.lore.learn_recipe(recipe_id)     # 305
	_run.lore.meet(out_def.id)
	done.emit(detail)
	return detail
