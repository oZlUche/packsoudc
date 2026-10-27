# 258 三档字号：设置里选 小 / 中 / 大，全游戏跟着放大（主菜单除外）（架构方案）

作者 2026-10-26 20:55（小修线程，协调转来）：「整体游戏的字号都要调大一号，最好做一个可以在设置里面调整的选项，以目前为小号，再增加两个更大的版本」；20:57：「注意主菜单的字体不用改，其余的要改」。

## 一、现在字号是怎么定的（盘点）

| 哪里 | 现状 |
|---|---|
| 主题 | `UiTheme` 代码建主题，`FONT_SIZE := 14` 是默认字号（`ui_theme.gd:17`，`t.default_font_size` :1144）；`_fill` 里 22 处 `set_font_size`，常量 TITLE 18 / DISPLAY 40 / HERO_TITLE 128 / MENU_PRIMARY 44 / MENU_SECONDARY 34 / MENU_FOOT 18 / RICH_BODY 20 / RICH_SMALL 13 / HUD_LARGE 34 / HUD_DOUBLE 28 / OVERLAY_TITLE 20 / TENT_SIGN 22 / FLIP_NUM 72 / CAP_VALUE 28 / SKILL_NAME 22 / SKILL_TEXT 17 / SCREEN_TITLE 26 / HOME_BUTTON 20 / HOME_PRIMARY 28。主题只在背景色变时 `refresh`（:318） |
| 造控件的入口 | `UiTheme.label / rich / make_button / make_display / make_title_label / make_art_text_button / _dress_drop …` 都收一个字号参数，和变体默认不同时 `add_theme_font_size_override`；全游戏约 **191 处**传字面字号给这些入口 |
| 直接 override | 55 处 `add_theme_font_size_override(`：`ui_theme.gd` 11、编辑器（作者工具）约 19、`text_fit` 1、其余散在界面 |
| 富文本 | BBCode 里 `[font_size=N]` 18 处（`item_tooltip` 7、`faith_tooltip` 6、`glossary` 3、`countdown_widget`、`battle_view`）；所有富文本都经 `UiTheme.set_rich` → `UiPalette.toned()`（16 个调用点）这一个口 |
| 部件自带常量 | `Glossary` NAME 20 / KIND 14 / BODY 16；`ItemTooltip` NAME 20 / SUB 14 / DESC 15 / BODY 16 / FOOT 14；`FaithTooltip` META 14 / POWER 15；tip_button 14、price_tag 14、stone_chip 18、stone_stepper 18、ledger_rows 16、balance_scale 20、cat_key 22、notice_scroll 18、stone_field 16、title_plate 34、header_tag 16 / 18、stat_plaque 13 / 24、nameplate 20、recipe_scroll 28 / 18 |
| 场景文件 | 15 个 .tscn 没有一个写字号 |
| 缩放 | 视口 1600 × 1000，`stretch/mode = canvas_items`，窗口分辨率只是整体等比缩放；没有 `content_scale_factor`、没有 `UiTheme.scale`；主菜单自己有 `MainMenu.ui_scale()`（高 / 1080） |
| 定宽定高 | 作者定「面板尺寸不随内容变」：255 角色卡 `CARD_H 840`、三栏 312 / 536 / 608；悬浮窗 `MAX_WIDTH 360`；顶端栏 `BAR_HEIGHT 88`；战前铜面板 ≤ 884（v4.53）；事件文 560、百科页 760、科技卡 320、`BoardNine`。`TextFit.shrink_button` 已能把定宽键的字缩到放得下（只两处在用） |
| 字体 | 子集按**字**裁，不按字号（动态字体，不是 MSDF），放大不用重裁 |
| 护栏 | `test_theme` 的 ratchet：`add_theme_` 调用数 ≤ 130 |

## 二、方案：一个倍率，三个口，主菜单绕开

### 2.1 三档

| 档 | 倍率 | 14 → | 16 → | 20 → | 28 → |
|---|---|---|---|---|---|
| 小（现在） | 1.0 | 14 | 16 | 20 | 28 |
| 中 | 1.125 | 16 | 18 | 23 | 32 |
| 大 | 1.25 | 18 | 20 | 25 | 35 |

`UiTheme.sz(n: int) -> int = roundi(n * text_scale)`，最少 +1 / +2（小字号 13 → 15 / 16，不然 1.125 × 13 还是 15 取整后看不出）。**默认档 = 中**（作者「整体调大一号」），老存档没有这项时也按中。

### 2.2 三个口全部走倍率

1. **主题**：`_fill` 里每个 `set_font_size` 包一层 `sz()`；默认字号 `sz(FONT_SIZE)`。换档时调 `UiTheme.refresh()`（现成，背景色变时就走它）。
2. **入口函数**：`label / rich / make_button / make_display / make_title_label / make_art_text_button / _dress_drop / make_wrapped / rich_block …` 把传进来的字号先过 `sz()`，于是那 191 处字面字号**一行不改**就跟着变。`TextFit.shrink_button` 的 floor 也过 `sz()`，基准字号记在 meta 里的那份记未缩放的。
3. **富文本**：`UiPalette.toned()` 里把 `[font_size=N]` 的 N 过 `sz()`（一条正则，16 个调用点全覆盖）；`set_rich` 存的 `raw` 不变，换档后 `refresh_tones` 式地重跑一遍即可。

部件自带的 `FONT_SIZE` 常量在用处过 `sz()`（上表那十几个）；55 处直接 override 里，界面里的改成走入口函数（顺手减 ratchet），编辑器那 19 处不动（作者工具）。

### 2.3 主菜单除外

`MENU_PRIMARY / MENU_SECONDARY / MENU_FOOT / HERO_TITLE / HOME_BUTTON / HOME_PRIMARY` 不过 `sz()`；`make_menu_line / make_home_button / set_hero_size` 不缩放。主菜单继续用 `MainMenu.ui_scale()`。设置屏本身要跟着变（作者在那里切档，当场看到）。

### 2.4 设置项

`GameSettings.text_size: StringName = &"medium"`（`small / medium / large`），`to_dict / from_dict` 各一行，不升 `SAVE_VERSION`（和 `show_grid` 一样）。设置屏加一行「字号」：三枚 `StoneChip` 小 / 中 / 大（226 带入现金那一组的样式），当前档压下；切换即 `UiTheme.text_scale = …; UiTheme.refresh(); 当前屏重建`。设置屏之外的屏在下次进入时按新档建（不做活体重排，省得每个屏都写 `on_text_size_changed`）。

### 2.5 定宽面板怎么办（作者规矩：面板不随内容变）

字大了、盒子不变，只有两条路：**字缩回去**，或**盒子里的内容换排法**。规矩：

| 情况 | 做法 |
|---|---|
| 定宽键、美术字区（偷袭键 72 宽字区、退回键、石键、价签、蜡板数字） | 字号过 `sz()` 后交 `TextFit.shrink_button`，floor = 小档字号 → 放不下就缩回现在的大小。效果：这类键在中 / 大档**可能不变**，可接受（它们是一两个字） |
| 悬浮窗（不是面板，浮着） | `MAX_WIDTH` 360 → `sz(360)` = 405 / 450，高度本来随内容 |
| 定高卡：255 角色卡 840、战前铜面板 884、设置页二、结果页账目、百科页、事件文 560、科技卡 320 | 文字行多的用 `sz()`，然后**按档跑一遍现有的尺寸断言**（`test_character_select_255`、`test_unarmed_222`、`test_screens_157`）；超出的那几块逐个处理：先缩行距 / 内距，再给那一块的字号封顶 `sz(n, cap)`，最后才改排法。预计 大档 下角色卡（9 行）和百科页要封顶，其余放得下 —— 这是 批二 的活 |
| 顶端栏 88 高 | 栏内部件字号过 `sz()`，数字用 `TextFit` 缩回；栏不变高 |
| 棋盘上的字（道具名、角标） | 不变 —— 它们按格子画，不是界面文字 |

### 2.6 不做的

- 不用 `content_scale_factor` / 改视口：那是整体放大，面板、棋盘、美术全变，不是字号。
- 不重裁字体：动态字体放大不用重裁。
- 不给每个屏写活体重排。

## 三、改动清单（给执行，两批）

**批一（机制）**：`GameSettings.text_size` + 设置屏「字号」三枚石片；`UiTheme.text_scale / sz()`，`_fill` 与入口函数过 `sz()`（主菜单的几条除外），`refresh` 换档重建；`UiPalette.toned` 缩放 `[font_size=N]`；部件常量过 `sz()`；`TextFit` floor 过 `sz()`，键与美术字区接 `TextFit`；悬浮窗宽 `sz(360)`；默认 中。测试：`test_text_size_tiers`：三档各建一次主题，断言 default_font_size 与几个变体 = 表 2.1；主菜单字号三档相同；`toned("[font_size=16]x")` 在大档给 20。

**批二（定高面板适配）**：把 `test_character_select_255 / test_unarmed_222 / test_screens_157 / test_no_bare_text_226` 的尺寸断言在三档各跑一次（一个 `for tier in TIERS` 外环），红的逐块按 2.5 处理，记在落地记录里。

## 四、待定（默认按推荐）

1. 倍率 1.125 / 1.25（推荐）；备选 +2 / +4 像素（小字号涨得多、标题涨得少）。
2. 默认档 中（推荐，作者「整体调大一号」）；备选 小。
3. 换档只重建设置屏，别的屏下次进入生效（推荐）；备选 全屏活体重排。
4. 悬浮窗宽随档 405 / 450（推荐）；备选 固定 360、只长高。
5. 键与美术字区放不下就缩回小档（推荐）；备选 让美术按大档重出字区。

## 五、测试

见三。另：ratchet 不涨（入口函数内部的 override 不算新增调用点）；226 无裸字测试三档都绿。

## 六、作者定稿（2026-10-27 11:19）

作者：「字号就先这样实行，我需要到游戏里看实际效果再决定下一步」。方案原样实施，待定五项全按推荐（×1.125 / 1.25；默认 中；换档只重建设置屏；悬浮窗宽随档；键与美术字区放不下缩回小档）。11:20 派执行，排在 257 之后，批一、批二可分两个 PR。作者看过实际效果后的调整另记。
