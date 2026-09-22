## 同心环的角度求解器（架构文档 5.9）：**角度是解出来的，不是配出来的。**
##
## 数据层只有「第几环、环上第几个、和谁相连」。这里给每个点一个角度，目标只有一条：
## **异环通路永远垂直于切线** —— 一条径向边的两端在同一个角度上，画出来是一根笔直的、指向圆心的线。
## 切向弧之间隔多远是自由的，按需要拉开或挤紧。
##
## 输入是形态无关的：每个点一个「层」（0 = 圆心，越大越靠外）和一个「圈上的位置」（0～1）。
## 同心环图与手绘图各自把自己的 ring/order、row/col 翻译成这两个数，求解器只写一次。
##
## 解法是松弛：最外层按圈上的位置钉死；里面每个有径向边的点反复取它径向邻居角度的圆周均值，
## 直到不动 —— 一条链上的点就都落在同一个角度上（垂直），一个点接着两个外层点就落在它们中间
## （这种图本来就画不成全部垂直，告警让作者知道）。每轮之后按圈上的次序整理一遍：
## 同层的点不许越过彼此、不许挤到一起 —— 这是保证画出来不拧的约束。
## 没有径向边的点按圈上的位置放。
##
## 没有随机：同一张图解两次结果逐位相同。
class_name RingAngleSolver
extends RefCounted

## 圆周均值时，两个角度差超过这么多才算「不同」（弧度）
const SAME_ANGLE := 1e-6
## 松弛几轮。六层的图两百轮就不动了；四百轮是余量
const ROUNDS := 400
## 同层相邻两点至少隔多少（按这一层槽位宽度的几分之几）
const MIN_GAP_RATIO := 0.45
## 没连到最外层的分量往名义位置拉的力（相对一条径向边的权重）
const LOOSE_ANCHOR := 0.2

## 解出来的角度：id → 弧度（-PI/2 为正上方，顺时针增大，和 Vector2.from_angle 一致）
var angles: Dictionary = {}
## 告警：每条一句人话，说的是哪张图的哪个点
var warnings: Array[String] = []
## 调试用：>= 0 时只跑这么多轮
var rounds_override: int = -1
## 每个点往自己名义位置拉的力（相对一条径向边的权重）。0 = 只管径向边垂直（手绘图：`|` 就该竖直）；
## 大一点 = 保留按槽位的均匀分布，只把径向边往竖直方向带一带（随机生成的图：每个点向内连一两条
## 斜边是它的本意，硬拉直会把点挤成一团）
var anchor: float = 0.0


## [param levels]：id → 层（int，0 = 圆心）；[param fractions]：id → 圈上的位置（float，0～1）；
## [param radial]：跨层的边，每项 [a, b]。
func solve(levels: Dictionary, fractions: Dictionary, radial: Array) -> Dictionary:
	angles = {}
	warnings = []
	if levels.is_empty():
		return angles

	# 层 → 该层的点，按圈上的位置排好
	var by_level := {}
	var top := 0
	for id in levels:
		var lv := int(levels[id])
		top = maxi(top, lv)
		if not by_level.has(lv):
			by_level[lv] = [] as Array[int]
		(by_level[lv] as Array[int]).append(int(id))
	for lv in by_level:
		var ids: Array[int] = by_level[lv]
		ids.sort_custom(func(a: int, b: int) -> bool:
			var fa := float(fractions.get(a, 0.0))
			var fb := float(fractions.get(b, 0.0))
			return fa < fb or (fa == fb and a < b))

	# 径向邻居（不含圆心：它在中间，角度无所谓）
	var nbrs := {}
	for pair in radial:
		var a := int(pair[0])
		var b := int(pair[1])
		if not levels.has(a) or not levels.has(b) or int(levels[a]) == int(levels[b]):
			continue
		if int(levels[a]) == 0 or int(levels[b]) == 0:
			continue
		if not nbrs.has(a):
			nbrs[a] = [] as Array[int]
		if not nbrs.has(b):
			nbrs[b] = [] as Array[int]
		(nbrs[a] as Array[int]).append(b)
		(nbrs[b] as Array[int]).append(a)

	# 起点：都按圈上的位置放
	for id in levels:
		angles[id] = TAU * float(fractions.get(id, 0.0)) - PI / 2.0
	if by_level.has(0) and (by_level[0] as Array).size() == 1:
		angles[(by_level[0] as Array)[0]] = -PI / 2.0

	# 松弛：最外层钉死；有径向邻居的取邻居的圆周均值；没有的留在原位。
	# 一整个分量都没连到最外层的（几个内环点互相连着，不接外环），没有东西钉住它，
	# 会被同层的整理一轮轮推着满圈游走 —— 给它一点回到名义位置的拉力
	var free: Array[int] = []
	for id in levels:
		if int(levels[id]) > 0 and int(levels[id]) < top and nbrs.has(id):
			free.append(id)
	free.sort()
	var anchored := _anchored_components(nbrs, levels, top)
	for _round in (rounds_override if rounds_override >= 0 else ROUNDS):
		var next := {}
		for id in free:
			var v := Vector2.ZERO
			for n in (nbrs[id] as Array[int]):
				v += Vector2.from_angle(float(angles[n]))
			var pull := anchor if anchored.has(id) else maxf(anchor, LOOSE_ANCHOR)
			if pull > 0.0:
				v += Vector2.from_angle(TAU * float(fractions.get(id, 0.0)) - PI / 2.0) * pull
			next[id] = v.angle() if v.length() > 1e-9 else float(angles[id])
		for id in next:
			# 带阻尼：一步到位会和后面的整理互相打架，来回抖，永远不收敛
			var a0 := float(angles[id])
			angles[id] = a0 + RingAngleSolver._wrap(float(next[id]) - a0) * 0.5
		_keep_order(by_level, fractions, top)

	# 告警：接着多个角度不同的外层点的
	for id in free:
		var outer: Array[float] = []
		for n in (nbrs[id] as Array[int]):
			if int(levels[n]) > int(levels[id]):
				outer.append(float(angles[n]))
		if outer.size() < 2:
			continue
		var mean := _circular_mean(outer)
		for a in outer:
			if absf(_wrap(a - mean)) > SAME_ANGLE:
				warnings.append("节点 %d 接着 %d 个角度不同的外层点，落在它们中间 —— 这几条径向边画不成全部垂直"
					% [id, outer.size()])
				break

	# 校验：每层按位置角度单调（循环意义下）。整理过一遍之后应该都成立；不成立说明整理不动它
	for lv in by_level:
		if int(lv) == 0:
			continue
		var ids: Array[int] = by_level[lv]
		if ids.size() < 3:
			continue
		var backwards := 0
		for k in ids.size():
			var d := fposmod(float(angles[ids[(k + 1) % ids.size()]]) - float(angles[ids[k]]), TAU)
			if d > PI:
				backwards += 1
		if backwards > 0:
			warnings.append("第 %d 层的角度按次序不单调（%d 处折返）—— 有径向边在次序上交叉了" % [lv, backwards])
	return angles


## 同层的点按圈上的次序整理：相邻两点至少隔 min_gap，挤到一起的两个各让一半 ——
## 只往一个方向推会把整层的点顺着推到一边去，图就歪了。首尾也是相邻的。最外层不动。
##
## 两点之间的距离用**带符号的圆周差**（折到 (-PI, PI]）算，不展开到一条线上：
## 第一版以第一个点为基准展开，一个点只落后基准一点点就被折到一圈之外，
## 当成差了六个弧度去推 —— 整个内圈一轮轮被推着转。
func _keep_order(by_level: Dictionary, fractions: Dictionary, top: int) -> void:
	for lv in by_level:
		if int(lv) <= 0 or int(lv) == top:
			continue
		var ids: Array[int] = by_level[lv]
		var n := ids.size()
		if n < 2:
			continue
		# 这一层「一个槽位」多宽：按位置的最小间距估，没有更好的信息
		var slot := TAU
		for k in n:
			var f0 := float(fractions.get(ids[k], 0.0))
			var f1 := float(fractions.get(ids[(k + 1) % n], 0.0))
			var dd := fposmod(f1 - f0, 1.0) * TAU
			if dd > 1e-6:
				slot = minf(slot, dd)
		var min_gap := minf(slot * MIN_GAP_RATIO, TAU / float(n))
		# 两两推开，推到没有一对再挤为止（一对推开可能挤到下一对，所以要反复；至多 n 轮就稳了）
		for _pass in n + 1:
			var moved := false
			for k in n:
				var j := (k + 1) % n
				var gap := _wrap(float(angles[ids[j]]) - float(angles[ids[k]]))
				if gap < min_gap - 1e-9:
					var shift := (min_gap - gap) / 2.0
					angles[ids[k]] = _wrap(float(angles[ids[k]]) - shift)
					angles[ids[j]] = _wrap(float(angles[ids[j]]) + shift)
					moved = true
			if not moved:
				break


## 哪些点所在的径向分量连到了最外层（那一层是钉死的，整个分量就有了着落）。
static func _anchored_components(nbrs: Dictionary, levels: Dictionary, top: int) -> Dictionary:
	var out := {}
	var seen := {}
	for start in nbrs:
		if seen.has(start):
			continue
		var comp: Array[int] = []
		var stack: Array[int] = [int(start)]
		seen[start] = true
		var touches_top := false
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			comp.append(cur)
			if int(levels[cur]) == top:
				touches_top = true
			for n in (nbrs[cur] as Array[int]):
				if not seen.has(n):
					seen[n] = true
					stack.append(n)
		if touches_top:
			for id in comp:
				out[id] = true
	return out


static func _circular_mean(list: Array[float]) -> float:
	var v := Vector2.ZERO
	for a in list:
		v += Vector2.from_angle(a)
	if v.length() < 1e-9:
		return list[0]
	return v.angle()


## 折到 (-PI, PI]
static func _wrap(a: float) -> float:
	return fposmod(a + PI, TAU) - PI
