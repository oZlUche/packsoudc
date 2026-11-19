## 局内界面布局方案 §4.2（待办 2026-11-14「行动前预览实际代价与危险」）：在地图上走到某个点之前，算出这一步（或连走的一串）
## [b]真正[/b]会发生什么 —— 倒计时实际扣几（进阶七按累计多扣、向下取整之后的数，不是倍率）、走进被侵蚀的点会扣多少体力 / 金币、
## 会不会侵蚀或毁掉一件道具、看得见的猎手这一步之后够不够得着。
##
## 只读：照 [method MapTravel.apply]（行动点 = [method MapTravel.cost_of] 的算法，熟门熟路的免费步、负重倍数）、
## [method CountdownModule.spent]（累计 × (100 + 多扣) / 100 向下取整）、[method ErosionField.on_action]（推进几档）的同一套数在副本上走一遍，
## 不改任何状态、不抽随机数。规则改了这里跟着改（测试拿真实走一步的结果对这里的预测）。
##
## 不泄露：只说看得见的猎手（[method HunterSystem.visible_hunters]）；侵蚀挑中哪一件不说；有概率的效果写「可能」。
## 侵蚀的推进时刻本来就在顶栏读数里（[code]hud.erosion_band[/code]），预测它不算多给信息
class_name ActionPreview
extends RefCounted

## 预测结果的键
const COUNTDOWN := "countdown"     # 倒计时实际扣几（没有倒计时 = -1）
const ACTIONS := "actions"     # 行动点合计
const STEPS := "steps"     # 走几步
const LOAD_MULT := "load_mult"     # 负重倍数（>1 才说）
const VITALITY := "vitality"     # 侵蚀一定扣的体力
const VITALITY_MAYBE := "vitality_maybe"     # 侵蚀可能扣的体力（有概率的效果）
const MONEY := "money"
const MONEY_MAYBE := "money_maybe"
const ITEM_LAYER := "item_layer"     # 0 不会 / 1 可能 / 2 一定 —— 侵蚀一件随身道具（进阶九）
const ITEM_LOSS := "item_loss"     # 0 / 1 / 2 —— 毁掉一件道具
const HUNTERS := "hunters"     # 看得见、这一步之后可能够得着的猎手名字
const LOAD_ROOM := "load_room"     # 再重几就到下一档走路倍数（离得远 / 没有下一档 = 0）
const LOAD_NEXT := "load_next"     # 下一档走一步乘几
## §4.3：负重离下一档走路倍数只差上限的这么多成以内才在地图上提（平时留在背包里）
const LOAD_NEAR := 0.1


## [param path]：要走的点（不含脚下，最后一个是终点；隔壁就是一个点）。走不通（不相邻、不在图上）返回空字典
static func of(run: RunState, path: Array[int]) -> Dictionary:
	if run == null or run.travel == null or run.map == null or path.is_empty() or run.phase != RunState.Phase.ON_MAP:
		return {}
	var travel := run.travel
	var total := travel.clock.total if travel.clock != null else 0
	var paid := travel.paid_steps
	var field: ErosionField = travel.erosion
	var bands := field.eroded_bands if field != null else -1
	var next_at := field.next_at_action if field != null else 0
	var balance := run.wallet.balance if run.wallet != null else 0
	var vit_left := run.vitality.current if run.vitality != null else 0
	var out := {COUNTDOWN: -1, ACTIONS: 0, STEPS: path.size(), LOAD_MULT: maxi(1, travel.action_cost_mult), VITALITY: 0, VITALITY_MAYBE: 0,
		MONEY: 0, MONEY_MAYBE: 0, ITEM_LAYER: 0, ITEM_LOSS: 0, HUNTERS: [] as Array[String]}
	var start_total := total
	var from := travel.current_id
	for to in path:
		var intent := MapNavigator.resolve_step(run.map, from, to)
		if intent == null:
			return {}
		var free := travel.free_step_every > 0 and paid >= travel.free_step_every
		var cost := 0 if free else intent.action_cost * maxi(1, travel.action_cost_mult)
		paid = 0 if free else paid + 1
		total += cost
		if field != null and field.mechanic != null:
			while bands < field.max_band and total >= next_at:
				bands += 1
				next_at += maxi(1, field.mechanic.interval_actions)
			var stops: Array[int] = []
			stops.append_array(intent.passes_through)
			stops.append(to)
			for id in stops:
				var node := run.map.get_node(id)
				if node == null or bands < 0 or node.erosion_band > bands:
					continue
				var hit := _erosion_at(run, field, bands - node.erosion_band, bands >= field.max_band, balance, vit_left)
				for k in [VITALITY, VITALITY_MAYBE, MONEY, MONEY_MAYBE]:
					out[k] = int(out[k]) + int(hit[k])
				balance -= int(hit[MONEY])
				vit_left -= int(hit[VITALITY])
				out[ITEM_LAYER] = maxi(int(out[ITEM_LAYER]), int(hit[ITEM_LAYER]))
				out[ITEM_LOSS] = maxi(int(out[ITEM_LOSS]), int(hit[ITEM_LOSS]))
		from = to
	out[ACTIONS] = total - start_total
	var cd := CountdownModule.of(run)
	if cd != null and cd.has_countdown():
		out[COUNTDOWN] = _spent(run, total) - _spent(run, start_total)
	out[HUNTERS] = _hunters_near(run, path)
	var room := load_room(run)
	out[LOAD_ROOM] = room[0]
	out[LOAD_NEXT] = room[1]
	return out


## §4.3：[再重几就到下一档走路倍数, 那一档乘几]；离得远（超过上限的 [constant LOAD_NEAR]）、没有更重的一档、这一章不算负重 = [0, 0]
static func load_room(run: RunState) -> Array:
	var enc := run.encumbrance if run != null else null
	var cap := run.carry_capacity() if enc != null else 0
	if enc == null or cap <= 0:
		return [0, 0]
	var w := run.carry_weight()
	var now := enc.travel_mult_of(enc.level_of(w, cap))
	for i in enc.levels.size():
		var lv := enc.levels[i]
		if lv.travel_mult <= now:
			continue
		var room := floori(float(cap) * lv.over) + 1 - w     # 超过 上限 × over 才算这一档
		if room > 0 and room <= maxi(1, ceili(float(cap) * LOAD_NEAR)):
			return [room, lv.travel_mult]
		return [0, 0]
	return [0, 0]


## [method CountdownModule.spent] 的同一个算法，按给定的累计行动点
static func _spent(run: RunState, total: int) -> int:
	var pct := run.difficulty.countdown_percent if run.difficulty != null else 0
	@warning_ignore("integer_division")
	return total * (100 + maxi(0, pct)) / 100


## 走进一个被侵蚀了 [param depth] 层的点：各效果构件（[ErosionEffect] 的四道门里不抽随机的那三道 + 概率）
static func _erosion_at(run: RunState, field: ErosionField, depth: int, total_now: bool, balance: int, vit_left: int) -> Dictionary:
	var hit := {VITALITY: 0, VITALITY_MAYBE: 0, MONEY: 0, MONEY_MAYBE: 0, ITEM_LAYER: 0, ITEM_LOSS: 0}
	for e in field.mechanic.effects:
		var effect := e as ErosionEffect
		if effect == null or not effect.enabled or depth < effect.from_depth or (effect.only_total and not total_now) or effect.chance <= 0.0:
			continue
		var sure := effect.chance >= 1.0
		if effect is ErodeSpendVitality:
			var s := effect as ErodeSpendVitality
			var n := mini(maxi(0, s.amount + s.per_depth * depth - run.buff_context().erosion_resist), maxi(0, vit_left))
			hit[VITALITY if sure else VITALITY_MAYBE] = int(hit[VITALITY if sure else VITALITY_MAYBE]) + n
		elif effect is ErodeDrainMoney:
			var m := effect as ErodeDrainMoney
			var n := mini(maxi(0, m.amount + m.per_depth * depth), maxi(0, balance))
			hit[MONEY if sure else MONEY_MAYBE] = int(hit[MONEY if sure else MONEY_MAYBE]) + n
		elif effect is ErodeItemLayer:
			hit[ITEM_LAYER] = maxi(int(hit[ITEM_LAYER]), 2 if sure else 1)
		elif effect is ErodeDamageItem:
			hit[ITEM_LOSS] = maxi(int(hit[ITEM_LOSS]), 2 if sure else 1)
	return hit


## 看得见的猎手里，这一串走完之后可能够得着终点的（距离 ≤ 开打距离 + 这几步里它最多能走的步数，追击攒满再多一步）。
## 猎手往哪走由它的行动逻辑定、有随机，所以只说「可能」；还没出现的、看不见的一律不说
static func _hunters_near(run: RunState, path: Array[int]) -> Array[String]:
	var names: Array[String] = []
	var hs := run.hunters
	if hs == null or not hs.has_spawned or hs.metric == null:
		return names
	var dest: int = path[path.size() - 1]
	for h in hs.visible_hunters():
		var def := hs.def_of(h)
		if def == null:
			continue
		var reach := def.engage_range + float(maxi(0, def.speed) * path.size()) if not h.guarding else def.engage_range
		if hs.chase_percent() > 0 and not h.guarding:
			reach += 1.0
		if hs.metric.distance(h.node_id, dest) <= reach:
			var n := Names.of(def)
			if not names.has(n):
				names.append(n)
	return names


## 浮窗里的几行（BBCode，钱是 `[coin=N]` 记号，显示方换成金币图）。什么都不用说返回空串
static func lines(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	var out: Array[String] = []
	var head := UiText.t("preview.walk") % int(p[STEPS]) if int(p[STEPS]) > 1 else UiText.t("preview.step")
	var parts: Array[String] = []
	if int(p[COUNTDOWN]) >= 0:
		parts.append(UiText.t("preview.countdown") % int(p[COUNTDOWN]))
	if int(p[LOAD_MULT]) > 1:
		parts.append(UiText.t("preview.load") % int(p[LOAD_MULT]))
	elif int(p.get(LOAD_ROOM, 0)) > 0:
		parts.append(UiText.t("preview.load_near") % [int(p[LOAD_ROOM]), int(p[LOAD_NEXT])])
	if not parts.is_empty():
		out.append("{c:dim}%s{/c}%s" % [head, UiText.t("preview.sep").join(parts)])
	var sure: Array[String] = []
	var maybe: Array[String] = []
	if int(p[VITALITY]) > 0: sure.append(UiText.t("preview.vitality") % int(p[VITALITY]))
	if int(p[MONEY]) > 0: sure.append("−" + CoinShort.coin(int(p[MONEY])))
	if int(p[ITEM_LAYER]) == 2: sure.append(UiText.t("erosion.entry_warning").trim_suffix("。").trim_suffix("."))
	if int(p[ITEM_LOSS]) == 2: sure.append(UiText.t("preview.item_loss"))
	if int(p[VITALITY_MAYBE]) > 0: maybe.append(UiText.t("preview.vitality") % int(p[VITALITY_MAYBE]))
	if int(p[MONEY_MAYBE]) > 0: maybe.append("−" + CoinShort.coin(int(p[MONEY_MAYBE])))
	if int(p[ITEM_LAYER]) == 1: maybe.append(UiText.t("erosion.entry_warning").trim_suffix("。").trim_suffix("."))
	if int(p[ITEM_LOSS]) == 1: maybe.append(UiText.t("preview.item_loss"))
	if not sure.is_empty():
		out.append("{c:danger}%s{/c}%s" % [UiText.t("preview.erosion"), UiText.t("preview.sep").join(sure)])
	if not maybe.is_empty():
		out.append("{c:warn}%s{/c}%s" % [UiText.t("preview.maybe"), UiText.t("preview.sep").join(maybe)])
	var hunters: Array = p[HUNTERS]
	if not hunters.is_empty():
		out.append("{c:danger}%s{/c}%s" % [UiText.t("preview.hunter"), UiText.t("preview.sep").join(hunters)])
	return TextTemplate.render("\n".join(out), {})
