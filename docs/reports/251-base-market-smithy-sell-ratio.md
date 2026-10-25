# 251 基地集市、铁匠铺（都靠科技升级）与「局内卖得贱、带回基地卖得贵」

作者 2026-10-24 11:46（架构设计线）：「添加基地商店机制，可以通过科技升级，出售直接用钱购买的道具和低稀有度素材(白到蓝)。添加铁匠铺机制，可以通过科技升级，有特定配方，可以通过素材和金钱合成武器、防具」；11:47：「调整局内外的出售价，局内出售价更低，鼓励玩家将东西带出局再卖」。三件都是明说的改法，一起写、一起派；配方表与库存表是占位数，作者随时改 json。

## 〇 一句话

基地多两间铺子，都从科技树上点出来、按级长大：**集市**卖「花钱就能买的」消耗品与白 / 绿 / 蓝三档素材，一局一换货；**铁匠铺**按配方吃仓库里的素材加钱，打出整件武器 / 防具。配着第三条：**局内商店只收三成，基地收五成**，素材与装备带出来才值钱 —— 集市卖素材、铁匠吃素材、局内卖素材亏，三件事互相咬合。

## 一 现状

| 事 | 现在 | 出处 |
|---|---|---|
| 基地 | 仓库（多页，163）、保险箱、科技树（118）、出售区（一键出售 + 筛稀有度 / 标签，177 补）、成就、开发区 | `ui/game/meta_screen.gd` |
| 科技 | 11 条，三种效果构件：`tech_run_buff`（9 条）/ `tech_safe_size` / `warehouse_pages`；每级要钱 + 上交道具（`TechTier.funds / items`）；再加一种效果 = 一个 [TechEffect] 子类 + 登记一行（110）；派生值不存档，读档按级数重算（120） | `core/meta/techs/*.gd`、`data/authoring/techs/*.json` |
| 局内商店 | 4 格货架按稀有度权重抽（`shop_rarity_weights` 40/30/20/8/2/0.5 × 深度），不上架 treasure / supply；买价 = 价值 × `shop_price_mult` 1.0；**卖给店里 = 价值 × `shop_sell_ratio` 0.5**；包格 / 金银格 / 随身排 | `core/run/shop_session.gd`、`data/authoring/economy_rules/standard.json` |
| 基地出售 | **价值 × `MetaRules.sell_ratio` 0.5**；贵重品 / 金银按面值全收（244） | `core/meta/meta_state.gd` `sell_price_of` |
| 局内合成 | 114：两件拖到一起立刻合（`RecipeDef.inputs` 两个 id → `output`），9 张配方，全是药 / 食 / 毒刃 | `core/run/modules/crafting_module.gd` |
| 铸炉 | 175：三槽查表铸「铸牌」给武器附魔，不造整件 | `core/forge/forge.gd` |
| 素材 | 71 件材料：白 13 / 绿 18 / 蓝 25 / 紫 12 / 金 3；建材 `supply` 10 件已是上交科技用的 | 数据统计 |
| 装备 | 不封存的武器 16（白 1 / 绿 8 / 蓝 3 / 紫 4）、防具 / 盾 / 插件 7（绿 5 / 蓝 1 / 紫 1） | 同上 |

稀有度：0 白 / 1 绿 / 2 蓝 / 3 紫 / 4 金（246 补充二已用蓝 / 紫 / 金）。「白到蓝」= 稀有度 ≤ 2。

## 二 集市（基地商店）

### 2.1 规矩

- **科技「集市」**（`market`，三级；前置「讨价」`bargain` 1 级 —— 会讨价才有人来摆摊）。级数 = 铺子的大小：

| 级 | 货格 | 素材上限 | 还卖什么 |
|---|---|---|---|
| 1 | 4 | 白 | 消耗品（药剂 remedy / 食物 food / 弹药 ammo，稀有度 ≤ 1） |
| 2 | 6 | 绿 | 同上，稀有度 ≤ 2 |
| 3 | 8 | 蓝 | 同上 + 空包（按章节包池，一格） |

- **卖什么**：「花钱就能买的」= 消耗品 + 素材（`material`，稀有度 ≤ 该级上限）；**不卖**武器 / 防具 / 盾（那是铁匠铺的事）、珍宝 / 贵重品 / 金银（局内才有）、信仰物、特殊道具、铸牌、封存件。每次上货素材占一半以上的格（素材是铁匠的饭，集市的主业）。
- **价钱**：买价 = 价值 × `price_mult` 1.0（和局内一样；不吃「讨价」的局内 buff —— 那是局内 buff，局外没有 RunState）。基地回收 0.5 → 买 1.0 卖 0.5，没有套利。
- **一局一换货**：每次从一局回到基地（撤离或战败）重新上货；基地里**不能花钱刷新**（钱留给局内刷）。升级集市那一刻也重新上货（多出来的格立刻有东西）。
- **买了去哪**：直接进仓库当前页有空处的位置（`Warehouse` 自动找位，163）；仓库满了不卖、说一句「仓库放不下」。钱从 `MetaState.funds` 走 `spend_funds`。
- **库存存档**：`MetaState.market_stock: Array[Dictionary]`（`{"id", "sold"}`）与 `market_seed`；173 对账：id 退役的行直接去掉。级数本身是派生值（120），不存。

### 2.2 做法

- 新效果构件 `TechFacility`（`"type": "tech_facility"`, `facility: StringName`）：`derive` 把 `meta.facility_levels[facility] = level`（新字典，不存档）。集市与铁匠铺共用。
- 新规则数据 `data/authoring/base_rules/market.json` → [MarketRules]：`slots_per_level [4,6,8]`、`rarity_cap_per_level [0,1,2]`、`consumable_rarity_cap_per_level [1,2,2]`、`price_mult 1.0`、`material_share 0.5`、`allowed_tags [remedy, food, ammo, material]`、`excluded_tags [treasure, valuable, bullion, faith, keepsake, token, sealed, supply?]`（建材 supply 要不要卖见 §五）、`bag_slot_from_level 3`。章节不分（基地只有一个）。
- `core/meta/market.gd` [Market]：`restock(meta, rules, items, seed)`（候选 = 过滤标签 + 稀有度上限，按 `shop_rarity_weights` 截到上限抽；素材先抽满 `material_share`，剩下抽消耗品）、`price_of(def)`、`can_buy(i) -> String`（空 = 行；否则原因键：钱不够 / 仓库满 / 卖掉了）、`buy(i)`。`ShopSession.candidates` 的过滤逻辑抽成静态函数两边共用。
- 触发：`GameFlow` 一局结束进基地（`MetaState.absorb` 之后）调 `Market.restock`；`TechService.upgrade` 升到 `market` 时也调。
- 文案键 `market.*`（标题「集市」、空格「今日没货」、原因三句），英文 Market。

## 三 铁匠铺

### 3.1 规矩

- **科技「铁匠铺」**（`smithy`，三级；前置「仓库」`warehouse` 1 级）。级数 = 能打哪一档：1 级绿、2 级蓝、3 级紫。
- **配方是数据**：`data/authoring/smith_recipes/*.json` → [SmithRecipeDef]：`id`、`output`（道具 id）、`inputs {素材 id: 件数}`、`funds`、`level`（几级才会打）、`display_name(s)`、`note(s)`。和 114 的 [RecipeDef]（两件拖合、无钱无数量）是两回事，不往一张表里塞。
- **吃什么**：只吃**仓库**里的（不碰保险箱、不碰下一局的棋盘）；锁住的（230）不吃；产物进仓库有空处的位置，放不下不打。
- **定价尺度**（作者调表时的参考）：素材价值之和 + 钱 ≈ 产物价值的 0.8～1.0。比买现成的便宜一点、但得把对的素材背回来 —— 这就是「带出局」的理由；配上 §四，素材局内卖只回三成，背回来打一件回得更多。
- **首批配方（占位，作者改 json 即可）**：

| 级 | 产物 | 素材 | 钱 |
|---|---|---|---|
| 1 绿 | shortsword 短剑 | iron_ore ×2、hardwood_plank ×1 | 40 |
| 1 绿 | cleaver 砍刀 | copper_ingot ×1、iron_ore ×1 | 30 |
| 1 绿 | longsword 长剑 | steel_ingot ×1、tanned_leather ×1 | 60 |
| 1 绿 | shortbow 短弓 | ironwood_branch ×1、rope_coil ×1 | 30 |
| 1 绿 | gambeson 棉甲 | linen_bolt ×2、wool_cloth ×1 | 30 |
| 1 绿 | leather_armor 皮甲 | tanned_leather ×2、beast_hide ×1 | 40 |
| 1 绿 | round_shield 圆盾 | copper_ingot ×1、hardwood_plank ×1 | 40 |
| 1 绿 | warhammer 战锤 | iron_ore ×2、oak_log ×1 | 50 |
| 2 蓝 | longbow 长弓 | ironwood_branch ×2、rope_coil ×1、fine_fur ×1 | 60 |
| 2 蓝 | plate_cuirass 板甲 | steel_ingot ×2、rivet_box ×1、tanned_leather ×1 | 120 |
| 2 蓝 | pendulum_blade 摆锤刃 | steel_ingot ×1、brass_gear ×1、mainspring ×1 | 100 |
| 2 蓝 | bloodletter 放血刀 | steel_ingot ×1、whetstone ×1、bone_charm_bits ×1 | 90 |
| 3 紫 | festering_blade 溃烂之刃 | steel_ingot ×1、viper_gland ×1、wound_salt ×1 | 150 |
| 3 紫 | mithril_sword 秘银附魔长剑 | silver_ingot ×2、steel_ingot ×1、fire_crystal_low ×1 | 200 |

（秘银没有对应素材，先用银锭 + 下品魔晶石占位；作者若想加「秘银锭」素材另说。）

### 3.2 做法

- [SmithRecipeDef] 走内容管线（`data/smith_recipes/*.tres`），导入器查：output / inputs 的 id 存在、output 带 weapon / armor / shield / gear_plug 之一、level 1～3。
- `core/meta/smithy.gd` [Smithy]：`recipes_for(meta) -> {ready, locked}`、`have(meta, recipe) -> Dictionary`（每种素材仓库里有几件，不算锁住的）、`can_forge(meta, recipe) -> String`（空 = 行；级不够 / 缺素材 / 钱不够 / 仓库满）、`forge(meta, recipe) -> ItemInstance`（扣素材按仓库顺序先扣最早放进去的、扣钱、产物 `grant`）。
- 文案键 `smithy.*`（「铁匠铺」、「打造」、四句原因）；英文 Smithy / Forge。「铸」字已归铸炉，这里用「打造」。
- 产物是新实例（`allocate_uid`），图鉴点亮走 `_record_codex` 同一条路。

## 四 局内卖贱、基地卖贵

- `EconomyRules.shop_sell_ratio` **0.5 → 0.3**（`data/authoring/economy_rules/standard.json` 写 `"shop_sell_ratio": 0.3`；注释改「作者 2026-10-24：三成，带回基地五成」）。`MetaRules.sell_ratio` 留 0.5。
- 贵重品 / 金银不动：局内商店买金银是面值 × 1.1，卖回店里走比例（0.3 × 1.1 = 三成三，更不值），基地按面值全收 —— 已经是「带出来」的方向。
- 文案：局内商店的出售框悬浮窗加一句「这里只收三成；带回基地能卖五成」（文案键 `shop.sell_hint`，比例从两处规则读出来、按 112 用「几成」写，不写阿拉伯数字）。基地 `meta.sell_intro` 已写比例，不动。
- 教练（coach）要不要提一次：第一次在局内卖东西时说一句同样的话 —— 推荐**要**，走现有的 coach 条目格式，看过不再说。

## 五 待定（默认取推荐）

1. **集市卖不卖建材 `supply`**：推荐**卖**（建材本来就是给基地用的，让人能花钱补齐科技要交的那几件；局内商店仍不上架 supply）。备选：不卖，逼人在局里找。
2. **集市卖不卖白 / 绿武器防具**：推荐**不卖**，整件装备归铁匠铺；否则铁匠铺 1 级没活干。
3. **铁匠铺的交互**：推荐**点配方 → 看有无 → 按「打造」自动从仓库扣**（不用拖），拖素材进槽留给将来美术定了再说。
4. **两间铺子在基地的位置**：推荐各一个页签（和仓库 / 科技 / 出售并列），不塞进出售区。
5. **局内比例 0.3 还是 0.25**：推荐 0.3；再低玩家会觉得卖了白送。

## 六 界面与美术

- 两个新页面都是棋盘式货架 / 槽：**集市货架一块框 + 格线**（227 全棋盘带框）、铁匠铺的素材槽同样带框；文字都落在签 / 牌 / 卷轴上（226 不裸字）；按钮平的（230）。
- 风格：基地是 235 的 Caesar III 白灰石 + 墨字；集市 = 石台上摆货（和局内 233 的市集帆布帐篷区分开：帐篷是野外临时摊，石台是城里的铺子）；铁匠铺 = 砧与炉台的近景（和 199 的铸炉近景区分：铸炉是野外一次性的炉，铁匠铺有砧、有挂架）。按 2026-10-21 18:42 的规矩至少出一张非矩形样稿（如拱门 / 山墙）。
- 美术设计出样 → 作者看 → UI替换美术换上；执行先用现成 `OverlayFrame` / `BoardFrame` 占位落地。页签图标照 2026-10-24 10:45 的规矩：先给作者看再定。

## 七 测试（执行写）

- `test_base_market_251.gd`：(a) 级 0 没有集市；(b) 级 1 上货 4 格、全 ≤ 白素材或 ≤ 绿消耗品、素材 ≥ 2 格；(c) 级 3 可见蓝素材、有一格包；(d) 买一件：钱减、仓库多一件、格标 sold；(e) 钱不够 / 仓库满 → 原因键，钱与仓库不动；(f) 一局结束重新上货，升级也重新上货；(g) 存档读回库存一致、退役 id 行被去掉。
- `test_smithy_251.gd`：(a) 级不够不打；(b) 缺一件素材不打；(c) 齐了：素材按数扣、钱扣、仓库多一件产物、图鉴点亮；(d) 锁住的素材不算有；(e) 仓库满不打、不扣；(f) 导入器拦 output 不是装备 / id 不存在的配方。
- `test_sell_ratio_251.gd`：局内 `ShopSession.sell_price_of` = ⌊价值 × 0.3⌋，基地 `MetaState.sell_price_of` = ⌊价值 × 0.5⌋，金银两边各自不变；`shop.sell_hint` 两个数从规则读。

## 八 不改的

局内商店的货架 / 刷新 / 包格 / 金银格（209 / 244）、114 局内合成、175 铸炉、基地一键出售、贵重品面值回收、科技树现有 11 条的费用、「讨价」只管局内买价。

## 九 落地（v4.34，PR #327，2026-10-24；v4.33 PR #326 顺手修了 248 逃跑结果页标题露出占位符）

执行按本文落地，偏差 / 补充：

1. **铁匠铺前置改成「行囊」`pack`**（第 0 列深度 3），不是「仓库」：前置仓库会落在深度 1、和保险箱并排，树宽到 1112，超过 `test_tech_tree` 的 792 上限；行囊往下就是保险箱、仓库，仍在仓库那条线上。集市前置「讨价」不变，放第 1 列深度 3。要改回前置仓库得先给树腾宽度。
2. 科技费用（本文没写数，执行定的占位，记在 `docs/techs.xlsx`，`check_content` 对照）：集市 600 / 1200 + 硬木板 ×2 / 2000 + 钢锭 ×2 + 铁钉桶 ×1；铁匠铺 500 / 1000 + 钢锭 ×2 / 1800 + 硬木板 ×2 + 铆钉盒 ×2。
3. 集市自己带稀有度权重 `MarketRules.rarity_weights [40, 30, 20]`，不读局内的 `shop_rarity_weights`（基地没有章节也就没有经济规则）；没有和 `ShopSession.candidates` 共用 —— 集市是白名单（remedy / food / ammo / material），局内是黑名单，各写各的。建材 supply 照卖（待定 1），武器防具不卖（待定 2）。
4. 上货时机：一局结算（撤离、战败都算）、升级集市、开发区改集市级数（改回 0 级清空）；打开基地时有集市却没货（老档）补一次。空包从 standard 包池抽，档次不超过当级的素材上限。
5. 铁匠铺「放不下」判得严：只看产物现在能不能进仓库，不算扣掉素材腾出的位置。扣素材按仓库顺序从前往后。图鉴走 `MetaState.light_codex`，和带出来是同一个计数。
6. 局内 `shop_sell_ratio` 0.3 **standard 与 prologue 两份都改了**（本文只写了 standard；序章也是局内）。
7. 「第一次局内卖东西提一次」没走 CoachOverlay 的步骤，而是接在「卖掉了」的告示后面说一次，记进 `coach_seen` 的 `shop_sell_hint`。出售区原来的 `shop.sell_tip`「回定价的一半」去掉，换成悬浮窗第二行 `sell_hint`；比例用新的 `UiText.tenths` 写「几成」（英文写百分数）。
8. 界面（占位，等美术设计样稿与作者的挑选）：两个页签排在出售后面，0 级不露；右半边仍是仓库。集市 = 一块素框里一排货位加铜价签，双击 / 右键买；铁匠铺每张配方一行：产物格（带框）+ 铭牌（有几 / 要几、钱）+「打造」主档木牌键。
9. 新内容种类 `base_rules`（market.json，数组字段总会导出，JSON 写全）与 `smith_recipes`（14 张，id `smith_<产物>`，秘银剑带占位说明）。字体重切补「砧」「购」。

## 十 补充一：界面定稿（作者 2026-10-24 14:49，美术设计线）怎么落到代码

作者原话（静态美术设计线 14:49:32）：「关于商店，做成古罗马风格的市场（木质凉棚）样式，货物摆在台子上且更散开。铁匠铺没有必要留个空间画铁砧，而是以左侧列表为大类，右侧格子平铺排列为各个道具显示，可以打造的道具亮起，不可打造的道具灰暗。点击具体的道具后在下方弹出界面显示需要的具体材料和数量。另外关于金钱一定要用金币图标而不是文本，铁匠铺的打造按钮要烧亮的铁红。升级商店和铁匠铺的选项应该是科技界面里，不会显示在本身页面」；14:45「如果要做页签的话就给所有基地页面都加上页签」；14:49 页签图标选乙 平墨。样稿 `/mnt/project-files/art/ui/base251/market2.png`、`smithy2.png`，美术等作者定稿后切图交 UI替换美术。下面是结构上要执行改的（美术换皮不在此列）。

### 10.1 集市（`ui/game/market_panel.gd`）

- **货散放在木台上**：不再是一排货位。摆法照 199 铸炉的办法 —— 底图 + `assets/ui/market/layout.json`（底图像素）：`tables`（几块台面的矩形）、`spots`（最多 8 个货位的左上角，按级数取前 4 / 6 / 8 个）、`sign`（招牌）、`funds`（钱袋读数在哪）。货位之间留空，不排成行。每个货位仍是一块小棋盘：那件的格子 + 一圈框（227 每块棋盘带框），散着摆不等于不带框。
- **价签 = 金币图标 + 数字**：`PriceTag` 加 `coin` 式（`assets/ui/hud/coin.png` 的小图 + 数字，不写「币」字）；卖掉的盖「已售」章（美术给图，没图先盖灰）。
- **页面上不写等级**：删 `market.level_line` / `market.level_bag` 在页面上的用法（那两句搬到科技卡 `TechFacility.describe_level`，科技页「现在 / 下一级」用）；没点出集市时整页只画空棚 + 一块「在科技页点出「集市」」的签（现有 `market.locked_tip`）。
- 买法不变（双击 / 右键「买」，右键菜单的价钱也用金币图标）。

### 10.2 铁匠铺（`ui/game/smithy_panel.gd`）

- **左列大类**：`SmithRecipeDef.group` 新字段，枚举 `blade 刀剑 / hammer 斧锤 / bow 弓 / staff 法杖 / shield 盾 / armor 护甲`（导入器必填）。首批 14 张：刀剑 = 短剑 / 砍刀 / 长剑 / 放血刀 / 溃烂之刃 / 秘银剑；斧锤 = 战锤 / 摆锤刃；弓 = 短弓 / 长弓；盾 = 圆盾；护甲 = 棉甲 / 皮甲 / 板甲；法杖暂无（列着，空）。左列是一排平的石键（230），选中的亮。
- **右边格子平铺**：当前大类下每张配方一格（产物按格子画在一块带框的小格里），**能打的亮、不能打的压灰**（亮 = `Smithy.can_forge` 返回空串；级不够、缺素材、钱不够、仓库满都灰，悬浮窗写原因）。格子行列按面板宽自动折行。
- **点一格 → 下方展开卷轴**（226 那种横向展开的告示卷轴样式，新 `RecipeScroll` 或复用 `NoticeScroll` 的壳）：产物名、每样素材「小图 + 有几 / 要几」、工钱「金币图标 + 数字」、右端一颗「打造」键。再点别的格子就换内容，点同一格收起。
- **「打造」键 = 烧亮的铁红**：四态图（美术出：normal / hover / pressed / disabled），用 `IconButton.make_art` 挂（和战旗一样）；没图之前用平键 + `UiPalette` 里新加的 `hot_iron` 色占位。
- **页面上不写等级**：删 `smithy.line_locked` / `smithy.level_line` 在页面上的用法（后者进科技卡）；级不够的只是灰格 + 悬浮窗「铁匠铺要几级」。
- 打完：产物那格闪一下、卷轴上的「有几」刷新；告示卷轴照说「打好了」。

### 10.3 钱的写法

两页里凡是价钱 / 工钱 / 钱袋读数都是**金币图标 + 数字**（`CoinLabel` 小控件：图 + 数字，一处写、两页用；局内商店以后也换它）。告示卷轴里的整句话（「买下「短剑」，花四十币」）是人话，照 112 写几十币，不插图标。

### 10.4 页签

基地七页（仓库 / 出售 / 科技 / 集市 / 铁匠铺 / 图鉴 / 成就）统一一排页签，每页一枚平墨图标（美术已切，`art/ui/base251/out/tab_icons/` → `assets/ui/base/tabs/`）+ 字；没点出的集市 / 铁匠铺页签照旧藏着（0 级不露）。页签样式沿现有木牌页签（163 的 `WarehousePages` 那套字形与高度），只是多了图标位。

### 10.5 不改的

Market / Smithy 两个核心类、配方 json 的其他字段、上货时机、三成 / 五成。

**10.1 补（第三版样稿，作者 15:57 在美术线改）**：集市只剩一张带透视的大平桌，货分前后两排。`layout.json` 的 `tables` 只有一项；每个 `spot` 带 `foot`（货底中点，底图像素）与 `scale`（后排小、前排大，货的格子按它缩），价签平放在货前面，「已售」章盖在价签上。铁匠铺背景改红砖墙 + 砖拱，六个大类键是平木牌（不是平石）。样稿 `market3.png` / `smithy3.png`。

## 十一 补充一落地（v4.39，PR #332，2026-10-24）

执行按 §十（含第三版格式）落地，偏差 / 细节：

1. 集市 `layout.json`：`tables` 一项（back_y / back_x / front_y / front_x / band，只给占位画用）；每个 spot 是 `foot` + `scale`，另有顶层 `cell` 作基准格长（spot 实际格长 = cell × scale × 整棚缩放）；按级数取前 4 / 6 / 8 个、前后两排交错；价签放在 foot 下方，后排先画、前排后画压在上面。右半边照旧是仓库（样稿整页铺满，§十没要求去掉仓库，执行没动 —— 作者若要整页集市，另说一声）。
2. 金币：新控件 `CoinLabel`；`PriceTag.coins` 金币式；右键菜单 `Action.coin` 字段，按钮右端画金币 + 数字，文字只写「买下」（新 key `act.buy_coin`）。
3. 铁匠铺：大类键用 `StoneChip.entry`（选中按下），木牌皮归 UI替换美术；`RecipeScroll` 的纸身与两头的轴借告示卷轴的图；打造键 `IconButton.make_art("res://assets/ui/smithy/", "forge_key", …)`，四态 forge_key / _hover / _pressed / _disabled，图上不带字；没图时 `UiTheme.BUTTON_FORGE` 平键，颜色 `UiPalette.HOT_IRON`。删了用不到的 key：smithy.line / line_locked / need_item / need_funds。英文大类「斧锤」= Hammers（Axes & Hammers 放不进左列）。
4. 顺带合进这一版：`TagRegistry.icon_path` 遇到 `faith:<神>` 返回 `assets/ui/faith/<神>.png`（UI替换美术要的信仰徽记）；饰物 / 贵重品两枚标签图标（250）。

## 十二 补充二：两页整页、打造界面铁砧配色（作者 2026-10-25 14:20，美术设计线）

作者原话（美术设计线，已核对）：14:20「集市里不需要显示仓库，铁匠铺里也不需要，重来」；14:21「另外铁匠铺的合成界面应该是铁砧配色的」。

### 12.1 整页

- `MetaScreen` 加 `FULL_TABS = ["market", "smithy"]`：切到这两页时右列（仓库木架 + 挂牌 + 页签）整列隐藏，中列吃满 —— `layout()` / `middle_width()` 已经有 `not _right.visible` 的分支（抽屉收起时用的），复用它；切回别的页再显示。隐藏不是销毁：仓库视图仍登记在拖拽层、`Market.buy` / `Smithy.forge` 照旧把东西放进仓库。
- 看不见仓库了，反馈全靠告示与读数：买下 / 打好照说「买下「短剑」，进了仓库」「打好了「短剑」，进了仓库」（文案 `market.bought` / `smithy.forged` 补「进了仓库」四个字）；「仓库放不下」照旧；两页右上角的钱袋读数（`CoinLabel`）留着。
- 美术的整页设计尺寸 **1600 × 1000**（横版）：`MarketStage` 把底图按中列的宽高「包含」缩放居中（和 199 铸炉一样），`layout.json` 的坐标全按这个设计尺寸重写（美术定稿后给坐标，执行只换 json）。集市：招牌、钱袋、一张大桌前后两排 8 个货位。铁匠铺：左列大类键约占宽的六分之一，右边格子区，底部约四分之一高留给弹出的打造界面；也从 layout.json 读（`keys` / `grid` / `scroll` / `funds` 四个矩形），没底图照旧用容器排。
- 页签不变（七页）；0 级的两页照旧藏。

### 12.2 打造界面铁砧配色

- `RecipeScroll` 不再借告示卷轴的纸：改成**铁砧铁灰的深底板**（`skin = "anvil"`），按 2026-10-12 的明暗规矩声明 `tone: dark` → 浅字（`UiPalette` 加 `ANVIL_IRON` 底色、`ANVIL_INK` 字色占位；美术给 `assets/ui/smithy/anvil_plate.png` 九宫格后换图，形状由美术定，可以是砧面的梯形，非矩形规矩）。缺素材的那几行用深底上的暖红（现有 `SHORT` a8331a 在铁灰上看不清，换 `UiPalette.WARN_ON_DARK`）。
- 打造键的烧红四态图不变；素材小图、金币读数的字色随 tone 取浅色。
- 页面其余（大类木牌键、格子区）配色不动，只有弹出的打造界面是铁砧色。

### 12.3 测试

`test_meta_full_tabs_251.gd`：切到 market / smithy 时 `_right` 不可见、中列宽 = 屏宽 − 两边距 − 左列；切回 warehouse 恢复；买一件后仓库多一件且告示含「进了仓库」。`RecipeScroll` 的 tone 为 dark、字色为浅色。

**12.1 补（美术定稿 14:23）**：底图实际为 **1300 × 950**（另有 @2x 2600 × 1900）—— 是 1600 × 1000 整页里中列 + 右列那一块，左列按钮不在底图里；执行按「包含」缩放居中即可，layout 坐标按底图像素、`size` 写 `[1300, 950]`。集市 layout：sign / funds / tables（一张）/ cell / spots（8 个 foot + scale）。铁匠铺 layout：keys / grid / scroll / funds / sign，另有 `face`（原尺寸时砧面上放内容的区）、`plate_nine`（九宫格四边）、`pointer`、`text_light #f0e8d8`、`text_missing #ff8a6a`，`tone: dark`。`smithy/anvil_plate.png` 是整块非矩形的铁砧剪影（九宫格横拉不变形）、`anvil_pointer.png` 指向选中格的小尖、`forge_key*.png` 四态 250 × 100 不带字（键面见 `forge_key.json`）。文件在 `/mnt/project-files/art/ui/base251/final/`（README.md 有说明），经 UI替换美术 转执行。

### 12.1 补二 UI替换美术 10-25 14:29 的落图尺寸（给执行，和 §十二 一起落）

- 两页底图 1300×950，坐标按底图像素（`base251/final/market/layout.json`、`smithy/layout.json`）。基地左列页签区宽 220，整页放在页签右边正好装下（1600 − 220 ≥ 1300）。
- 铁匠铺打造面板是一块铁砧：scroll 区 1228×348 在底图底部，九宫格横向可拉，四边留量见 layout 的 `plate_nine`。
- 大类木牌键 212×56 一个，六个竖排在 `keys` 区（x 48、y 190、宽 212，间隔 6，正好占满 366），五态 `assets/ui/smithy/cat_{normal,hover,pressed,on,disabled}.png`，九宫格左 14 / 右 30 / 上 14 / 下 14，字由代码写（粗体 22，墨色 #2e2219，压灰 #7d7064），说明在 `/mnt/project-files/art/ui/smithy_cats/README.md`。
- 集市效果图上「每局回来换一批货」那句在底图里没画：留这句就做成钉在左柱上的便条，皮用 `UiTheme.PANEL_SUMMARY_NOTE`。
- 252 的第七个大类「冶炼」：美术 10-25 14:48 已把 `keys` 区挪成 x 48、y 128、w 212、h 428（七块 56 高、间隔 6），layout.json 与 cut_final.py 同步改了；木牌皮通用，不用新图。
