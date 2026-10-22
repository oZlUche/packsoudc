# 233 · 方案：商店换成集市帐篷（局内非矩形 · 第二轮之一）

> 架构设计线程，2026-10-21。来由：232 第一轮时作者 19:23 说「3 的商店要考虑时代背景，古代风格或者魔幻风格」；美术设计出四个方向（甲 罗马店铺 / 乙 集市帐篷 / 丙 行商篷车 / 丁 魔晶秘店），作者 21:42 在方向卡上选 **乙 集市帐篷**。细稿 22:02 到：`/mnt/project-files/art/ui/nonrect/tent/`（README「商店定稿：集市帐篷」一节，`out/tent.json` 摆位，`mocks/shop_before_after.png` 前后对比，`ingame_try.diff` 只是摆位证据）。本文只做方案，不实施。
> 战斗三屏的边框作者 21:44 曾改成「斗兽场样式，横着的椭圆形，上半部分从界面后面穿过」；22:23 作者在美术设计原话「目前斗兽场还没有办法完美融合进界面，先放弃吧」—— **斗兽场作废**，战斗三屏保留 v3.79 的青铜板，不另开报告。

## 〇 一句话

商店叠层窗（`ShopScreen` 的 `OverlayFrame`）的石板换成帐篷：篷面是一张九宫格（门帘、木杆、油灯、地毯、流苏都靠 `expand_margin` 画在窗外），窗顶正中加一个尖顶和一块布招牌，标题字照旧写在标题条上、正好落在布牌红面上。内容区边距不变，店里的货架、随身栏、出售区、右边背包一动不动。

## 一、现状（v3.87 核过）

- `ui/game/shop_screen.gd` `open()`：`_centered_panel(Vector2(0, 0))` → 石板 `OverlayFrame`（`UiTheme.slab`，`slab_edge` 九宫格 + 标题条 14..50），`_frame_title(UiText.t("node.label.shop"))`；左列 店 / 右列 背包，`_hbox(24)`。
- `OverlayFrame._init(margin, p_bronze, p_book)`（232 落地后）：三种皮各走一条 `_init_*`；`GameScreen._centered_panel(min_size, margin, bronze, book)`。
- 商店窗离顶栏（`HudHost.bar_height_in`）只有 50 多 px（美术设计量的，v3.85 截图 `mocks/shop_now_v385.png`）。

## 二、改法

### 2.1 皮

`tent.json`（都是左上右下）：

| 件 | 文件 | 怎么摆 |
|---|---|---|
| 篷面 | `tent_front.png` 1476 × 884（画的面板 1292 × 814），九宫格 | `StyleBoxTexture`：`texture_margin [126, 94, 126, 80]`，**`expand_margin [92, 30, 92, 40]`**（门帘、木杆、油灯往外 92，地毯和流苏挂在窗下 40，檐往上 30），`content_margin [24, 14, 24, 30]`（和石板一样，内容不挪），STRETCH，tone light。门帘里侧最多伸进窗 22，左右内边距 24 刚好盖住 |
| 尖顶 | `tent_peak.png` 420 × 58 | 左上 = 窗 (W/2 − 210, −56)，最高到 −54 |
| 布牌 | `tent_sign.png` 276 × 74 | 左上 = 窗 (W/2 − 138, −4)；字区 `field_in_sign [17, 19, 242, 34]`，中心 = 窗 (W/2, 32) |
| 标题 | 代码写 | 标题条照旧 14..50；字居中、serif_bold 22、`#f2e7cb`（浅字写在红布上） |

### 2.2 代码落点

- `OverlayFrame`：三个 bool 改成一个皮 —— `_init(margin: int = -1, skin: StringName = &"slab")`，`&"slab" / &"bronze" / &"book" / &"tent"`；`bronze` / `book` 两个成员照旧由 skin 推出，`_bronze_panel` 不变，`_centered_panel(min_size, margin, skin)`（232 刚落的 `book: bool` 参数改成 `skin`，调用处就事件屏一处）。
- `_init_tent(margin)`：走石板那条（标题条 + 内容区），只是底换 `StyleBoxTexture`（`shop/tent_front`，按 §2.1 三组 margin）、`title_label` 用新的主题变体 `LABEL_TENT_SIGN`（居中、22、`#f2e7cb`，在 `UiTheme` 注册，不在屏里 override）；`_draw` 里用 `UiTheme.art_cached("shop/tent_peak")` / `"shop/tent_sign"` 画尖顶和布牌（`_draw` 在子节点下面，所以标题字压在布牌上）。没图退回石板（和 bronze / book 一样）。
- `ShopScreen.open()`：`_centered_panel(Vector2(0, 0), 16, &"tent")`，其它不动。
- 顶栏让位：尖顶到窗顶上 56，窗离顶栏只有 50 多 px → `_centered_panel` 加 `top_outset: int = 0`，`center.offset_top = bar_height + top_outset`；商店传 `56 − 现在的空隙`（算法：`maxi(0, 56 − (center 居中后窗顶 − bar_height))`，`OverlayFrame` 加 `outset_top()` 返回皮需要的上伸量，由 `_centered_panel` 在 `resized` 时取用），这样尖顶永远不被顶栏盖住，窗下移的几个像素看不出来。书（232）上伸 34 没撞到，不用改。
- 图进 `assets/ui/shop/`（`tent_front.png`、`tent_peak.png`、`tent_sign.png` 1x；`@2x` 不拷）+ `layout.json`（就是 `tent.json`）。
- 不涉及：局外基地的出售页（石板照旧）、226 的告示签 / 价签 / 「已售」戳、商店按钮纸卷（PR #2xx）—— 都在内容区里。

### 2.3 测试

- `test_shop_tent_233`：皮是 `StyleBoxTexture` 且三组 margin 对；`title_label` 变体 `LABEL_TENT_SIGN`、字居中；窗顶 − 顶栏 ≥ 56；没图时退回石板且标题照旧。
- `test_screens_157` 商店用例：`overlay_frame().title()` 照旧 = 「商店」。
- 截图：中英各一张（标题字 CONTINUE 那种长度不涉及；「Shop」短）交游戏测试。

## 三、待作者定（没回音按推荐）

1. 顶栏让位用**窗下移几像素**（推荐，尖顶完整）—— 还是尖顶被顶栏盖住几像素不管。

## 四、派工

- **执行**：一单，排在 226 批二 + 224 补充二之后、227 之前（改动小）。
- **美术设计**：斗兽场已作废（作者 22:23），不再有后续。

## 五、落地（v3.91，执行）

- `OverlayFrame._init(margin, p_skin)`：`SKIN_SLAB / SKIN_BRONZE / SKIN_BOOK / SKIN_TENT` 一个参数；缺图退回石板，`skin` 记实际用上的那张。`_centered_panel(min_size, margin, skin)`，事件屏传 `SKIN_BOOK`、`_bronze_panel` 传 `SKIN_BRONZE`、商店传 `SKIN_TENT`。
- 帐篷皮：`StyleBoxTexture` 三组 margin 读 `assets/ui/shop/tent_front.json`（美术 `tent.json` 原样，没另起 `layout.json`）；`_draw` 画尖顶（窗 (W/2 − 210, −56)）和布牌（窗 (W/2 − 138, −4)），标题 `LABEL_TENT_SIGN`（`UiTheme` 注册，进浅底文字主题的配对表，不被墨字盖掉）。
- 顶栏让位按推荐（§三.1）：没加 `top_outset` 参数，`_centered_panel` 见 `outset_top() > 0` 就在 `resized` / `minimum_size_changed` 时算 `center.offset_top = bar + 2·max(0, 56 − 现空隙)`（居中区往下让两倍 = 窗下移一倍），空隙够了不挪。
- **截图后多做的两处**（执行判断，数都在 `OverlayFrame` 常量里，想改一行改）：
  1. 布牌连流苏挂到窗顶下 70，标题条 14..50 下面就是内容 —— 店里第一行（货币那行）被流苏挡住。标题条加高到流苏下沿 + 6（`TENT_SIGN_CLEAR`），标题字那一行仍是 14..50（`TENT_TITLE_H` 36、贴顶），字心照旧对红布 y 32。
  2. 垂布伸进窗 22、边距 24 —— 截图上货架和出售格贴着布边。内容左右各多垫 12（`TENT_SIDE_PAD`）。
- 测试 `test_shop_tent_233`（2 用例 23 断言）；截图 `/mnt/project-files/art/ui/shop/shots233/shop_zh.png`、`shop_en.png`（1280 × 800，尖顶离顶栏够、地毯不出屏）。
