## 合成（279 拼接；310 改造 C 批起是唯一的一种）：两件在棋盘上贴着、有配方，接缝上浮一枚小锤；点锤先开确认窗
## （[method fuse_preview]），按「合成」才合（[method fuse]）。114 的「拖到上面立刻合」已删。
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
func known_level(a: ItemDef, b: ItemDef) -> int:
	var r := RecipeDef.find(recipes, a.id, b.id) if a != null and b != null else null
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


## 279 拼接：棋盘上贴着、能拼的每一对（[method Fusion.pairs]）；没棋盘 / 没配方 = 空
func fusion_pairs() -> Array[Dictionary]:
	if _run == null or _run.board == null:
		return [] as Array[Dictionary]
	return Fusion.pairs(_run.board, recipes)


## 279 拼接（待定 2：点锤合）：棋盘上贴着的 [param a_uid]、[param b_uid] 两件有拼接配方 —— 两件消失，产物落在两件原来的占格里；
## 落不下在棋盘上找位，再不行到地上并提醒。不贴着、没配方、产物没地方去：棋盘原样不动。返回 `{"ok": bool, "output": 产物 id, "recipe": 配方 id, "where": "board" / "storage", "log": [几句话]}`，成了发一次 [signal done]
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


## 合成成了的那笔账：记一次合成、学到这张配方、认识成品（落在地上也算），发 [signal done]
func _settle(recipe_id: StringName, out_def: ItemDef, where: String, lines: Array) -> Dictionary:
	var detail := {"ok": true, "output": String(out_def.id), "recipe": String(recipe_id), "where": where, "log": lines}
	_run.tally["crafts"] = int(_run.tally.get("crafts", 0)) + 1     # 224：结算账单「合成」
	_run.lore.learn_recipe(recipe_id)     # 305
	_run.lore.meet(out_def.id)
	done.emit(detail)
	return detail
