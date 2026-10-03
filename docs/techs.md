# 科技树配置表（镜像）

> **源是 `docs/techs.xlsx`**，这份由 `tools/techs_xlsx_to_json.gd` 生成，别手改：改表、跑工具，再跑 `tools/import_content.gd`。
> 是否点亮不在这里，看存档的 `tech_levels`（119）。列的含义见表里的「说明」页。

## 节点

| id | 名称 | 英文名 | 列 | 排序 | 前置 | 说明 | 效果构件 | 构件参数 | 每级说明模板 |
|---|---|---|---|---|---|---|---|---|---|
| pack | 行囊 | Travel Pack | 0 | 0 | safe_box | 出发时多带一笔钱。 | tech_run_buff | {"effect": "starting_funds_bonus"} | 开局钱 {starting_funds_bonus_amount\|signed} |
| safe_box | 保险箱扩格 | Bigger Safe | 0 | 0 | warehouse | 局内的保险箱多出格子，撤不出来也能多保住几件。 | tech_safe_size | {"rows": 1} |  |
| warehouse | 仓库扩建 | Warehouse Expansion | 0 | 0 |  | 仓库往下长，放得下更多带回来的东西；仓库里的东西原地不动。 | warehouse_rows |  |  |
| endurance | 耐久 | Endurance | 1 | 0 |  | 体力上限更高，在图上走得更远。 | tech_run_buff | {"effect": "vitality_max_bonus"} | 体力上限 {vitality_max_bonus_amount\|signed} |
| undaunted | 不屈 | Undaunted | 1 | 0 | endurance | 输给节点敌人的头一次不扣体力。 | tech_run_buff | {"effect": "free_losses"} | 前 {free_losses_amount} 次输给节点敌人不扣体力 |
| sinew | 筋骨 | Sinew | 1 | 1 | endurance | 开局生命上限更高。 | tech_run_buff | {"effect": "stat_bonus"} | 开局生命 {stat_bonus_amount\|signed} |
| luck | 幸运 | Fortune | 2 | 0 | thorough_search | 敌人的东西更容易掉。 | tech_run_buff | {"effect": "luck_bonus"} | 幸运 {luck_bonus_amount\|signed}：敌人的东西更容易掉 |
| scouting | 侦察 | Scouting | 2 | 0 | luck、bargain | 隐形的猎手走近到一定距离就看得见。 | tech_run_buff | {"effect": "scout_range"} | 侦察距离 {scout_range_range} |
| thorough_search | 细搜 | Thorough Search | 2 | 0 |  | 每个搜索点能多搜几次。 | tech_run_buff | {"effect": "extra_searches"} | 每个搜索点多搜 {extra_searches_amount} 次 |
| bargain | 讨价 | Haggling | 2 | 1 | thorough_search | 商店的东西更便宜。 | tech_run_buff | {"effect": "shop_price_mult"} | 商店售价 ×{shop_price_mult_factor} |

## 等级

| 科技 id | 级 | 钱 | 材料 | 效果参数 |
|---|---|---|---|---|
| pack | 1 | 400 |  | {"amount": 50} |
| pack | 2 | 800 |  | {"amount": 100} |
| pack | 3 | 1200 | tanned_leather: 2；linen_bolt: 1 | {"amount": 150} |
| safe_box | 1 | 300 |  |  |
| safe_box | 2 | 600 | nail_keg: 1；steel_ingot: 1 |  |
| warehouse | 1 | 100 |  |  |
| warehouse | 2 | 200 |  |  |
| warehouse | 3 | 400 |  |  |
| warehouse | 4 | 600 | steel_ingot: 2 |  |
| warehouse | 5 | 900 | hardwood_plank: 2；steel_ingot: 3；nail_keg: 1 |  |
| warehouse | 6 | 1300 | hardwood_plank: 3；rivet_box: 2；steel_ingot: 4 |  |
| endurance | 1 | 200 |  |  |
| endurance | 2 | 500 |  | {"amount": 2} |
| endurance | 3 | 900 |  | {"amount": 3} |
| undaunted | 1 | 800 | hardwood_plank: 2；steel_ingot: 2 |  |
| sinew | 1 | 300 |  | {"amount": 5} |
| sinew | 2 | 700 |  | {"amount": 10} |
| sinew | 3 | 1200 | copper_ingot: 2 | {"amount": 15} |
| luck | 1 | 400 |  |  |
| luck | 2 | 800 |  | {"amount": 2} |
| luck | 3 | 1300 | hardwood_plank: 2；rivet_box: 2 | {"amount": 3} |
| scouting | 1 | 1500 | steel_ingot: 3；hardwood_plank: 2；rivet_box: 2 | {"range": 3} |
| thorough_search | 1 | 250 |  |  |
| thorough_search | 2 | 700 |  | {"amount": 2} |
| bargain | 1 | 500 |  | {"factor": 0.95} |
| bargain | 2 | 1000 | silver_ingot: 1 |  |
