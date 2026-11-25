## 报告 377：万神院（Senatus Panthei）—— 营地里的一方阵营，出征前在这里选这一局奉哪位神。纯逻辑，状态在 [MetaState]
##（[member MetaState.pantheon_choice]、[member MetaState.gods_worshipped]）与委托簿（到没到、声望）。
##
## 规则（作者 2026-11-22 定方向，数值是初值）：
## - 新档开始时不在营地；教程之后第 3 次成功撤离结算时来（[member FactionDef.arrive_after]）。没来之前这一局没有信仰（[method faith_open]）。
## - 报告 396（作者 2026-11-25 19:25）：神殿自选解锁。六座神殿（[member FactionDef.temples]）；声望节点和两份引导委托给「解锁一座神殿」的机会
##   （0、25 和 50 的委托、100、125、150），玩家点一座、【确认解锁】（[method unlock]）。牌表没写好的神（[method temple_ready]）看得见、不能解锁。
##   其余节点：40【重选】、60【跳过】（70 / 90 加次数）、50 经验 +20%、75 神坛「赐福」；到来时声望 5（[member FactionDef.start_rep]）。
## - 老档：原来能选的神直接算解锁（[method migrate_temples]）。
## - 选神不要代价；出征时这位神的信物自动放进背包，局结束后不带回仓库。
class_name Pantheon
extends RefCounted

const FACTION := &"pantheon"
## 节点效果（[constant Commissions.EFFECTS]）：经验加成和赐福（396 起神不再挂在节点上，改成自选解锁神殿）
const SERVICE_XP := &"faith_xp"
const SERVICE_BLESS := &"altar_bless"
## 原来第五档的「开局质变那一次多一张」：作者 2026-11-24 定第五层先留空，现在没有节点开它（逻辑留着，[member RunState.opening_extra_choice]）
const SERVICE_OPENING := &"opening_pick"
## 奉神的局经验值多给几成（节点没写 `value` 时用这个）
const XP_BONUS := 0.10
## 局外旗标：老档的万神院迁移做过了（新档建档时就标上）
const MIGRATED := &"pantheon_migrated"
## 396：老档的神殿迁移做过了（新档建档时就标上）
const TEMPLES_MIGRATED := &"pantheon_temples_migrated"
## 396：节点效果「多一次解锁神殿的机会」；委托上写 `grants: temple` 也算一次
const EFFECT_TEMPLE := &"temple"
const GRANT_TEMPLE := &"temple"
## 396：节点效果「重选 / 跳过」（`value` = [重选次数, 跳过次数]，到了的几个相加）
const EFFECT_PICK_AIDS := &"pick_aids"


static func faction() -> FactionDef:
	return Commissions.faction(FACTION)


## 万神院到营地了没有
static func arrived(meta: MetaState) -> bool:
	var f := faction()
	return meta != null and f != null and Commissions.present(meta.commissions, f)


## 万神院的声望（没来 = -1）
static func rep(meta: MetaState) -> int:
	if not arrived(meta):
		return -1
	return meta.commissions.rep_of(FACTION)


## 某项服务（节点效果）到了没有：万神院到了、带这个效果的节点有一个到了
static func has_service(meta: MetaState, service: StringName) -> bool:
	return arrived(meta) and Commissions.has_effect(meta.commissions, faction(), service)


## 396：神殿 —— 页上的排法（[member FactionDef.temples]）。[param faith_defs] 给了就只列「神」那一类
static func gods(faith_defs: Dictionary = {}) -> Array[StringName]:
	var out: Array[StringName] = []
	var f := faction()
	if f == null:
		return out
	for t in f.temples:
		var fid := StringName(String((t as Dictionary).get("god", "")))
		var def := faith_defs.get(fid, null) as FaithDef
		if fid != &"" and not out.has(fid) and (faith_defs.is_empty() or (def != null and def.camp == FaithDef.Camp.GODS)):
			out.append(fid)
	return out


## 这座神殿悬浮窗那一句（作者写；没写 = 空）
static func blurb(faith_id: StringName) -> String:
	var f := faction()
	if f == null:
		return ""
	for t in f.temples:
		var row := t as Dictionary
		if StringName(String(row.get("god", ""))) == faith_id:
			return Names.pick(row.get("blurbs", {}) if row.get("blurbs", null) is Dictionary else {}, String(row.get("blurb", "")))
	return ""


## 这位神的牌表写好了没有（升级选牌里有祂的牌）：没写好的神殿看得见、不能解锁（「神殿尚未落成」）
static func temple_ready(faith_id: StringName) -> bool:
	if faith_id == &"":
		return false
	var r := LevelRules.load_rules()
	for cid in r.card_ids():
		if r.god_of(cid) == faith_id:
			return true
	return false


## 一共挣到几次解锁机会：到了的「解锁一座神殿」节点 + 办成的、写着 `grants: temple` 的委托
static func chances_earned(meta: MetaState) -> int:
	if not arrived(meta):
		return 0
	var n := Commissions.reached_with(meta.commissions, faction(), EFFECT_TEMPLE).size()
	for d in Commissions.defs():
		if d.faction == FACTION and d.grants == GRANT_TEMPLE and meta.commissions.is_done(d.id):
			n += 1
	return n


## 手里还有几次没用（老档先解锁的可能比挣到的多，算 0）
static func chances(meta: MetaState) -> int:
	if meta == null:
		return 0
	return maxi(0, chances_earned(meta) - meta.temples.size())


## 这座神殿现在能不能点【确认解锁】：有机会、牌表写好了、还没解锁
static func can_unlock(meta: MetaState, faith_id: StringName) -> bool:
	return chances(meta) > 0 and gods().has(faith_id) and temple_ready(faith_id) and not meta.temples.has(faith_id)


## 【确认解锁】。返回解锁成了没有
static func unlock(meta: MetaState, faith_id: StringName) -> bool:
	if not can_unlock(meta, faith_id):
		return false
	meta.temples.append(faith_id)
	meta.changed.emit()
	return true


## 这位神现在能不能奉：万神院到了、神殿解锁了、牌表写好了
static func god_open(meta: MetaState, faith_id: StringName) -> bool:
	if not arrived(meta) or faith_id == &"":
		return false
	return meta.temples.has(faith_id) and temple_ready(faith_id)


## 396 老档：在节点开神的那一版能选的神（奉过的、声望到了 0 蛮神 / 10 自然 / 20 日神），直接算解锁了。只做一次（[constant TEMPLES_MIGRATED]）
static func migrate_temples(meta: MetaState) -> Array[StringName]:
	var out: Array[StringName] = []
	if meta == null or meta.flag(TEMPLES_MIGRATED) != 0:
		return out
	meta.set_flag(TEMPLES_MIGRATED)
	if not arrived(meta):
		return out
	var r := meta.commissions.rep_of(FACTION)
	var f := faction()
	if f != null and r < f.start_rep:
		meta.commissions.rep[String(FACTION)] = f.start_rep
	var was := meta.gods_worshipped.duplicate()
	for pair in [[&"brute", 0], [&"nature", 10], [&"sun", 20]]:
		if r >= int(pair[1]):
			was.append(pair[0])
	for fid in gods():
		if was.has(fid) and temple_ready(fid) and not meta.temples.has(fid):
			meta.temples.append(fid)
			out.append(fid)
	return out


## 选好下一局奉谁（空 = 以人为本）。不能选的返回 false、不改
static func choose(meta: MetaState, faith_id: StringName) -> bool:
	if meta == null:
		return false
	if faith_id != &"" and not god_open(meta, faith_id):
		return false
	meta.pantheon_choice = faith_id
	meta.changed.emit()
	return true


## 下一局奉谁：选过、而且现在还能选（老档的选择不在表里了就当以人为本）
static func choice(meta: MetaState) -> StringName:
	if meta == null or not god_open(meta, meta.pantheon_choice):
		return &""
	return meta.pantheon_choice


## 是不是万神院发的那种信物（各神那枚 `charm_<神>` 护符；种子、手写的赐福武器虽然也归神，不算）
static func is_charm(def: ItemDef) -> bool:
	return def != null and def.is_anchor() and String(def.id).begins_with("charm_")


## 这位神的信物（1 格的那枚护符；先找 `charm_<神>`，没有再按标签找）
static func charm_of(items: ItemDatabase, faith_id: StringName) -> ItemDef:
	if items == null or faith_id == &"":
		return null
	var d := items.get_def(StringName("charm_" + String(faith_id)))
	if d != null and d.is_anchor():
		return d
	var tag := FaithTags.tag_of(faith_id)
	var ids := items.ids_where(func(x: ItemDef) -> bool: return x.is_anchor() and x.faith_tag() == tag and ItemVolume.cells_of(x) == 1)
	Ids.sort(ids)
	return items.get_def(ids[0]) if not ids.is_empty() else null


## 这一局的信仰开关（[member RunState.FAITH_INPUT]）：万神院到了才有信仰；经验加成、赐福看节点
static func access(meta: MetaState) -> Dictionary:
	var on := arrived(meta)
	var xp := 0.0
	var aids := [0, 0]
	if on:
		for n in Commissions.reached_with(meta.commissions, faction(), SERVICE_XP):
			xp = maxf(xp, float(n.get("value", XP_BONUS)))
		for n in Commissions.reached_with(meta.commissions, faction(), EFFECT_PICK_AIDS):
			var v: Variant = n.get("value", [])
			if v is Array and (v as Array).size() >= 2:
				aids[0] += int(v[0])
				aids[1] += int(v[1])
	return {"enabled": on, "bless": on and has_service(meta, SERVICE_BLESS), "xp_bonus": xp,
		"opening_extra": on and has_service(meta, SERVICE_OPENING), "rerolls": aids[0], "skips": aids[1]}


## 不受限制的开关（教程章、老规矩）
static func full_access() -> Dictionary:
	return {"enabled": true, "bless": true, "xp_bonus": 0.0, "opening_extra": false, "rerolls": 0, "skips": 0}


## 出征了，记下奉的是哪位神
static func note_worship(meta: MetaState, faith_id: StringName) -> void:
	if meta != null and faith_id != &"" and not meta.gods_worshipped.has(faith_id):
		meta.gods_worshipped.append(faith_id)


## 老档（报告 377 第四节第 7 条）：通过过序章三、仓库里有信物、或者奉过神 —— 直接算万神院已到来（声望从 0 起），
## 奉过的神（对局记录里奉过的、图鉴里点亮过信物的）全部能选；仓库与带回来的棋盘里的信物按价值折成金币。
## 只做一次（[constant MIGRATED]）。返回 {"arrived": 这回算到了没有, "gods": 补进来的神, "refund": 折了多少钱}
static func migrate_legacy(meta: MetaState, items: ItemDatabase, legacy_unlock: StringName = &"prologue3_done") -> Dictionary:
	var out := {"arrived": false, "gods": [] as Array[StringName], "refund": 0}
	if meta == null or meta.flag(MIGRATED) != 0:
		return out
	meta.set_flag(MIGRATED)
	var gods_seen: Array[StringName] = []
	for row in meta.history:
		var fid := StringName(String((row.get("faith_top", {}) as Dictionary).get("id", ""))) if row.get("faith_top", null) is Dictionary else &""
		if fid != &"" and not gods_seen.has(fid):
			gods_seen.append(fid)
	var charms: Array[ItemInstance] = []
	for inst in meta.warehouse.items():
		if is_charm((inst as ItemInstance).def):
			charms.append(inst)
	if meta.board != null:
		for inst in meta.board.items():
			if is_charm((inst as ItemInstance).def):
				charms.append(inst)
	if items != null:
		for id in meta.codex:
			var d := items.get_def(StringName(String(id)))
			if is_charm(d) and int(meta.codex[id]) > 0:
				var fid := FaithTags.id_of_tag(d.faith_tag())
				if fid != &"" and not gods_seen.has(fid):
					gods_seen.append(fid)
	var legacy := meta.has_unlock(legacy_unlock) or not charms.is_empty() or not gods_seen.is_empty()
	if not legacy:
		return out
	var f := faction()
	if f != null and not meta.commissions.arrived.has(String(f.id)):
		meta.commissions.arrived[String(f.id)] = meta.runs
		out["arrived"] = true
	for fid in gods_seen:
		if not meta.gods_worshipped.has(fid):
			meta.gods_worshipped.append(fid)
			(out["gods"] as Array[StringName]).append(fid)
	for inst in charms:
		var v := ItemValue.of(inst.def)
		if meta.warehouse.remove(inst.uid) == null and meta.board != null:
			meta.board.remove(inst.uid)
		meta.funds += v
		out["refund"] = int(out["refund"]) + v
	return out
