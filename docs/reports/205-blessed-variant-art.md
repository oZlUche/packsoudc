# 205 赐福版道具的贴图：沿用原件图 + 信仰印记

> 架构设计 thread · 2026-10-19 · 提案（作者 17:30「这种被赐福的亚种道具还缺少贴图，检查并转交美术处理」，附图：棋盘上「蛮神赐福的魔法杖」是蓝色块 + 名字）

## 0 一句话

赐福版是 095 从原件**派生**的（id = `<原件>_<神>`，形状、格子完全同原件，只改名字、标签、稀有度、价值与信力加成），一共约 92 件（65 件原件 × 4 位有赐福模板的神），不值得也不该一件件画。
改法：`ItemPainter.art_of` 认不出赐福版的 id 时**退回原件的图**（有自己的图仍优先），再在图上盖一枚**信仰印记**（小徽记，不随道具旋转，贴在脚印右下那一格）。
代码一处（执行）；印记 7 枚（美术）。印记没到之前先用 HUD 现有的 `assets/ui/faith/<id>.png`（32 px 圆徽），所以代码可以先落。

## 1 现状（核过）

| 项 | 现状 |
|---|---|
| 派生 | `Blessings.derive`：`out = def.duplicate(true)`，`id = base_faith`，`display_name = 前缀 + 原名`，`blessed_of = base`；形状不变 |
| 哪些神 | 有赐福模板的：蛮神（weapon）、日神（metal）、大地之神（盾 ≥ 5 格 / 任意 ≥ 5 格）、自然之神（盾 / gear·armor·nature）；新教、狩猎、技巧没有模板 |
| 数量 | 按模板在 127 件上推算：自然 43、日神 26、蛮神 13、大地 10，共 **92** 件，涉及 65 件原件，**原件全部有图** |
| 查图 | `ItemPainter.art_of`：`art_ids().has(def.id)` 查 `manifest.json`，赐福版 id 不在清单 → null → 色块 + 名字（附图就是这样） |
| 手写的赐福件 | `blessed_longbow`、`blessed_shield` 是独立文件、有图，不走派生（`is_blessed()` 为假） |
| 下游 | 图鉴 `meta_screen` 的异体页（原件 / 蛮神版…）与棋盘、仓库、地面（198 轮廓取 `_art_image`）都经 `art_of`；战利品剪影不用图（087） |
| 徽记 | `assets/ui/faith/<id>.png` 7 枚 32 px 圆徽（166，HUD 信仰槽用） |

## 2 规则

### 2.1 图的来源

`ItemPainter.art_id_of(def) -> StringName`：清单里有 `def.id` → 它；否则 `def.is_blessed()` 且清单里有 `def.blessed_of` → 原件；否则空。`art_of` 改查它。
以后美术真想给某个赐福版单独画（比如「日神赐福的秘银剑」），放 `assets/items/<base>_<faith>.png` 进清单就自动用上，不改代码。

### 2.2 印记

- 文件：`assets/items/marks/<faith_id>.png` 24 × 24，`marks/@2x/<faith_id>.png` 64 × 64；缺的退回 `assets/ui/faith/<faith_id>.png`（`UiTheme.art_cached` 走法，画在 `_draw` 里必须缓存）。
- 位置：**不随道具旋转**，永远正着。贴在当前朝向脚印**最靠右下的那一格**（`cells_rotated(rot)` 里 y 最大、再 x 最大）的右下角，内缩 `cell × 0.06`，边长 `cell × 0.4`（60 px 格 = 24 px）。印记是「盖上去的章」，不是图的一部分，所以不进 `art_transform`。
- 时机：`draw_art` 画完图之后、调用方画内容物之前；`modulate` 同图（图鉴未点亮的灰化一起灰）。
- 没图的赐福版（原件也没图，目前为 0）照旧色块 + 名字，不盖印。
- 地面：198 的轮廓取 `_art_image`，走原件图，印记不算碰撞。
- 不加信仰色调（tint）：稀有度已经靠图说话，再压一层色会和稀有度梯子打架（item-art-rules）。

### 2.3 美术要出的

| 项 | 要求 |
|---|---|
| 7 枚印记 | 蛮神 / 新教 / 大地 / 狩猎 / 自然 / 技巧 / 日神各一（现在只有 4 位有模板，7 枚一起出，以后加模板不回头） |
| 样子 | 「神的印记」：像封蜡章或烙印，圆或盾形底 + 该神的符号（和 HUD 徽记同一符号系统），风格 A 墨线平涂，1 px 墨线外描边 |
| 尺寸 | 24 × 24（+ @2x 64 × 64），透明底，符号占满直径的 80%，在 24 px 下能认出是哪位神 |
| 对比 | 要压在任何道具图上、以及包底 `#2f3542` 上都看得见：底色不透明、外描边深色 |
| 交付 | `/mnt/project-files/art/items/marks/<faith_id>.png` 与 `marks/@2x/`，交给 架构方案执行 拷进 `assets/items/marks/` |

## 3 改动

| 文件 | 改什么 |
|---|---|
| `ui/inventory/item_painter.gd` | `art_id_of(def)`（§2.1）；`art_of` 改查它；`draw_art` 末尾盖印记（§2.2）；印记贴图走 `UiTheme.art_cached` 式缓存，`clear_art_cache` 一起清 |
| `assets/items/marks/`（新） | 美术到了放进去；`tools/sync_item_art.sh` 加一段：源目录里有 `marks/` 就一并拷（不进 manifest） |
| `tests/ui/test_blessed_art_205.gd`（新） | ① 派生的赐福版 `art_of` 与原件返回同一张贴图；② 清单里有同名 `base_faith` 时优先用它（用临时清单 + `clear_art_cache`）；③ `draw_art` 对赐福版返回 true；印记贴图 `mark_of(faith)` 有 marks 取 marks、没有退回 ui/faith；④ 图鉴异体页的赐福版瓦片有图；⑤ 印记落点：L 形四个朝向各算一次，落在最右下那格 |
| `docs/architecture.md` | 201 那段加一句：赐福版沿用原件图 + 印记 |

落地顺序：执行现在就落（印记用 HUD 徽记顶上）；美术 7 枚印记到了，执行拷文件、测试、合并，不改代码。

## 4 待定（按推荐做）

| # | 事 | 推荐 | 另一选 |
|---|---|---|---|
| 4.1 | 印记随不随道具转 | 不转（章是盖上去的，总是正的） | 跟着图转 |
| 4.2 | 印记位置 | 脚印右下那一格的右下角 | 包围盒右下角（L 形会落在空格上） |
| 4.3 | 印记大小 | 0.4 格 | 0.5 格（1 格的小件会遮掉近半张图） |
| 4.4 | 美术印记没到之前 | 先用 HUD 圆徽，代码先落 | 等印记一起落 |

## 5 不做

- 一件件画赐福版（92 件，而且模板一改数量就变）。
- 信仰色调 / 发光（和稀有度梯子打架）。
- 手写的 `blessed_longbow` / `blessed_shield`：有自己的图与功能，不盖印（它们 `is_blessed()` 为假，自然不盖）。

## 6 落地（架构方案执行 · 2026-10-19 · v3.46）

按 §3 落了，待定 4.1–4.4 按推荐，没有偏离。

- `ItemPainter.art_id_of(def)`：清单有自己的 id → 自己；赐福版且清单有 `blessed_of` → 原件；否则空。`art_of` 改查它。现有的赐福版全部拿到原件的图（同一张贴图对象）。
- 新增 `faith_of(def)`（id 去掉 `原件_` 前缀，只认派生的赐福版）、`mark_of(faith, cell_px)`（`assets/items/marks/` 优先，格子大于 60 取 `@2x/`，没有退回 `assets/ui/faith/`；进 `_art` 缓存，`clear_art_cache` 一起清）、`mark_rect(def, rot, anchor, cell)`（§2.2 的落点）。
- `draw_art` 画完图、复位变换后盖印记，`modulate` 同图（图鉴没点亮一起压暗）。地面的 `base` 变换照常相乘，印记跟着落地动画走，但不跟着朝向转。
- `tools/sync_item_art.sh`：源目录有 `marks/`（与 `marks/@2x/`）就一并拷进 `assets/items/marks/`，不进清单。
- `tests/ui/test_blessed_art_205.gd`：§3 的 ①～⑤ 五组。② 是直接往 `art_ids()` 的字典里塞一个赐福版 id，再 `clear_art_cache` 复原，不写临时清单文件。
- `docs/architecture.md` v3.46：201 那段加了「赐福版（205）」一段。
- 印记现在用的是 HUD 的 32 px 徽记（缩到 0.4 格）。美术的 7 枚到了只拷文件：`bash tools/sync_item_art.sh <含 marks/ 的目录>`，不改代码。
- 全量测试 23697 项断言、185 个套件全绿。

### 6.1 印记到位（同日）

美术设计交来 7 枚封蜡章印记（`/mnt/project-files/art/items/marks/`，24 px 与 `@2x/` 64 px，RGBA 透明底），已拷进 `assets/items/marks/` 并导入，没有改代码。测试 ③ 加了尺寸核对：有 marks 的取 marks，1x 是 24 px，@2x 是 64 px。全量测试 23711 项断言全部通过。
