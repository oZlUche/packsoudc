# 科技树配置表（镜像）

> **源是 `docs/techs.xlsx`**，这份由 `tools/techs_xlsx_to_json.gd` 生成，别手改：改表、跑工具，再跑 `tools/import_content.gd`。
> 是否点亮不在这里，看存档的 `tech_levels`（119）。列的含义见表里的「说明」页。

## 节点

| id | 名称 | 英文名 | 列 | 排序 | 前置 | 说明 | 英文说明 | 效果构件 | 构件参数 | 每级说明模板 |
|---|---|---|---|---|---|---|---|---|---|---|
| pack | 行囊 | Travel Pack | 0 | 0 | safe_box | 死里逃生：战败时保住身上一部分钱，级数越高留得越多。 | Keep part of the coins you're carrying if you die; higher levels keep more. | tech_run_buff | {"effect": "keep_on_death"} | 战败时保住身上一部分钱 |
| safe_box | 保险箱扩格 | Bigger Safe | 0 | 0 | warehouse | 局内的保险箱多出格子，撤不出来也能多保住几件。 | The safe in a run gets more cells, so more is kept even if you fail to extract. | tech_safe_size | {"rows": 1} |  |
| warehouse | 仓库扩建 | Warehouse Expansion | 0 | 0 |  | 仓库多一页，放得下更多带回来的东西；各页独立，左边的页签切换。 | One more Warehouse page for what you bring back; each page is separate, switch with the tabs on the left. | warehouse_pages |  |  |
| endurance | 耐久 | Endurance | 1 | 0 |  | 体力上限更高，在图上走得更远：按角色自己的体力上限加百分比。 | Higher max Vitality, so you travel further on the map: a percentage of the character's own max Vitality. | tech_run_buff | {"effect": "vitality_max_bonus"} | 体力上限 {vitality_max_bonus_percent\|signed}% |
| undaunted | 不屈 | Undaunted | 1 | 0 | sinew | 打输了少扣体力，最少还是扣一点。 | Lose less Vitality when you lose a battle, but always at least one point. | tech_run_buff | {"effect": "loss_discount"} | 打输了少扣 {loss_discount_amount} 点体力（最少扣一点） |
| sinew | 筋骨 | Sinew | 1 | 1 | endurance | 开局生命上限更高：按角色自己的生命加百分比。 | Higher max Health at the start: a percentage of the character's own Health. | tech_run_buff | {"effect": "stat_bonus"} | 开局生命 {stat_bonus_amount\|signed}% |
| luck | 幸运 | Fortune | 2 | 0 | thorough_search | 敌人的东西更容易掉。 | Enemies drop their things more often. | tech_run_buff | {"effect": "luck_bonus"} | 幸运 {luck_bonus_amount\|signed}：敌人的东西更容易掉 |
| hauling | 扛重 | Hauling | 1 | 2 | endurance | 背得更多再开始吃力：按角色自己的负重上限加百分比。 | Carry more before it gets heavy: a percentage of the character's own Load limit. | tech_run_buff | {"effect": "carry_capacity_bonus"} | 负重上限 {carry_capacity_bonus_percent\|signed}% |
| scouting | 侦察 | Scouting | 2 | 0 | bargain | 隐形的猎手走近到一定距离就看得见。 | Hidden hunters become visible once they come close enough. | tech_run_buff | {"effect": "scout_range"} | 侦察距离 {scout_range_range} |
| thorough_search | 细搜 | Thorough Search | 2 | 0 |  | 每个搜索点能多搜几次。 | Search each search spot a few more times. | tech_run_buff | {"effect": "extra_searches"} | 每个搜索点多搜 {extra_searches_amount} 次 |
| bargain | 讨价 | Haggling | 2 | 1 | luck | 商店的东西更便宜。 | Shop prices are lower. | tech_run_buff | {"effect": "shop_price_mult"} | 商店售价 ×{shop_price_mult_factor} |
| market | 高级货物 | Finer Goods | 1 | 2 | bargain | 集市进更好的货：级数越高，货格越多、素材档次越高。 | The market stocks finer goods: higher levels mean more slots and better materials. | tech_facility | {"facility": "market"} |  |
| smithy | 高级配方 | Advanced Recipes | 0 | 1 | pack | 铁匠铺接更难的活：级数越高，打得出的配方档次越高。 | The smithy takes on harder work: higher levels unlock better recipes. | tech_facility | {"facility": "smithy"} |  |
| mithril_smelting | 秘银冶炼 | Mithril Smelting | 0 | 0 | smithy | 学会炼秘银：银锭加钱炼成秘银锭，再用它打更好的刀剑。 | Learn to smelt mithril: turn Silver Ingots and coins into Mithril Ingots, then forge better blades with them. | tech_recipes | {"tech": "mithril_smelting"} |  |
| staffcraft | 法杖工艺 | Staffcraft | 1 | 0 | smithy | 学会做法杖：级数越高，做得出的杖越好。 | Learn to make staves: higher levels make better staves. | tech_recipes | {"tech": "staffcraft"} |  |

## 等级

| 科技 id | 级 | 钱 | 材料 | 效果参数 |
|---|---|---|---|---|
| pack | 1 | 400 |  | {"percent": 20} |
| pack | 2 | 800 |  | {"percent": 30} |
| pack | 3 | 1200 | tanned_leather: 2；linen_bolt: 1 | {"percent": 50} |
| safe_box | 1 | 300 |  |  |
| safe_box | 2 | 600 | nail_keg: 1；steel_ingot: 1 |  |
| warehouse | 1 | 100 |  |  |
| warehouse | 2 | 200 |  |  |
| warehouse | 3 | 400 |  |  |
| warehouse | 4 | 600 | steel_ingot: 2 |  |
| warehouse | 5 | 900 | hardwood_plank: 2；steel_ingot: 3；nail_keg: 1 |  |
| warehouse | 6 | 1300 | hardwood_plank: 3；rivet_box: 2；steel_ingot: 4 |  |
| endurance | 1 | 200 |  | {"percent": 20, "amount": 0} |
| endurance | 2 | 500 |  | {"percent": 40, "amount": 0} |
| endurance | 3 | 900 |  | {"percent": 60, "amount": 0} |
| undaunted | 1 | 800 | hardwood_plank: 2；steel_ingot: 2 |  |
| sinew | 1 | 300 |  | {"mode": "MULT", "amount": 10} |
| sinew | 2 | 700 |  | {"mode": "MULT", "amount": 20} |
| sinew | 3 | 1200 | copper_ingot: 2 | {"mode": "MULT", "amount": 30} |
| luck | 1 | 400 |  |  |
| luck | 2 | 800 |  | {"amount": 2} |
| luck | 3 | 1300 | hardwood_plank: 2；rivet_box: 2 | {"amount": 3} |
| hauling | 1 | 300 |  | {"percent": 15, "amount": 0} |
| hauling | 2 | 700 | beast_hide: 1；rope_coil: 2 | {"percent": 30, "amount": 0} |
| hauling | 3 | 1200 | tanned_leather: 2；hardwood_plank: 1 | {"percent": 50, "amount": 0} |
| scouting | 1 | 1500 | steel_ingot: 3；hardwood_plank: 2；rivet_box: 2 | {"range": 3} |
| thorough_search | 1 | 250 |  |  |
| thorough_search | 2 | 700 |  | {"amount": 2} |
| bargain | 1 | 500 |  | {"factor": 0.95} |
| bargain | 2 | 1000 | silver_ingot: 1 |  |
| market | 1 | 1200 | hardwood_plank: 2 |  |
| market | 2 | 2000 | steel_ingot: 2；nail_keg: 1 |  |
| smithy | 1 | 1000 | steel_ingot: 2 |  |
| smithy | 2 | 1800 | hardwood_plank: 2；rivet_box: 2 |  |
| mithril_smelting | 1 | 1500 | silver_ingot: 2；crystal_shards: 3 |  |
| staffcraft | 1 | 600 | crystal_shards: 3 |  |
| staffcraft | 2 | 1200 | fire_crystal_low: 1 |  |
| staffcraft | 3 | 2000 | silver_ingot: 2；fire_crystal: 1 |  |
