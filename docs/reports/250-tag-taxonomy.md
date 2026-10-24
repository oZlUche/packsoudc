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
