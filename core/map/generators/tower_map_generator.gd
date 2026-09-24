## 塔形的生成器（8-2，报告 078）：形状由 [TowerMapConfig] 算出来，其余在 [LatticeMapGenerator]。
class_name TowerMapGenerator
extends LatticeMapGenerator

const ID := &"tower"


func default_config() -> Resource:
	return TowerMapConfig.sample()


func shape(cfg: Resource) -> LatticeShape:
	var c := cfg as TowerMapConfig
	if c == null:
		build_note = "塔形要的是 TowerMapConfig"
		return null
	var widths := c.widths()
	if widths.size() < 2 or c.base_width < 1:
		build_note = "塔至少两层：底宽 %d、每层收 %d、层数 %d 算出来只有 %d 层" % [c.base_width, c.shrink_per_row, c.floors, widths.size()]
		return null
	var s := LatticeShape.new()
	s.kind = ID
	s.cols = c.base_width
	for r in widths.size():
		var w := widths[r]
		var offset := (c.base_width - w) / 2
		var cols: Array[int] = []
		for x in w:
			cols.append(offset + x)
		s.add_row(cols, true, false, c.fill)
	var top := widths[widths.size() - 1]
	s.goal_col = (c.base_width - top) / 2 + (top - 1) / 2
	s.entry_count = c.entry_count
	s.forward_reach = c.forward_reach
	s.lateral_span = c.lateral_span
	s.forward_break_chance = c.forward_break_chance
	s.lateral_break_chance = c.lateral_break_chance
	s.one_way = c.one_way
	s.one_way_from_row = maxi(0, c.one_way_from_floor)
	s.erosion_reversed = c.erosion_reversed
	s.danger_by_row = c.danger_by_row.duplicate()
	s.rules = c.rules
	return s
