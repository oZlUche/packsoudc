## 一段序列帧（154）：一组贴图 + 帧率，[method advance] 推时间、[method frame] 给当前那张。宝箱屏的三段动画都用它。
##
## 不是节点：谁画谁持有、谁的 `_process` 推它。缺的图跳过；一张都没有时 [method is_empty] 为真，调用方画占位。
class_name FrameStrip
extends RefCounted

var frames: Array[Texture2D] = []
var fps: float = 8.0
## 播完一遍停在最后一张（开箱）；否则循环（开锁、尝试开锁）
var once: bool = false
var _time: float = 0.0


## 按路径装一段（读不到的跳过）
static func from_paths(paths: Array, p_fps: float, p_once: bool = false) -> FrameStrip:
	var strip := FrameStrip.new()
	strip.fps = maxf(0.01, p_fps)
	strip.once = p_once
	for p in paths:
		var tex := EventImage.load_texture(String(p))
		if tex != null:
			strip.frames.append(tex)
	return strip


func is_empty() -> bool:
	return frames.is_empty()


func reset() -> void:
	_time = 0.0


func advance(delta: float) -> void:
	_time += maxf(0.0, delta)


## 当前第几张（没有图返回 -1）
func index() -> int:
	if frames.is_empty():
		return -1
	var i := int(floor(_time * fps))
	return mini(i, frames.size() - 1) if once else i % frames.size()


func frame() -> Texture2D:
	var i := index()
	return frames[i] if i >= 0 else null


## 播一遍要多久（秒）；没有图为 0
func duration() -> float:
	return frames.size() / fps


## 只播一遍的那种播完了没有
func finished() -> bool:
	return once and _time >= duration()
