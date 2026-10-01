## 合成（084 / 087，作者定）：**相邻即合** —— 棋盘上两件有配方的道具四邻相接，走到下一个点时自动合成，
## 不用拖到一起、也没有「配对」这一步。产物落在 a 的位置（a 的朝向），放不下试 b 的位置、再自动找位，
## 再不行进暂存区并提醒。
##
## 101 第 1 刀：配方表、配对规则、合成那一下全在这里，[RunState] 不认识合成。取它用 [method of]。
class_name CraftingModule
extends RunModule

const ID := &"crafting"

## 到了下一个点，合成发生了（或没成）：
## `detail = {"log": [几句话], "output": 产物 id 或空, "where": "board" / "storage" / ""}`
signal done(node_id: int, detail: Dictionary)

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
	return "相邻即合：棋盘上有配方的两件相邻，走到下一个点就自动合成"


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
	# 头一回踩上一个点时合（暂存区已经把留在这儿的东西还回来了，产物才有地方去）
	if not run.arrived.is_connected(_on_arrived):
		run.arrived.connect(_on_arrived)


## 这两件能合成什么：配方里有就返回产物的定义；没有 null
func output_of(a: ItemDef, b: ItemDef) -> ItemDef:
	if a == null or b == null or _run == null or _run.items == null:
		return null
	var r := RecipeDef.find(recipes, a.id, b.id)
	return _run.items.get_def(r.output) if r != null else null


## 087：棋盘上现在相邻、有配方的对子，`[[a, b, 产物定义], …]`：a 是 uid 小的那件。每件只进一对（uid 升序先配到的算），
## 顺序稳定 —— 同一个棋盘永远同样的结果。包不参与邻接（[method GridInventory.neighbors_of]）
func pairs() -> Array:
	var out: Array = []
	var board: GridInventory = _run.board if _run != null else null
	if board == null or recipes.is_empty():
		return out
	var used := {}
	var uids: Array[int] = []
	for inst in board.items():
		uids.append((inst as ItemInstance).uid)
	uids.sort()
	for uid in uids:
		if used.has(uid):
			continue
		var a := board.get_item(uid)
		if a == null or a.def == null or board.acts_as_bag(a.def):
			continue
		for other in board.neighbors_of(uid):
			if used.has(other):
				continue
			var b := board.get_item(other)
			if b == null or b.def == null:
				continue
			var out_def := output_of(a.def, b.def)
			if out_def == null:
				continue
			used[uid] = true
			used[b.uid] = true
			out.append([a, b, out_def])
			break
	return out


## 棋盘上这件现在配着谁（界面画「合」）；没有 null
func partner_of(uid: int) -> ItemInstance:
	for pair in pairs():
		if (pair[0] as ItemInstance).uid == uid:
			return pair[1]
		if (pair[1] as ItemInstance).uid == uid:
			return pair[0]
	return null


## 到了一个点（暂存区已经还回来了）：把此刻相邻的每一对合掉。每一桩发一次 [signal done]
func resolve(at_id: int) -> void:
	var list := pairs()
	if list.is_empty() or _run == null:
		return
	var board := _run.board
	for pair in list:
		var a: ItemInstance = pair[0]
		var b: ItemInstance = pair[1]
		var out_def: ItemDef = pair[2]
		var detail := {"log": [] as Array, "output": String(out_def.id), "where": ""}
		var out := ItemInstance.create(out_def, a.rotation)
		var where := ""
		board.begin_batch()
		var home_a := a.origin
		var rot_a := a.rotation
		var home_b := b.origin
		var rot_b := b.rotation
		board.remove(a.uid)
		board.remove(b.uid)
		if board.place(out, home_a, rot_a) or board.place(out, home_b, rot_b) or board.try_add(out, true):
			where = "board"
		elif _run.storage != null and _run.storage.admit(out):
			where = "storage"
		board.end_batch()
		detail["where"] = where
		(detail["log"] as Array).append("「%s」和「%s」相邻，合成了「%s」。" % [a.def.display_name, b.def.display_name, out_def.display_name])
		if where == "storage":
			(detail["log"] as Array).append("背包里装不下它：放进了暂存区。走之前记得放回包里，暂存区里的东西会留在这个点上。")
		done.emit(at_id, detail)


## 配方是内容、合成的结果在棋盘上，模块自己没有要存的状态
func to_dict() -> Dictionary:
	return {}


func _on_arrived(node_id: int, first_time: bool) -> void:
	if first_time:
		resolve(node_id)
