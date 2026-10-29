# 方案：道具收藏 —— 悬浮窗【收藏】按钮与右上角明暗图标、收藏过的道具画上标记、铁匠铺材料栏也能看悬浮窗并收藏（265）

> 作者 2026-10-29 16:43（本线程）明确指令，直接派执行，待定按推荐。

作者原话：「给道具的悬浮窗添加一个收藏按钮，收藏后道具显示会不同，且悬浮窗右上角有图标明暗切换表示是否被收藏。在铁匠铺的材料栏里面，材料也要可以显示悬浮窗并被收藏」。

## 一、现状（v4.71 核过）

- 悬浮窗 `ui/inventory/hover_tip.gd`：`TipWindow.set_item(full)` 画名字 / 词条 / 页脚，`set_actions` 在页脚下画一排 `TipButton`（230：容器按 `actions_for` 给按钮，双击 = 第一颗，右键钉住）；右上角现在画「钉住」的小图（`_pin_tex`，`size.x − 20, 4`，16 × 16）或钉住进度环。
- 道具上的角标：`ItemPainter.draw_lock`（230 玩家锁）、`draw_pin`（随身之物）、`draw_charges`、`draw_honor`，都是按件（`ItemInstance`）画。
- 铁匠铺材料栏：`ui/widgets/recipe_scroll.gd` 第 200 行起，`r.inputs`（道具 id → 件数）每条一行 `_mat(def, 有, 要)`，只有图 + 数，没有悬浮窗。
- 局外有 `MetaState.codex`（点亮过的种类）、`keepsakes`、`flags`；没有「收藏」。

## 二、方案

### 2.1 收藏的是「种类」不是「这一件」

铁匠铺材料栏里是种类（def），不是件；收藏跟着种类走，局内局外、仓库 / 背包 / 商店 / 图鉴里同一种都显示收藏。存 `MetaState.favorites: Array[StringName]`（def id，存档；`toggle_favorite(id)` / `is_favorite(id)`，`changed` 信号），导入器不管它（存档里的 id 若已不存在，读档时丢掉，照 173 的 IdAliases 走）。

### 2.2 悬浮窗

- **按钮**：`ItemActions` 多一颗 `favorite`（「收藏」/「取消收藏」，`Favorite` / `Unfavorite`），不是危险动作、不用两步确认；**每个有道具悬浮窗的容器都给**（背包、地上、战利品、货架、仓库、带回来的棋盘、包架、保险箱、祭坛…：在 `ContainerView.actions_for` 的公共尾部加，不逐屏写），排在那一屏按钮的最后。
- **右上角图标**：`TipWindow._draw` 右上角画收藏图标 `tip/fav_on` / `tip/fav_off`（16 × 16，亮 = 收藏了、暗 = 没收藏），**可点**（`TipWindow` 加一个 16 × 16 的透明按钮盖在上面，点 = 同一颗 action）；原来的钉住图 / 进度环往左挪 22（`size.x − 42`）。没图之前：亮 = `RING_COLOR` 实心小星（五角），暗 = 同色 35% 透明。
- 切换后 `_refresh_item()` 重画窗（图标明暗、按钮字换）并 `queue_redraw` 所有在看的视图（角标）。

### 2.3 道具显示不同

- `ItemPainter.draw_favorite(canvas, def, rot, anchor, cell)`：道具图**右上角**一枚小角标（`item/fav_badge`，占格边 0.28，一个正面、无投影；没图画小星），所有走 `draw_item` 的地方都画（棋盘、仓库、货架、货位、图鉴格、书架图鉴窗、商店货位 / 随身格不画 —— 随身技能不是道具）；和锁角标（左上）、充能（左下）不撞；**255 随身之物的小钉（`ItemPainter.draw_pin`）也在右上角** —— 两样都有时收藏角标往左让一个角标宽 + 2（UI替换美术 16:57 定）。
- 图都放 `assets/ui/tip/`（锁、钉的角标已在那里）：`fav_on` / `fav_off`（16）、`fav_badge`（16）+ `fav_badge_2x`（32）；不用 `item/` 目录。样图 `/mnt/project-files/art/ui/fav265/fav_samples.png`（A 金星 / B 蜡封 / C 丝带）；**作者 17:01 选 C 丝带**，定稿 `/mnt/project-files/art/ui/fav265/final/tip/`（fav_on / fav_off / fav_badge / fav_badge_2x）已交执行。
- 名字行不变色（六色稀有度那套不动）。

### 2.4 铁匠铺材料栏

- `recipe_scroll._mat` 那一行挂 `HoverTip`：停上去出**种类**的道具窗（图鉴格用的那条路：按 def 组 `full`，没有件的充能 / 磨损行），按钮只有「收藏 / 取消收藏」；画角标同 2.3。集市货位、图鉴格本来就有道具窗，只加按钮与角标。

### 2.5 收藏有什么用（待定 1，推荐做）

和 230 的锁不同，收藏**不阻止**任何操作，只做标记与筛选：

- 「一键出售」「出售同类」「出售筛选」跳过收藏的种类（出售页的预览字写「跳过收藏 N 件」，单件拖去卖照旧能卖）；
- 264 仓库页筛选牌多一颗「只看收藏」；
- 图鉴 / 书架图鉴窗多一档筛选「收藏」。

不做：收藏不影响掉落、不影响整理顺序、不同步到成就。

## 三、改动清单（执行）

1. `MetaState.favorites` + 存档（`SAVE_VERSION` 不动，缺省空）。
2. `ItemActions` 公共动作 `favorite`；`ContainerView.actions_for` 尾部统一加（一处）。
3. `HoverTip.TipWindow`：右上角图标 + 透明按钮，钉住图左挪；`_refresh_item` 后重画视图。
4. `ItemPainter.draw_favorite`，`draw_item` 里调用。
5. `recipe_scroll._mat` 挂 `HoverTip`（种类窗）。
6. 出售三处跳过收藏；仓库筛选牌 / 图鉴筛选加「收藏」档（图鉴那档随 264 一起）。
7. 文案：`act.favorite` / `act.unfavorite` / `tip.favorite_tip` / `meta.sell_skip_fav` 中英。
8. 美术（UI替换美术）：`tip/fav_on`、`tip/fav_off` 16 × 16、`tip/fav_badge`（+ `_2x`）；没到之前代码画星。

## 四、测试

- `test_favorites`：toggle 存读档；action 在背包 / 仓库 / 货架 / 材料栏四处都有；右上角按钮点一下切换、图标明暗；角标画出（`draw_favorite` 返回 true）；一键出售跳过收藏且预览字对；锁 + 收藏同时画不重叠。
- 截图：悬浮窗亮 / 暗各一张、材料栏窗一张（中英）交 游戏测试（新）。

## 五、待定（没回音按推荐）

1. 收藏的用处：**做**（跳过一键出售 + 筛选，推荐）/ 纯标记。
2. 收藏按种类：**是**（推荐）/ 按件（材料栏做不到按件）。
