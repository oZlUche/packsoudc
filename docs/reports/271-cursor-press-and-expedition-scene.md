# 271 光标按下动作 + 出征页专属背景

作者 2026-11-03 11:10：「1. 给鼠标增加一个按下时手指会下压的动作 2. 给出征界面加一个专属的背景」。两件都是小改：代码各一两处挂钩，重头在美术出样。

## 〇 一句话

按下鼠标时箭头光标换成「食指压下」那一帧，松开还原；出征页像集市 / 铁匠铺那样铺自己的整屏场景图，淡入淡出沿用。附带发现：按钮上现在显示的是系统小手，不是铠甲手套，建议一并换成手套，否则「按下」动作在按钮上看不到。

## 一、现状（读码）

| 项 | 现状 | 出处 |
|---|---|---|
| 光标 | 三套材质（秘银 / 铁 / 皮革）各四张 32 × 32：arrow / drag / can_drop / forbidden，热点 (2, 2) 在指尖；启动和设置换材质时 `UiCursor.apply` 装上 | `ui/ui_cursor.gd`，`assets/ui/cursors/<材质>/` |
| 按下 | 没有任何按下态；拖拽时按「拖动 / 可放 / 不可放」换形状 | `UiCursor.set_drag`，`DragLayer` |
| 按钮上的光标 | 按钮、书架格、滑块等把 `mouse_default_cursor_shape` 设成 `CURSOR_POINTING_HAND`，而 `SHAPES` 没给这个形状配图 → **按钮上显示系统小手** | `ui/ui_cursor.gd:16`，`forge_screen.gd:214`、`shelf_view.gd:68` 等 |
| 基地背景 | 默认基地底图 `home/bg_home`（1920 × 1080 cover）；集市 / 铁匠铺两页按 `SCENES` 换成各自场景图，0.25 s 淡入淡出；有场景图的页不垫粗布 | `ui/game/meta_screen.gd:59`、`backdrop_of`、`_swap_backdrop` |
| 出征页 | 左碑 + 右列三块木牌（上回出征 560 × 200、军需 560 × 260、倾向 90 高）+ 右下【开始探索】360 × 96；仓库列藏起 | `ui/widgets/expedition_board.gd` |

## 二、方案

### 2.1 光标按下

- **动作**：鼠标任一键按下，箭头光标换成 `cursor_arrow_pressed.png`（同材质、同 32 × 32、**热点不动仍是 (2, 2)**：指尖钉在原处，手指弯下 / 手掌压低 2 ～ 3 px，所以点中的位置不变）；松开、窗口失焦、鼠标离开窗口都还原。
- **按钮也是手套**：`SHAPES` 加 `"pointing_hand"` 用同一张 arrow 图（按下也同一张 pressed），按钮上不再出现系统小手，整局只有一只手套。
- **拖拽不动**：拖动 / 可放 / 不可放本来就是「按着」的图，不另出按下帧（待定 1）。
- **挂钩**：`GameDirector._input`（比控件先看到所有鼠标事件，被按钮吃掉的也看得到）→ `UiCursor.press(true/false)`；`press` 只在当前形状是箭头 / 小手时换图，静态 `pressed` 变量给测试看（无头跑读不回系统光标）。
- **美术**：三套材质各一张 `cursor_arrow_pressed.png`（+ @2x 源），由 美术设计 出 2 ～ 3 样给作者看（例如 A 食指弯下 / B 整手下压）；执行先用代码把 arrow 图整体下移 2 px 当占位。

### 2.2 出征页场景

- **代码**：`SCENES` 加 `"expedition": "home/scene_expedition"`，`backdrop_of` 缺图自动回基地底图，淡入淡出和去粗布都沿用集市那套；进基地第一眼就是出征页，所以建图时把起始底图直接设成 `backdrop_of("expedition")`，不要每次进基地都淡一次。
- **美术**（UI替换美术）：1920 × 1080 cover，光线 / 色调自报；画面要给左碑、右列三块木牌和右下大键留位（1600 × 1000 下：左 220 页签列，碑约 x 250 ～ 560，木牌列 x 980 ～ 1540），木牌挂在场景里的横梁 / 栅栏上更顺；主题是「出发」—— 营门外的路通向野地，军旗（和出征页签图标一致）。出 A / B / C 三样给作者挑。
- 仓库 / 书架照旧铺基地底图；主菜单不动。

## 三、改动清单（执行）

1. `UiCursor`：`SHAPES` 加 `pointing_hand`（复用 arrow 图）；新 `press(down: bool)`、静态 `pressed`；`apply` 时顺带缓存 pressed 图（缺图 = 不换）。
2. `GameDirector._input`：`InputEventMouseButton` 按下 / 松开 → `UiCursor.press`；`NOTIFICATION_APPLICATION_FOCUS_OUT` / `WM_MOUSE_EXIT` 还原。
3. `MetaScreen.SCENES` 加 `expedition`；建图时起始底图取 `backdrop_of("expedition")`。
4. 占位：三套 `cursor_arrow_pressed.png` 由 arrow 图下移 2 px 生成（美术定稿后覆盖）；出征场景缺图时自动回基地底图。
5. 测试：按下 / 松开后 `UiCursor.pressed`；`backdrop_name()` 在出征页 = `home/scene_expedition`（图在时）。
6. 美术：美术设计 → 光标按下帧三套（样 → 作者 → 定稿交执行）；UI替换美术 → 出征场景 A / B / C（样 → 作者 → 定稿交执行）。

## 四、待定（没回音按推荐）

1. 拖拽三种形状要不要也出按下帧 —— **推荐不出**（本来就是按着的图）。
2. 按钮上的小手换成手套 —— **推荐换**（否则按钮上看不到按下动作）。
3. 出征页去粗布、木牌直接挂在场景上 —— **推荐去**（和集市 / 铁匠铺一致）。
4. 主菜单背景不动 —— **推荐不动**（作者只提了出征页）。

## 五、落地记录（v4.96，PR #406，main e2db48b，2026-11-03 12:11）

执行按 §三 做，§四 全按推荐；全套 33736 项通过。待定 3「出征页去粗布」不用改：这一页本来就是 HBox，没垫粗布。占位：三套按下帧 = 箭头图下移 2 px；出征场景还没放图，现在显示基地底图。美术定稿后直接覆盖两个文件：`cursors/<材质>/cursor_arrow_pressed.png`、`assets/ui/home/scene_expedition.png`。

**美术样（2026-11-03）**
- 光标按下帧（美术设计 12:06）：秘银三样已给作者挑，A 食指弯下 / B 整手压低 / C 指尖按扁，推荐 A；源 `/mnt/project-files/art/ui/cursors/press271/gen.py`（接 `art/cursors/glove.py` 的 `glove()`，热点 (2, 2) 不动）。选定后出三套 `final/<材质>/cursor_arrow_pressed.png` + @2x 交执行。
- 出征场景（UI替换美术 12:17，UI设计线程决策卡，推荐 A）：A 营门 · 清晨（木门楼，木牌挂走道梁下）/ B 驿亭 · 午后（营外路口，木牌挂驿亭檐梁下）/ C 石门 · 黄昏（石砌门楼 + 火盆，深色调）；材料 `/mnt/project-files/art/ui/scene271/`，按 A 预备的定稿已在 `final/home/scene_expedition.png` + `.json`。

**作者定稿（2026-11-03）**：光标按下帧 12:42 选 **B 整手压低**，三套材质定稿 `art/ui/cursors/press271/final/` 已交执行覆盖占位；出征场景 12:48 选 **A 营门 · 清晨**（tone light），定稿 `art/ui/scene271/final/home/scene_expedition.png` + `.json` 已交执行，代码不用动。
