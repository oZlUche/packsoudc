# 方案：地图屏十四条 —— 满幅底图、正式的顶端栏（图标按钮）、调试台悬浮、进点自动存档、图例、序章静态教程、大理石（166）

> 作者原话（2026-10-13，架构设计，附截图）：十三条地图界面想法 + 第十四条「我先前提到的石板更倾向于大理石那种颜色，让美术修改」。原文逐条引在各节开头。
> 性质：架构 · 实施（2 ～ 4 节）+ 美术清单（5 节，转美术设计）。待定按推荐。关联 150（读数组件与布局文件）、155（节点图标）、157（石板框 / 深浅）、160（腰带圆槽）、139（调试台）、090（暂停菜单）。

## 1. 先回答第三条：「咬牙」是什么

布鲁图斯的**主动技能**（136，`second_wind`，`data/authoring/characters/brutus.json`）：在地图上点一下恢复一点体力，一局限两次，体力满时不能用（不扣次数）。按钮是 150 的 `skills` 部件，角色有主动技能才出现（安德烈乌斯是「脱身」）。它留着，但按第七条进顶端栏变成图标按钮（2.3）。

## 2. 布局：底图满幅、顶端栏、左下图例、右下腰带、调试台悬浮

### 2.1 底图满幅（第一条）

- 地图视图现在被右边那一列部件挤出一条石板（`_mid.offset_right = -_hud_host.right_inset()`）。改成 `MapView` 铺满整个视口，所有读数与按钮浮在它上面；底图（`MapSkin`）随视图满幅。
- 路网的「刚好放下」（`fit()`）改按**安全区**算：视口扣掉顶端栏高度、左下图例与右下腰带的占位（`MapView.content_inset: Rect2`，由 `HudHost` 按已摆部件的包围盒算出来告诉它），路网不会被顶栏压住。
- 右边那一列部件（`HudLayout.COLUMN`）取消：背包 / 放大镜 / 技能进顶端栏，撤离按钮与「存档并回主菜单」删（第五、六条），路线部件（`routes`）挪到左下图例上方。

### 2.2 顶端栏是一个部件容器，不是写死（第七条）

- 新部件 `hud_bar`（`ui/hud/widgets/hud_bar.gd`，`HudWidget`）：一条横贯顶部的栏，高 64（两倍档），底是主题变体 `PANEL_HUD_BAR`（美术给 `assets/ui/hud/bar.png` 九宫格 + json `tone` 就贴图，没给是现在的半透明深底），左右各留 16 边距。
- 栏里有**三个槽**：`bar_left`、`bar_center`、`bar_right`，是 `HudHost` 的三种新锚点（和 `top / top_right / bottom_right` 并列）。布局条目写 `"anchor": "bar_left", "line": 0` 就排进去 —— 顶端栏本身与里面每一样东西都仍是布局文件里的条目，「摆读数」模式里照样能拖进拖出、换槽、藏掉。`HudLayout.VERSION` +1，旧布局丢弃。
- 默认 `map` 布局：
  - `bar_left`：体力（红心，两倍档）、货币（金币图标 + 数字，第四条）、信仰（图标槽，第八条）；
  - `bar_center`：倒计时（大号）；
  - `bar_right`：背包图标按钮、放大镜图标按钮（第五条）、主动技能图标按钮（咬牙 / 脱身，右下角标剩余次数）、调试台箭头。
  - 侵蚀、buff、负重读数仍在栏里 `bar_left` 的第二行（line 1），小字；行动点、距离照旧默认藏。
- 新控件 `IconButton`（`ui/widgets/icon_button.gd`）：一张图标（`assets/ui/hud/icon_<id>.png`，缺图画现有文字）+ 悬浮窗（名字、快捷键、一句说明）+ 右上角可选小字（快捷键 B / N）+ 右下角可选数字角标（技能剩余次数）。48 × 48，按下态按主题变体 `BUTTON_ICON`，不加 `add_theme_`。
- 顶端栏上的字色按栏的 `tone` 挂（157 补）；美术若把栏做成大理石（第十四条），json 写 `light`，字自动换墨色。

### 2.3 按钮（第五、六条）

- 「背包（B）」→ 背包图标按钮；「回到这个点（N）」→ 放大镜图标按钮（它的含义是「再看这个点的内容」，放大镜正合适）；快捷键不变。
- **撤离按钮删掉**：撤离只在撤离点上发生，而撤离点的事件屏本来就有「撤离」选项（`hooks.request_extract`）。`extract_button` 部件与条目一并删；测试里按撤离按钮的用例改走事件选项。
- **「存档并回主菜单」删掉**（右列那颗与 Esc 暂停菜单里那颗都删），改成**自动存档**：
  - `GameFlow.step_to()` 里旅程把人挪到新点之后、`_flush()` 跑这个点的事件之前 `save()`；传送落地同理（`relocate` 之后）。
  - 另外每次从叠层回到地图、队列清空时（`_flush` 走到地图那一步）也 `save()` 一次，不然在点上拿了战利品再退出会回到进点之前（待定 1）。
  - 暂停菜单剩「继续 / 设置 / 回主菜单」，回主菜单前静默存一次；主菜单的「继续」照旧读它。
  - `save()` 的 `writable()` / 一局结束不存的守卫不变；读档后的点不重触发事件（现有 `last_handled_id` 逻辑）。

### 2.4 调试台（第二、九、十条）

- 日志（`log` 部件）与「地上 N 件」（`ground_count`）**从布局里拿掉，搬进调试台内容**（和 157 小修已搬进去的提示行并列）；调试模式关着时它们就不存在。
- 调试台变成**侧边悬浮窗**：`dock(顶栏高 + 8, …)`，顶缘在顶端栏之下，不再盖住右上角的箭头；开着时**盖在地图上**，不再 `set_extra_right` 挤地图（`HudHost.extra_right` 这条路保留给别的用途，地图屏不再调）。基地屏（139）本来就是盖着的，两边一致。

### 2.5 左下角图例（第十三条）、右下角腰带（第十一条）

- 新部件 `legend`（`ui/hud/widgets/legend_widget.gd`），默认锚 `bottom_left (8, -8)`，小字档：一列「图标 + 名字」，只列**这张图上出现的**节点类型（待定 3），顺序按 `MapNodeStyle.STYLES` 表；图标就是 155 的节点图标（`assets/nodes/<type>.png`，按类型色着色，24 px），名字来自新加的 `MapNodeStyle.NAMES`（战斗 / 精英 / 事件 / 未知 / 搜索 / 商店 / 休息 / 撤离 / 核心 / 出生 / 保险箱 / 宝箱；岔路口不列）。底是 `PANEL_HUD` 变体。
- 腰带圆槽（160）直径 56 → **72**、间距 12，角标与命中半径跟着；160 待定 2 改成这个数。

## 3. 信仰图标与金币（第四、八条）

- 货币部件：左边一枚金币图标（`assets/ui/hud/coin.png`，24 px；缺图画一个描边圆）+ 数字，不再写「货币」两个字；悬浮窗写「货币」。
- 信仰部件：有信仰时画该信仰的图标（`assets/ui/faith/<id>.png`，七个：brute / church / earth / hunt / nature / skill / sun，32 px）+ 信力 / 阶的小字；**没信仰时留一个空槽**（固定宽，不画字），悬浮窗照旧。缺图时退回现在的文字。

## 4. 序章静态教程（第十二条）

- 新控件 `CoachOverlay`（`ui/widgets/coach_overlay.gd`）：整屏半透明阴影（`Color(0, 0, 0, 0.62)`），目标控件的包围盒向外扩 8 px 挖一个圆角洞（画法：洞外四块矩形 + 洞边一圈 2 px 高光描边，不用着色器）；洞的对面放一只手绘箭头（`assets/ui/coach/arrow.png`，按方向翻转 / 旋转）指向洞，箭尾一块羊皮纸文本框（`PANEL_TOOLTIP` 变体，157 的纸底，浅底墨字）写说明；**点任意处下一步**，最后一步点了收掉。阴影层 `mouse_filter = STOP`，吞掉所有点击，Esc 也是下一步。
- 步骤是数据：`data/authoring/coach/prologue_map.json`：
  ```json
  {"id": "prologue_map", "steps": [
    {"target": "vitality", "text": "这是体力。走路、受伤都会用掉它；用光就……"},
    {"target": "wallet", "text": "这是货币。商店、付费撤离点都要它。"},
    {"target": "bag_button", "text": "背包：整理棋盘上的东西，打架前先排好。"},
    {"target": "reopen_button", "text": "放大镜：再看一眼脚下这个点里还有什么。"}
  ]}
  ```
  `target` 是读数部件的 id（`HudHost.rect_of(id)` 给包围盒 —— 部件挪了位置教程自动跟着）。文案占位，不写阿拉伯数字。
- 触发：章节字段 `ChapterDef.coach = "prologue_map"`，序章一配；地图屏在**开场事件关掉、第一次露出地图**时放，`MetaState.coach_seen` 记过就不再放（待定 4）；调试台里一颗「重放教程」。导出包同样生效。
- 和序章现有的教程事件（事件屏那一套）不冲突：教程事件讲玩法，这一层只讲界面上四个东西在哪。

### 4.1 测试

- `test_hud_layout`：默认布局的三个槽各有谁、`VERSION` 升了、旧布局被丢；`extract_button / menu_button / log / ground_count` 不在布局里。
- `test_hud_bar`：`bar_left / center / right` 的排布、`IconButton` 缺图退回文字、技能角标数字。
- `test_map_screen`：地图视图满幅、`content_inset` 扣掉顶栏与图例；调试台开着不改地图尺寸、顶缘在顶栏之下；暂停菜单没有存档按钮。
- `test_game_flow`：`step_to` 进点后存档文件更新且早于事件触发；回到地图再存一次；传送同理。
- `test_legend`：只列图上有的类型、顺序按表。
- `test_coach_overlay`：洞的矩形 = 目标包围盒 + 8；点一下进下一步、最后一步收掉；`coach_seen` 记过不再放；步骤 json 里的 `target` 都是登记过的部件 id（导入校验）。
- UI 棘轮不涨。

## 5. 美术清单（转美术设计）

| 文件 | 规格 | 用途 |
|---|---|---|
| `assets/ui/hud/bar.png` + json | 九宫格 128 × 64，顶端栏底；**大理石**质感（第十四条），`tone` 自定（大理石浅 → `light`） | 2.2 |
| `assets/ui/hud/icon_bag.png`、`icon_lens.png` | 48 × 48 线稿，背包 / 放大镜 | 2.3 |
| `assets/ui/hud/icon_skill_second_wind.png`、`icon_skill_slip.png` | 48 × 48，咬牙（紧咬的牙 / 握拳）、脱身（烟 / 侧身） | 2.2 技能按钮 |
| `assets/ui/hud/coin.png` | 24 × 24 金币（帝国纹样可用 157 定的徽记） | 3 |
| `assets/ui/faith/{brute,church,earth,hunt,nature,skill,sun}.png` | 32 × 32，七个信仰各一枚，同一套线稿粗细；避免真实宗教符号（美术线程已有的规矩） | 3 |
| `assets/ui/coach/arrow.png` | 约 160 × 80 手绘箭头，透明底，指向右；代码按方向翻转 | 4 |
| `assets/ui/belt_slot.png` | 160 清单那张圆底改成 72 px | 2.5 |
| **第十四条：石板 → 大理石** | 已交的 `frame_stone.png`、`panel_stone / inset / hud`、`nameplate_stone.png`、`bg_stone` 整套按大理石配色重做（偏白、带纹理的冷灰或暖白，少一点深棕）；每张 json 的 `tone` 重新填（大理石多半是 `light`，字会自动换墨色） | 157 那一套 |

交付到 `/mnt/project-files/art/ui/`（信仰 `art/ui/faith/`、教程 `art/ui/coach/`），落仓库由执行线程接；所有图缺了都有退路，不挡实施。

## 6. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 自动存档的时机 | A 进点前 + 回到地图时；B 只进点前（作者原话） | **A**：B 会把点上拿到的东西丢回进点之前 |
| 2 | 主动技能按钮 | A 进顶端栏右槽，图标 + 次数角标；B 留在地图上另放 | **A** |
| 3 | 图例列哪些 | A 这张图上出现的类型；B 全部类型 | **A**：序章图只有四五种，列全是噪音 |
| 4 | 教程放几次 | A 每个存档位一次（`coach_seen`），调试台可重放；B 每次开序章都放 | **A** |
| 5 | 腰带圆槽直径 | A 72；B 64 | **A** |

## 7. 改动范围

| 文件 | 改什么 |
|---|---|
| `ui/hud/hud_host.gd`（三个栏槽、`rect_of`、`content_inset` 回传）、`ui/hud/hud_layout.gd`（默认布局、`VERSION`）、`ui/hud/hud_widgets.gd` | 2.1 / 2.2 |
| `ui/hud/widgets/hud_bar.gd`（新）、`legend_widget.gd`（新）、`wallet_widget.gd`、`faith_widget.gd`、`belt_widget.gd`、`ui/widgets/icon_button.gd`（新）、`ui/widgets/coach_overlay.gd`（新） | 2 ～ 4 |
| `ui/game/map_screen.gd`（满幅、按钮、暂停菜单、调试台悬浮、教程触发）、`ui/game/dev_drawer.gd`（dock 顶缘） | 2.1 / 2.3 / 2.4 / 4 |
| `core/run/game_flow.gd`（`step_to` / 回地图自动存档）、`core/run/chapter_def.gd`（`coach`）、`core/meta/meta_state.gd`（`coach_seen`） | 2.3 / 4 |
| `ui/map/map_view.gd`（`content_inset`）、`ui/map/map_node_style.gd`（`NAMES`） | 2.1 / 2.5 |
| `ui/ui_theme.gd`（`PANEL_HUD_BAR`、`BUTTON_ICON` 变体，`PANEL_ART` 加一行） | 2.2 |
| `data/authoring/coach/prologue_map.json`（新）、`data/authoring/chapters/prologue.json`（`coach`）、`data/authoring/ui_layouts/map.json` | 4 / 2.2 |
| `tests/ui/…`、`tests/run/test_game_flow.gd` | 4.1 |
| `docs/architecture.md` 8.7（读数组件）、8.9（新：教程遮罩） | |

## 落地记录（2026-10-13）

五项待定全按推荐 A（进点前 + 回地图各存一次、技能进栏右槽、图例只列图上有的、每个存档位放一次可重放、圆槽 72）。

- 顶端栏：`hud_bar` 组件（`PanelHudBar` 变体，`PANEL_ART` 指 `hud/bar`，缺图半透明深底）+ 三个栏槽锚点；`HudHost` 先定栏高（至少 64），栏槽在栏里摆，再摆右边与其余；`top_inset / bottom_inset / content_inset / bar_height / rect_of`。布局版本 4。
- 按钮：`IconButton` —— 背包（B）、放大镜（N，原「回到这个点」）、主动技能（次数角标）；撤离按钮、「存档并回主菜单」删掉，暂停菜单改「回主菜单」（照旧先存）。
- 自动存档：`GameFlow.step_to` 在 `run.step_to` 与录像之后、`_flush` 之前存；`_flush` 回地图前再存。
- 调试台：`dock` 在栏下面（栏高变了跟着挪），悬浮盖地图；提示行、「地上 N 件」、日志都在里面；`ground_count_widget.gd` 删掉。
- 地图：`MapView` 满幅，`content_inset` 只管安全区（居中、适配、聚焦）；预览两行字浮在底部正中。
- 金币 `HudIcon`、信仰图标（没信仰留空槽，缺图退回老的字）、左下 `legend` 图例（`MapNodeStyle.NAMES`）、腰带圆槽 72。
- 教程：`CoachOverlay` + `data/authoring/coach/prologue_map.json`（体力、货币、背包、放大镜）；`ChapterDef.coach`、`MetaState.coach_seen`；开场事件、规则卡、暂停压着都不放，地图露出来才放；调试台「重放教程」。
- 美术：所有图都是占位接口（缺图写字 / 画圆 / 折线箭头），按第 5 节清单交图后放进对应路径即可，不用改代码。
- 测试：`tests/ui/test_hud_150.gd`（顶端栏几何、栏槽、地图满幅、调试台内容）、`tests/ui/test_map_screen_166.gd`（新：图标按钮、图例、自动存档、教程数据与遮罩、序章开场放一次）、`test_belt_slots_160.gd`、`test_author_090.gd`。

