## 合成（114，作者定）：**拖到上面立刻合** —— 一局里把一件道具拖到棋盘上另一件上面（正好只压着这一件）、两件有配方，
## 两件消失、产物立刻出现在被压那件的位置。放不下自动找位，再不行到地上并提醒。
## 不再有 087 的「相邻即合 / 走到下一个点结算」：相邻是增益槽 / 受益槽的事，挨着放不该把东西变掉。
##
## 101 第 1 刀：配方表、配对规则、合成那一下全在这里，[RunState] 不认识合成。取它用 [method of]。
class_name CraftingModule
extends RunModule

const ID := &"crafting"

## 合成了一次：`detail = {"ok": true, "log": [几句话], "output": 产物 id, "where": "board" / "storage"}`
signal done(detail: Dictionary)

## 配方表（内容，持有方给；没有就是这一局不合成）。[GameFlow] 在接管一局时赋上，
## 开局也可以由 `module_inputs[&"crafting"]["recipes"]` 给
var recipes: Array[RecipeDef] = []
var _run: RunState = null


## 这一局的合成模块（没装返回 null）
static func of(run: RunState) -> CraftingModule:
	return run.module(ID) as CraftingModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "拖到上面立刻合：把一件拖到棋盘上另一件上面，两件有配方就合成"


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
	if b == null or b.def == null:
		return failed
	var out_def := output_of(a.def, b.def)
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
	var detail := {"ok": true, "output": String(out_def.id), "where": where, "log": lines}
	_run.tally["crafts"] = int(_run.tally.get("crafts", 0)) + 1     # 224：结算账单「合成」
	done.emit(detail)
	return detail


## 配方是内容、合成的结果在棋盘上，模块自己没有要存的状态
func to_dict() -> Dictionary:
	return {}

