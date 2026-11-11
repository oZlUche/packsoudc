## 272 战记：把一场的回放日志写成人读的一行行字（纯函数，不碰界面）。
##
## 一次出手 = 一组：从一条 item_fired 起，同一刻里同一方同一件引出的伤害、治疗、施加都归这一组；
## 没有出手事件的行（持续伤害、消失、倒下、反应……）各自成组。相邻两组的正文交替用 `log_a` / `log_b` 两种墨，
## 组内的数字与属性词仍用属性色。同一组第二行起缩进、省掉「谁使用什么」。
##
## 每行 `{time, group, side, at, text}`：`at` = 引出这一行的事件在日志里的下标（末行战报是日志长度），
## 回放放过那条事件就把这一行贴上去；`text` 是 bbcode，颜色写成颜色名（`[color=@log_a]`、`@dmg_fire`……），界面按底色深浅换（[method UiPalette.resolve_styles]）。
class_name BattleNarrator
extends RefCounted

## 战记最多留几行（超了丢最早的）
const MAX_LINES := 400


## [param names]：两方的名字；[param item_names]：两方的 uid → 道具名；[param loads]：两方的法杖 uid → 轮读的晶石 uid（按顺序）
static func lines(result: BattleResult, names: Array, item_names: Array = [], loads: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if result == null:
		return out
	var n := _Narration.new()
	n.result = result
	n.names = names
	n.item_names = item_names
	n.loads = loads
	n.run()
	out = n.out
	out.append(n.line(result.log.size(), result.duration, -1, null, report(result, names), false))     # 测试反馈：战报自己有秒数，行首不再写一遍
	return out


## 收尾战报：几秒、双方各造成多少（日志里伤害的数逐条累加，治疗不算）、谁打倒了谁
static func report(result: BattleResult, names: Array) -> String:
	var dealt := [0, 0]     # 下标 = 打出的一方
	for e in result.log:
		var ev := e as BattleEvent
		if ev.name == BattleEvent.DAMAGE and ev.side >= 0 and ev.side <= 1 and ev.get_int(&"amount") > 0:
			dealt[1 - ev.side] += StatMath.to_int(ev.get_int(&"amount"))
	var end := UiText.t("battle.draw")
	if not result.is_draw():
		end = UiText.t("battle.defeated") % [names[result.winner], names[1 - result.winner]]
	return UiText.t("battle.report") % [result.duration_sec(), names[0], dealt[0], dealt[1], names[1], dealt[1], end]


## 一段整行的纯文字（测试、日志看）
static func plain(line: Dictionary) -> String:
	var rx := RegEx.create_from_string("\\[/?[a-z_]+(=[^\\]]*)?\\]")
	return rx.sub(String(line.get("text", "")), "", true)


## 持续伤害：[param def] 每跳打自己的伤害类型
static func dot_types(def: BuffDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if def == null:
		return out
	for r in def.rules:
		for e in (r as AbilityRule).effects:
			if e is DealDamage and (e as DealDamage).target == DealDamage.Target.SELF and not out.has((e as DealDamage).damage_type):
				out.append((e as DealDamage).damage_type)
	return out


## 一场写字时的状态（一次 [method lines] 用一个）
class _Narration:
	var result: BattleResult
	var names: Array = []
	var item_names: Array = []
	var loads: Array = []
	var out: Array[Dictionary] = []
	var _time := -1
	## 这一刻出过手的组：「side:uid」→ 组
	var _fired := {}
	var _last: Dictionary = {}
	var _groups := 0
	## 两方身上现在的状态：buff id → 层数；最近叠上的排在后面（推断持续伤害是哪个状态）
	var _stacks := [{}, {}]
	var _order := [[], []]
	## 反转成治疗的那一下：它连带的那条治疗不另写
	var _skip := {}
	## 301：这一刻刚引发的反应那一组（它打的伤害缩进写在下面）
	var _react: Dictionary = {}

	func run() -> void:
		_pair_inverted()
		var events := result.log
		for i in events.size():
			var e := events[i] as BattleEvent
			if e.time != _time:
				_time = e.time
				_fired = {}
				_last = {}
				_react = {}
			_event(i, e)

	func _pair_inverted() -> void:
		var events := result.log
		for j in events.size():
			var d := events[j] as BattleEvent
			if d.name != BattleEvent.DAMAGE or d.get_int(&"amount") >= 0:
				continue
			for k in range(j - 1, -1, -1):
				var r := events[k] as BattleEvent
				if r.time != d.time:
					break
				if r.name == BattleEvent.RESOURCE_CHANGED and r.side == d.side and not _skip.has(k) \
						and String(r.get_name(&"key")) == "hp" and String(r.get_name(&"reason")) == "heal" and r.get_int(&"delta") == -d.get_int(&"amount"):
					_skip[k] = true
					break

	func _event(i: int, e: BattleEvent) -> void:
		match e.name:
			BattleEvent.ITEM_FIRED:
				_open(e.side, e.get_int(&"uid"), e.payload.get("step", -1))
			BattleEvent.DAMAGE:
				_damage(i, e)
			BattleEvent.RESOURCE_CHANGED:
				if not _skip.has(i) and String(e.get_name(&"key")) == "hp" and String(e.get_name(&"reason")) == "heal" and e.get_int(&"delta") > 0:
					_heal(i, e)
			BattleEvent.STATUS_STACKED:
				_stacked(i, e)
			BattleEvent.STATUS_UNSTACKED:
				_track(e)
				if e.get_int(&"stacks") <= 0 and e.side >= 0:
					_alone(i, e, UiText.t("log.fade") % [_who(e.side), _buff(e.get_name(&"buff"))])
			BattleEvent.EFFECT_RESOLVED:
				var effect := String(e.payload.get("effect", ""))
				if effect == ReactionResolver.EFFECT:
					var def := ReactionResolver.by_id(e.get_name(&"reaction"))
					var label := Names.of(def) if def != null else String(e.get_name(&"reaction"))
					var els: Array = e.payload.get("elements", [])
					var c := _dmg(StringName(String(els[0]))) if not els.is_empty() else "crit"
					_react = _alone(i, e, UiText.t("log.reaction") % [_who(e.side), _paint(label, c)])
				elif effect == "undying":
					_alone(i, e, UiText.t("log.undying") % _who(e.side))
			BattleEvent.DIED:
				_alone(i, e, UiText.t("log.down") % _who(e.side))
			BattleEvent.OVERTIME_STACKED:
				if e.get_int(&"count") == 1:
					_alone(i, e, UiText.t("log.overtime") % e.get_int(&"percent"))
			BattleEvent.AXIS_SHIFTED:
				if not e.get_bool(&"system"):
					var a := e.get_name(&"axis")
					_alone(i, e, UiText.t("log.axis") % [_who(e.side), StatAxes.name_of(a, e.get_int(&"delta")), e.get_int(&"delta"), e.get_int(&"stacks")])
			BattleEvent.DECAY_STARTED:
				_alone(i, e, UiText.t("log.decay"))
			BattleEvent.DISPATCH_OVERFLOW:
				_alone(i, e, UiText.t("log.overflow"))

	## 新开一组（出手，或没有出手事件的规则打出了东西）
	func _open(side: int, uid: int, step: int = -1) -> Dictionary:
		var g := {"side": side, "uid": uid, "step": step, "id": -1, "lines": 0}
		_fired["%d:%d" % [side, uid]] = g
		_last = g
		return g

	func _group_of(side: int, uid: int) -> Dictionary:
		var g: Dictionary = _fired.get("%d:%d" % [side, uid], {})
		return g if not g.is_empty() else _open(side, uid)

	func _damage(i: int, e: BattleEvent) -> void:
		var amount := e.get_int(&"amount")
		var cancelled := e.get_bool(&"cancelled")
		var absorbed := maxi(0, e.get_int(&"absorbed"))
		var block := maxi(0, e.get_int(&"block"))
		if amount == 0 and absorbed == 0 and block == 0 and not cancelled:
			return
		var src := e.get_int(&"source_side", -1)
		var uid := e.get_int(&"uid")
		var type := e.get_name(&"type")
		var tint := _dmg(type)
		var type_word := _paint(UiText.t("log.true_word") if e.get_bool(&"pure") else DamageTypes.name_of(type), tint)
		if uid == 0 and (src == e.side or src < 0):     # 持续伤害（身上状态自己跳的）、环境伤害
			if cancelled:     # 281：被化解的一跳（单元素试炼）和直击同一个说法，不写 0 伤害
				_alone(i, e, UiText.t("log.dot_cancelled") % [_who(e.side), _dot_name(e.side, type)])
				return
			var n := _paint(str(StatMath.to_int(absi(amount))), tint)
			_alone(i, e, UiText.t("log.dot") % [_who(e.side), _dot_name(e.side, type), n, type_word])
			return
		var reacted := e.payload.has("reaction") and not _react.is_empty()     # 301：反应打的 —— 写在反应那一行下面
		var g := _react if reacted else _group_of(src, uid)
		var actor := _who(src)
		var item := _item(src, uid, int(g["step"]))
		var body := ""
		if cancelled:
			body = UiText.t("log.cancelled") % [actor, item]
		elif amount < 0:
			body = UiText.t("log.inverted") % [actor, item, _paint(str(StatMath.to_int(-amount)), "heal")]
		else:
			var stopped := absorbed + block
			var crit := e.get_bool(&"crit")
			var num_c := "crit" if crit else tint
			var dealt := _paint(str(StatMath.to_int(maxi(e.get_int(&"raw"), amount + stopped))), num_c)
			if reacted:
				body = UiText.t("log.reaction_hit") % [dealt, type_word]
			else:
				body = (UiText.t("log.hit_more") % [dealt, type_word]) if int(g["lines"]) > 0 else (UiText.t("log.hit") % [actor, item, dealt, type_word])
			if crit:
				body = _paint(UiText.t("log.crit"), num_c) + body
			if stopped > 0:
				var final := _paint(str(StatMath.to_int(amount)), tint)
				if absorbed > 0 and block > 0:
					body += UiText.t("log.blocked_split") % [str(StatMath.to_int(stopped)), str(StatMath.to_int(absorbed)), str(StatMath.to_int(block)), final]
				else:
					body += UiText.t("log.blocked") % [str(StatMath.to_int(stopped)), final]
		_put(i, e, g, body)

	func _heal(i: int, e: BattleEvent) -> void:
		var n := _paint(str(StatMath.to_int(e.get_int(&"delta"))), "heal")
		if not _last.is_empty() and int(_last["side"]) == e.side and int(_last["uid"]) > 0:
			var g := _last
			var body: String = (UiText.t("log.heal_more") % n) if int(g["lines"]) > 0 \
				else (UiText.t("log.heal") % [_who(e.side), _item(e.side, int(g["uid"]), int(g["step"])), n])
			_put(i, e, g, body)
			return
		_alone(i, e, UiText.t("log.heal_bare") % [_who(e.side), n])

	func _stacked(i: int, e: BattleEvent) -> void:
		_track(e)
		var delta := e.get_int(&"delta")
		var reason := String(e.payload.get("reason", ""))
		if delta <= 0 or reason == "system" or reason == "refresh" or e.side < 0:
			return
		var buff := _buff(e.get_name(&"buff"))
		var total := e.get_int(&"stacks")
		if _last.is_empty() or int(_last["uid"]) <= 0:
			_alone(i, e, UiText.t("log.stacked") % [_who(e.side), delta, buff, total])
			return
		var g := _last
		var actor := int(g["side"])
		var more := int(g["lines"]) > 0
		var body := ""
		if actor == e.side:
			body = (UiText.t("log.gain_more") % [delta, buff, total]) if more \
				else (UiText.t("log.gain") % [_who(actor), _item(actor, int(g["uid"]), int(g["step"])), delta, buff, total])
		else:
			body = (UiText.t("log.apply_more") % [_who(e.side), delta, buff, total]) if more \
				else (UiText.t("log.apply") % [_who(actor), _item(actor, int(g["uid"]), int(g["step"])), _who(e.side), delta, buff, total])
		_put(i, e, g, body)

	## 记两方身上现在的层数（推断持续伤害来源用）
	func _track(e: BattleEvent) -> void:
		if e.side < 0 or e.side > 1:
			return
		var id := String(e.get_name(&"buff"))
		var n := e.get_int(&"stacks")
		var order: Array = _order[e.side]
		order.erase(id)
		if n > 0:
			_stacks[e.side][id] = n
			if e.name == BattleEvent.STATUS_STACKED:
				order.append(id)
			else:
				order.push_front(id)
		else:
			_stacks[e.side].erase(id)

	## 持续伤害是哪个状态跳的：身上现在有、每跳打这种类型的，取最近叠上的；推断不出写「持续效果」
	func _dot_name(side: int, type: StringName) -> String:
		if side >= 0 and side <= 1:
			var order: Array = _order[side]
			for k in range(order.size() - 1, -1, -1):
				var def: BuffDef = result.buffs.get(StringName(String(order[k])), null)
				if def != null and BattleNarrator.dot_types(def).has(type):
					return _buff(def.id)
		return UiText.t("log.dot_unknown")

	func _buff(id: StringName) -> String:
		var def: BuffDef = result.buffs.get(id, null)
		var label := Names.of(def) if def != null else String(id)
		if def != null and def.element != &"":
			return _paint(label, _dmg(def.element))
		return label

	## 伤害类型的颜色名（元素名就是伤害类型）
	func _dmg(type: StringName) -> String:
		return TextTemplate.DAMAGE_STYLE + String(type)

	func _who(side: int) -> String:
		return String(names[side]) if side >= 0 and side < names.size() else "?"

	func _item(side: int, uid: int, step: int) -> String:
		if uid <= 0:
			return UiText.t("battle.innate")
		var table: Dictionary = item_names[side] if side >= 0 and side < item_names.size() and item_names[side] is Dictionary else {}
		var label := String(table.get(uid, "?"))
		var held: Dictionary = loads[side] if side >= 0 and side < loads.size() and loads[side] is Dictionary else {}
		var beads: Array = held.get(uid, [])
		if step >= 0 and not beads.is_empty():
			label += "·" + String(table.get(int(beads[step % beads.size()]), "?"))
		return label

	func _paint(s: String, style: String) -> String:
		return "[color=%s%s]%s[/color]" % [TextTemplate.STYLE_PREFIX, style, s]

	## 一行自成一组
	func _alone(i: int, e: BattleEvent, body: String) -> Dictionary:
		var g := {"side": e.side, "uid": 0, "step": -1, "id": -1, "lines": 0}
		_put(i, e, g, body)
		return g

	func _put(i: int, e: BattleEvent, g: Dictionary, body: String) -> void:
		var more := int(g["lines"]) > 0
		if int(g["id"]) < 0:
			g["id"] = _groups
			_groups += 1
		g["lines"] = int(g["lines"]) + 1
		out.append(line(i, e.time, int(g["side"]), g, (UiText.t("log.indent") if more else "") + body))

	## [param stamped] 假 = 不写行首的时刻（末行战报自己带秒数）
	func line(i: int, time: int, side: int, g, body: String, stamped: bool = true) -> Dictionary:
		var gid := int(g["id"]) if g is Dictionary else _groups
		if not g is Dictionary:
			_groups += 1
		var text := _paint(body, "log_a" if gid % 2 == 0 else "log_b")
		if stamped:
			text = "%s  %s" % [_paint(UiText.t("log.time") % StatMath.to_float(time), "dim"), text]
		return {"time": time, "group": gid, "side": side, "at": i, "text": text}
