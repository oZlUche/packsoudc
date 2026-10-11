## 宝箱的长按开锁（154，作者定）：纯逻辑的状态机，画面（[code]ui/game/chest_screen.gd[/code]）每帧推它、按它画。
##
## [codeblock]
## IDLE       ── 按下 ──▶ HOLDING
## HOLDING    ── 每帧 progress += delta / hold_seconds；走满 ──▶ UNLOCKED
##            ── 松手（没满）──▶ RELEASING
## RELEASING  ── 每帧 progress −= delta × release_decay / hold_seconds；归零 ──▶ IDLE；再按下 ──▶ HOLDING
## UNLOCKED   终态（之后的按下、松手都不理）
## [/codeblock]
## 作者定（待定 1）：松手按二倍速回退，再按接着走 —— 手滑不至于全白费，又不能点一下歇一下。`release_decay = 0` 一松手立刻归零。
class_name LockHold
extends RefCounted

enum State { IDLE, HOLDING, RELEASING, UNLOCKED }

## 走满了（只发一次）
signal unlocked

var state: int = State.IDLE
## 0～1
var progress: float = 0.0
## 按住多久走满
var hold_seconds: float = 1.0
## 松手后回退的倍速
var release_decay: float = 2.0


func _init(p_hold_seconds: float = 1.0, p_release_decay: float = 2.0) -> void:
	hold_seconds = maxf(0.05, p_hold_seconds)
	release_decay = maxf(0.0, p_release_decay)


## 按下（已经开了就不理）。返回状态变了没有
func press() -> bool:
	if state == State.UNLOCKED or state == State.HOLDING:
		return false
	state = State.HOLDING
	return true


## 松手：没满就开始回退（回退倍速为 0 时立刻归零回 IDLE）。返回状态变了没有
func release() -> bool:
	if state != State.HOLDING:
		return false
	if release_decay <= 0.0:
		progress = 0.0
		state = State.IDLE
	else:
		state = State.RELEASING
	return true


## 推进 [param delta] 秒。返回这一步是不是刚走满
func advance(delta: float) -> bool:
	match state:
		State.HOLDING:
			progress = minf(1.0, progress + delta / hold_seconds)
			if progress >= 1.0:
				state = State.UNLOCKED
				unlocked.emit()
				return true
		State.RELEASING:
			progress = maxf(0.0, progress - delta * release_decay / hold_seconds)
			if progress <= 0.0:
				state = State.IDLE
	return false


func is_holding() -> bool:
	return state == State.HOLDING


func is_unlocked() -> bool:
	return state == State.UNLOCKED


## 现在能不能离开（作者定：按住的时候不能走；回退中、没按都能走）
func can_leave() -> bool:
	return state == State.IDLE or state == State.RELEASING
