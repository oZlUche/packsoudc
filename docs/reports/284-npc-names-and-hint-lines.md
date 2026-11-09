# 284 三位 NPC 的名字与提示台词（282 补充）

> 作者 2026-11-07 10:01（架构设计线程）：「名字你负责就好，局内商店店主用中东风格名字，其他两位古代欧洲文明就好。台词现在只用加入小提示就好，比如局内商店店主：【精英敌人有概率掉落额外的好东西】；铁匠：【不同地区会产出不同材料】。写一份方案让我过目决定」。
>
> 作者 14:43 看过第一版后：3.1 第三句改成【东西卖给我就好，我肯定出个公道价格，嘿嘿】（商人要奸诈一点，坦白自己给得少就和人设冲突）；第四句不要直接引用游戏术语，改成【待得越久，就越出不去】；第五句要先按世界观改【保险箱】的概念——魔法阵、撤离部队，或者并进免费撤离点，进入时选【撤离】或【托付道具】；第六句改成【别太贪心，拿的东西越多，就越走不动路】；**其余台词照这个逻辑全改**。作者 14:56 在卡片上选 **C 并入免费撤离点**（另开 287）。
>
> 作者 14:57：「关于提示，记得加入一些通用（即所有人都会说）的提示：按R可以旋转，按alt可以隐藏物品信息，按ctrl可以整个包拖动，同时记得将这些文本设置成引用而非写死，以应对玩家未来想要改键的情况」。本篇是第三版（§3.4 通用句 + `[key=…]` 引用），**名字与台词仍等作者过目**。

## 〇 一句话

三位 NPC 各给三个名字候选（A / B / C，带推荐）；台词全部是提示句，每人六句，**用人话、带人设、不说系统术语**，每句背后仍是一条真的、现在就在游戏里的规则；不写世界观、不写任务链线索。保险箱的概念另给 A / B / C（§四），店主第五句跟着它走。作者点头后执行填 `data/authoring/npcs/*.json`，重跑字集裁字。

## 一、规矩（写台词前先定）

1. **只说真话**：每句对应一条代码里现有的规则（§三 每句后面标了出处）；数值会变的不写数。
2. **不碰任务链**：寂灭 / 刹那 / 断水 / 破晓一个字不提（作者 11-05 12:33：提示以后写进道具说明，不另加）。
3. **不说术语**（作者 14:43）：「倒计时」「撤离点」「保险箱」「科技」「配方」「稀有度」这些界面上的词都不进台词，换成这个人会说的话；玩家自己把话和界面对上号。
4. **带人设**：店主是个嘴甜心黑的行商，话里带「嘿嘿」，永远不说自己给得少；摊主是个提果篓的胖子，热络、实在，爱拉生意；铁匠光头大胡子，话少、直、不客气。
5. **一句一事、不超过两行**：纸条宽 300 像素（`NpcBadge.NOTE_W`），正文一行约 16–18 个汉字；不加「提示：」之类的前缀，纸条本身就是提示（奥卡姆）。
6. **全部无条件开放**：六句都随时能说，不挂 `requires`；十句内不重复的队列对六句照样工作（说完一轮从最早的放开）。
7. **种类**：六句全是 `guide`；原来的 `lore_1–3` 三个槽改 id 为 `guide_4–6`，`kind` 一律 `guide`。

## 二、名字（A / B / C，推荐加粗）

名字只在纸条左上角显示（282 §二.2），三个字以内最合适。英文名写进 `display_names.en`。

| NPC | 头像（作者 11-05 12:53 选 A） | A | B | C |
|---|---|---|---|---|
| 局内商店店主 `shopkeeper`（中东风格） | 行商，带秤 | **哈基姆** Hakim（阿拉伯语「智者」，行商气） | 纳西尔 Nasir | 尤瑟夫 Yusuf |
| 集市散货摊摊主 `stall_keeper`（古代欧洲） | 草帽胖摊主，提果篓 | **德米特里** Demetrios（希腊，取自丰饶女神德墨忒尔，合果篓） | 卢修斯 Lucius（罗马） | 菲洛 Philo（希腊） |
| 铁匠铺铁匠 `blacksmith`（古代欧洲） | 光头大胡子，持锤 | **布伦努斯** Brennus（凯尔特，古高卢首领之名） | 瓦鲁斯 Varus（罗马） | 奥拉夫 Olaf（北欧） |

三个推荐放在一起：哈基姆 / 德米特里 / 布伦努斯 —— 三种文明各一个，念起来不撞。

## 三、台词（第二版：每人六句，全是提示，不说术语）

### 3.1 局内商店店主（嘴甜心黑的行商；局里说的话，围着「这一局怎么活着带东西出去」）

| id | 中文 | en | 背后的规则 |
|---|---|---|---|
| guide_1 | 精英敌人有概率掉落额外的好东西 | Elite foes have a chance to drop something extra. | 作者原句；精英点的敌人高一档（`StrengthRule`），身上的货更好，另有珍宝掷 |
| guide_2 | 越往里走，我摆出来的货越好，嘿嘿 | The deeper you go, the finer the wares I lay out. Heh. | `EconomyRules.shop_depth_gain`：货架稀有度权重随深度放大 |
| guide_3 | 东西卖给我就好，我肯定出个公道价格，嘿嘿 | Sell it to me, friend. I always give a fair price. Heh. | 作者原句；251：局内卖价低于基地（他当然不说） |
| guide_4 | 待得越久，就越出不去 | The longer you linger, the harder it is to leave. | 作者原句；092：过半关掉离出生点最近的免费出口 |
| guide_5 | 拿不动的先托付给出口那儿接应的人，他们比你先到家 | Hand what you can't carry to the crew waiting at the exit. They'll be home before you. | §四 推荐 C 的写法；A / B 的写法见 §四 |
| guide_6 | 别太贪心，拿的东西越多，就越走不动路 | Don't be greedy. The more you carry, the slower you walk. | 作者原句；129：负重分级，第三级走一步行动点翻倍 |

### 3.2 集市散货摊摊主（提果篓的胖子，热络实在；基地里说的话，围着「这摊子怎么用」）

| id | 中文 | en | 背后的规则 |
|---|---|---|---|
| guide_1 | 相中了又没钱？先给它拴上，下回来还在 | Fancy it but short on coin? Tie it down and it'll still be here next time. | 270：`Market.toggle_lock`，换货不动锁住的格 |
| guide_2 | 嫌货不好？花点钱我给你换一批，不过越换越贵哦 | Don't like the lot? Pay a little and I'll bring out another. It gets dearer each time, mind. | 270：`refresh_cost = 40 + 20 × 次数`（数不写） |
| guide_3 | 买归买，你家库房得放得下 | Buy all you like, so long as your storehouse has room. | `Market.buy`，仓库满了不卖（`market.full`） |
| guide_4 | 隔壁几家翻来覆去就那几样，新鲜玩意儿只在我这儿 | The other stalls sell the same old things. The surprises are all here. | 270：固定摊货单不变、买了不减；散货摊按权重抽 |
| guide_5 | 等你家底厚了，我的货色也跟着上档次 | Once your house is better off, my wares go up a notch too. | 251 / 262：集市级数 = 科技「高级货物」 |
| guide_6 | 拴上的和打了星的我一件不收，袋子也不收 | I won't take anything tied down or starred, and no bags. | 268：一键出售跳过锁定和收藏（265 右上角星），不卖包 |

### 3.3 铁匠（光头大胡子，话少、直；基地里说的话，围着「料从哪来、怎么变好」）

| id | 中文 | en | 背后的规则 |
|---|---|---|---|
| guide_1 | 不同地区会产出不同材料 | Different lands yield different materials. | 作者原句；283：每章每环自带材料节点与产物表 |
| guide_2 | 两件一样的家伙挨着放，缝上会冒个小锤子，敲一下就成一件好的 | Lay two of the same side by side. A little hammer shows at the seam. Strike it and they become one better piece. | 279：`Fusion`，相邻 + `adjacent` 配方，白 → 绿 |
| guide_3 | 歇脚的地方有砧子，一把家伙配一块对路的料，敲一下就上一档 | Where you rest there's an anvil. One weapon, one right piece of stock, one strike, one grade up. | 279：`Anvil`，每处休息点免费一次 |
| guide_4 | 料越好，打出来的越好，别心疼好料 | Better stock, better work. Don't hoard the good stuff. | 279 补充二：材料比配方高几档，品质高几档 |
| guide_5 | 矿石先炼成锭，再谈打东西 | Ore gets smelted into ingots first. Then we talk. | `smith_silver_ingot` / `smith_mithril_ingot`，分组「冶炼」 |
| guide_6 | 我只动你库里的料，上了锁的不碰；打好的也放回库里 | I only use stock from your storehouse, never anything locked. The work goes back there too. | `Smithy`：只吃仓库、锁住的不算、产物进仓库 |

### 3.4 通用句（三位都会说；作者 14:57）

放在 `data/authoring/npcs/common.json`（只有 `lines`，没有头像），`NpcChatter` 把它并进每个 NPC 的池子，十句内不重复的队列照旧按 NPC 记。按键**不写死**：台词里写 `[key=<动作>]`，显示时换成这个动作现在绑的键名（§3.5）。

| id | 中文 | en | 背后的规则 |
|---|---|---|---|
| common_rotate | 拖着东西的时候按 [key=rotate_item]，能转个方向 | Press [key=rotate_item] while dragging to turn it round. | `DragLayer`：R 转向（277 第 5 条滚轮也行） |
| common_hide_tip | 按住 [key=hide_tip]，道具的说明先藏起来，松开又回来 | Hold [key=hide_tip] to hide item descriptions; let go and they're back. | `HoverTip.hold_alt`（作者 10-21） |
| common_whole_bag | 按住 [key=whole_bag] 再拖，整个包连里面的东西一起走 | Hold [key=whole_bag] and drag to move a whole bag with everything in it. | 274：Ctrl（mac 上 Cmd）点包里的道具 = 点这个包 |

### 3.5 按键引用（作者 14:57：引用而非写死）

- 三个动作进 `InputMap`（`project.godot` `[input]`）并列进 `InputKeys.ACTIONS`：`rotate_item` 默认 R、`hide_tip` 默认 Alt、`whole_bag` 默认 Ctrl（mac 加 Meta）。154 补充一的改键存档（`GameSettings.key_bindings`）原样覆盖它们；改键界面照 154 待定 1 = A，仍等要改键的动作攒够再做。
- 三处代码改成查动作：`drag_layer.gd` 的 `KEY_R`、`hover_tip.gd` 的 `KEY_ALT`、`inventory_view.gd` 的 `KEY_CTRL / KEY_META` → `InputMap.action_has_event` / `Input.is_action_pressed`。
- 新记号 `[key=<动作>]`：`KeyNames.expand(text)`（和 `CoinShort` 一样的小工具）把它换成该动作第一个键的名字（`OS.get_keycode_string`，Ctrl / Alt / R 这类不分语言；没绑键写「未绑定」）。NPC 纸条、悬浮窗、提示都先过它。
- 顺手：`UiText` 里写死的「整理背包（B）」「（Esc）」这类先不动（不在本单；以后改键做界面时一并换成 `[key=…]`）。

## 四、「保险箱」改成什么（作者 14:43 问；A / B / C，推荐 C）

现状（092）：地图中层一个 `safe` 点（`SafePlacer`，深度约 0.7，两章各 1 个），踩上开一块 3×3 的格子，放进去的东西「视为已带出」，走开就锁上送回基地；科技「保险箱」加行列；寂灭的法杖计数「撤离或经保险箱回家 +1」也认它。一个只有名字、没有来历的箱子，确实和世界观对不上。

| 方案 | 做法 | 改动 | 利弊 |
|---|---|---|---|
| A 魔法阵 | 点原地不动，改名「传送阵」：放进阵里的东西先一步回家 | 只改名、改图标、改文案；科技改名「传送阵」 | 最省；魔法本来就有（魔晶、符文堆），说得通；但图上还是多一种点 |
| B 撤离部队（原位） | 点原地不动，改成一支在图中接应的小队「接应队」：把东西托付给他们带回去 | 同 A，改名、改图标、改文案 | 和 C 用同一个世界观，但接应的人站在图中间说不通 —— 他们为什么不顺便带你走 |
| **C 并入免费撤离点** | 不再单放 `safe` 点（两章 `safes` = 0，`SafePlacer` 退役）。踩上**免费撤离点**先问一句：【撤离】结束这一局 / 【托付】把东西交给出口接应的人、自己接着走；托付屏 = 现在的保险箱屏；付费出口不接托付（那边是花钱买路，不是自家人）。免费出口过半关门，托付也跟着关 —— 正好接「待得越久，就越出不去」 | 撤离点进入流程加一问；保险箱屏换个标题；科技「保险箱」改「接应队的背囊」；寂灭计数的「经保险箱回家」改「经托付回家」；图上少一种点、少一个图标、少一段节点悬浮句 | 少一个概念（奥卡姆）；来历说得通；**玩法变了一点**：原来中层就能把东西先存起来，以后要走回免费出口才能托付，而且出口关了就没得托 —— 逼人早点回头，和作者「别太贪心」一个方向。机关沙漏的出口在出生点对侧，托付就在终点那头，顺路 |

作者 14:56 选 **C**（卡片），设计与改动另开 **287**。店主第五句按 C 写（§3.1 guide_5）；若作者选 A，改成「拿不动的先放进阵里，它比你先到家，嘿嘿」；选 B，改成「图里有接应的人，拿不动的先托付给他们，嘿嘿」。

## 五、改动清单（执行，作者点头后）

1. 三份 `data/authoring/npcs/*.json`：`display_name` / `display_names.en` 填作者挑的名字；六句按 §三 填 `text` / `texts.en`，`lore_1–3` 改 `guide_4–6`、`kind` 全 `guide`；`specials` 不动。
2. 字集：`python3 tools/font_charset.py` → `tools/subset_fonts.sh`，提交子集与 `charset.txt`（名字和台词里的新字）。
3. 测试：282 的用例里「台词为空只显示……」那条改成有字；十句内不重复的用例六句照样过。
4. 保险箱 = C，见 287（单独一版）；台词先落，第五句按 C 的写法。
6. `common.json` 三句 + `InputMap` 三个动作 + `KeyNames.expand`（§3.4 / 3.5）。
5. README 282 行补「名字与台词见 284」。

## 六、待定（没回音按推荐）

| # | 事 | 推荐 |
|---|---|---|
| 1 | 台词要不要带【】 | 不带，纸条本身就是框（作者例子里的【】当作引号读） |
| 2 | 三位名字 | A / A / A：哈基姆 / 德米特里 / 布伦努斯 |
| 3 | 世界观句（lore）还留不留槽 | 不留，六句全提示；以后要加世界观再加槽 |
| 4 | 要不要挂条件 | 全部无条件 |
| 5 | 英文台词 | 照 §三 的 en 列，执行一并填 |
| 6 | 保险箱改什么 | 作者 14:56 选 C，见 287 |
| 7 | 通用句放哪 | `common.json` 一份，并进三个池子；不放进每个 NPC 的文件里重复三遍 |
| 8 | 键名怎么显示 | `[key=…]` 显示时换成当前绑定的键名；mac 的 Ctrl 显示 Cmd |

## 七、落地记录

| 时间 | 事 | 出处 |
|---|---|---|
| 2026-11-07 10:01 | 作者原话见顶部；写成本篇第一版（PR #499），等作者过目 | 架构设计线程 |
| 2026-11-07 14:43 | 作者改 3.1 第三 / 四 / 六句（原话见顶部），第五句要先改保险箱的概念，其余台词照同一逻辑全改 → 第二版：§一 加「不说术语」「带人设」，§三 十八句重写，§四 保险箱 A / B / C（推荐 C），店主第五句按 C | 架构设计线程 |
| 2026-11-07 14:56 | 作者卡片选 C 并入免费撤离点 → 287 | 架构设计线程 |
| 2026-11-07 14:57 | 作者：通用三句（R 旋转 / Alt 隐藏说明 / Ctrl 整包拖）且按键走引用不写死 → 第三版 §3.4 / 3.5 | 架构设计线程 |
| 2026-11-07 | **§3.4 / 3.5 落地 v5.36**（PR #510）：`npcs/common.json` 三句（`common_` 前缀，导入校验：通用句只写 lines、id 前缀分开），`NpcChatter.open_lines` 给三位 NPC 并进来；`InputKeys` 加 `rotate_item` / `hide_tip` / `whole_bag`（进 `ACTIONS`，能被 `key_bindings` 改），拖拽转向、按住藏说明、整包点选三处改查动作（点包时修饰键看那次点击自带的标记）；`KeyNames.expand` 把 `[key=动作]` 换成现绑键名（mac 整包写 Cmd，没绑写「未绑定」），NPC 纸条先过它。取舍：三个动作的默认键登记在代码里（`InputKeys.CODE_DEFAULTS` / `ensure`），没写进 `project.godot` —— 作者本机那份有没提交的改动，改它会让同步拉取冲突；效果一样（`apply` 先回 project 默认再补这三个）。名字与各人六句仍等作者 | 架构方案执行 |
| 2026-11-09 09:30 | 作者：「台词可以实装了」「名字也是」—— §三 十八句与 §二 推荐名（哈基姆 / 德米特里 / 布伦努斯，待定 2 的 A / A / A）照本篇实装，待定 1–5 按推荐；§五 1–3、5 派执行 | 架构设计线程 |
| 2026-11-09 | **名字与十八句落地 v5.45**（PR #521）：三份 `npcs/*.json` 填名字（哈基姆 Hakim / 德米特里 Demetrios / 布伦努斯 Brennus）和 §3.1–3.3 各六句中英（`lore_1–3` 改 `guide_4–6`，`kind` 全 `guide`，无条件、不带【】，铁匠 `specials` 不动）；字集与四个字体子集重做；282 测试改成核名字和六句，新增「真池子九句、每句和前八句不同」。顺手：散货摊纸条「上面放得下才贴上方」的断言改成看头顶空间（测试窗里头像离顶太近，长台词放不下；真屏 1600 × 1000 照贴上方，截图 /mnt/project-files/screens/284/stall_keeper_note.png） | 架构方案执行 |
| 2026-11-09 | **v5.46**（PR #PRNUM）：测试报局内商店点哈基姆纸条开了但看不见：纸条 `top_level` 不跟商店整页的 z 100，压在商人棋盘下面。纸条的 z 改成头像实际的 z 加 20，截图 /mnt/project-files/screens/284/shop_note_above_board.png | 架构方案执行 |
