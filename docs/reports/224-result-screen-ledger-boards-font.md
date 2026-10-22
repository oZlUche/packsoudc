# 结算屏四件事：按钮换图、第二页棋盘与仓库格线、第一页逐行账单、大数字体（224）

> 架构 thread，2026-10-21。作者 14:41–14:42 四条 + 一条：①结算界面还有按钮需要替换成 UI；②第二页也要有棋盘；③第一页加击败敌人数、经过节点数等，逐行显示（类似杀戮尖塔），点一下全显，将来接经验值，先留空占位，先头脑风暴排版；④第一页数字字体不契合美术风格，给几个方案；⑤仓库界面的棋盘也要横竖格子线。
> 排版稿 + 字体样张：https://claude.ai/artifact/VCp1EERooHfgheYC9Q4d6D 。截图存在 `/mnt/project-files/art/ui/result/ref/`。

## 一、按钮换图（→ UI替换美术）

结算屏还是平板按钮：第一页「继续」（橙色整条）、第二页「一键置入」「整理」（深色小块）和「继续」、序章之间的「进入下一张：X」。交 UI替换美术 出样：主按钮一条（宽 720 高 96）、次按钮两枚（约 150×56），风格照战利品屏「全部拾取」（火漆 + 羊皮签）那一路或基地的木牌主钮（`home/btn_wood_primary`），由美术定；中英各一份文字或图上无字（字由代码写）。代码侧只换 `UiTheme` 的变体贴图，不动流程。

## 二、棋盘：第二页带回来的棋盘加框，仓库棋盘加格线

现状（查过）：

- 第二页左边「带回来的背包」是一块不画包的 `InventoryView`，没有框；仓库分页也只有一块棕底。
- 187 把格线改成「有道具图时默认不画」（`GameSettings.show_grid = GRID_AUTO`），拖着东西时按半透明临时画。所以仓库、带回来的棋盘都没有横竖线 —— 不是漏画，是全局开关。

改法：

1. `InventoryView` 加一个每块视图自己的 `grid_mode`：`FOLLOW_SETTING`（默认，照 187）/ `ALWAYS`。仓库分页（结算屏与基地「家」页共用 `WarehousePanel`）、带回来的棋盘、保险箱格子设 `ALWAYS`。格线颜色按底色来：棕色仓库底上用浅色细线（1 px，约三成半透明），不再用深色 `COLOR_GRID`。
2. 第二页带回来的棋盘套**皮带框**（`frame_player`，和搜索 / 战利品屏左棋盘同一张九宫格，格 60），格线照 1。仓库分页要不要外框由 UI替换美术 看着给（棕底已有木纹边，可能只要格线）。
3. 作者 14:42 的截图里仓库是 10×8 格、棕底：格线铺在棕底之上、道具之下。

## 三、第一页：逐行账单

### 3.1 排版（见稿）

标题区照旧（「撤离成功」+ 章节 · 结局），下面一张 **720×440 的账单**（蜡板或羊皮纸，待美术），十行 + 表头，三列：项目 | 数量 | 经验（占位）。最后一行「总价值」加粗放大，是整页的落点。原来的三块大数（总价值 / 图鉴新点亮 / 带出金币）**并进账单**，不再单独摆；「背出来 N 件、保险箱 N 件」和「地上出售」两行小字照旧在账单下。「继续」钉在页底。

### 3.2 行

| 行 | 数据 | 现在有没有 |
|---|---|---|
| 走过的点 | `RunResult.visited` | 有 |
| 走了多少步 | `RunResult.steps` | 有 |
| 击败的敌人 | `tally.battles_won`（一场一个对手） | 有 |
| 其中精英 / 首领 | 新计数 `tally.elite_won` / `tally.boss_won`（按点类型记） | **新** |
| 打输的仗 | `tally.battles_lost` | 有 |
| 翻过的搜索点 · 合成 | 新计数 `tally.searches` / `tally.crafts` | **新** |
| 图鉴新点亮 | `absorb` 返回的 `lit` | 有 |
| 带出金币 | `RunResult.balance` | 有 |
| 保险箱带出 | `safe_items.size()`（战败时也有） | 有 |
| **总价值** | `value + safe_value` | 有 |

经验列：每行一个 `xp` 槽位，现在都画「—」；表头写「经验」。将来经验值系统给每行一个数、底行合计，不改排版。战败时同一张账单，只是总价值为零、带出金币为零，「保险箱带出」照写。

### 3.3 逐行显出

- 进屏 0.4 秒后第一行出现，之后每 0.35 秒一行；数字 0.3 秒内从零滚到实值（等宽数字，右对齐）。
- 点屏幕任意处或按任意键：剩下的行立刻全显、数字直接到位。
- 全显之后「继续」才可点（之前半透明），避免还没看完就点走。
- 这一屏的 `numbers()`（测试读的名 → 标签）保留，加 `rows()`；`reveal_all()` 给测试直接调。
- 回放 / 重看结算（序章之间连打）同一套，不记「看过」。

## 四、第一页大数的字体（四案，样张在稿里）

现在的大数用马善政（毛笔书写体，`FONT_DISPLAY`），和石板、铜币、宋体正文不搭。

| 案 | 字体 | 代价 | 评 |
|---|---|---|---|
| 甲 | 思源宋体 Bold（`serif_bold.otf`，已打包） | 零 | 和正文、火漆签同源，最稳，不出彩 |
| 乙 | 朱雀仿宋（`zhuque_fangsong.ttf`，标题字，已打包） | 零 | 和「撤离成功」同字，整页两种字；网页预览不了，游戏里切一行就能看 |
| **丙** | **Cinzel**（罗马碑刻体，OFL） | 新增一个只含数字 + 罗马数字约二十个字形的小字体 | **推荐**：按图拉真柱碑文设计，数字像刻在石上，和钱币肖像、罗马数字倍速钮一个世界；只用于大数、罗马数字 |
| 丁 | EB Garamond 老式数字（OFL） | 同丙 | 文艺复兴账本味，和羊皮纸亲，偏书卷不偏石刻 |

不管选哪个，`FONT_DISPLAY` 整体换掉：火漆签大字、倍速罗马数字、开局屏翻页计数器都跟着（现在也都是马善政）。马善政若再无处使用就从打包里去掉（168 的子集化顺带）。

## 五、改动范围（作者点头后派执行；①的图等 UI替换美术）

| 文件 | 改什么 |
|---|---|
| `ui/inventory/inventory_view.gd` | `grid_mode`；浅色格线 |
| `ui/game/warehouse_panel.gd`、`warehouse_pages.gd` | 仓库分页与带回来的棋盘 `ALWAYS` + 皮带框 |
| `core/run/run_state.gd`、`run_result.gd` | `tally` 加 `elite_won` / `boss_won` / `searches` / `crafts`，存档兼容（缺省 0） |
| `ui/game/result_screen.gd` | 第一页改账单（`LedgerView` 新件，逐行显出、点击全显、经验占位列）；大数字体换 |
| `ui/ui_palette.gd`、`assets/fonts/` | `FONT_DISPLAY` 按选的案换；新字体走 168 子集化流程 |
| `core/text/ui_text.gd` | 账单行名中英 |
| 测试 | `test_result_177`：行集合与数值、`reveal_all` 后全显、「继续」在全显前不可点、战败账单；`test_warehouse_*`：格线 ALWAYS；字体覆盖测试照 168 |

## 六、待作者定

1. 大数字体：甲 / 乙 / **丙（推荐）** / 丁。
2. 三块大数并进账单（推荐）还是账单之上仍保留三块大数。
3. 账单十行就这十行（推荐）还是增减。

## 七、补充一：作者定稿（2026-10-21 15:02）

作者：「背出来 27 件、保险箱 2 件 / 地上还有 3 件没背出来：离开这一屏时一键出售，得 40 币 —— 带出东西的数量显示在列表里就行，还可以加上最高稀有度，这种文本不用显示，而且地上的怎么可能出售呢。字体按推荐来，尤其是在需要和美术风格结合时。」

### 7.1 账单改成十一行，两行小字去掉

| 行 | 数据 |
|---|---|
| 走过的点 | `visited` |
| 走了多少步 | `steps` |
| 击败的敌人 | `tally.battles_won` |
| 其中精英 / 首领 | `tally.elite_won` / `boss_won`（新） |
| 打输的仗 | `tally.battles_lost` |
| 翻过的搜索点 · 合成 | `tally.searches` / `crafts`（新） |
| 图鉴新点亮 | `lit` |
| 带出的东西 | 「27 件 · 保险箱 2 件」（`carried.size()` / `safe_items.size()`；保险箱为零就只写前半） |
| 最高稀有度 | 带出 + 保险箱里最高的那档，写稀有度名、用稀有度色（`UiPalette.rarity_color`）；什么都没带出写「—」 |
| 带出金币 | `balance` |
| **总价值** | `value + safe_value`，放大 |

账单 720×**480**（表头 + 十一行 × 40），y 190 → 670；原「背出来 N 件、保险箱 N 件」和「地上出售」两行小字**删掉**；「继续」仍钉在页底。经验列照旧占位。战败时同一张账单：带出的东西只有保险箱那半句，最高稀有度按保险箱算。

### 7.2 「地上出售」撤销（092 那条作废）

作者问「地上的怎么可能出售」。现在的机制是 092 定的：撤离时地上（`state.storage`，一局里的临时摆放区）剩下的东西，离开结算屏时按基地出售比例一键卖掉、钱进局外，结算屏先提示一句。按作者今天的意思改回 3.4 的本义：**地上的东西撤离时就没了，不卖、不提示、不给钱。**

- 删：`UiText` `result.ground_sale`、`result_screen` 的 `_stash_line`；`GameFlow.stash_sale_preview()` / `_sell_left_behind()`（`finish_result` 和另一处调用一起删）；`MetaState.left_behind_preview()` / `sell_left_behind()`；`last_absorbed["stash_sold"]` 与 `meta_screen` 收到 `stash_sold` 后那句提示。
- `RunResult.left_behind` / `left_value` / `left_items` 只剩这一个用途，可一并删（`to_dict` 里两个键删掉；旧存档多出来的键照旧忽略）。
- 测试：`test_result_177` / 092 相关的「一键出售」用例改成「地上的东西不进仓库也不进钱」。

### 7.3 字体：丙 Cinzel

`FONT_DISPLAY` 换成 Cinzel Bold（OFL），按 168 的流程只子集化：阿拉伯数字十个、罗马数字用到的 I V X、`+ − % / · —` 和空格。火漆签大字、倍速罗马数字、翻页计数器、账单数值一起换；汉字一律不走 `FONT_DISPLAY`（它本来就只画数字）。马善政字体文件留着给 `mashanzheng` 别处若还有引用，没有就删。

### 7.4 派执行

②③④（棋盘格线与皮带框、账单、字体）现在做；①按钮等 UI替换美术 的图；账单底（720×480 蜡板或羊皮纸）已向美术设计要，图没到之前先用现有石板色块占位，图到了换一行。§六 三条全按推荐。

**账单底已出（美术设计 15:11）**：三款样稿 甲 碑板（推荐）/ 乙 账簿 / 丙 蜡板，在 `/mnt/project-files/art/ui/ledger/`（README、`out/ledger_<stele|book|wax>.png` + @2x + json、`out/layout.json`、`mocks/page_*.png`）。整图不拉伸，图比账面大（框 / 耳朵 / 阴影在外），图左上 = 账面左上 + origin（碑板改版后 (−32, −32)，图 784×544；账簿 (−22, −22)、蜡板 (−18, −18)）；行间线、表头双线、合计双线、分栏线 x 300 / 600 都在图里，代码不画线。字：标签 x 18 思源宋体 18 基线 +27；数量右对齐 x 584 Cinzel Bold 20 基线 +28，串里的汉字退回思源宋体；经验右对齐 x 704「—」16 dim；表头 14 基线 26；总价值标签思源粗体 22 基线 +29、数字 Cinzel Bold 32 基线 +33；三款字色各一套在 layout.json。Cinzel ttf 在 `/mnt/project-files/art/fonts/chosen/`（来源 `Cinzel_SOURCE.txt`），打包时另补 `assets/fonts/LICENSES/OFL_Cinzel.txt`。材质按作者 15:02 的规矩（美术风格的选择按推荐）默认 **甲 碑板**，作者另选再换图。

**稀有度行的颜色（作者 15:23）**：「代表稀有度的字体要有颜色，和稀有度本身对应，颜色要足够显眼但不跳脱」。做法：稀有度名用 `UiPalette.rarity_color(r, tone)`（`data/authoring/ui/text_colors.json` 的六档，dark / light 两套，tone 跟账单底走），serif_bold 18；美术设计把六档放到碑板 / 账簿 / 蜡板三款底上核一遍，暗的提亮、扎眼的压一压，改在 `text_colors.json` 里（全游戏的稀有度字色一起受益），执行只照表取色、不另写颜色。

**§二 被更大的规矩盖过（作者 2026-10-21 15:19，在 UI替换美术 线程定）**：所有棋盘都显示外框和格线，新出现的棋盘视图默认 `frame_*` + `cell_seams`，格线常开。于是不必按视图开 `ALWAYS`：`InventoryView` 格线一律画，187 的 `GameSettings.show_grid` / `GRID_AUTO` 失去意义（执行定是删掉设置项还是只把默认改成常开；玩家设置里不再露这一项）。结算屏第二页的按钮和格线定稿在 `/mnt/project-files/art/ui/result/`，战前 / 战斗屏的属性签与生命耐力条在 `/mnt/project-files/art/ui/battle_stats/`，都已交执行。

**甲 碑板改版（美术设计 15:32，作者 15:23 在美术设计线程要「更有大理石味，参考《凯撒大帝 3》」）**：暖米色大理石，外框凸起、账面凹下，表头与合计是两条凸起石条，铜线铜钉和耳朵都去了；图 784×544，origin (−32, −32)；表头字 serif_bold 15 墨色（`styles.stele.head_font`），字色 数字 / 表头 `#16110d`、标签 `#2e2219`、dim `#6e604c`、总价值 `#8c2b22`。账面 720×480、行栏字号不变；文件名不变。凯撒 3 记进了 `art/style-guide.md` 的参考对象。

**稀有度六色核完（美术设计 15:38）**：改的是 `data/authoring/ui/text_colors.json` 的 `rarity`，账单不另配。新六对（0..5）：light `#525862 #186521 #1b56a4 #842ca7 #7c4d00 #a8221b`，dark `#d8dce3 #5fa85f #5598e6 #bd7bde #e0b040 #ee6253`（`/mnt/project-files/art/ui/ledger/rarity/rarity_colors.json`，并排图 `rarity_compare.png`，逐档理由同目录 README）。改动理由：浅版 0 普通由墨色改冷石板灰（原来和标签分不开）、4 传说由橄榄绿挪到琥珀金、5 神话避开甲款总价值的朱红；深版 2 / 3 / 5 在蜡板上提亮，深版 5 在 PANEL 上从 4.04 提到 5.40（原来唯一会触发 TextColorCheck 警告的一档）。对比度：浅版在 PAPER ≥ 6.2、在甲大理石凹面 ≥ 4.2；深版在 PANEL ≥ 5.4。执行留意：深版 2 / 3 / 5 从此和 `ItemPainter.RARITY_COLORS`（棋盘格色，087 作者定，不动）不再相同，`test_text_colors_169` 只断言第 0 档相等，照旧过；没有代码把稀有度色写死进 BBCode。

**账单底定稿 甲（美术设计 15:44；作者 15:41 在美术设计线程：「甲的整体可以，不过边框不用那么复杂，稍微简易一点，颜色白灰」）**：白灰大理石，外框只留一层斜面加一道墨线；图 768×528，origin **(−24, −24)**（盖掉上面的 (−32, −32)），dim 色 `#68655f`，其余字色不变；只交甲，定稿说明在 `/mnt/project-files/art/ui/ledger/README.md`，执行已收。

**账单去表头、「继续」钮出样（美术设计 16:05；作者 16:00 在美术设计线程提的）**：
- 表头行删掉：账面 720×**440**（十行 + 合计），第 i 行（1..10）上沿 40×(i−1)，合计 400..440；图 768×488，origin (−24, −24) 不变。经验列仍留着占位，只是没有「经验」二字的表头 —— 占位列每行写「—」即可，将来接经验值时再决定要不要表头。
- 「继续」钮：美术出了三款 210×64 四态（甲 石键 推荐 / 乙 纸卷（第二页那张）/ 丙 铜线石键），放账单下居中，字由代码写，文件 `/mnt/project-files/art/ui/ledger/continue/`；作者在美术设计线程挑，甲先落。
- **统一规矩（架构定）**：结算屏两页是同一屏，「继续」钮两页用同一款，作者在卡上选哪款，第二页就跟着换（选乙则两页都是纸卷，第二页不动）；战斗 / 回放屏的「继续」照旧是 UI替换美术 的纸卷，不跟结算屏走。§一的「主钮一条」改由这一款顶替，UI替换美术 那边结算屏主钮的样不用再出。第二页「继续」旁的两枚 150×56 小钮（一键置入、整理）跟着同一款：作者选甲或丙，美术设计补两枚同款石键小钮（四态，字由代码写）交执行；选乙则整行都是纸卷、不动。

**「继续」定稿 甲 石键（作者 16:06 在美术设计线程：「甲的整体样式，但箭头更加罗马式一点，比如在箭头的左侧凹陷处加上一个圆形」）**：箭头后沿内凹、凹口嵌一颗圆珠；按两页同款的规矩第二页「继续」也换石键，旁边两枚 150×56 小钮（一键置入、整理）同款石键、不带箭头；切图与规格全在 `/mnt/project-files/art/ui/ledger/continue/`，已交执行。

**第二页仓库棋盘右对齐（作者 16:32 在美术设计线程）**：分页签贴着棋盘左边，和棋盘一起整块右移，棋盘外框右沿对齐「继续」钮右沿（第二页内容区右沿）；带回来的背包仍靠左，两块棋盘中间留空。效果图 `/mnt/project-files/art/ui/ledger/continue/mocks/page2_right.png`，美术已直接发执行。

**裸露文字（作者 16:32 全游戏规矩，另开 226 清查）**：结算屏先照做：第一页「撤离成功」刻进标题牌 `out/title_plate.png`（320×60 半透明，页内 (640, 84)，字由代码写 36 号），副标题「帝国营地 · 从撤离点出来」删；第二页两块棋盘上方的说明字和底下「带回来的背包里还有 N 件：置入仓库；…」那行删。美术已发执行。


## 八、落地（执行，2026-10-21，v3.77）

②③④ 与第一页 / 第二页的按钮一起落了（§一 的主钮由「继续」石键顶替，见 §七末）。

**账单**（`ui/game/ledger_view.gd`，`LedgerView`）：账面 720×440 摆在设计稿 (440, 190)（屏幕正中对齐）；底图 `assets/ui/result/ledger_stele.png` 按 origin (−24, −24) 整图画在结算页石板上，不垫底、代码不画线。十行 + 合计照 §7.1（去表头后的版本）：数量 Cinzel Bold 20 右对齐 x 584（串里的汉字落到思源宋体），最高稀有度写稀有度名、serif_bold 18、`UiPalette.rarity_color(r, light)`，经验列每行「—」、合计行「合计 —」。逐行显出照 §3.3；`_input` 里点一下或按任意键全显，这一下不往下传；全显时发 `revealed`，结算屏这时才让「继续」可点。给测试的：`rows()`（key / label / 到位的数 / 显没显）、`numbers()`（行名 → 到位的数）、`reveal_all()`、`text_at(row, p)`。战败同一张账单：带出的东西写「保险箱 N 件」，最高稀有度按保险箱算。

**新计数**：`RunState.tally` 加 `elite_won` / `boss_won`（赢了按这一场的点类型，`elite` / `core`）、`searches`（`search_opened`，宝箱也算；同一个点只算一次，翻过的点记在 `RunState.searched_nodes`，进存档）、`crafts`（`CraftingModule.craft` 成了一次记一笔）；`RunResult` 同名四个字段。旧存档缺的键 = 0。

**「继续」与第二页按钮**：`UiTheme.make_art_text_button(text, handler, art, size, center, font_size)` —— 四态 `StyleBoxTexture`（图四周各多 6 px），字 serif_bold、按字心算内边距，按下往下挪 1 px，字色照美术（normal / pressed `#2e2219`、hover `#16110d`、disabled `#8d8a84`）；缺图退回平板主钮。两页的「继续」都是 `result/btn_stone`（210×64，字心 (92, 32)），第一页摆在 (695, 690)；第二页「一键置入」「整理」是 `result/btn_small_stone`（150×56，字心 (75, 28)，间隔 14），`WarehousePanel.art_buttons` 打开；「继续」放进同一行右端，整行挪到滚动区外钉在底下、宽度跟着仓库面板（右沿对齐仓库区右沿）。序章连打时「进入下一张：X」那颗大钮去掉，按钮写「继续」。

**棋盘**（§七末作者 15:19 的规矩）：187 的设置项删了，不是只改默认 —— `GameSettings.show_grid` / `GRID_AUTO` / `grid_on`、设置屏的开关与 `settings.grid*` 文案、`InventoryView.grid_shown` / `drag_hint` / `apply_grid_setting` / `GRID_DRAG_ALPHA`、`DragLayer._hint_grids` 都删；旧设置文件里的 `show_grid` 读时忽略。仓库按 UI替换美术 的 `boards.warehouse` 画：`InventoryView.ground = GROUND_WAREHOUSE`（棕底 `#543c2a`、两层内格线在道具下面、外圈 4 px 圆角深边），`WarehousePages` 三处（基地、开局屏第二页、结算屏）一起换。带回来的背包套 `board/frame_player` 素皮带框（`StyleBoxTexture`，四边 54、中段平铺、格子缩进 24）加战利品屏同一套格缝；不滚时不留滚动条那 14 px（`ScrollBox` 的 meta `tight`），基地中列算格子边长时扣掉框宽。

**字体**：`assets/fonts/cinzel_bold.ttf`（Cinzel Bold，只裁 `0-9 I V X + − - % / · —` 和空格，4 KB）+ `LICENSES/OFL_Cinzel.txt`，`tools/subset_fonts.sh` 跟着裁；`UiPalette.FONT_NUMERAL` / `numeral_font()`（缺字走思源宋体）。

**稀有度色**：`data/authoring/ui/text_colors.json` 的 `rarity` 换成美术设计核过的六对（§七末），`ItemPainter.RARITY_COLORS` 没动。

**地上出售撤销**（§7.2）：照单删干净；帮助页「地上」末句改成「撤离时地上没背出来的那几件就没了：不进仓库，也不换钱。」（英文同改）。

**作者 16:32 的补充**（美术设计 16:36 转来）：
- 第一页标题刻进标题牌：`result/title_plate`（320×60，摆在 (640, 84)，图 origin −6），字 36、居中、墨色（`UiTheme.make_title_label`）；副标题「章节 · 结局」删了，页面 tone 设成 light。
- 去掉裸露文字：第二页顶上那行「置入仓库 / 总价值 · 带出」删了；`WarehousePanel.art_buttons` 打开时两块棋盘上面的说明字（带回来的背包、仓库大小）和底下那行状态字（「带回来的背包里还有…」、一键置入的结果）不显示（`visible = false`，字照旧更新）；序章之间那句「下面直接进…」也删了。没再用到的 `result.reason_*` / `store_title` / `store_recap` / `next_note` 文案一起删。
- 第二页仓库连同分页签右对齐（面板里加一个撑开的空位），带回来的背包仍靠左；仓库框右沿和「继续」右沿对齐。

**221 补充五**（随这次落）：`event_marked_reward` 台词改「他塞给你一瓶{item:salve}」；`faith_call` 标题改「无名的祭坛」/ A Nameless Altar；`extract_default` 里的仓库、地上改 `{zone:…}`；`event_altar` 的匕首改 `{item:knife}`；四个 `faith_call_*` 和 `tut3_faith_call` 台词里的护符名改 `{item:charm_*}`。中英同改。

### 和方案不一样的地方

1. **`FONT_DISPLAY` 没有整体换成 Cinzel，另加了 `FONT_NUMERAL`。** §四 / §7.3 说火漆签大字、倍速罗马数字、翻页计数器都走 `FONT_DISPLAY`、汉字不走它 —— 查下来不是：`FONT_DISPLAY`（马善政）现在画的是开场事件的章节名和宝箱屏的说明字，都是汉字；倍速钮是图（缺图时写的是 Ⅰ Ⅱ Ⅳ 这种 Unicode 罗马数字字符，Cinzel 没有）；翻页计数器和火漆签走的是正文 / 粗体。整体换掉会让章节名变成朱雀仿宋，所以 Cinzel 只用在账单的数上，马善政留着。倍速、翻页计数器要换 Cinzel 得先把 Ⅳ 这类字符改成字母 IV，要做的话另开一条。
2. **战败也可能有第 2 步。** 原来战败时带回来的背包里有东西（保险箱带出的进了这块背包，或上一局没置入的），第一页下面会挂一块仓库面板；账单占了页面中间，放不下了。现在这种情况下第一页的「继续」翻到和撤离一样的第 2 步置入仓库；带回来的背包是空的就照旧一步到底。
3. **战败页的布局**：保险箱放大后摆在账单右边（1200, 190），「全都留在了里面」那句在「继续」下面。战败页这两句（保险箱上面那句、「继续」下面那句）作者 16:32 没点名，稿里也没有战败页，这次先留着；报告 226 批二把它们删掉。

截图：`/mnt/project-files/art/ui/ledger/shots/`（第一页逐行中途 / 全显、第二页、战败、基地仓库页）。

## 九、补充二：作者看实装截图后的六条（2026-10-21 17:22–17:23，美术设计线）→ 派执行

作者原话：「1. 顶端的横线去掉，现在和【撤离成功】的牌子重叠了 2. 将整体界面放大，清晰度提高一点 3. 击败的敌人/击败的精英/击败的首领，这样分三行」「1. 保险箱的棋盘也该是和背包棋盘统一的颜色 2. 仓库棋盘和右上角对齐，去掉中间的分隔横线 3. 战败时不显示保险箱，也不给它单独开页」。美术设计已出第二版件（17:33，交执行）；代码口径如下。

| # | 定 | 代码 |
|---|---|---|
| 1 顶端横线 | 那条线是 `slab_edge.png` 烤进去的标题刻线（title_height 36）。结算屏两页改用美术的 **`slab_edge_plain`**（边距不变、title_height 0） | `_slab_screen()` 给结算屏一个 `edge_art` 参数（`slab_box(false, -1, edge)`），别的屏不动 |
| 2 放大 1.2 倍 + 清晰度 | 第一页的件全部 ×1.2：账单 **864×576**（十一行 + 合计，行高 48，摆在 x 368、y 150）、标题牌 **384×72**（x 608、y 60）、继续 **252×77**（x 674、y 760）；字号 ×1.2（行名 22、数 24、合计名 26、合计数 38）；第二页小钮 180×67。**位置、字号以美术 `layout.json` 为准**。清晰度：美术给 2 倍分辨率的图，代码按设计尺寸缩着画 —— `LedgerView` 的 `draw_texture` 改 `draw_texture_rect`，标题牌 `TextureRect.expand_mode = IGNORE_SIZE`，按钮 `StyleBoxTexture` 本来就拉伸 | 第二页棋盘：带回的棋盘格子 **72**（同背包窗），仓库格子按剩余宽度放大（`cell_px` 上限 96 照旧） |
| 3 三行 | 「击败的敌人」= `battles_won − elite_won − boss_won`（普通敌人），「击败的精英」= `elite_won`，「击败的首领」= `boss_won`；删掉现在的「其中精英 · 首领」合并行 | `LedgerView.rows_for`：`defeated` 改普通数，新增 `elite` / `boss` 两行，删 `elite_boss`；UiText `ledger.elite` / `ledger.boss`（中英）；总计仍十一行 + 合计 |
| 4 保险箱格子同色 | 保险箱视图和背包棋盘一样：**皮带框 `player` + 格缝**（227 清单里结算保险箱那行由 `plain` 改 `player`；美术 17:10 说的「宝箱木框铁角」作废） | 第一页撤离时保险箱视图挪到账单右侧 **x 1280、y 160**（账单放大后原位 1200 会压住账单） |
| 5 仓库靠右上 | 第二页仓库面板（分页签 + 棋盘）**贴到页面右上角**（边距 32），右沿仍与继续右沿对齐；删 `_build_store` 的 `HSeparator` | 228 的木底页沿用这个摆位 |
| 6 战败不显示保险箱、不开第二页 | 战败：第一页只有账单（保险箱那块、`lost_all / lost_safe` 两句都不要，226 批二顺带）；**`_has_store_step()` 只看 `is_extracted()`**，战败永远没有第二页。保险箱带出的东西：`MetaState.absorb` 在战败分支里**直接 `warehouse.try_add`**，放不下的才进待置入棋盘 `board`（基地「仓库」页照旧能清；`has_pending_board` 照旧挡下一局）。账单「带出的东西」行战败时仍写「保险箱 N 件」 | 测试：战败 + 保险箱有东西 → 没有第二页、仓库里有它们、`result.safe_line` 不出现；放不下 → `board` 非空、基地仓库页能清 |

顺带（游戏测试 17:28 提、美术已改图）：Cinzel 的「1」加长顶旗，英文「Continue」字缩一号 —— 换图即可。

排序：这单紧跟 226 批二（同一屏），在 227 / 228 之前。

### 补充二落地（v3.88）

- 板边：`UiTheme.slab(c, edge_art)` / `GameScreen._slab_screen(min_size, edge_art)` 多一个板边参数，结算屏两页传 `slab_edge_plain`；内容区边距照旧按主题的石板。
- 第一页按 v2 `layout.json`：账单 864 × 576 摆 (368, 210)，行高 48，图 2 倍分辨率按 922 × 634 `draw_texture_rect`；标题牌 (608, 92) 384 × 72，图 `EXPAND_IGNORE_SIZE` 画成 398 × 86，字 43；继续 252 × 77 摆 (674, 834)，字 34、字心 (110, 38)，英文 28、字心 (100, 38)，出血 7。
- 三行：`LedgerView.rows_for` 的 `defeated` = 胜场 − 精英 − 首领，新增 `elite` / `boss`（`ledger.elite` / `ledger.boss`），删 `elite_boss` 与 `ledger.pair`。
- 保险箱：只在撤离的第一页，框左上 (1280, 160)，皮带框 `player`（`WarehousePanel.board_frame_box`）+ 格缝，格子最大 60、按框最宽 218 缩；第二页不再画保险箱，分隔线删了（带出的东西已经在带回来的棋盘里）。
- 第二页：带回来的棋盘格子 72（`WarehousePanel.board_cell`）；仓库格子按石板内容区扣掉包架、棋盘、按钮行后剩下的宽高 `WarehousePages.fit`（量内容区，不量滚动区，免得越撑越大）；小钮 180 × 67，字 26（英文 22）。
- 战败：只有标题牌、账单、继续；`_has_store_step()` 只看 `is_extracted()`。`MetaState.absorb` 战败分支：包进包架 → 仓库 → 放不下才进待置入的棋盘。删 `result.lost_all / lost_safe / safe_line`。
- 测试：新套件 `test_result_v2_224`（战败进仓库 / 溢出进棋盘；板边、摆位、2 倍图、保险箱框、第二页棋盘 72、仓库靠右、英文字号）；`test_result_steps_177`、`test_screens_157`、`test_author_092` 跟着改。截图 `/mnt/project-files/art/ui/ledger/shots_v2/`。


## 十、补充三：合计行改「总分」、经验列去掉（作者 2026-10-22 12:45）→ 派执行 + 美术设计

作者原话：「结算的第二页最后一栏【总价值】改成【总分】，经验列去掉，以后有对应系统直接将分数转化为经验就行」。

> 账单在结算的**第一页**（第二页是 228 的仓库），改的就是这张账单；作者说的「最后一栏」是合计行。

### 改什么

| 处 | 现状（v3.88） | 改成 |
|---|---|---|
| 合计行标签 | `ledger.total` = 「总价值」/ Total value | 「总分」/ Score。数值不变：`r.value + r.safe_value`（`ledger_view.gd:93`），和 `MetaState.score` 累加的是同一个数（`meta_state.gd:260/284`），「统计」里的「累计价值」= 这个分的总和 |
| 经验列 | 每行写「—」，合计行写「合计 —」（`ledger_view.gd:194–197`，`XP_RIGHT 845`） | 整列删：常量、两处 `draw_string`、文本键 `ledger.xp_total`；`ledger.none` 留着（最高稀有度为空时还用） |
| 数量列 | 右对齐在 `NUMBER_RIGHT 701`，右边是经验列 | 右对齐挪到 **845**（原经验列右沿），数量列占到右边 |
| 图 `result/ledger_stele` | 两道分栏线画在图里（账面 x 360 / 720） | 只留 360 那道；720 那道去掉。美术设计改 `art/ui/ledger/v2.py`：`COLS0 = (300,)`、`NUM_R` 取原 `XP_R`、`xp` 字段删，重跑出 `out/v2/`（1x + @2x）和 layout.json，执行换图 |
| 菜单「统计」 | 「累计价值」（en Score） | 顺手改「累计总分」，英文已经是 Score，不动 |

### 不改什么

- 行数、行高、逐行显出、点击全显、滚数：原样（`test_result_v2_224.gd` 的「十一行 + 合计」照旧过）。
- 分数怎么换经验：作者说以后有系统再定，这次不建 XP 字段、不加换算。

### 顺带

236 ⑤ 本来要把这张图改成 1x 导出（2x 图 1844×1268 在 1x 画是白费显存）；这次反正要重出图，**执行若已在做 236 甲批，就一起按 1x 出**；没做就先只去线，1x 留给 236。

### 派单

- 美术设计：改 v2.py 去掉第二道分栏线，重出 `out/v2/ledger_stele.png`（+ @2x）与 layout.json（`columns_x [360]`，`number_right_x 845`，无 `xp_*`）。
- 执行：换图 + `ledger_view.gd`（删 `XP_RIGHT` 与经验列绘制，`NUMBER_RIGHT` 845，头注释三栏改两栏）+ `ui_text.gd`（`ledger.total` 总分 / Score，删 `ledger.xp_total`，`menu.stats` 累计总分）+ 对应测试文案。

### 落地（执行，2026-10-22，v4.15）

- `ledger_view.gd`：两栏（项目 | 数量），`XP_RIGHT` 与经验列的两处 `draw_string` 删掉，`NUMBER_RIGHT` 845；头注释改两栏。
- `ui_text.gd`：`ledger.total` = 「总分」/ Score；`ledger.xp_total` 删；`menu.stats` 的「累计价值」改「累计总分」，基地「统计」那一行（`meta.stats`，同一个数）顺手一起改，英文 total value → score。
- `assets/ui/result/ledger_stele.png` 换美术设计重出的 `out/v2/@2x/ledger_stele.png`（只剩 360 那道分栏线）；仍是 2× 文件、`ART_SIZE` 不变，1× 在 236 甲批里换。
- 测试：`test_result_steps_177` 两处「总价值」改「总分」。全套 31396 项断言通过。
