## 166（作者定）：顶端栏 —— 横贯顶部的一条底（主题变体 [constant UiTheme.PANEL_HUD_BAR]：美术的大理石九宫格，没图是半透明深底）。
## 它本身不写字：栏里摆什么由布局里锚在 `bar_left / bar_center / bar_right` 的条目决定（[HudHost] 排），
## 所以「摆读数」时照样能把东西拖进拖出、换槽，栏自己也能藏。大小由宿主定（整屏宽 × 栏高）；宿主把它排成第一个子节点，垫在栏里的组件下面
extends HudWidget


func _init() -> void:
	super()
	theme_type_variation = UiTheme.PANEL_HUD_BAR
	UiTheme.apply_tone(self, UiTheme.PANEL_HUD_BAR)     # 大理石是浅底：栏里直接挂的字跟着换墨色
	_text.visible = false


func title() -> String:
	return "顶端栏"


func text_of() -> String:
	return "顶端栏"     # 只要这一局在就显示


func _sync_visible() -> void:
	visible = editing or (shown and run != null)


## 宿主按整屏宽摆它：最小尺寸不参与（不然一排读数会被它撑开）
func _get_minimum_size() -> Vector2:
	return Vector2.ZERO
