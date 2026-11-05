## 沙漏形的生成器（8-2，报告 078）：形状由 [HourglassMapConfig] 算出来，其余在 [LatticeMapGenerator]。
class_name HourglassMapGenerator
extends LatticeMapGenerator

const ID := &"hourglass"


func default_config() -> Resource:
	return HourglassMapConfig.sample()


func shape(cfg: Resource) -> LatticeShape:
	var c := cfg as HourglassMapConfig
	if c == null:
		build_note = "沙漏形要的是 HourglassMapConfig"
		return null
	if c.width < 1 or c.half_rows < 1 or c.neck_rows < 1:
		build_note = "宽度、每半层数、颈部层数都得至少 1"
		return null
	var s := LatticeShape.new()
	s.kind = ID
	s.cols = c.width
	var lanes := c.lane_cols()
	for x in lanes:
		if x < 0 or x >= c.width:
			build_note = "线段的列 %d 超出宽度 %d" % [x, c.width]
			return null
	var neck_side := c.half_cols(c.half_rows - 1)
	for x in lanes:
		if not neck_side.has(x):
			build_note = "颈部线段落在收窄的层外：列 %d 不在 %s 里" % [x, neck_side]
			return null
	for k in c.half_rows:
		s.add_row(c.half_cols(k), true, false, c.fill)
	for _r in c.neck_rows:
		s.add_row(lanes.duplicate(), false, true, 1.0)
	for k in c.half_rows:
		s.add_row(c.half_cols(c.half_rows - 1 - k), true, false, c.fill)
	# 横置：出生在左、终点在右。对侧一排撤离点；核心（BOSS）不是必须的
	s.orientation = LatticeShape.HORIZONTAL
	for x in c.exit_cols():
		s.goals[x] = &"extract"
		if c.two_sided:
			s.goals_first[x] = &"extract"     # 281 §六：两头各一排，挑了出生点留对侧那排
	s.two_sided = c.two_sided
	s.mirror_tier = c.two_sided
	if c.with_core and c.axis_core:
		# 281 §六：核心在颈部正中，挂在两条线段上；钟房在它下方，只挂下面那条线段
		var ax := c.axis_col()
		if lanes.has(ax):
			build_note = "中轴的核心要一格空位：列 %d 已经是线段（宽度取单数，线段别落在正中）" % ax
			return null
		var up: Array[int] = []
		var down: Array[int] = []
		for x in lanes:
			if x < ax:
				up.append(x)
			elif x > ax:
				down.append(x)
		var near: Array = [up.max()] if not up.is_empty() else []
		if not down.is_empty():
			near.append(down.min())
		# 危险 0：和原来对侧的核心一样，池里只有大钟够得着它（危险 1 起的精英不进核心）
		s.extras.append({"row": c.axis_row(), "col": ax, "type": "core", "links": near, "danger": 0})
		if c.clock_room and not down.is_empty() and int(down.max()) + 1 < c.width:
			s.extras.append({"row": c.axis_row(), "col": int(down.max()) + 1, "type": "event", "links": [down.max()], "event": String(HourglassMapConfig.CLOCK_ROOM_EVENT)})
	elif c.with_core:
		@warning_ignore("integer_division")
		s.goals[(c.width - 1) / 2] = &"core"
	s.entry_count = c.entry_count
	s.forward_reach = c.forward_reach
	s.lateral_span = c.lateral_span
	s.forward_break_chance = c.forward_break_chance
	s.lateral_break_chance = c.lateral_break_chance
	s.erosion_reversed = c.erosion_reversed
	s.danger_by_row = c.danger_by_row.duplicate()
	s.segments = c.segments()
	s.rules = c.rules
	return s
