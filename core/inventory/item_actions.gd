## 230（作者 19:01 选「两者都要」）：道具的**操作**一处供给 —— 一件东西此刻在哪个容器、哪一屏，就给哪几颗按钮。
## 悬浮窗只管画和点（[HoverTip]），各屏在视图上登记 `actions_for(uid) -> Array[ItemActions.Action]`（[member ContainerView.actions_for]）。
## 顺序 = 默认动作（就是双击做的那件事）→ 搬运 → 锁 → 危险；灰的也给（原因写在 `reason`）。
##
## 这里只放纯数据与通用的几颗（锁定 / 锁定同类、出售 / 出售同类）和排行规则（§2.6），不碰界面
class_name ItemActions
extends RefCounted

## 一颗按钮
class Action extends RefCounted:
	var id: StringName = &""
	var label: String = ""
	var enabled := true
	## 灰着时为什么（按钮的悬浮提示）
	var reason := ""
	## 两步确认（出售、献祭、放到地上……）：第一下变「再点一次」
	var danger := false
	## 成对的两颗（锁定 | 锁定同类、出售 | 出售同类）同一个键，排行时永远在同一行
	var pair: StringName = &""
	var run: Callable = Callable()
	## 251 补充一 §10.1：≥ 0 时按钮右端画「金币 + 这个数」（买的价钱），[member label] 只写动作
	var coin := -1


## 造一颗
static func make(id: StringName, label: String, run: Callable, danger: bool = false, pair: StringName = &"") -> Action:
	var a := Action.new()
	a.id = id
	a.label = label
	a.run = run
	a.danger = danger
	a.pair = pair
	return a


## 灰掉一颗（[param why] 写进它的悬浮提示）
static func disable(a: Action, why: String) -> Action:
	a.enabled = false
	a.reason = why
	return a


#region 通用的几颗
## 锁定 / 解锁这一件。[param after] 锁完叫（存档、刷新）
static func lock(inst: ItemInstance, container: ItemContainer, after: Callable = Callable()) -> Action:
	var on := inst.is_locked_by_player()
	return make(&"lock", UiText.t("act.unlock" if on else "act.lock"), func():
		inst.set_locked(not on)
		_touched(container, after), false, &"lock")


## 锁定同类 ×n / 解锁同类 ×n：[param container] 里同一个 id 的每一件（230 待定 4：同类 = 同 id）。全锁着时是「解锁同类」
static func lock_same(inst: ItemInstance, container: ItemContainer, after: Callable = Callable()) -> Action:
	var same := same_kind(inst, container)
	var all_on := same.all(func(i: ItemInstance) -> bool: return i.is_locked_by_player())
	return make(&"lock_same", UiText.t("act.unlock_same" if all_on else "act.lock_same") % same.size(), func():
		for i in same:
			(i as ItemInstance).set_locked(not all_on)
		_touched(container, after), false, &"lock")


## 2026-10-22（作者）：不参战 / 参战 —— 战前整备用：用不到的装备不必扔到地上散着，
## 标一下就不参战（东西还在棋盘上，占格照占、能拖、存档照存）；再点一下回来
static func bench(inst: ItemInstance, container: ItemContainer, after: Callable = Callable()) -> Action:
	var on := inst.is_benched()
	return make(&"bench", UiText.t("act.bench_on" if on else "act.bench"), func():
		inst.set_benched(not on)
		_touched(container, after))


## 出售 N 币（[param sell] = `func(uid) -> int` 卖一件，返回得了多少；没卖成 < 0）。锁着的灰
static func sell(inst: ItemInstance, price: int, do_sell: Callable) -> Action:
	var a := make(&"sell", UiText.t("act.sell") % price, func(): do_sell.call(inst.uid), true, &"sell")
	return disable(a, UiText.t("act.locked")) if inst.is_locked_by_player() else a


## 出售同类 ×n 得 M 币：[param container] 里同 id 没锁的那几件
static func sell_same(inst: ItemInstance, container: ItemContainer, price_of: Callable, do_sell: Callable) -> Action:
	var same := same_kind(inst, container).filter(func(i: ItemInstance) -> bool: return not i.is_locked_by_player())
	var total := 0
	for i in same:
		total += int(price_of.call(i))
	var a := make(&"sell_same", UiText.t("act.sell_same") % [same.size(), total], func():
		for i in same:
			do_sell.call((i as ItemInstance).uid), true, &"sell")
	return disable(a, UiText.t("act.locked")) if same.is_empty() else a


## 信物「奉为主信仰」（099 的右键改成按钮）：[param reseat] = `func(uid)`；已经是主信仰的灰着写「已是主信仰」
static func anchor(inst: ItemInstance, board: ItemContainer, reseat: Callable) -> Action:
	var main := is_main_anchor(inst, board)
	var a := make(&"anchor", UiText.t("act.anchor_now" if main else "act.anchor"), func(): reseat.call(inst.uid))
	return disable(a, "") if main else a


## 这件信物是不是现在的主信仰（棋盘上最后置入的那件信物）
static func is_main_anchor(inst: ItemInstance, board: ItemContainer) -> bool:
	var best: ItemInstance = null
	for i in board.items():
		var it := i as ItemInstance
		if it.def.is_anchor() and (best == null or it.placed_seq > best.placed_seq):
			best = it
	return best == inst


## 255：随身之物的按钮全灰（不参战 / 锁定 / 出售 / 丢到地上 / 献祭 / 进铸炉），理由一句「随身之物」。悬浮窗拿按钮时过一道（[HoverTip]）
static func pinned_guard(inst: ItemInstance, actions: Array) -> Array:
	if inst != null and inst.is_pinned():
		for a in actions:
			disable(a as Action, UiText.t("act.pinned"))
	return actions


## 同一个容器里和它同 id 的（含它自己）
static func same_kind(inst: ItemInstance, container: ItemContainer) -> Array:
	var out: Array = []
	if container == null:
		return [inst]
	for i in container.items():
		if (i as ItemInstance).def.id == inst.def.id:
			out.append(i)
	return out


## 锁了 / 解了：容器发一声 changed（视图重画小锁），再叫回调
static func _touched(container: ItemContainer, after: Callable) -> void:
	if container != null:
		container.changed.emit()
	if after.is_valid():
		after.call()
#endregion


#region 排行（§2.6，UI替换美术 19:26）
## 把按钮排成行：两两并排；成对的同一行不拆；单颗后面紧跟一对、或单颗落在最后 → 独占一行；
## 一行两颗时任一颗放不下半宽（[param fits_half] = `func(label) -> bool`）→ 这一行拆成两行。返回 `[[Action], [Action, Action], …]`
static func rows(actions: Array, fits_half: Callable = Callable()) -> Array:
	var out: Array = []
	var i := 0
	while i < actions.size():
		var two := _pair_start(actions, i) or (i + 1 < actions.size() and not _pair_start(actions, i + 1))
		if not two:
			out.append([actions[i]])
			i += 1
			continue
		var a: Action = actions[i]
		var b: Action = actions[i + 1]
		if not fits_half.is_valid() or (bool(fits_half.call(a.label)) and bool(fits_half.call(b.label))):
			out.append([a, b])
		else:
			out.append([a])
			out.append([b])
		i += 2
	return out


## 第 [param j] 颗是不是一对的前一颗（落单的「锁定」不算一对，和别的单颗照样并排）
static func _pair_start(actions: Array, j: int) -> bool:
	if j + 1 >= actions.size():
		return false
	var x: Action = actions[j]
	return x.pair != &"" and x.pair == (actions[j + 1] as Action).pair
#endregion
