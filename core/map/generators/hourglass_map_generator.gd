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
	var full: Array[int] = []
	for x in c.width:
		full.append(x)
	var lanes := c.lane_cols()
	for x in lanes:
		if x < 0 or x >= c.width:
			build_note = "线段的列 %d 超出宽度 %d" % [x, c.width]
			return null
	for _r in c.half_rows:
		s.add_row(full.duplicate(), true, false, c.fill)
	for _r in c.neck_rows:
		s.add_row(lanes.duplicate(), false, true, 1.0)
	for _r in c.half_rows:
		s.add_row(full.duplicate(), true, false, c.fill)
	# 横置：出生在左、终点在右。对侧一排撤离点；核心（BOSS）不是必须的
	s.orientation = LatticeShape.HORIZONTAL
	for x in c.exit_cols():
		s.goals[x] = &"extract"
	if c.with_core:
		s.goals[(c.width - 1) / 2] = &"core"
	s.entry_count = c.entry_count
	s.forward_reach = c.forward_reach
	s.lateral_span = c.lateral_span
	s.forward_break_chance = c.forward_break_chance
	s.lateral_break_chance = c.lateral_break_chance
	s.erosion_reversed = c.erosion_reversed
	s.danger_by_row = c.danger_by_row.duplicate()
	s.rules = c.rules
	return s
