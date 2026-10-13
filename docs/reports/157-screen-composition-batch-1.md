
## 补充三（2026-10-13）：石板是「一整块」—— 每个界面坐在一块完整石板上，不要石砖墙底

> 作者原话：「关于我提到的石板，我说的不是让背景成为石板拼成的石砖墙，而是让每个界面（框）在一块完整的石板上显示」。性质：架构 · 美术。关联 166 第十四条（大理石色）、164（基地有自己的家底，不走石板）、166 §2.1（地图屏满幅纸底，不走石板）。

### 1. 现在差在哪

- 落地时把 `bg_stone`（一格格石砖的可平铺图）**平铺满整屏**当底（`UiTheme.dress_backdrop`，`GameScreen._backdrop` 里挂），面板再压在砖墙上 —— 这就是作者不要的「石砖墙」。大理石版（`art/ui/marble/preview.png`）同样是方砖拼墙。
- 叠层框 `frame_stone` 本身只是砖墙上的一个描边方框（双线 + 四角铜钉），不像一块石头。

### 2. 改成什么样

**一屏一块石板。** 石板就是框：一块有厚度、边缘手凿不太规整的完整大理石板，整个界面的内容都放在这块板上；板外面没有砖墙，是暗处（叠层屏：底下的地图压暗透出来；底屏：纯色暗底）。一屏只有一块石板，板里的分区是**刻进板里的凹槽**，不再是叠一块更小的石板。

- **叠层屏（九屏，`OverlayFrame`）**：`OverlayFrame` 的底换成「石板」两层画：
  - 下层 `slab_body.png`：无缝的大理石纹（256 × 256，浅暖白加灰纹），**平铺**（`StyleBoxTexture.axis_stretch_* = TILE`），纹理不随框大小被拉花；
  - 上层 `slab_edge.png`：九宫格、中心透明，只有板的边 —— 外轮廓手凿的小缺口与斜面、一圈受光的棱、底边一道投影，四个角各不相同（九宫格只拉伸四条边，四角原样，所以缺口要画在角上和边的中段各一处，拉长后仍看得出是一块石头）；
  - 标题条不再是另一色的横带，而是板顶一道**刻线**（`title_height` 照旧从 json 读，刻线画在 `slab_edge` 顶边里），标题字就刻在线上方；
  - 外框内边距照旧从 json `margin` 读。
  - 实现：`OverlayFrame` 不再直接用 `PANEL_OVERLAY` 的一个 `StyleBox`，而是 `UiTheme.slab(control)`：给一个 `PanelContainer` 挂两个 `Panel` 子底（body 平铺 / edge 九宫格，都 `MOUSE_FILTER_IGNORE`，`PRESET_FULL_RECT`），没图时退回现在的 `StyleBoxFlat`。`PANEL_OVERLAY` 变体留着做无图退路；`PANEL_ART[PANEL_OVERLAY]` 改指 `slab_edge`，`UiTheme.tone_of(PANEL_OVERLAY)` 读 `slab_edge.json` 的 `tone`（light）。
- **叠层屏的底**：`GameScreen._backdrop()` 在叠层屏上不再铺 `bg_stone`，改成**半透明暗色罩**（`Color(0.04, 0.05, 0.07, 0.6)`，和 `_shade` 一致）—— 底下的地图压暗透出来，石板像浮在地图上（待定 补 1 推荐 A）。`mouse_filter` 仍 STOP。宝箱屏、百科屏各自传的颜色不变。
- **底屏**：
  - 开局屏三页（161）、主菜单、设置、存档位、结算：内容放进**一块居中的大石板**（屏幕的九成宽高，同一套 `UiTheme.slab`，`GameScreen._slab_screen(min_size)` 造，返回内容区），板外是纯色暗底（091 的底色设置照旧管这块纯色）。
  - 基地屏（164）用家的布底，地图屏（166）满幅纸底，**都不走石板**；战前对阵式 / 战斗 / 回放是叠层屏，走上面那条。
- **板里的分区**：`PanelDark` / `PanelLine` 不再是石板九宫格（砖墙上叠小石板），改成**刻进板里的凹槽** `inset.png`（九宫格：内沿一道暗线 + 上左内阴影，底色比板身暗一档，没有铜钉），`PANEL_ART[PANEL_DARK] = PANEL_ART[PANEL_LINE] = "inset"`；`PanelHud` 的顶端栏（166 `hud_bar`）是**一条独立的长石板**（它不在任何屏的板里），用同一套 `slab_body + slab_edge` 画，`bar.png` 从 166 清单里撤；名牌（157 补二）保留切角石碑，但只在板里以凹槽式出现（铜角片去掉、改刻线），避免一屏里出现第二块「石板」。
- **退掉**：`bg_stone.png/json` 不再被引用（`UiTheme.ART_BG`、`backdrop_art`、`dress_backdrop` 删；`tint_backdrop` 改成给纯色底 / 暗罩染色）。旧图归档到 `art/ui/stone/dark_v1/` 旁。
- **深浅**：石板 light（墨字），暗罩 / 纯色暗底不是面板不标；凹槽 `inset.json` light（比板身暗一档仍是浅底）。`test_screens_157` 的「底图 json 必须有 tone」照旧覆盖新图。

### 3. 美术清单（转美术设计，替换 166 §5 的「石板改大理石」那一条与 `bar.png`）

| 文件 | 规格 | 用在 |
|---|---|---|
| `assets/ui/slab_body.png` + json `{"tile": true, "tone": "light"}` | 256 × 256 无缝大理石纹，浅暖白加灰纹，纹要细、对比低（上面压字） | 石板板身（叠层框、底屏大板、顶端栏） |
| `assets/ui/slab_edge.png` + json `{"margin": [l, t, r, b], "title_height": 36, "tone": "light"}` | 192 × 192 九宫格、中心透明：手凿不规整的外轮廓（角与边中各一处小缺口）、受光棱、底边投影、顶边一道刻线当标题线；四角各不相同 | 石板的边 |
| `assets/ui/inset.png` + json `{"margin": [...], "tone": "light"}` | 64 × 64 九宫格：刻进板里的凹槽，内沿暗线 + 上左内阴影，底色比板身暗一档，无铜钉 | `PanelDark` / `PanelLine` |
| `assets/ui/nameplate_stone.png`（改） | 同尺寸；铜角片去掉改刻线，颜色与 `inset` 一致 | 名牌 |
| 退掉 | `bg_stone`、`panel_stone`、`panel_inset`、`panel_hud`、`frame_stone`、166 的 `bar.png` | 归档 |

预览请按真实构图出：一张叠层事件屏（地图压暗透出 + 一块石板）、一张开局屏第一页（纯色暗底 + 大石板 + 板里两个凹槽）。

### 4. 测试与改动范围

- `test_overlay_frame`：有图时树里是 body + edge 两层、无图退 `StyleBoxFlat`；`_slab_screen` 的板占屏九成并居中；叠层屏 `_backdrop` 不再挂 `StoneBackdrop` 子节点、颜色带透明度；`PANEL_DARK` 的底是 `inset`。UI 棘轮不涨。
- 文件：`ui/ui_theme.gd`（`slab()`、`ART_*` 改名、`PANEL_ART`、删 `dress_backdrop / backdrop_art`）、`ui/widgets/overlay_frame.gd`、`ui/game/game_screen.gd`（`_backdrop` 叠层暗罩、新 `_slab_screen`）、`ui/game/setup_screen.gd` / `main_menu.gd` / `settings_screen.gd` / `slots_screen.gd` / `result_screen.gd`（内容进大板）、`ui/hud/widgets/hud_bar.gd`（166，改用 `slab`）、`ui/widgets/nameplate.gd`、`tests/ui/test_screens_157.gd`、`docs/architecture.md` 8.8。

### 5. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 补 1 | 叠层屏板外是什么 | A 底下的地图压暗透出（暗罩 0.6）；B 不透明纯色暗底 | **A**：石板「浮在地图上」才像一块板；文字都在板上，不受地图干扰 |
| 补 2 | 底屏的大板占多大 | A 屏幕九成宽高、居中，板外纯色；B 顶天立地（板边贴屏幕边） | **A**：看得见板的边才像一块石头，B 又回到「满屏石头」 |
| 补 3 | 板身纹理 | A 平铺无缝纹（TILE）；B 一张大图按框拉伸 | **A**：框大小各屏不同，拉伸会花 |
