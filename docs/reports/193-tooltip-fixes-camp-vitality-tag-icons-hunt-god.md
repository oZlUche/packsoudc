# 193 · 作者反馈 10-18 晚：节点浮窗黑字、扎营体力、悬浮窗四处、拖拽时的增益格、增益 / 受益图标、标签图标字段、狩猎之神的等级效果

> 架构设计线，2026-10-18。作者在本线程连发五条反馈（20:23–20:29），按「先查清是不是 bug、再定怎么改」写成一份；每节末尾是改动点，§9 是总清单与测试。写完直接派给「架构方案执行」；图标两件派给「美术设计」出样。

## 1. 节点浮窗黑字：是 bug，根在 `bright_text_theme`，不只地图点

**现象**：鼠标停在商店点上，浮窗「有人在这里做买卖。」是黑字压在深色皮革底上（作者截图）。

**原因**（无头跑过一遍确认）：悬浮窗 `TipWindow` 挂的是 `UiTheme.bright_text_theme()`（185 加的，防止嵌在浅石板里继承墨字）。这份小主题是「把墨字主题里的每一种字色，换回全局主题同名的那一种」——它对墨字主题列出的每个类型调 `base.get_color(key, type)`。全局主题只给 `RichTextLabel` 本身写了 `default_color`，**没给 `RichTextSmall` / `RichTextBody` 两个变体写**（`ui/ui_theme.gd` 第 950 行附近只给了字号），Godot 的 `Theme.get_color` 查不到时返回 `Color()`，也就是**不透明黑**。于是亮字主题里：

| 类型 | 亮字主题里实际的值 |
|---|---|
| `RichTextLabel/default_color` | 前景灰白（对） |
| `RichTextSmall/default_color` | **黑** |
| `RichTextBody/default_color` | **黑** |
| `LabelHud` / `LabelHudLarge` / `LabelHudDouble/font_color` | **黑**（同一个坑，全局主题的 HUD 标签变体也没写 `font_color`） |

悬浮窗正文全是 `rich_block(width, RICH_SMALL_SIZE)`，所以**凡是没被 BBCode 上色的字都黑**。道具窗没事是因为 `ItemTooltip` 把正文整段包在 `[color=@tip_fg]` 里（`item_tooltip.gd:234`），效果窗（185）、信仰窗（188）也各自 `_fg()` 了；地图点的模板是纯文字，就露了馅。作者说「部分节点」——`visited` / `random` 两类模板自带 `{c:dim}`，灰字正常；`battle` 第一行红、后两行黑；`shop` / `search` / `event` / `rest` / `extract` / `spawn` / `safe` / `chest` 全黑。

**同一个根的其它受害者**（作者要求「检查所有情况」）：
- 地图上「地上（N 件）：…」那一行的件名、猎手那一行（`show_text`）。
- 钉住后开的关键词子窗（词条正文是纯文字）。
- 效果窗 `update_status` 只换字时走的也是同一条路，但正文带色，没事。
- 铜名牌（`nameplate.gd:29`）也挂亮字主题，但里面是 `Label`，`Label/font_color` 有值，没事。

**改法**（两处都做，一处治本一处兜底）：
1. `bright_text_theme()`：取颜色时沿变体链往上找——`base.has_color(key, type)` 没有就查 `base.get_type_variation_base(type)`，一直到基类；都没有就跳过这一项（不写进小主题，让它正常继承），**绝不写 `Color()`**。
2. 全局主题 `build()`：给 `RichTextBody` / `RichTextSmall` 补 `default_color = UiPalette.FG`，给 `LabelHud*` 三个补 `font_color = UiPalette.FG`——变体缺默认色本身就是坑，别只靠 1 救。

**测试**（`tests/ui/test_tooltip_193.gd`）：
- 亮字主题里每一个 `(type, key)` 的颜色都不是纯黑，且 `RichTextSmall/default_color == RichTextLabel/default_color`。
- 地图屏：对一个没用过的 `shop` 点调 `_update_tooltip`，主窗 `body.get_theme_color("default_color")` 等于 `UiPalette.FG`（亮度 > 0.6）。
- 全局主题 `has_color("default_color", RICH_SMALL)` 为真。

## 2. 扎营回了三点：按数据是对的，不是显示错；但选项文字该写总数

**查到的账**：休息点事件 `rest_default.json` 里「扎营」的后果是 `pass_time(2)` + `proceed` + `restore_vitality(1)`。`proceed` = 这个点照类型发生，休息点照类型发生就是回 `NodeRules.rest_restore`（默认 **2**，章节没有覆盖）+ `rest_bonus`；再加 `restore_vitality` 的 **1**，一共 **3**。1/5 → 4/5 正是 2 + 1。
「歇一会儿」只有 `proceed`，回 2。

**显示路径没有漏**：体力只有 `Vitality.change()` 一个入口，改了就发 `changed`，HUD 的心（`vitality_widget.gd`）订的就是它；没有第二条不发信号的改法。所以「之前是 2/5 显示成 1/5」没有代码依据——除非作者当时看到的 1 颗红心是别的原因（比如那一下刚输一场扣了 1 点，HUD 已经刷新）。结论：**回复量对，显示对，是选项文字把人带偏了**：「多回 1 点体力」读起来像一共回 1 点。

**改法**：选项文字写这一下总共回多少，不写「多回」。
- 「歇一会儿（回 {rest_restore} 点体力）」
- 「扎营（多耗 {pass_time_actions} 步，回 {rest_total} 点体力）」
- 占位符：`TextTemplate.context_for` 已经从 `run.node_rules` 取 `loss_cost`，同一处加 `rest_restore`（= `node_rules.rest_restore + run_context().rest_bonus`）；`rest_total` 在事件屏拼选项文字那一步（`event_screen.gd:58`，`ctx.merged(TextParams.of(opt))`）按这个选项的后果算：`rest_restore` + 第一条 `restore_vitality.amount`（没有就等于 `rest_restore`）。
- 数字都从字段来，符合「玩家文字只写名字和此刻的具体效果」（185）。
- 帮助页 `rest_point` / `vitality` 的「多耗几步多回一些」不用动（那是机制页）。

**「步」字**：作者说这里的选项文字「还是【步】，要统一修改」。按 179（10-17 落地）「行动点」退役、倒计时**只按「步」说**，顶端栏日晷的悬浮窗（190）也写「还剩 N 步」，所以 `pass_time` 的「多耗 2 步」已经是统一后的词。要么作者想换的是别的词、要么是想统一成「倒计时」的说法（作者自己的描述是「多消耗一点倒计时」）——本线程发了选择卡问清楚；执行先按 179 保持「步」，卡上定了再改词（改词只动 `pass_time.describe()`、`countdown_widget.gd:195/202`、`node_tooltip._countdown_line`、`map_screen` 第 663 行的「计 N 步」和 `rest_default.json` 这一条，词在一处 `Glossary` 常量里）。

## 3. 悬浮窗四处

### 3.1 钉住先等半秒再起步（作者：「放在道具区域内 0.5 秒后再开始」）
现在 `tick()` 里只要在源上或窗里就累 `dwell`，满 `PIN_SEC`（0.6 s）钉住，黄铜线从第一帧就开始走。改成：
- `HoverTip.PIN_DELAY_SEC := 0.5`。`dwell` 照累，但**进度 = (dwell − PIN_DELAY_SEC) / PIN_SEC**，小于 0 不画线；`dwell ≥ PIN_DELAY_SEC + PIN_SEC` 才 `pin()`。离开（宽限之外）仍归零。
- 主窗与子窗同一套（子窗停在关键词上也走钉住进度，作者 10-17 定的）。
- `TipWindow._draw` 用同一个进度算式；`pin()` 把 `dwell` 设成 `PIN_DELAY_SEC + PIN_SEC`。
- 测试：显示后喂 0.4 s 没线、0.6 s 有线（进度 ≈ 0.17）、1.1 s 钉住。

### 3.2 卡死不收的悬浮窗（作者：进新节点时鼠标正指着道具）
**原因**：`_on_source` 是个只靠鼠标事件翻转的旗子（`_on_view_input` 置真、`mouse_exited` / `release()` 置假）。鼠标停在道具上时那块视图被藏起来或释放（进点开事件屏 / 收起地上 / 换屏），**没有新的鼠标事件、也不一定来 `mouse_exited`**，旗子就停在「真」上。钉住的窗在 `tick()` 里 `inside = _on_source or 鼠标在窗里` 永远为真，`_away` 不累，窗就永远不收；没钉住的窗同理卡在「在源上」不走宽限。作者的截图（蛮族的项链，地图上的地上一行）正是长寿命宿主（地图屏的 HoverTip）接着一块会藏起来的视图。

**改法（按作者说的：不挂鼠标离开事件，每帧核对）**：`tick()` 开头加一段源核对，主窗是道具窗（`_for_view != null`）时：
1. `_for_view` 已释放、不在树里、`is_visible_in_tree()` 为假、`can_process()` 为假 → `hide_tip()` 收整串（钉住的也收：源都没了）。
2. `_shown_item(_for_view, _uid) == null`（道具被拿走、卖掉、搜走）→ 同上收整串。
3. 否则每帧重算 `_on_source = _for_view.get_global_rect().has_point(mouse) and _uid_under(_for_view, 鼠标在视图里的坐标) == _uid`，不再信旧旗子。
主窗是文字窗（地图点、地上）时：宿主（这个 HoverTip）`is_visible_in_tree()` 为假 → 收；`_on_source` 仍由 `release()` 管（地图屏离开点时调），再加一条：地图屏 `_update_tooltip` 在 `_bag / _confirm / _pause` 开着时已经 `hide_tip()`，进点开事件屏那一刻叠层开了却不一定经过它——`MapScreen` 收到 `flow.screen_changed` / 叠层打开时也调一次 `_tip.hide_tip()`。
- `mouse_exited` 的那段保留（它只是提前进入宽限，不再是唯一的出口）。
- 测试：显示一件道具的窗并钉住 → 把视图 `visible = false`，喂一拍 `tick` → 窗收起；显示后把道具从容器拿掉 → 收起；视图还在、鼠标移到空格但不发事件 → 走宽限后收起。

### 3.3 没有正文的道具窗去掉中间的空白
`TipWindow.set_item()` 不管正文空不空都显示分隔线 + 正文。改成：`full.body` 去掉 BBCode 外壳后为空 → `sep.visible = false`、`body.visible = false`，只剩 头 / 虚线 / 脚注（作者：「只要最后的价值和重量就好」）。`ItemTooltip.describe_full` 里 `lines` 为空时 `body` 直接给 `""`（现在会包一层 `[font_size][color]` 空壳，判空得先看 `lines`）。`text()` 跟着不拼空行。测试：战利品（蛮族的项链）的窗 `body.visible == false`，`sep.visible == false`，脚注仍在。

### 3.4 信仰窗献祭图标行：去掉下面的字、排成一行
现在是 `[table=N]`，每格一叠图标 + 下面一行 12 号名字（`faith_tooltip._offer_section`）；格宽按内容算，名字折行、几格挤在左边（作者截图：排版有问题）。改成：
- 一行，不用 table：`[img=24]` 一枚接一枚，同一条规矩里的图标间空 4 px（一个半角空格），**规矩之间空 16 px**（`[font_size=16] [/font_size]` 两个全角空），不写名字。
- 没图退回文字那条不变。
- 图标本身的含义靠悬停：这一步不做（标签图标字段落地后，§6 的词条再接）。
- 测试：`_offer_section(hunt)` 的结果不含 `[table` 也不含「血肉」等名字，含三组 `[img`。

## 4. 拿起道具（含旋转）时也画它的增益 / 受益 / 装载格
**现在**：抓取时道具从容器移除（`DragLayer` 设计如此），`InventoryView._draw_adjacency` 只遍历容器里的件，于是手上这件的格位消失，转了方向也看不出格位转到哪了。

**改法**：
- `InventoryView.set_preview(cells, origin, valid, victims, costly, held: ItemDef = null, held_rot: int = 0)`：多带手上这件的定义与朝向。`_draw` 的落点预览之后、被顶件描边之前，按 `held.adjacency` 的 `grant_cells / receive_cells / load_cells` 用 `held_rot` 旋转（和 `cells_rotated` 同一套旋转）加 `origin` 得到格位，调 `_draw_marker`；点亮与否用现有 `_marker_lit` 的判据对着**现在棋盘上的邻居**算（把 `ItemInstance` 版的 `_marker_lit` 抽一个 `(def, origin, rot, cell, filter, filter_all)` 版，老的转调它）——玩家放手前就看得见「放这儿谁会亮」。
- 棋盘外（地上 / 空处）：`DragLayer._draw` 在残影旁按同样的偏移画**未点亮**态的图标（用 `UiTheme.slot_icon(kind, false)`，格边长用残影的 `_cell`），让旋转反馈在哪儿都有。
- `rotate_dragged()` 之后已经会 `update_preview`，不用另加刷新。
- 测试：沙盒棋盘拿起一件有 `grant_cells` 的道具，`set_preview` 后 `InventoryView` 的 `preview_markers()`（新加的只读查询，返回这一帧会画的 `[cell, kind, lit]`）含那几格；转一次后格位跟着转。

## 5. 增益 / 受益图标重做（派美术出样）
现在 `assets/ui/tip/{grant,receive,load}_{on,off}.png`：增益 = 绿方框 + 右上斜出的箭头，受益 = 蓝方框 + 一支笔似的斜线，作者评价「不够美观，也不够直观」。要美术按下面的语义出 2–3 套样给作者挑，挑定后替换文件即可（代码按 `kind_on/off` 读，不用改）：
- **增益（grant）**：这件道具把效果**给出去**到这一格——方向是「从我向外」。建议意象：从格心向外的短放射线 / 一只张开的手掌 / 外扩的光环；色相沿用 `UiPalette.GRANT`（代码里是蓝 #6fb3f0；旧图的绿不是它，美术已问作者要不要保留旧色）。
- **受益（receive）**：这一格上的邻居会**给我**效果——方向是「向我收进来」。建议意象：指向格心的箭头 / 一只接住的碗或漏斗 / 内收的光环；色相沿用 `UiPalette.RECEIVE`（代码里是橙 #f0a85c）。
- **装载（load）**：法杖的晶石槽——已经是槽的意象，顺手统一风格即可（`UiPalette.MANA`）。
- 两态：点亮 = 实心、饱和、可带一圈微光；未点亮 = 同一轮廓的细线、半透明。**同一格叠两种时沿对角线错开 6 px**（现有画法），所以轮廓要小于格子一半（格 48 px 时图标 20 px，提供 20 / 40 两档）。
- 压在道具美术图上也要认得出：外圈给 1 px 深色描边。
- 交付：`/mnt/project-files/art/ui/tip/v2/`，命名同现在；README 写 tone 无关（图标不是底）。

## 6. 标签加图标字段，美术按现有标签出一套
**数据**：`TagDef` 加 `@export var icon: String = ""`——`assets/ui/tags/` 下的文件名（不含扩展名），**空 = 用 id**（现有 14 枚 `assets/ui/tags/<id>.png` 不用改数据就接上）。
- 导入器：`icon` 非空而文件不在 → 报错（和 171「没登记的标签报错」同一处）；空且 `assets/ui/tags/<id>.png` 不在 → 不报错（允许暂无图）。
- 标签制作器（`ui/tag_editor/`）加一栏「图标」：文本框 + 右边 24 px 预览（读得出就画，读不出写「无图」）。
- `TagRegistry.icon_path(id) -> String`：按上面的规则给路径，没图返回 `""`。`FaithTooltip.icon_paths` 改调它（现在是自己拼 `TAG_ICON_DIR + id`）。
- `tools/snapshot_content.sh` 跟着跑一遍（新字段进快照）。
- **这一步不改道具悬浮窗**：作者说的是「未来计划」把标签文字换成图标，等美术这套样出来、作者点头后，再由本线程写副行的版式（图标 + 悬停出名字 / 词条）。

**美术清单**（派给美术设计；玩家看得见、会进副行的标签 = 非内部、非来源类；来源类 工艺 / 自然 / 魔法 因献祭要用也要）：
- 已有 14 枚（188 A.4）：武器 防具 盾 装备 食物 宝石 金属 皮革 骨制品 血肉 战利品 火焰 + 工艺 自然。
- 还缺 **28** 枚（美术 20:40：已全部画好，样稿在美术设计线程）：
  - 用途：弹药 弓 晶石 信物 防具插件 特殊道具 材料 近战 零件 远程 试剂 遗物 药剂 法杖 建材 工具 珍宝
  - 属性：流血 赐福 附魔 毒
  - 材料：石材 木制
  - 归属：蛮族 信仰 帝国 符号
  - 来源：魔法
- 风格同已有 14 枚（圆形底、单色剪影），24 px 与 48 px 两档，交付 `/mnt/project-files/art/ui/tags/`，文件名 = 标签 id。

## 7. 狩猎之神：等级效果是「没做」，不是「没写」；顺手让所有已实装的能力都显示出来
**查到的**：`data/authoring/faiths/hunt.json` 里 **没有 `perks`**（只有信力来源与献祭），`docs/gods.md` 也记着「狩猎 / 技巧 / 新教：没有信仰级效果（按阶功能在长弓上）」——这是 104 落地作者表时的状态。狩猎之神现在实装的「按阶」能力只在**道具上**：
- 狩猎之神赐福的长弓 `faith_bonuses`：激活即 伤害 +4；**2 级** 伤害 ×1.15。
- 狩猎之神的护符：没有加成（只是信物）。
- 技巧之神同款：赐福的盾牌 激活即 格挡 +4；2 级 开战挂「弹开更久」。护符也没有加成。
所以信仰窗里狩猎之神没有「各级效果」一段，不是漏标注，是这位神确实没有信仰级 perk。要不要给狩猎 / 技巧补真正的等级效果是另一个设计题（本线程可以另出一份，等作者说）。

**这次做的（作者：「让所有已实装的能力标注」）**：信仰窗的「各级效果」段**把赐福道具的按阶加成也列进去**，每位神都一样：
- 来源：所有带 `faith:<id>` 标签、且 `faith_bonuses` 非空的道具定义（`ItemDatabase` 按标签筛）。
- 每条 `FaithBonus` 一行，归到它的 `tier`（没写 = 1 级，和 `mode: active` 同列 1 级），句子 = 「{道具名}：{效果}」，效果用 `ItemTooltip` 写信仰加成那一套文字（`Glossary.mods_text` / 规则句 / `note`），数字 `@val`。例：「Lv.1　狩猎之神赐福的长弓：伤害 +4」「Lv.2　狩猎之神赐福的长弓：伤害 ×1.15」。
- 和 perk 行同样的到 / 没到着色与 `[table=2]` 合并；没有 perk 也没有道具加成的神（新教）仍不出这一段。
- 这样「实装了但窗里不见」的就只剩代码写死的通用项：包内转化（3% + 每阶 1%）——也加一行到「信力来源」段后面：「每走一步，包里能被赐福的道具各有 N% 转化」（N 随阶，从 `convert_chance / convert_per_tier` 字段算）。
- 测试：`FaithTooltip.describe_full(hunt)` 的 sections 含「长弓」与「×1.15」；`church` 无各级效果段；`brute` 的 perk 行数不变、多出其赐福道具行。

## 8. 待定（默认按推荐）
1. **「步」字**（§2）——推荐 **甲**：保持「步」，只把休息点两条选项改成写总数；乙：全局改成作者卡上选的词。等卡。
2. **钉住延迟是否也管子窗**（§3.1）——推荐 **甲**：一视同仁；乙：只管主窗。
3. **狩猎 / 技巧要不要补真正的等级效果**（§7）——推荐 **先不补**，只把道具按阶加成列出来；作者要补再出设计稿。
4. **增益 / 受益图标**（§5）——推荐美术先出 3 套方向（放射 / 手 / 光环）各一对，作者挑一套再精修。

## 9. 改动清单与测试
| 文件 | 改什么 |
|---|---|
| `ui/ui_theme.gd` | `bright_text_theme()` 沿变体链取色、缺则不写；`build()` 给 `RichTextBody/Small` 与 `LabelHud*` 补默认字色 |
| `ui/inventory/hover_tip.gd` | `PIN_DELAY_SEC`、进度算式、`pin()`；`tick()` 开头每帧核对源（视图在不在 / 可见 / 道具还在 / 鼠标在格上）；`set_item` 空正文隐藏分隔线与正文 |
| `ui/inventory/item_tooltip.gd` | `lines` 为空时 `body = ""` |
| `ui/game/map_screen.gd` | 叠层打开 / 换屏时 `_tip.hide_tip()` |
| `core/run/faith/faith_tooltip.gd` | 献祭一行图标无字；各级效果段并入赐福道具的按阶加成；包内转化一行 |
| `core/inventory/tag_def.gd` / `tag_registry.gd` / 导入器 / `ui/tag_editor/` | `icon` 字段、`icon_path()`、校验、编辑器栏 |
| `ui/inventory/inventory_view.gd` / `drag_layer.gd` | 预览带手上这件的格位标记；棋盘外残影旁画未点亮态 |
| `core/text/text_template.gd` / `ui/game/event_screen.gd` / `data/authoring/events/rest_default.json` | `{rest_restore}` `{rest_total}`；两条选项文字 |
| `tests/ui/test_tooltip_193.gd`（新） | §1 / §3 的用例 |
| `tests/ui/test_drag_markers_193.gd`（新） | §4 |
| `tests/run/test_faith_tip_193.gd`（新） | §7 |
| `tests/run/test_rest_event_193.gd`（新） | §2：扎营回 `rest_restore + 1`、选项文字含总数 |
| `docs/architecture.md` | 悬浮窗一节：源核对、钉住延迟；标签 `icon` |

美术两件（§5 图标重做、§6 标签 27 枚）派给「美术设计」，样图到了作者在那边挑；代码侧不等它们。

## 补充一（2026-10-18 20:36，作者在选择卡上选了「改成「倒计时」」）

待定 1 定为 **乙**：凡是说**倒计时这口钟**的消耗与剩余，单位词从「步」换成「倒计时」；**走路的距离**仍然说「步」（「走一步」「离最近的休息点 3 步」「躲开猎手 N 步」是路程 / 回合数，不是钟）。判据：这个数是从 `CountdownModule` / `ActionClock` 读的，或者是扣进它的代价 → 说「倒计时」。

| 处 | 现在 | 改成 |
|---|---|---|
| `rest_default.json` 扎营 | 多耗 {pass_time_actions} 步，多回 1 点体力 | **倒计时 −{pass_time_actions}，回 {rest_total} 点体力** |
| `pass_time.describe()` | 耗 N 步 | 倒计时 −N |
| `event_cost_icons.gd:15` | 耗步 | 耗倒计时 |
| `event_screen.gd:105` / `map_screen.gd:397` | 耗了 N 步 / 原地耗了 N 步 | 倒计时 −N |
| `countdown_widget.gd:195` | 还剩 N 步（共 M 步） | **倒计时还剩 N（共 M）** |
| `countdown_widget.gd:202` / `:74` | 最近的撤离点还剩 N 步关闭 / 剩 N 步关闭 | 最近的撤离点倒计时剩 N 时关闭 / 倒计时剩 N 时关闭 |
| `node_tooltip._countdown_line` | 倒计时剩 N 时关闭（还有 M 步） | 倒计时剩 N 时关闭（还有 M） |
| `ui_text.gd` `notice.countdown` / `map_screen.gd:555` | 倒计时只剩 N 步 | 倒计时只剩 N |
| `map_screen.gd:663` 路线预览 | 计 N 步 | **倒计时 −N**（「熟门熟路：这一步不计」→「熟门熟路：这一步不扣倒计时」） |
| `travel_discount.gd` | 每走 N 步，下一步不计入倒计时 | 不动（已是倒计时的说法） |
| `encumbrance_rules.gd:77` / `encumbrance_widget.gd:20` | 走一步计 N 步 / 走一步花 N 倍 | 走一步倒计时 −N / 走一步倒计时扣 N 倍 |
| `glossary.gd` 寸步难行 | 每走一步计两步 | 每走一步倒计时 −2 |
| `setup_screen.gd:550` | N 步 | 倒计时 N |
| `field_text.gd` `step_limit` | 全局倒计时（步） | 全局倒计时 |
| 帮助页 `countdown_and_closing` / `map_and_steps` / `rest_point` / `vitality` / `encumbrance` 等 | 「多耗几步」「一局只能走这么多步」 | 按同一判据逐句改；路程句不动 |

**不改**（路程 / 回合数）：`distances_widget`「N 步」、`evade_skill`「躲开猎手 N 步」、技能「冷却 N 步」、`buffs_widget`「剩 N 步」（这几处是「再走几步」）、`result_screen`「走了 N 步」、`erosion_widget`「N 步后开始」、猎手行为。184 的「计二步签」纸签是美术图上的字，含义是路程倍数，不动。

- 单位词收进 `Glossary.COUNTDOWN_WORD := "倒计时"` 一处，上面各处拼句子用它；测试 `test_rest_event_193` 加一条：玩家可见的倒计时句子里不含「步」（对 `countdown_widget.tooltip_bbcode()`、`PassTime.describe()`、扎营选项文字断言）。
- 这一条随 193 一起落地。

## 10. 落地（2026-10-18，架构方案执行）

待定 1–4 按推荐，补充一（「倒计时」）同 PR 落地。和方案的出入：

- §4 手上这件的标记没有给 `set_preview` 加参数，而是另加 `InventoryView.set_held(def, rot)`（`DragLayer._update_preview` 每帧喂；拖的是包不画）；`clear_preview` 一并清掉。棋盘外的残影旁画未点亮态（`DragLayer._draw_held_markers`）。
- §7 信仰道具加成按 `items.ids_where(信仰标签 = 这位神 且 有 faith_bonuses)` 收；**赐福版合成一行「赐福的道具：…」**，不逐件列（逐件列会把狩猎神的窗撑到几十行）。包内转化一句挂在「事迹」段末尾，这位神没有赐福模板或概率 ≤ 0 不写。
- §3 献祭一行：图标之间空一格，规则之间用 8 号字的两个全角空格隔开；任何一条规则缺图标就整段退回文字（188 补充一的退路不变）。
- 补充一：`Glossary.COUNTDOWN_WORD` 一处，十几处拼句子都引用它（含 `UiText` 的 `notice.countdown` 与 `寸步难行` 词条）。「最近的撤离点倒计时剩 N 时关闭」/ 地图上的牌子 / 栏上的字，N 都改成**关闭时倒计时的读数**（`PaidExtracts.closes_at`），和节点浮窗一致；原来写的是「还有几步关」。地图牌子另收 `closing["at"]`。`CountdownModule.describe` 改成「走路、原地等待都扣它」。帮助页 6 张按判据逐句改，路程句不动。

测试：新增 `test_tooltip_193`、`test_drag_markers_193`、`test_faith_tip_193`、`test_rest_event_193`（含补充一：日规悬浮窗、栏上的字、`PassTime.describe`、扎营、代价提示、快没了的提醒都不含「步」）；`test_tooltip_170` / `test_feedback_1012` 的钉住时刻加 `PIN_DELAY_SEC`；`test_hud_189`、`test_screens_157`、`test_altar`、`test_brute_188b` 跟着新文字改。截图见 /mnt/project-files/screenshots/193/。

## 补充二（2026-10-18 21:21，作者在美术设计线程定的尺寸）

作者原话：「32像素，另外献祭栏里面不要名字，图标也要32像素」。据此改三处写法：

- **悬浮窗里的标签图标**（§6）：显示尺寸 **32 px**（`[img=32]`），不是 24；美术按 32 / 64 两档交付（`/mnt/project-files/art/ui/tags/`，文件名 = 标签 id）。
- **信仰献祭栏**（§3.4）：只放图标、不放名字（已定），图标也是 **32 px**，同一条规矩里间隔 4 px、规矩之间 16 px 不变。
- **增益 / 受益 / 装载格位图标**（§5）：§5 写的「格 48 px 时图标 20 px」不对，实际用的是 **40 px**（作者 21:37 看过 32 的试玩截图后说「放大一些」，由 32 改 40；新图已交付 `art/ui/tip/v3/`，v2 作废）；颜色按 `UiPalette`：增益蓝 `6fb3f0`、受益橙 `f0a85c`、装载紫 `7a8cf0`。两种叠在同一格时仍沿对角线错开，40 px 已超过格子（48）的一半，推荐错开量由 6 px 放到 8 px、允许图标压到格边（执行按实际效果定）。

美术已把两套图交给执行线程；执行落地时按本补充的尺寸接。

## 补充三（2026-10-18 21:37，作者在美术设计线程：「现在就改」）—— 道具悬浮窗的标签行换成图标

作者定：道具悬浮窗副行里的标签**现在就从文字换成 32 px 图标**，名字放进图标的悬停提示，和献祭栏（§3.4 / 补充二）一致。图标已在 `assets/ui/tags/`（PR #182，42 枚）；195 的 cloth / herb / clay 三枚在 `/mnt/project-files/art/ui/tags/`，随 195 一起接。

**改法（都在 `ui/inventory/item_tooltip.gd` 的 `describe_full`，副行那三行）**：

1. `sub` 的「 · 名字 · 名字」改成图标串：每个要列的标签 `t`（仍是 `TagRegistry.shown` → 按大类排 → 去掉来源类，不变）取 `TagRegistry.icon_path(t)`，有图就拼 `[url=term:tag:<id>][img=32]<path>[/img][/url]`，图标之间一个半角空格（4 px）；没图的标签退回今天的文字名（`[color=@tip_meta]名字[/color]`），所以 195 的三枚图标没接上之前织物 / 草药 / 陶瓷照旧显示文字，不会出空洞。稀有度名仍在最前，后面不再写「 · 」分隔，直接接图标。
2. **名字进悬停提示 = 复用关键词子窗**（`HoverTip` 的 `[url=term:<id>]` 机制，钉住后停 `TERM_SEC` 0.25 秒开子窗）：`terms` 字典给每个画成图标的标签加一条 `"tag:<id>": {"name": 标签显示名, "text": 登记了说明且 tip 为真的给 TagRegistry.describe(t)，否则空串, "style": "term"}`。子窗标题就是名字，有说明的照旧带说明 —— 今天 `Glossary.tag_terms(listed)` 靠在文字里找名字加下划线，换成图标后找不到字，所以改为直接按 id 加词条；`tag_terms` 对别处（商店、图鉴）仍可用，不删。
3. 子窗（`CHILD_WIDTH` 260）里只有一个名字时显得空：`HoverTip._open_child` 查到 `text` 为空的词条就按名字宽度收窄（`MIN_WIDTH` 220 以下，取名字宽 + 边距），不留大块空白。
4. 不动的：`_names()` 继续给「只收 ×× 标签」的包和别的文字句用；献祭栏已是图标行；标签制作器预览不变。

**待定（默认按推荐）**：
- 补 3.1 32 px 图标在 13 号字的副行里会把那一行撑高：推荐 **A** 图标另起一行（稀有度名一行、图标一行，行距 2 px），B 同一行接在稀有度名后。两者都 ≤ 360 宽；A 不挤名字。
- 补 3.2 没钉住时鼠标停在图标上要不要也出名字：推荐 **A 不出**（和关键词一致，钉住 0.5 秒后再停 0.25 秒），B 用 RichTextLabel 原生 `[img tooltip=…]`（4.7 支持）—— 原生提示是另一套样式，和 170 的悬浮窗风格不一致，先不用。

**测试**：`tests/ui/test_item_tooltip_*` 里断言副行含标签名字的那几条改成断言含 `[img=32]…/weapon.png` 与 `terms` 里有 `tag:weapon`；没图的标签（临时去掉一个 png 或用假标签）仍出文字名。

## 11. 补充二、补充三落地（2026-10-18，架构方案执行）

- **格位图标 40**：`assets/ui/tip/` 六张换成 v3。尺寸收进 `InventoryView.marker_side(cell)` = `minf(40, cell × 0.67)`，棋盘与拖拽残影（`DragLayer._draw_held_markers`）共用。棋盘格实际是 60 px（`InventoryView.CELL`），不是补充二写的 48，所以图标是 40。两枚叠在一格时，对角错开沿用原来的 lerp（两端各留 2 px），没有改成固定 8 px：格 60、图 40 时两枚已经错开 16 px。
- **悬浮窗标签图标**：`ItemTooltip.tag_icons(tags)` 拼图标行，`ItemTooltip.tag_icon_terms(tags)` 给每个画成图标的标签加一条 `tag:<id>` 词条。图标另起一行（待定 3.1 A），没钉住时不出名字（3.2 A）。没图的标签照写名字，仍走 `Glossary.tag_terms` 按文字找词条。
- **子窗收窄**：只写名字的子窗按名字宽收窄，最窄 40（`HoverTip.NAME_ONLY_MIN_WIDTH`），最宽仍是 `CHILD_WIDTH`。
- 195 的织物 / 草药 / 陶瓷三枚图标已随 PR #184 接上。
- 测试：新增 `test_tag_icons_193c.gd`。`test_text_and_tooltips`、`test_tooltip_170`、`test_author_096`、`test_keyword_tips` 里断言副行含标签名字、或数词条的几条，改成断言图标与 `tag:<id>` 词条（只写名字的标签词条不算「有说明的词条」）。截图在 `/mnt/project-files/screenshots/193c/`。
