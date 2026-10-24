# 249 开战前不丢东西 + 丢到地上的东西带着手上的速度飞出去

作者 2026-10-24 11:26（架构设计线）：「让开战界面不能丢出道具(但可以设置为不参战)，以及给丢出道具的动画加一个初始速度和方向，以鼠标按住道具时的速度和方向为准(受密度影响)」。两件事都是明说的改法，照办；本文只把边界与做法写清，供 执行 落地。

## 〇 一句话

**战前屏只整队、不卸货**：棋盘上的东西在战前屏出不去（拖出去弹回、右键「放到地上」灰掉、双击不搬），要让它不打就右键「不参战」（243）；地上已有的照样能拾进棋盘。**别的屏丢到地上的东西不再只会竖直掉**：松手那一刻鼠标有多快、往哪甩，它就带着这股初速度飞出去，越沉的飞得越短，落地、撞墙、砸到别的东西都交给 198 那套解算。

## 一 现状

| 事 | 现在 | 出处 |
|---|---|---|
| 战前屏出棋盘的路 | 三条都通：拖出棋盘 = 放到地上（084 / 128 `drop_outside_to_stash`）；右键第一项「放到地上」（`InventoryPanel.board_actions` → `quick_move`）；双击 = `quick_move` → 地上 | `ui/game/inventory_panel.gd` 82、151、186 |
| 战前屏「不参战」 | 右键菜单里，只给有战斗定义、不是信物的那几件（`can_bench`） | 同上 165 |
| 落地动画 | 162 补充二：从松手时残影的位置**竖直**往下掉到第一个支撑，按重力加速，沉的（密度 ≥ 2）不封顶、飘的到末速度、左右小摆；落稳后 `wake_bumps` 交给解算 | `ui/inventory/ground_layer.gd` `_begin_fall` / `_fall` / `land_profile` |
| 解算（180 / 198 补充一） | 每件是一个有 `vel` / `w` / `m = √重` / `I` 的刚体：重力、屏边与地面、登记的面板当墙、两两接触带反弹与摩擦、斜度、睡着；最多醒 1.5 s | 同上 `_new_body` / `_bump_step` |
| 拖拽层记的 | 只记当前鼠标位置（`_input` 里 `update_preview`），不记上几帧 —— 没有速度可取 | `ui/inventory/drag_layer.gd` 238 |
| 密度 | 已有：`ItemWeight.of(def) / 格数`，`land_profile` 用它分沉 / 飘 | `ground_layer.gd` 465 |
| 光标 | `drop_ok_at`：棋盘外只看开关 `_drops_outside_to_stash()`，**不看 `drop_filter`** —— 要是用过滤器拦地上，光标还会说「能放」 | `drag_layer.gd` 396 |

## 二 开战前不丢东西

### 2.1 规矩

| 从 → 到（战前屏） | 改后 | 反馈 |
|---|---|---|
| 棋盘 → 地上（拖出去松手） | **不放**，弹回原格 | 一句「开战前不丢东西」（走面板已有的提示口 `hint_sink`，落在说明签上，226 不裸字），`bag.invalid` 那一声照响 |
| 棋盘 → 地上（右键「放到地上」） | 那一项**灰着**，原因同上一句 | 右键菜单灰项带原因，和「锁住的」一样（`ItemActions.disable`） |
| 棋盘 → 地上（双击） | 不搬 | 同一句提示 |
| 棋盘 → 「不参战」（右键） | 不变 | — |
| 地上 → 棋盘（拖 / 双击） | 不变，照样能拾 | 放不下照说「放不下」 |
| 地上拿起 → 又放回地上 | 不变（它本来就在地上，不算丢出） | — |
| 腰带 / 别的屏 | 不动 | — |

拖拽中光标：悬在棋盘外要显示「不能放」（157 的光标两态）—— 顺手修 `drop_ok_at`：`target == null` 时也要过 `_drop_allowed(stash)`。

### 2.2 做法

- `InventoryPanel` 加一个开关 `ground_exit_notice: String = ""`：非空 = 这一屏棋盘上的东西出不去，字符串就是那句原因。设了它：
  - `_drag.drop_filter` 挂一条：`源容器 == _run.board 且 目标 == _run.storage → false`（源是地上的放回地上不拦）。拖拽层现有的 `drop_filter.call(inst, target)` 没带源，加一句 `source()` 判断即可（`DragLayer.source()` 已有）；
  - `board_actions` 的第一项 `ItemActions.disable(first, ground_exit_notice)`（有 `quick_target` 的屏不受影响 —— 战前屏没有）；
  - `quick_move` 棋盘 → 地上那一支改成 `_hint_text(ground_exit_notice)` 返回 false；
  - 松手被拒：`drag_finished(uid, false)` 且松手点不在任何视图上 → 面板说那一句（拖拽层可以加一个 `drop_refused(uid)` 信号，比在面板里猜「为什么没放下」干净）。
- 战前屏 `_inv.ground_exit_notice = UiText.t("pre.no_drop")`，文案键 `pre.no_drop`：zh 「开战前不丢东西」/ en "Nothing is thrown out before a fight"。头注释第 4 行改掉「拖出棋盘 = 放到地上」。
- 别的屏（地图包窗、容器屏、事件、神坛、铁炉、保险箱、营地）一个字不改。

## 三 丢到地上的东西带着手上的速度飞出去

### 3.1 规矩

- 只管**用手拖到地上**松手的那一下（棋盘外空处 / 开局屏那块地）。右键「放到地上」、双击、顶替挤出去的、战利品放不下掉地上的：没有「手上的速度」，照 162 补充二竖直掉，不变。
- 松手那一刻的速度 = 鼠标最近 **90 ms** 内的位移 ÷ 时间（拖拽层在 `_input` 收 `InputEventMouseMotion` 时存一圈 `(时刻, 位置)`，最多 8 个样本；松手取窗口里最老的一个到松手点）。单位换成**屏高 / 秒**，和落地动画的重力 `LAND_G = 2.0 屏高/s²` 一个量纲。
- **受密度影响**：初速度 × `1 / (1 + 密度 / THROW_DENSITY)`，`THROW_DENSITY = 2.0`（和 `LAND_SINK_DENSITY` 同一条线）。密度 = `ItemWeight.of(def) / 格数`：布 / 木 / 皮每格 1 → 0.67；金属每格 3 → 0.4；重物每格 4 → 0.33；包重 0（161）→ 1.0。沉的东西手一样快却飞不远，这就是「受密度影响」的全部含义，不再另给它减速。
- 太慢的不算甩：缩放后速度 < `THROW_MIN = 0.15 屏高/s` → 走原来的竖直掉（点一下放手、慢慢挪过去放的，手感不变）。封顶 `THROW_VMAX = 1.6 屏高/s`（甩得再狠也别一帧飞出屏）。
- 飞出去以后：重力、撞屏边 / 地面 / 登记的面板、砸到地上别的东西、滑行摩擦、斜着落、翻倒 —— **全部交给 180 / 198 补充一的解算**，不另写一套抛物线。所以飞出去的东西能沿着地滑一段、能把睡着的那件撞醒（解算里撞得过撞击线就醒）、撞到面板会弹一下落下，和作者为 198 选的自由角度一致。
- 声音（206）：飞出去的那件第一次撞地面 / 墙过撞击线那一步响 `landing_cue`（沉的 `bag.land.heavy`、飘的 `bag.land.light`），之后的小碰不响。

### 3.2 做法

1. `DragLayer`：
   - `_input` 的 `InputEventMouseMotion` 分支存样本 `{"t": Time.get_ticks_usec(), "p": 全局位置}` 进环形数组（≤ 8，丢 > 90 ms 的）；拿起时清空。
   - `release_velocity() -> Vector2`（全局像素 / 秒）：窗口里最老样本到松手点的位移 ÷ 时间；样本不足两个 → 零。
   - `drop_at` 两处写 `stash.landing_from[uid] = _release_px(...)` 的旁边（棋盘外空处那一支、`target is GroundLayer` 那一支），同时写 `stash.landing_vel[uid] = release_velocity() × 密度因子`；就地放回（`_put_back` 为真）不写。
2. `ItemStash`：加 `landing_vel: Dictionary`（uid → Vector2，全局像素 / 秒），和 `landing_from` 同生命周期（拿走、清空时一起清）。核心层其余不动 —— 落点仍在松手时由 `spot_for_drop` 写进 `spots`，和现在一样；飞完由 `_finish_bumps` 的 `_store` 改成真正停下的位置，这和今天落到堆上被解算挪开是同一条路。
3. `GroundLayer._scan`：有 `landing_vel` 且换算成屏高 / 秒后长度 ≥ `THROW_MIN` → `_begin_throw(inst, from_local, vel)`：
   - 不进 `_landing`；直接 `_bodies[uid] = _new_body(it, ground_y, walls, true)`，再把 `vel` 填进去（`limit_length(THROW_VMAX × 屏高)`），`pos` 用松手时残影的位置（不是落点），`ang = 0`，朝向 = 拖着时的 `rotation`（解算结束 `normalize_pose` 自己归到四向 + 斜度）；
   - 其他件按 `wake_bumps` 现有规矩入队（睡着的等它撞）；`_bump_t / _bump_start` 照 `wake_bumps` 那样起表；
   - 速度不够的照旧 `_begin_fall`。
   - 画：正在解算的件已经按 `_bodies` 的 `pos / ang` 画（198 补充一），所以飞出去的那件从残影位置起画是现成的；不做 134 的「起手放大 / 半透明」（那是竖直掉的样子，飞的不需要）。
   - 声：`_prep` 里 `a["hit"]` 第一次置位且 `b == null`（撞墙 / 地）时，若这件带着 `thrown` 标记就响一次 `landing_cue([uid])` 并清标记。
4. 常数全放 `GroundLayer`（和 `LAND_*` / `BUMP_*` 一排）：`THROW_WINDOW_SEC 0.09`、`THROW_SAMPLES 8`、`THROW_MIN 0.15`、`THROW_VMAX 1.6`、`THROW_DENSITY 2.0`。都是占位数，执行按手感调，调完回写本文。

### 3.3 为什么交给解算，而不是在落地动画里画一条抛物线

| | 甲 落地动画加抛物线 | 乙（推荐）起手就当刚体 |
|---|---|---|
| 新代码 | 要在 `_fall` 外再写一套：横向走、撞屏边反弹、沿途每步问 `floor_under` 找第一个支撑、落到面板上沿、落到堆上 | 存速度 + 一个 `_begin_throw`（十几行），物理一行不加 |
| 砸到别的东西 | 落稳后才 `wake_bumps`，飞行途中穿过别的东西 | 途中就撞、就醒 |
| 滑行 / 翻滚 | 没有 | 摩擦与角速度现成 |
| 与 198 自由角度 | 两套姿态规则 | 一套 |
| 风险 | 低 | 解算的 1.5 s 封顶：甩得很快撞几次墙还没停 → 冻在当时姿态再落一次（现有收尾），可接受 |

## 四 待定（默认取推荐）

1. **飞出去时要不要带角速度**（抓的不是重心、甩的时候手腕一转）：推荐**先不带**，`w = 0`，看手感再说 —— 撞地撞墙时解算自己会给它转起来。
2. **战前屏地上拿起又放回地上**：推荐**允许**（见 2.1）；要是作者想战前屏地上完全不动，把过滤器那一句的「源 == 棋盘」去掉即可。
3. **包**：重 0 → 密度因子 1.0，飞得最远；若作者觉得空包飘得太远，给 `is_bag` 单独一个因子（如 0.8）。

## 五 测试（执行写）

- `tests/ui/test_prebattle_no_drop_249.gd`：战前屏下 (a) 棋盘拖出棋盘外松手 → 仍在棋盘原格、地上没多、提示文案 = `pre.no_drop`；(b) 右键菜单第一项 `disabled`、原因同上，「不参战」项仍在；(c) 双击棋盘件 → 不动；(d) 地上一件拖进棋盘 → 成功；(e) 地上拿起放回地上 → 成功；(f) `drop_ok_at(棋盘外)` 为假。再开地图包窗或容器屏做一次 (a)：照样落地（别的屏没被连坐）。
- `tests/inventory/test_ground_throw_249.gd`（照 `test_ground_tilt_198.gd` 的搭法，不进树直接 `settle_bumps`）：(a) 写 `landing_from` + 向右 1.0 屏高/s 的 `landing_vel` → 解算完 x 比松手点大、y 在地面；(b) 同速度一件木的（每格 1）和一件重的（每格 4）→ 重的位移更短；(c) `landing_vel` 长度 < `THROW_MIN` → 走 `_landing`（`is_landing` 为真、`landing_speed` 竖直）；(d) 朝屏边甩 → 停在屏内；(e) 没写 `landing_vel`（右键放地上）→ 和 162 一样竖直掉；(f) 一次 `landing_cue` 调用。

## 六 不改的

不参战的判定与清除（243 / 244 补充一）、162 补充二的竖直掉本身、198 的解算参数、`spots` 的存档格式、别的屏的丢东西规矩、战前屏「退回」（248）与「溜走」（136）。
