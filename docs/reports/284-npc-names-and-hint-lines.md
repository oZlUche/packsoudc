# 284 三位 NPC 的名字与提示台词（282 补充）

> 作者 2026-11-07 10:01（架构设计线程）：「名字你负责就好，局内商店店主用中东风格名字，其他两位古代欧洲文明就好。台词现在只用加入小提示就好，比如局内商店店主：【精英敌人有概率掉落额外的好东西】；铁匠：【不同地区会产出不同材料】。写一份方案让我过目决定」。本篇是方案，**等作者过目**后再派执行。

## 〇 一句话

三位 NPC 各给三个名字候选（A / B / C，带推荐），台词**全部改成提示句**：每人六句，每句一个真的、现在就在游戏里的规则，不写世界观、不写任务链线索；作者点头后执行把 `data/authoring/npcs/*.json` 填上，重跑字集裁字。

## 一、规矩（写台词前先定）

1. **只说真话**：每句对应一条代码里现有的规则（§三 每句后面标了出处），数值会变的不写数（「三成 / 五成」这类数据项不进台词）。
2. **不碰任务链**：寂灭 / 刹那 / 断水 / 破晓一个字不提（作者 11-05 12:33：提示以后写进道具说明，不另加）。
3. **一句一事、不超过一行**：纸条宽 300 像素（`NpcBadge.NOTE_W`），正文一行约 16–18 个汉字，超了自动换行也不要超过两行；不加「提示：」之类的前缀，纸条本身就是提示（奥卡姆）。
4. **不重复界面上已有的字**：节点悬浮句已经写了矿脉出矿石、林地出草药（`node.hint.search_*`），铁匠不再逐个报；集市的「每局回来换一批货」招牌已有，摊主那句换个角度说锁格。
5. **全部无条件开放**：六句都随时能说，不挂 `requires`（作者给的两句例子也没有条件；十句内不重复的队列对六句照样工作：说完一轮从最早的放开）。
6. **种类**：六句全是 `guide`；原来的 `lore_1–3` 三个槽改 id 为 `guide_4–6`，`kind` 一律 `guide`（导入器只许 lore / guide，不用改校验）。

## 二、名字（A / B / C，推荐加粗）

名字只在纸条左上角显示（282 §二.2），三个字以内最合适。英文名写进 `display_names.en`。

| NPC | 头像（作者 11-05 12:53 选 A） | A | B | C |
|---|---|---|---|---|
| 局内商店店主 `shopkeeper`（中东风格） | 行商，带秤 | **哈基姆** Hakim（阿拉伯语「智者」，行商气） | 纳西尔 Nasir | 尤瑟夫 Yusuf |
| 集市散货摊摊主 `stall_keeper`（古代欧洲） | 草帽胖摊主，提果篓 | **德米特里** Demetrios（希腊，取自丰饶女神德墨忒尔，合果篓） | 卢修斯 Lucius（罗马） | 菲洛 Philo（希腊） |
| 铁匠铺铁匠 `blacksmith`（古代欧洲） | 光头大胡子，持锤 | **布伦努斯** Brennus（凯尔特，古高卢首领之名） | 瓦鲁斯 Varus（罗马） | 奥拉夫 Olaf（北欧） |

三个推荐放在一起：哈基姆 / 德米特里 / 布伦努斯 —— 三种文明各一个，念起来不撞。

## 三、台词（每人六句，全是提示）

### 3.1 局内商店店主（局里说的话，围着「这一局怎么活着带东西出去」）

| id | 中文 | en | 出处 |
|---|---|---|---|
| guide_1 | 精英敌人有概率掉落额外的好东西 | Elite foes have a chance to drop something extra. | 作者原句；精英点的敌人高一档（`StrengthRule`），身上的货更好，另有珍宝掷 |
| guide_2 | 越往里走，货架上越容易见到好东西 | The deeper you go, the better the goods on my shelves. | `EconomyRules.shop_depth_gain`：稀有度权重随深度放大 |
| guide_3 | 东西卖给我，不如带回基地卖得贵 | You'll get more selling that back at base than to me. | 251：局内 `shop_sell_ratio` 低于基地 `MetaRules.sell_ratio` |
| guide_4 | 倒计时过半，离出生点最近的免费撤离点就关了 | Past half the Countdown, the free exit nearest the spawn closes. | 092：`PaidExtracts`，`closes_at` |
| guide_5 | 放进保险箱的，就算行动失败也带得出去 | Whatever's in the Safe comes home even if you fail. | `node.tip.safe`、`CountdownModule` |
| guide_6 | 背得太重，走一步花的倒计时也更多 | Carry too much and every step costs more Countdown. | 129：负重第三级走一步行动点翻倍（`EncumbranceLevel`） |

### 3.2 集市散货摊摊主（基地里说的话，围着「这摊子怎么用」）

| id | 中文 | en | 出处 |
|---|---|---|---|
| guide_1 | 看上的货先锁住，换货时锁着的不动 | Lock what you like; a restock won't touch locked wares. | 270：`Market.toggle_lock`，`market.locked` |
| guide_2 | 在家也能花钱换货，换得越多越贵 | You can pay to restock at home; each time costs more. | 270：`refresh_cost = 40 + 20 × 次数`（数不写进台词） |
| guide_3 | 买走的货进仓库，仓库满了我可不卖 | Purchases go to the Warehouse; no room, no sale. | `Market.buy`，`market.full` |
| guide_4 | 固定摊的货不断，只有我这儿看运气 | The fixed stalls never run dry; only my stall is luck. | 270：固定摊货单 `catalogue` 买了不减，散货摊按权重抽 |
| guide_5 | 点出「高级货物」，摊子上的货就更好 | Research Fine Goods and the wares get better. | 251 / 262：集市级数 = 科技「高级货物」 |
| guide_6 | 一键出售不卖锁住和收藏的，也不卖包 | Sell-all skips locked and favourited items, and bags. | 268：`meta.sell_intro`（出售走集市，265 收藏） |

### 3.3 铁匠（基地里说的话，围着「材料从哪来、怎么变好」）

| id | 中文 | en | 出处 |
|---|---|---|---|
| guide_1 | 不同地区会产出不同材料 | Different lands yield different materials. | 作者原句；283：每章每环自带材料节点与产物表 |
| guide_2 | 两件一样的东西贴在一起，接缝上的小锤能合成更好的 | Two of the same side by side: the little hammer at the seam fuses them into something better. | 279：`Fusion`，白 → 绿 |
| guide_3 | 休息点的砧子，一把武器加一件对路的材料就能升一档 | At a rest-point anvil, one weapon plus the right material goes up a grade. | 279：`Anvil`，每处免费一次 |
| guide_4 | 材料比配方要的好几档，打出来的品质就高几档 | Better material than the recipe asks for means a finer piece. | 279 补充二：`Anvil.quality_of` |
| guide_5 | 矿石得先在我这儿炼成锭，再打东西 | Ore gets smelted into ingots here before it becomes anything. | `smith_silver_ingot` / `smith_mithril_ingot`，分组「冶炼」 |
| guide_6 | 我只用仓库里的素材，锁住的不碰，打好的也放回仓库 | I only use Warehouse materials, never locked ones; the work goes back there too. | `Smithy`：只吃仓库、锁住的不算、产物进仓库 |

## 四、改动清单（执行，作者点头后）

1. 三份 `data/authoring/npcs/*.json`：`display_name` / `display_names.en` 填作者挑的名字；六句按 §三 填 `text` / `texts.en`，`lore_1–3` 改 `guide_4–6`、`kind` 全 `guide`；`specials` 不动。
2. 字集：`python3 tools/font_charset.py` → `tools/subset_fonts.sh`，提交子集与 `charset.txt`（名字里的 哈基姆 / 德米特里 / 布伦努斯 等字多半不在现有字集里）。
3. 测试：282 的用例里「台词为空只显示……」那条改成有字；十句内不重复的用例六句照样过。
4. README 282 行补「名字与台词见 284」。

## 五、待定（没回音按推荐）

| # | 事 | 推荐 |
|---|---|---|
| 1 | 台词要不要带【】 | 不带，纸条本身就是框（作者例子里的【】当作引号读） |
| 2 | 三位名字 | A / A / A：哈基姆 / 德米特里 / 布伦努斯 |
| 3 | 世界观句（lore）还留不留槽 | 不留，六句全提示；以后要加世界观再加槽 |
| 4 | 要不要挂条件 | 全部无条件 |
| 5 | 英文台词 | 照 §三 的 en 列，执行一并填 |

## 六、落地记录

| 时间 | 事 | 出处 |
|---|---|---|
| 2026-11-07 10:01 | 作者原话见顶部；写成本篇，等作者过目 | 架构设计线程 |
