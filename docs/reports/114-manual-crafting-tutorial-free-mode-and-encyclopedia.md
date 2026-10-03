# 114 · 方案：合成改「拖到上面立刻合」+ 序章一教合成；序章后只有自由模式；ESC 菜单里的百科

> 架构设计线程，2026-10-03。作者原话：「关于道具的合成，可以在序章的第一张地图里让玩家拿到毒药瓶和匕首后合成，目前是自动合成，我考虑改回拖动道具到上面后手动合成（或者保留两条途径），你来取舍抉择；增益和受益不用弹教程，可以只通过道具说明来展示。之后考虑添加一个百科全书类的说明，每个词条和行为都有专门的一页来解释，放在 ESC 菜单里」；
> 又：「序章结束后没有第一章了，只有自由模式」。
> 本文只做方案，不实施。文案一律走占位符（112），不写阿拉伯数字（TextLint 严格）。

## 一、合成：取舍 —— **只留手动，拖到上面立刻合**

### 1.1 现状与来历

| 版本 | 规则 | 结果 |
|---|---|---|
| 084 | 拖着 a 压到恰好一件 b 上、两件有配方 → **立刻合成**，产物落在 b 的位置（`DragLayer._craft_target` / `_craft_into`） | 作者定「合成不是立刻的」 |
| 085 | 拖到一起只**配对**（`RunState.queue_craft`），走到下一个点才合，配对跟存档 | 多了一步「配对」，棋盘上画「合」 |
| 087（现行） | **相邻即合**：棋盘上两件有配方的四邻相接，走到下一个点自动合成（`CraftingModule.pairs` / `resolve`），拖拽层只留「能合的亮一圈」 | 不用动手，但见下面三条 |

现行规则的问题（都是设计层的，不是 bug）：

1. **「相邻」已经有含义**：增益槽 / 受益槽靠相邻起效。把毒药瓶放在匕首旁边想吃槽加成、或只是没位置了挨着放，走一步就被合掉 —— 玩家没下决定，东西却变了。毒药瓶自己会慢毒，单独带着是合法打法。
2. **延迟到下一个点**：合成发生在玩家不看棋盘的时候，只有一行日志和一个结果屏；教程里「看见它变成涂毒匕首」这一下最有价值，却发生在屏幕外。
3. **教程讲不清**：现在要讲「挨着放、走到下一个点、装不下进暂存区」三件事（`tut2_search_2_again_1` 一大段），而「把 A 拖到 B 上」一句话就够，也是同类游戏的通用手势。

「保留两条途径」没有解决第 1 条（相邻误合照样发生），还要同时维护两套规则、两套文案与测试。所以取舍：**手动唯一，立刻生效**；配方、产物落位、装不下进暂存区这些规则一条不变。

### 1.2 规则（作者确认后进架构文档 7.4）

- **怎么合**：拖着一件道具，放到棋盘上另一件上面，正好只压着这一件、两件有配方 → 两件消失，产物立刻出现在被压那件的位置（沿用它的朝向）。放不下试自动找位，再不行进暂存区并提示。只在**一局里**（整理面板、战前准备、事件屏的整理）；基地的仓库 / 开局屏不合成（合成是局内行为，产物是局内获得）。
- **预览**：拖着时压到能合的那件上，预览格画成绿色（084 原样），不是红色顶替；拿起一件时能和它合成的那几件亮一圈（现有 `_highlight_partners`，保留）。
- **暂存区里的那件**不能当被压的一方（列表没有坐标）；把它拖到棋盘上那件上面就行。
- **不再有**：相邻自动合成、「合」记号、「挨在一起：走到下一个点时合成」提示、到点结算。`CraftingModule.to_dict()` 本来就是空，存档不变、不升版本。
- **词条**「合成」改成：「把一件道具拖到另一件上面，两件有配方就立刻合成一件新的；装不下就进暂存区。」配方 `poisoned_knife.note` 已经写的是「把毒药瓶拖到匕首上」，不用动。

### 1.3 改动点

| 层 | 改 |
|---|---|
| `CraftingModule` | 删 `pairs` / `partner_of` / `resolve` / `_on_arrived`；加 `craft(a: ItemInstance, b_uid: int) -> Dictionary`（`{ok, output, where, log}`：拆下 b、放产物、找位、进暂存区、发 `done`）。`output_of` 不动。信号 `done(node_id, detail)` 改成 `done(detail)` |
| `DragLayer` | 恢复 084 的 `_craft_target(inv, origin)`（正好压着一件、`craft` 给出产物）与绿预览；放下时 `place` 失败 → 先问 `_craft_target`，有就调新的 `craft_drop: Callable`（`func(a, b_uid) -> bool`，整理面板接到 `CraftingModule.craft`），成了算 dropped；没有 `craft_drop` 的地方（沙盒 / 开局屏）走原来的顶替。拖拽层仍然不认识配方 |
| `InventoryPanel` | 删 `_refresh_badges` / `_pair_keys` / `board_view.badges` 的「合」；接 `craft_drop`；`done` 来了 `_hint_text` 产物名 |
| `MapScreen` | `done` 的日志行照写（签名变） |
| `Glossary.TERMS["合成"]` | 文字按 1.2 |
| 文案 | 见二；`prologue_2.rules[1]` 的「挨着放会合成」→「拖到一起会合成」 |
| 测试 | `test_tutorial2.run_crafting_adjacent` → `run_crafting_drop`（压上去立刻合、产物在 b 的位置、装不下进暂存区、`done` 一次、不挨着 / 挨着都**不**自动合）；`run_crafting_drag` 改成「压到有配方的那件上 = 合成，不是顶替；压到没配方的 = 顶替」。`test_run_modules` 的模块 id 清单不变 |
| 架构文档 | 7.4 模块表 `CraftingModule` 一行改「拖到上面立刻合」；版本记录加一条 |

## 二、序章一教合成（匕首 + 毒药瓶 → 涂毒匕首）

### 2.1 为什么放这里合适

序章一的精英「守卫」在节点内容里写的是 `armor: 3`（`data/maps/prologue.json` 点 4），而中毒**无视防护与护盾**（106 / 107 作者定）。让玩家在打守卫之前手里有一把涂毒匕首，教的就不只是「怎么合」，还有「为什么合」—— 和序章二的「护符结界用毒打」一脉相承。

### 2.2 道具从哪儿来（不加新道具）

| 点 | 现在 | 改 |
|---|---|---|
| 点 2 战斗（拾荒者，身上 `bag_small` + `knife`） | 掉落按标准掉落表 | 节点内容加 `"guaranteed_drops": ["knife"]`（084 已有的字段，只能掉它身上有的；执行时确认 `DropResolver` 对战斗点也读它，若只对 `encounter` 读就补一行） |
| 点 3 搜索 第一次 | `["scimitar"]` | `["scimitar", "poison_vial"]` |

匕首与毒药瓶都是一格，布鲁图斯两个皮包够放；产物涂毒匕首也是一格，不会出现「装不下进暂存区」—— 那一条规则留给词条和百科，序章不讲。

### 2.3 文案（占位符；全部无数字）

| 事件 | 改 |
|---|---|
| `tut_battle`（战斗胜利后没有结果事件，用战利品屏） | 不改。匕首会出现在战利品里；下一条事件再提它 |
| `tut_search_2_again_1`「还有」 | 「翻出一把{item:scimitar}和一个{item:poison_vial}。{item:poison_vial}自己也能下毒，只是慢。{c:good}把它拖到{item:knife}上面{/c}，两件立刻合成一把{item:poisoned_knife}：借{item:knife}的快手，一刀一层毒。毒{b}无视防护和护盾{/b} —— 前面那个守卫披着甲，正好用它。\n\n下面还压着东西，再翻一次。」 |
| `tut_elite`「守卫」 | 末尾加一句：「它披着甲，普通刀剑每下都要被削掉一截；{item:poisoned_knife}的毒不看这个。」选项「进入战前准备」加门禁（见 2.4） |
| `prologue.rules`（本图规则卡，现在没有） | 加三条：「只有包里的东西参战，{zone:暂存区}里的留在这个点。」「{item:poison_vial}拖到{item:knife}上面，立刻合成{item:poisoned_knife}。」「打输了扣体力，体力归零这一局就结束。」 |
| `tut2_search_2_again_1`（序章二） | 缩成：「一个{item:poison_vial}。上一张合过一次：拖到{item:knife}上面就是{item:poisoned_knife}，毒不看护盾。\n\n再搜一次。」 |
| `prologue_2.rules[1]` | 「搜到的护具装不下两件，按对手挑一件；{item:poison_vial}拖到{item:knife}上会合成。」 |

### 2.4 门禁（与序章三一致）

`tut_elite` 的选项「进入战前准备」加条件 `has_item: poisoned_knife`，并写 `hint_when_hidden`（113 新增的字段）：「先把{item:poison_vial}拖到{item:knife}上面合成{item:poisoned_knife}」。按 113 的实现，条件不满足时选项灰显并带这句提示，玩家按 B 整理背包后回来就能走。`has_item` 现有语义若只查棋盘，这里要**棋盘或暂存区都算**（玩家可能把涂毒匕首先放在暂存区）—— 执行时看 `has_item.gd`，不够就加 `anywhere: true`。

不做强制失败、不做「没合成不让走」以外的门。

### 2.5 测试

`tests/run/test_prologue.gd`（若没有就新建）：走到点 2 打赢 → 战利品里有 `knife`；点 3 第一次搜到 `scimitar` + `poison_vial`；不合成时 `tut_elite` 的真选项隐藏、提示在；把毒药瓶拖到匕首上 → 棋盘上只剩 `poisoned_knife`、在匕首原位；选项亮；守卫 `armor` 不减毒伤（现有 `DamageResolver` 断言复用）。

## 三、增益槽 / 受益槽：作者定**不弹教程**

只靠道具说明：`ItemTooltip` 已有「增益槽 ×n：给站在那儿的邻居…」「受益槽 ×n：每点亮一格…」两行，词条「增益槽」「受益槽」照弹（107，`tip = true`）。112 第四节「欠缺」里这一项标为「作者定不教，靠悬浮窗」；百科（五）给它一页。不加事件、不加门禁。

## 四、序章之后只有自由模式

### 4.1 现状

`chapters/chapter_01.json`「第一章（占位）」：`order 3`、`requires_unlock: prologue3_done`、同心环随机图（三档规模）、过开局屏（挑角色、带入、规模）。`GameFlow.new_run_target` 教程全通后：能选的章只剩一章且 `skip_setup` 才直接开，否则进开局屏 —— 现在就是进开局屏、章节栏里只有「第一章（占位）」。

### 4.2 改

| 项 | 改 |
|---|---|
| 章节 | `chapter_01.json` → `free_mode.json`：`id: free_mode`，`display_name: 自由模式`（en: Free Mode），其余字段不动（随机图、三档规模、开局屏、带入）。`rules` 加三条给规则卡（承接 113 第 107 行「欠缺交第一章规则卡」）：「地图随机，每一局都不同；撤离点会按步数关闭，留意倒计时。」「商店买卖、保险箱、休息点都在地图上，停上去看浮窗。」「看不懂的词，暂停菜单（Esc）里的{ui:百科}都有一页。」 |
| 别名 | `IdAliases` 加 `chapter_01 → free_mode`（098 的内容层别名：旧局内存档的 `chapter` 还读得到） |
| 开局屏 | 左栏标题「章节」→「模式」；只有一项时照样列（将来加章再长） |
| 文案 | `tut3_extract` 末句「正式局里慢慢攒」→「{ui:自由模式}里慢慢攒」；`ChapterDef` 的注释「序章 0、第一章 1」改掉 |
| 测试 | `test_node_screens` / `test_text_and_tooltips` / `test_feedback_109` / `test_chapter_pipeline` 里的 `chapter_01` 改 `free_mode`，并加一条：教程全通后 `new_run_target()` 为 null、`available_chapters()` 只有 `free_mode` |
| 文档 | 架构文档 8.6「序章通关解锁第一章」→「解锁自由模式」；113 第 107 行的「第一章的规则卡」→「自由模式规则卡与百科」 |

代码里「第一章的同心环地图」一类历史注释不改（说的是生成器）。

## 五、百科：ESC 菜单里「每个词条和行为一页」

### 5.1 定位

**图鉴**（基地，089）管道具；**词条侧窗**（087）管「此刻停着的这件」；**百科**管「这个游戏的所有名词和行为」，离开上下文也能查。107 关掉 `tip` 时就留了话：「说明文字一字不动：编辑器的词典、文档、将来的帮助页照用」—— 百科就是那个帮助页。

### 5.2 入口与导航

- 暂停菜单（`MapScreen.toggle_pause`）加按钮「百科」，和「设置」同款嵌法（`pause_settings` / `close_pause_settings`：屏嵌进遮罩，`back` 回暂停菜单，Esc 先关百科）。主菜单加「百科」（`UiText menu.encyclopedia`，MINOR 档）。基地屏不加（图鉴在那儿）。
- 新屏 `ui/game/encyclopedia_screen.gd`（`GameFlow.Screen.ENCYCLOPEDIA`）：左栏搜索框 + 按分类折叠的目录；右栏一页。页里标了色的词是**链接**（`[url=term:<名>]`，`RichTextLabel.meta_clicked` 跳页），不是悬浮窗 —— 百科里点开比悬浮稳。顶部「← 返回上一页」记一条浏览栈。
- 打开时可带 `payload = {"page": id}` 直接定位（将来悬浮窗侧窗加「右键 → 百科」用它；本方案不做那个入口）。

### 5.3 内容：两类页

**A. 机制页（手写内容，新内容种类）** —— 作者说的「行为」。

- 新种类 `help_pages`：`data/authoring/help/*.json` → `data/help/*.tres`，`HelpPageDef { id, title, titles{}, category, order, text, texts{}, related: [页 id 或词条名], see_items: [道具 id] }`。`text` 走 `TextTemplate.render`（占位符、样式码、`{item:…}` 上色）与 `Glossary.mark`；`ContentPaths.ORDER` 加 `help_pages`（照 110 加 `techs` 的路：`content_paths` / `content_check` / `import_content` / `normalize_content` / `game_flow` 装载）。
- 分类与首批页（约二十五页，文字从现有教程事件、词条文字与 `describe()` 整理，不新编规则）：
  - **流程**：地图与走步、搜索点、战斗与战前准备、暂存区、撤离与失败、体力、结算与仓库
  - **背包**：拖放与旋转、包、双击快速置入、整理、**合成**（按一）、**增益槽与受益槽**（按三）、信物与右键
  - **战斗规则**：自动战斗怎么跑、直接伤害与防护、护盾、buff 与叠层、耐力与冷却、急速、乘区（增伤 / 物理 / 元素 / 急速）
  - **信仰**：信物与激活、信力与阶、神坛献祭、特殊操作、切换与休眠、各神一页（从 `FaithDef` 生成行为 / 阈值 / 奉献 / 效果表 —— `docs/gods.md` 那套 describe 已有）
  - **地图**：节点类型、随机点、商店、休息点、保险箱、倒计时与撤离点关闭、猎手、侵蚀
  - **局外**：仓库、科技（110）、图鉴、成就、存档位
- 113 第 107 行列的欠缺（耐力、邻接格、商店、保险箱、倒计时、基地、回放操作）每项一页，就此收口。

**B. 词条页（自动生成，不写内容）**

| 来源 | 页 | 文字 |
|---|---|---|
| `Glossary.TERMS` 全部（含 `tip = false` 的） | 每词一页 | `term_text` |
| `TagRegistry.ids()` 里非 `internal` 的 | 每标签一页 | `describe`；没说明的只列名字与「带这个标签的道具」 |
| `DamageTypes` | 每类型一页 | 名字 + 直接 / 间接形态说明（107 表） |
| 全部 `BuffDef`（`load_all`） | 每 buff 一页 | `Glossary.describe_buff`，加「来自：」—— 扫 `ItemDatabase` 用 `buffs_in_item` 找出带它的道具 |
| `STAT_NAMES` / `CATEGORY_NAMES` / `TRIGGER_NAMES` | 每项一页 | 现有名字 + 一句（词条里已有的复用，没有的补进 `Glossary` 常量，不另开表） |

词条页和机制页同一张目录，分类「词条」下再按来源分组。搜索按标题与正文子串。

### 5.4 可见性

全部页**始终可见**（规则不是剧透）。唯一遮的是道具名：页里的「相关道具」只报图鉴点亮过的（`MetaState.codex_lit`），没点亮的写「？」。

### 5.5 校验与测试

- 导入器：`help_pages` 的 id 唯一、`category` 在固定清单内、`related` 指到的页 / 词条存在、`see_items` 是真道具 id、占位符合法（112 的检查）、TextLint 无数字。
- `tests/ui/test_encyclopedia.gd`：每一页 `render` 后没有剩下的 `{…}`；`Glossary.TERMS` 每词都有页；每个 `BuffDef` 都有页；点一个 `[url=term:…]` 跳到对应页、返回栈回得去；暂停菜单嵌入与 Esc 顺序（先关百科再关暂停）；主菜单按钮在。
- `test_keyword_tips.LOUD_TERMS` 不动（百科不改弹不弹）。

## 六、待定（按推荐即执行）

| # | 事 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 合成途径 | 只手动 / 两条都留 | **只手动，立刻合**（一 1.1） |
| 2 | 序章一精英战门禁 | 门禁 + 提示 / 只在文案里提 | **门禁 + `hint_when_hidden`**（与序章三一致） |
| 3 | 自由模式的章节 id | 改 `free_mode` + 别名 / 只改显示名 | **改 id + `IdAliases`** |
| 4 | 百科页可见性 | 全可见 / 见过才有 | **全可见，道具名按图鉴遮** |
| 5 | 百科的词条页 | 自动生成 / 全部手写 | **自动生成**（文字改了跟着改） |

## 七、执行拆分

| 批 | 内容 | 大小 |
|---|---|---|
| ① 合成 | `CraftingModule.craft`、`DragLayer` 恢复绿预览与 `craft_drop`、`InventoryPanel` / `MapScreen`、词条、`test_tutorial2` 两段重写 | 中 |
| ② 序章 | 序章一地图两处、四条文案、规则卡、门禁、`test_prologue`；序章二两条文案 | 小 |
| ③ 自由模式 | 改名 + 别名 + 开局屏标题 + 规则卡 + 四个测试 + 文档 | 小 |
| ④ 百科 | `HelpPageDef` 内容种类、生成的词条页、`EncyclopediaScreen`、两个入口、首批约二十五页、导入器校验、测试 | 大（可单独一个 PR） |
| ⑤ 收口 | README、112 第四节标注、113 第 107 行、架构文档 7.4 / 8.6 | 小 |

①②③ 一个 PR，④ 一个 PR。
