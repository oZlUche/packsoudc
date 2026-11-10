## 平衡检测方案（2026-11-10）§8.1：一场回放的观看记录。战斗结果来自模拟，玩家看到的是回放 —— 两条时间线分开记。
##
## 纯记录，不认识界面：回放屏（`ui/game/battle_screen.gd`）每有一件事就调 [method note]，把墙上时间（毫秒）和回放走到的模拟时刻传进来；
## 这里只记账。实际观看时长 = 从开始到结果揭晓的墙上时间，扣掉停着（暂停、教程停住）和窗口失焦的时间。
## 提示弹出到下一件事之间记成「停留」：停留不等于读了，更不等于懂了。
## 没有观看记录（老版本、没开诊断）时不能从模拟时长推算玩家看了多久 —— 报告里写未知。
class_name ViewingSession
extends RefCounted

const FORMAT := 1
const START := "start"
const PLAY := "play"
const PAUSE := "pause"
const HOLD := "hold"           # 教程停住
const RELEASE := "release"
const SPEED := "speed"
const SEEK := "seek"
const SKIP := "skip"
const REVEAL := "reveal"       # 回放看完（或跳到底），「继续」出来
const LEAVE := "leave"
const FOCUS_OUT := "focus_out"
const FOCUS_IN := "focus_in"
const HINT := "hint"           # 反应解释、战斗教程弹出
const HINT_END := "hint_end"

var battle_id := ""
var simulation_duration := 0.0
var events: Array[Dictionary] = []
var before: Dictionary = {}
var after: Dictionary = {}

var _t0 := -1
var _last := 0
var _playing := true
var _held := false
var _focused := true
var _active_ms := 0
var _paused_ms := 0
var _held_ms := 0
var _unfocused_ms := 0
var _revealed_at := -1
var _left_at := -1
var _active_at_reveal := -1


## 开始看。[param playing] 是开场时回放在不在走（教程一开场就停住时为假）
func start(p_battle_id: String, sim_duration: float, speed: float, now_ms: int, playing: bool = true, p_before: Dictionary = {}) -> void:
	battle_id = p_battle_id
	simulation_duration = sim_duration
	before = p_before.duplicate(true)
	_t0 = now_ms
	_last = now_ms
	_playing = playing
	events.append({"kind": START, "wall": 0.0, "sim": 0.0, "speed": speed, "playing": playing})


func started() -> bool:
	return _t0 >= 0


## 记一件事：[param sim] 是此刻回放走到的模拟秒数，[param data] 原样进这一条
func note(kind: String, sim: float, now_ms: int, data: Dictionary = {}) -> void:
	if not started() or _left_at >= 0:
		return
	_advance(now_ms)
	match kind:
		PLAY:
			_playing = true
		PAUSE:
			_playing = false
		HOLD:
			_held = true
		RELEASE:
			_held = false
		FOCUS_OUT:
			_focused = false
		FOCUS_IN:
			_focused = true
		REVEAL:
			if _revealed_at >= 0:
				return     # 拖时间轴拖到头会再「看完」一次：只记第一次
			_revealed_at = now_ms
			_active_at_reveal = _active_ms
		LEAVE:
			_left_at = now_ms
	var row := {"kind": kind, "wall": (now_ms - _t0) / 1000.0, "sim": sim}
	row.merge(data)
	events.append(row)


func _advance(now_ms: int) -> void:
	var d := maxi(0, now_ms - _last)
	_last = now_ms
	if not _focused:
		_unfocused_ms += d
	elif _held:
		_held_ms += d
	elif not _playing:
		_paused_ms += d
	else:
		_active_ms += d


## 落盘的样子。揭晓前离开（没看完就走）时实际观看时长是 null
func to_dict() -> Dictionary:
	var speeds: Array = []
	var hints: Array = []
	var skip_at: Variant = null
	var seeks := 0
	var open_hint: Dictionary = {}
	for e in events:
		match String(e["kind"]):
			START, SPEED:
				speeds.append({"wall": e["wall"], "sim": e["sim"], "speed": e.get("speed", null)})
			SKIP:
				if skip_at == null:
					skip_at = e["sim"]
			SEEK:
				seeks += 1
			HINT:
				open_hint = {"id": e.get("id", ""), "wall": e["wall"], "sim": e["sim"], "dwell": null}
				hints.append(open_hint)
			HINT_END:
				if not open_hint.is_empty():
					open_hint["dwell"] = float(e["wall"]) - float(open_hint["wall"])
					open_hint = {}
	return {
		"format": FORMAT, "battle_id": battle_id, "simulation_duration": simulation_duration,
		"presentation_elapsed": (_active_at_reveal / 1000.0 as Variant) if _revealed_at >= 0 else null,
		"wall_to_reveal": ((_revealed_at - _t0) / 1000.0 as Variant) if _revealed_at >= 0 else null,
		"linger_after_reveal": ((_left_at - _revealed_at) / 1000.0 as Variant) if _revealed_at >= 0 and _left_at >= 0 else null,
		"wall_total": ((_left_at - _t0) / 1000.0 as Variant) if _left_at >= 0 else null,
		"paused_sec": _paused_ms / 1000.0, "held_sec": _held_ms / 1000.0, "unfocused_sec": _unfocused_ms / 1000.0,
		"speeds": speeds, "skipped": skip_at != null, "skip_at_sim": skip_at, "seeks": seeks,
		"revealed": _revealed_at >= 0, "left": _left_at >= 0, "hints": hints, "before": before, "after": after, "events": events,
	}
