## D2 猎手 hunter_1 档位对照

日期 2026-11-11；`tools/bench_hunters.gd -- hunter_1 100 res://data/authoring/calibration/archetypes.json free_mode ascension_3`：108 份木桩（每个步数段 27 份），每档 100 场，假节点抽样。wanted = 猎手表给这一段的档，best = 最接近五成的档。

| 步数段 | 木桩 | wanted 档 | best = wanted | best 比 wanted 高 | best 比 wanted 低 | wanted 档胜率中位（四分位） | 高一档胜率中位 |
|---|---|---|---|---|---|---|---|
| 0～4 | 27 | 0 | 0 | 27 | 0 | 100%（98～100%） | 54% |
| 5～9 | 27 | 1 | 14 | 13 | 0 | 81%（71～86%） | 25% |
| 10～19 | 27 | 2 | 17 | 10 | 0 | 78%（62～94%） | 1% |
| 20～∞ | 27 | 3 | 17 | 0 | 10 | 30%（7～67%） | — |

逐份木桩的原始输出见 `d2-hunter-raw.txt`。
