# 250 标签整理：现状盘点与分类方式重切

作者 2026-10-24 11:39（架构设计线）：「整理一下目前的标签，给他们的分类方式做个区分」。本文先把 57 个标签按现状摆出来（哪一类、几件道具带、代码与数据谁在用），再指出分类混在一起的地方，最后给一套重切的分类方式；分类方式是设计改动，**作者定了再派执行**。

## 〇 一句话

现在六个大类（171：用途 / 属性 / 材料 / 归属 / 来源 / 内部）里，**「用途」一类装了 29 个标签，把「这件是什么」「它是哪一小类」「它值不值钱」「它是不是信物」四种事混在一起**；「属性」里混进了赐福 / 附魔 / 封印这些**状态**；「归属」与「来源」两个词说不清谁是谁。建议重切成 **类别（每件恰好一个）· 细类（挂在类别下）· 属性 · 材质 · 本源 · 归属 · 价值 · 状态 · 打法（内部）** 九轴，每一轴写明「一件能带几个」，导入器照规矩查；顺带退掉 5 个重复 / 孤儿标签，新增 1 个「饰物」。

## 一 现状盘点

164 件道具、57 个登记标签（另有 `faith:<神>` 六个动态标签，算归属）。「代码」= `&"tag"` 在 core / ui 里出现的文件数；「数据」= 敌人 / 池 / 信仰 / 铸炉 / 配方 / 科技 / 包池 / 掉落 / 事件 json 里引用的文件数。

### 1.1 用途 purpose（29 个）

| 标签 | 名 | 件 | 代码 | 数据 | 它其实是 |
|---|---|---|---|---|---|
| weapon | 武器 | 20 | 20 | 6 | 类别 |
| melee / ranged | 近战 / 远程 | 13 / 3 | 0 | 11 / 2 | 武器的细类（射程），敌人配装靠它 |
| bow / gun / staff | 弓 / 枪械 / 法杖 | 1 / 3 / 1 | 0 / 1 / 1 | — | 武器的细类（器形）；gun 已封存且 internal |
| armor / shield | 防具 / 盾 | 4 / 4 | 7 / 7 | — | 类别（护甲 / 格挡两套数值） |
| gear | 装备 | 6 | 1 | — | **多余的伞**：6 件全都另带 armor 或 shield |
| gear_plug | 防具插件 | 2 | 1 | — | 类别 |
| ammo | 弹药 | 4 | 2 | — | 类别 |
| crystal | 晶石 | 12 | 2 | 4 | 类别（法杖供给）；12 件全都另带 material + part + gem + magic + valuable，**一件六个标签** |
| remedy / food | 药剂 / 食物 | 12 / 5 | 3 / 6 | 21 / 6 | 类别 |
| tool | 工具 | 5 | 1 | — | 3 件是药（解毒包 / 药囊 / 万灵药另带 remedy），1 件撬棍另带 weapon，1 件无人机已封存 —— **没有一件只是工具** |
| material | 材料 | 71 | 4 | 6 | 类别；**名字和大类「材料（材质）」撞车** |
| part / supply / reagent | 零件 / 建材 / 试剂 | 21 / 10 / 8 | 1 / 0 / 1 | 9 / 2 / 2 | 材料的细类（19 件 part、10 supply、8 reagent 都带 material）；但 2 件 part 是**符号**（猎血者的符号、护身符），不是材料 |
| beast_part | 兽材 | 12 | 0 | — | 12 件全是 material + nature：说的是**从哪来**（魔兽身上），是归属不是用途 |
| trophy | 战利品 | 4 | 0 | — | 3 件兼 beast_part，1 件蛮族项链：也是「从哪来」 |
| treasure | 珍宝 | 13 | 8 | 4 | **价值标记**（值钱、不参战）：6 护符、5 工艺摆件、果果之心、灰白碎片 |
| valuable | 贵重品 | 18 | 1 | 0 | 价值标记（244：基地按面值收）：12 晶石 + 6 金银 |
| bullion | 金银 | 6 | 1 | 0 | 类别（244）；6 件只有 valuable + bullion，连材质都没有 |
| relic | 遗物 | 1 | 1 | — | 只剩灰白碎片一件 |
| keepsake | 特殊道具 | 2 | 8 | — | 类别（不进背包、代表能力） |
| faith_anchor | 信物 | 8 | 1 | — | **功能标记**：6 护符 + 赐福长弓（武器）+ 赐福盾（盾）—— 跨类别，不是用途 |

### 1.2 属性 element（8 个）

| 标签 | 件 | 代码 | 它其实是 |
|---|---|---|---|
| fire / ice / lightning / poison / bleed | 3 / 1 / 1 / 8 / 9 | 14 / 5 / 5 / 7 / 8 | 真正的属性（伤害类型 / 状态） |
| blessed | 2 | 1 | **状态**（205 赐福变体） |
| enchanted | 1 | 0 | **状态**（175 附魔） |
| sealed | 13 | 1 | **状态**（封存的现代道具）；是 internal 却归在属性 |

### 1.3 材料 material（10 个）：metal 40 / cloth 16 / leather 15 / gem 15 / wood 14 / flesh 12 / herb 12 / bone 10 / stone 8 / clay 7。干净：71 件材料件件恰好一个（195）。代码用它的只有重量（`ItemWeight`）与音效（`SfxMaterial`）。gem 的 15 件里 13 件是魔晶石（244 把宝石并进魔晶石后，「宝石」这个名字已经名不副实）。

### 1.4 归属 origin（5 个 + 动态）：faith 12 / imperial 5 / clockwork 5 / barbarian 2 / sigil 2，`faith:<神>` 六个。imperial / clockwork / barbarian 代码一处不用、数据也不用 —— 纯世界观。sigil「刻着神的符号」挂在两件**不是信仰道具**的东西上（猎血者的符号、护身符）。

### 1.5 来源 source（3 个）：nature 48 / crafted 34 / magic 15。干净（122 / 195：材料恰好一个，导入器查）。中文「来源」与「归属」两个词挨着说不清：一个是工艺 · 自然 · 魔法，一个是信仰 · 阵营。

### 1.6 内部 internal（5 个）：rapid 8 / burst 6 / heavy 4（打法，敌人配装靠它；heavy 还管重量与音效）、token 1（铸牌 —— 它其实是一个**类别**，只是藏着）、node_tooltips 1（望远镜的能力开关 —— **不是标签**，是借标签表放的能力 id）。

### 1.7 没有类别的（18 件）

15 个包只带材质（is_bag 另有旗子）；3 颗自然神的种子（铁木苗 / 月草籽 / 荆棘籽）只带 faith + 材质；蛮族项链只带 trophy + bone。

## 二 问题归纳

1. **「用途」不是一个轴**，是四个轴叠在一起：类别（weapon / armor / material……）、细类（melee / part……）、价值（treasure / valuable）、功能（faith_anchor）。排序、导入校验、悬浮窗都没法按它讲规矩。
2. **「一件能带几个」没有规矩**：类别本该每件恰好一个，现在晶石带两个（crystal + material）、三件药带两个（remedy + tool）、撬棍带两个（weapon + tool）；18 件一个都没有。
3. **状态混进属性**：赐福 / 附魔 / 封印是「这一件现在怎样」，不是火毒雷。
4. **「从哪来」散在三处**：beast_part（用途）、trophy（用途）、barbarian / imperial / clockwork（归属）。
5. **五个标签多余或错位**：gear（伞）、tool（没有纯工具）、relic（一件）、trophy（和 beast_part / barbarian 重）、sigil（两件非信仰物）。
6. **两处借标签办别的事**：node_tooltips 是能力 id；token 是类别却靠 internal 藏。
7. **命名**：material 标签 vs 「材料」大类；来源 vs 归属；gem「宝石」名下几乎全是魔晶石。

## 三 分类方式重切（推荐）

### 3.1 九轴

| 轴 | 英文 | 一件带几个 | 标签 | 悬浮窗 |
|---|---|---|---|---|
| **类别** | kind | **恰好一个**（包按 is_bag 免） | weapon 武器 / armor 防具 / shield 盾 / gear_plug 防具插件 / ammo 弹药 / crystal 魔晶石 / remedy 药剂 / food 食物 / material 材料 / **trinket 饰物（新）** / bullion 金银 / keepsake 特殊道具 / token 铸牌（internal） | 第一行第一个 |
| **细类** | subkind | 0～2，且**它的类别得在**（`TagDef.parent`） | 武器下：melee 近战 / ranged 远程（武器**恰好一个**）、bow 弓 / gun 枪械 / staff 法杖（器形，可选）；材料下：part 零件 / supply 建材 / reagent 试剂（最多一个） | 紧跟类别 |
| **属性** | element | 任意 | fire / ice / lightning / poison / bleed | 第二 |
| **材质** | material | 材料**恰好一个**，其他最多一个 | metal / wood / leather / cloth / bone / stone / gem→改名**晶体** / clay / flesh / herb | 第三 |
| **本源** | source | 材料恰好一个，其他可选 | crafted 工艺 / nature 自然 / magic 魔法 | 第四 |
| **归属** | affiliation | 任意 | faith 信仰 + `faith:<神>`、faith_anchor 信物、beast_part 兽材（魔兽身上取的）、barbarian 蛮族 / imperial 帝国 / clockwork 机关 | 第五 |
| **价值** | value | 任意 | treasure 珍宝（值钱、不参战、商店收）、valuable 贵重品（基地面值收） | 第六 |
| **状态** | state | 任意 | blessed 赐福 / enchanted 附魔 / sealed 封存（internal） | 第七（将来可改成名字前缀） |
| **打法** | style | 任意，**全 internal** | rapid / burst / heavy | 不列 |

「归属」改叫**归属**不动，「来源」改叫**本源**（工艺 · 自然 · 魔法说的是东西的本性，不是谁家的）。

### 3.2 退、改、增

| 动作 | 标签 | 怎么处理 |
|---|---|---|
| 退 | gear 装备 | 6 件删掉即可（都另带 armor / shield）；`GridTidy` 排序改看 armor / shield |
| 退 | tool 工具 | 三件药只留 remedy；撬棍只留 weapon；无人机（封存）留 sealed + keepsake 或直接只剩 sealed |
| 退 | relic 遗物 | 灰白碎片 → trinket + treasure；`ItemWeight` 的轻物表去掉 relic |
| 退 | trophy 战利品 | 三件兽材已带 beast_part；蛮族项链 → trinket + barbarian |
| 退 | sigil 符号 | 猎血者的符号、护身符 → trinket（去掉错标的 part）；`ItemWeight` 轻物表 sigil → trinket |
| 增 | **trinket 饰物** | 「摆在包里就生效、不出手不穿不吃的小件」：6 护符、2 符号、3 种子、蛮族项链、灰白碎片（13 件）。轻物（半格一重）。护符仍带 treasure（价值轴），行为不变 |
| 改 | crystal | 12 件去掉 material 与 part（类别恰好一个）。**要查**：铸炉 / 配方 / 掉落按 `material` / `part` 圈东西的地方是否圈到了晶石（数据里 part 9 处、material 6 处）—— 圈到了就改成按 gem / magic 圈，行为不变 |
| 改 | sealed_wine_jar | food + material 二选一：留 food（它是吃的） |
| 改 | gem | 名字改「晶体」，英文 Crystal → 和类别 crystal「魔晶石 Mana crystal」分开 |
| 改 | node_tooltips | 从标签表挪走：`ItemDef.keepsake_abilities: Array[StringName]`（望远镜写 `node_tooltips`），`KeepsakeDef` / 成就按它读；标签制作器少一个假标签 |
| 改 | token | 归类别轴，internal 照旧 |
| 改 | material 标签 | id 不动（71 件、代码 4 处），中文名改「**材料**」不变，但大类「材料」改叫「**材质**」避免撞名 |

### 3.3 代码

- `TagDef.category` 枚举 → `kind / subkind / element / material / source / affiliation / value / state / style`；加 `parent: StringName`（细类用）。`TagRegistry.CATEGORY_ORDER` 同步，`sorted_by_category` 不变。
- `ContentImporter._validate_item_tags`：类别恰好一个（is_bag 免）；细类的 parent 在；武器恰好一个 melee / ranged；材料恰好一个材质 + 一个本源（现有）；非材料最多一个材质。都是 error（和 171「没登记报错」一档），因为规矩不查就会回到今天。
- 标签制作器（171）：大类下拉改九项，细类多一个「挂在哪个类别下」。
- 悬浮窗标签行按 3.1 的列顺序（现有 `sorted_by_category` 自然做到）；打法不列（现有）。
- `GridTidy` / `CategoryBias` 等按标签排序圈选的地方对照退掉的 5 个标签改。
- 数据：约 60 份道具 json 改标签；57 份标签 json 改 category；新建 trinket.json；`bash tools/snapshot_content.sh`（标签不进存档，不需要 IdAliases）。
- 测试：`test_tag_taxonomy_250.gd` —— 每件道具恰好一个类别（包除外）、细类都有 parent、武器恰好一个射程、材料材质 / 本源各一、退掉的 5 个 id 没人再带、node_tooltips 不在标签表。

### 3.4 为什么这样切

- **每一轴回答一个问题**：是什么（类别）/ 哪一种（细类）/ 带什么劲（属性）/ 什么做的（材质）/ 从哪种力量来（本源）/ 谁家的（归属）/ 值不值钱（价值）/ 现在怎样（状态）。玩家读悬浮窗一行就是一句话：「武器 · 近战 · 流血 · 金属 · 工艺 · 帝国」。
- **规矩能查**：恰好一个 / 最多一个 / 任意，导入器一条条查，以后新道具不会再带六个标签或一个没有。
- **代码只认 id，不认轴**：战斗、重量、音效、经济代码一行逻辑不改，只有退掉的 5 个 id 要改引用。

## 四 待定（默认取推荐）

1. **包要不要一个类别标签 `bag`**：推荐**不要**，is_bag 旗子就是类别，导入器按它免检；悬浮窗包的那一行已经写「包」。
2. **crystal 去掉 material**：推荐去（恰好一个类别）；若铸炉表靠 material 圈晶石，改成按 gem 圈。备选：允许 crystal 带 material 当唯一例外 —— 不推荐，例外一开规矩就散。
3. **状态轴将来改成名字前缀**（赐福的 / 附魔的 / 封存的，像 246 的魔晶石）：本次不动，只归类。
4. **乙案（最小改动）**：不重切，只把 blessed / enchanted / sealed 挪去新建的「状态」类、beast_part / trophy 挪去归属、退 gear / tool / relic / sigil、来源改名本源。约 20 份 json，不加导入校验。能解燃眉，但「用途」仍是一锅。

## 五 不改的

标签的名字 / 说明 / 词条开关（107）、图标（193）、`faith:<神>` 动态标签、internal 旗子、材料恰好一个本源的规矩（122 / 195）、代码里按 id 判定的逻辑。

## 六 补充一：作者定稿（2026-10-24 14:42）与落地清单

作者原话：「首先，根据每种标签至多只显示一个，可能不显示。1. 用途：按你推荐的来。不过金银、珍宝统一属于贵重品，防具插件删掉（这是最初始的现代版本的遗留，完全可以连道具一起删除），武器统一只有武器，其余无效果道具统一为素材，信物本身不属于用途，遗物也改为素材 2. 属性保留，现代道具全部删除，封印标签保留留作其他机制用 3. 材质标签删除，相关神明信仰需要的标签也给我列个表，统一修改 4. sigil标签删除，信仰删除，只保留不同神的信仰，用于当信仰锚点 5. 不需要价值标签，尤其是不参战属于一个状态，跟标签无关 6. 状态也不属于标签。另外关于待定：前三条按你推荐来」。

### 6.1 定稿：四个给玩家看的轴 + 一个内部轴

| 轴 | 一件带几个 | 悬浮窗 | 标签 |
|---|---|---|---|
| **类别** kind | **恰好一个**（包按 is_bag 免） | 列一个 | weapon 武器 / armor 防具 / shield 盾 / ammo 弹药 / crystal 魔晶石 / remedy 药剂 / food 食物 / **material 素材**（原「材料」，零件 / 建材 / 试剂 / 兽材 / 遗物都归它）/ **valuable 贵重品**（珍宝 + 金银并入）/ **trinket 饰物（新）**/ keepsake 特殊道具 |
| **属性** element | 任意 | **最多列一个**（按道具里写的先后取第一个；溃烂之刃 bleed + poison 只列流血） | fire / ice / lightning / poison / bleed |
| **本源** source | 素材恰好一个，其余最多一个 | 最多列一个 | crafted 工艺 / nature 自然 / magic 魔法 |
| **归属** affiliation | `faith:<神>` 最多一个（现有规矩），其余任意 | 最多列一个（有神先列神） | `faith:<神>` 六个（**就是信物标记**）、beast_part 兽材、barbarian 蛮族 / imperial 帝国 / clockwork 机关 |
| **内部** internal | 任意 | 不列 | rapid / burst / heavy（打法）、melee / ranged / staff（武器配装）、part / supply / reagent（素材配装）、bullion（金银：面值回收 / 商店金银格 / 不计分）、token、sealed（留作别的机制） |

「每种标签至多只显示一个，可能不显示」：悬浮窗标签行按 类别 → 属性 → 本源 → 归属 各取一个，没有的轴跳过。一把铁刀只写「武器」；一块铁矿写「素材 · 自然」；蛮神护符写「饰物 · 蛮神」。细类不再需要 `parent` 字段：全是内部标签，`TagDef.category` 枚举只剩 `kind / element / source / affiliation / internal`。

### 6.2 五十七个标签各去哪

| 动作 | 标签 | 处理 |
|---|---|---|
| 留（类别） | weapon, armor, shield, ammo, crystal, remedy, food, keepsake | category = kind |
| 改名（类别） | material 材料 → **素材** | id 不动 |
| 并入（类别） | treasure 珍宝、bullion 金银 → **valuable 贵重品** | 13 件 treasure：6 护符 → trinket（见下），5 工艺摆件 + 异化黑曜石 → valuable（去掉 material），灰白碎片 → material（作者：遗物改素材），果果之心 → crystal（类别恰好一个，不再带 valuable）。bullion 6 件：类别 valuable，`bullion` 降为内部标签（代码 `is_bullion` 照用） |
| 新（类别） | **trinket 饰物** | 「摆在包里就生效、不出手不穿不吃」：6 护符、猎血者的符号、护身符（去掉错标的 part）、3 颗种子 |
| 并入（类别） | part / supply / reagent / beast_part / relic / trophy → 类别都是 material | part / supply / reagent 降为内部标签（敌人配装、经济黑名单、事件照用）；beast_part 改到归属轴；relic 删（1 件）；trophy 删（见 6.4 狩猎之神） |
| 删（类别） | gear 装备 | 6 件删标签；敌人 / 池 `gear` 改 armor + shield |
| 删（类别） | gear_plug 防具插件 | armor_plate 随现代道具删；**gambeson 贴身内甲改成 armor 棉甲**（它在开局装备 `loadouts/standard.json` 与 251 的铁匠配方里，删了两处要补）—— 待定 1 |
| 删（类别） | tool 工具 | 3 件药只留 remedy，撬棍随现代道具删，无人机删；6 个敌人 + 3 个池的 `tool` 改 remedy（药匠 / 巫医）或去掉 |
| 删（类别） | bow, gun, sigil, faith_anchor, faith | bow 1 件删标签；gun 随枪删；sigil 2 件 → trinket，`enemies/shieldbearer` 与 `faiths/earth` 里的 sigil 改 trinket；**faith_anchor / faith 删：信物 = 带 `faith:<神>` 的那件**（`ItemDef.is_anchor() = faith_tag() != &""`，`has_faith()` 同义；休眠规矩不变，因为带 faith 的本来就恰好带一个神） |
| 降内部 | melee, ranged, staff | 敌人配装靠它（melee 11 / ranged 2 / staff 4 个敌人）；武器恰好一个 melee / ranged（导入器查） |
| 留（属性） | fire, ice, lightning, poison, bleed | 不动 |
| 删（状态不是标签） | blessed, enchanted | blessed：`is_blessed()` 本就看 `blessed_of` 字段，标签多余；enchanted：秘银剑删标签，`enemies/core_guardian` 的 `enchanted` 改成按 id 配 mithril_sword |
| 降内部 | sealed | 作者：留作其他机制用；现代道具删完后暂时没人带 |
| **删（材质）** | metal, wood, leather, cloth, bone, stone, gem, clay, flesh, herb | 标签删，**材质改成 `ItemDef.material` 字段**（十选一的下拉，不显示、不进标签表）—— 重量（`ItemWeight`）、音效（`SfxMaterial`）、铸炉三张表的 `material` 行改读字段；素材类必填，其余可空（空 = 按「其余」算重量、皮革声）。`enemies/witch_doctor` 的 `herb` 改 remedy |
| 留（本源） | crafted, nature, magic | 不动；category = source |
| 留（归属） | barbarian, imperial, clockwork, `faith:<神>` | 不动 |
| 改轴（归属） | beast_part | purpose → affiliation |
| 留（内部） | rapid, burst, heavy, token | 不动 |
| 挪走 | node_tooltips | → `ItemDef.keepsake_abilities`（§3.2） |

### 6.3 现代道具全部删除（13 件）

armor 贴身甲、high_tier_armor 高级贴身甲、armor_plate 防弹装甲、battery 电池、core 能量核心、crowbar 撬棍、drone 无人机、mag 弹匣、medkit 医疗包、pistol 手枪、rifle 步枪、shotgun 霰弹枪、stim 兴奋剂。都进 `IdAliases.RETIRED_ITEMS` + `bash tools/snapshot_content.sh`（173）。执行逐个查引用再删：`core` 这个 id 和「核心节点」`core` 同名，`armor` 和标签同名，grep 会撒网 —— 池 / 章节里的 `"core"` 多半是节点不是道具；`pistol` 在 `enemy_placer.gd` 的注释示例里；medkit / stim / pistol / rifle / crowbar / mag / battery 在十来个测试与沙盒里当夹具，换成现有道具（绷带 / 药膏 / 短剑 / 箭 / 铜锭）。tests/inventory/test_sealed_items.gd 整个随之改写或删除。

### 6.4 神明信仰牵连的标签（作者要的表）

献祭 / 功绩 / 赐福里按标签认东西的条目，凡用到要删的标签（材质十个、trophy、gear、sigil、part、treasure）都列在这儿；「改成」是推荐，作者改 `docs/gods.xlsx` 对应 sheet 后 `GodsTable` 重导即可。

| 神 | 条目 | 现在 | 改成 | 为什么 |
|---|---|---|---|---|
| 蛮神 | 献祭 | bone ×5；flesh ×5；weapon ×2；≥9 格 ×10 | **beast_part ×5**；weapon ×2；≥9 格 ×10 | 骨与血肉几乎都是兽材（12 件 flesh 全带 beast_part） |
| 蛮神 | 赐福模板 | weapon | 不动 | — |
| 日神 | 献祭 | metal ×5；fire ×5；gem ×5；正好中体积 ×5 | fire ×5；**crystal ×5**；**valuable ×5**；正好中体积 ×5 | 宝石已并进魔晶石；金属没了，日神改爱金银 |
| 日神 | 赐福模板 | metal | **weapon + armor + shield** | 金属件基本就是装备 |
| 自然 | 献祭 | nature ×5；food ×5；gear / armor / shield ×5 | nature ×5；food ×5；armor / shield ×5 | 只去掉 gear |
| 自然 | 功绩 | nature | 不动 | 本源留着 |
| 自然 | 赐福模板 | shield；gear / armor / nature | shield；armor / nature | 去掉 gear |
| 大地 | 献祭 | ≥9 格 ×5 每格 | 不动 | — |
| 大地 | 其他（json 68–73 行有 sigil / part / treasure） | sigil、part、treasure | trinket、material、valuable | 执行看那段是什么条目再对应改 |
| 技巧 | 献祭 | metal ×5；gear / armor / shield ×5；带暴击 ×8；crafted ×5 | **weapon ×5**；armor / shield ×5；带暴击 ×8；crafted ×5 | 金属 → 武器（技巧之神功绩本就认武器） |
| 技巧 | 功绩 | metal；weapon | **crafted**；weapon | 金属 → 工艺 |
| 狩猎 | 献祭 | flesh / bone ×5；trophy ×10；leather ×5 | **beast_part ×10**；**food ×5** | 三行材质 + 战利品都是「从兽身上取的」，合成一行高倍；猎人吃肉 |
| 狩猎 | 功绩 | trophy | **beast_part** | trophy 删 |
| 新教 church | — | 没有按标签的条目 | — | — |

献祭的「人话」列（骨制品 / 金属 / 皮革 / 宝石）跟着改；帮助页 `help_pages/god_*.json` 里提到材质的句子一起改。

### 6.5 代码改动

- `TagDef.category` 枚举 → `kind / element / source / affiliation / internal`；`TagRegistry.CATEGORY_ORDER` 同步；不加 `parent`。
- `ItemDef.material: StringName`（十选一；`ContentSchema` 下拉；导入器：素材类必填、其余可空、值必在十个里）。`ItemWeight.formula` / `SfxMaterial` / `ForgeTable.material` 行改读它（本源三行仍读标签）。
- `ItemDef`：删 `FAITH` / `ANCHOR` / `BLESSED` 常量，`is_anchor() = faith_tag() != &""`，`has_faith()` 同义；`is_valuable()` 不变（现在是类别）；`is_bullion()` 读内部标签。treasure 的 8 处代码（经济黑名单、掉落、负重、整理、商店）改成 `valuable`。
- 悬浮窗 `item_tooltip.gd` 101–103：按轴各取第一个（`TagRegistry.first_per_category`），内部不列。`GridTidy` 分组表改成新类别；`CategoryBias` 对照。
- 导入器 `_validate_item_tags`：类别恰好一个（is_bag 免）；武器恰好一个 melee / ranged；素材恰好一个本源 + 必填材质字段；带 `faith:<神>` 最多一个（已有）。
- 标签制作器（171）：大类下拉五项；道具编辑器多一个「材质」下拉。
- 数据：57 份标签 json（删 20、改 category）、约 110 份道具 json（删材质标签 → 填字段、换类别）、7 份信仰 json 由 gods.xlsx 重导、11 个敌人 + 3 个池的 gear / tool / sigil / herb / trophy / enchanted、`loadouts/standard.json`、`smith_recipes/smith_gambeson.json`、`base_rules/market.json` 的黑名单（treasure / bullion → valuable；faith → 没了，`faith:*` 用前缀拦）、`economy_rules` 两份的 `shop_exclude_tags`、字体子集（新字「饰」「素」等）。
- 测试：`test_tag_taxonomy_250.gd`（每件恰好一个类别、武器恰好一个射程、素材有本源与材质、删掉的 20 个 id 没人带、13 件现代道具不在库、悬浮窗每轴最多一个）；改写 test_sealed_items 等夹具。

### 6.6 待定（默认取推荐）

1. **gambeson 贴身内甲**：推荐**改成 armor「棉甲」**而不是删（它是开局装备、也是 251 的一张配方）。
2. **四件带 `faith:<神>` 却不是信物的**（铁木苗 / 月草籽 / 荆棘籽 / 胫骨 tibia_violence）按作者的规矩**变成信物**：放进包就激活那位神。推荐照规矩来；若种子不该激活信仰，去掉它们的 `faith:nature`（改成只是自然之神风味的饰物）。
3. **果果之心**不再带贵重品（类别恰好一个 = 魔晶石）：基地不再按面值收它。推荐接受 —— 它是拿来用的。
4. 日神 / 技巧之神 / 狩猎之神的献祭替换见 6.4，作者改表即可。

交执行落地；美术：饰物 / 贵重品两枚新标签图标（193）按 2026-10-24 10:45 规矩先出样。
