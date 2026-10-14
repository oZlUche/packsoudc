# 真实存档回归样本（173 §3.4）

每个子目录是一份存档，目录名用日期（`2026-10-20/`），里面放 `meta.json`、可选 `run.json`，以及 `expected.json`：

```json
{"refunded": ["sniper"]}
```

`tests/run/test_save_reliability_173.gd` 把每一份读一遍，断言：读得回来、报告里 `dropped` 为空、
折钱的道具 id 和 `expected.json` 的 `refunded` 一致（没写就必须为空）。

- **作者的真实存档**（待定 3 A）：每次升版或每月放一份。存档在
  `%APPDATA%\Godot\app_userdata\背包搜打撤\slots\<n>\` 下（`meta.json` / `run.json`），几 KB，没有隐私。
- 合并前想知道这次更新会不会动到自己的档：`bash tools/check_saves.sh`（只读，打印每一位的修复报告，不写文件）。
- `2026-10-14-synthetic/` 是合成样本（不是真实存档）：模拟删了三件、改名一件、一件放不回原位，守着对账层本身。
