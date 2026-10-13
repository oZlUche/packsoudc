# 方案：打包字体 —— 正文霞鹜文楷、标题朱雀仿宋、大标题马善政；按文案裁字，系统字体后备（168）

> 作者定（2026-10-13，美术设计线程，「可以，按照你的推荐来」）：正文 / 读数 / 按钮用霞鹜文楷（Regular，Medium 当粗体），标题 / 名牌用朱雀仿宋，手绘装饰只用于大标题用马善政；三款全是 SIL OFL 1.1。文件与授权在 `/mnt/project-files/art/fonts/chosen/`，美术的说明在 `art/fonts/README.md` 末节。
> 性质：实施。待定按推荐。关联 121（主题）、157 补（深浅字色）、167 §1（候选表）。

## 1. 现状

- 游戏不带字体：`UiPalette.cjk_font()` 是一个 `SystemFont`（微软雅黑 UI → 微软雅黑 → Noto Sans CJK SC → 黑体 → sans-serif），`cjk_font_bold()` 同一组字重 700。微软雅黑不能随游戏分发，玩家机器上没有就退到别的字，各机器长相不一样。
- 主题（`UiTheme._fill`）只设 `default_font` 与富文本的 `bold_font / bold_italics_font`；标题变体（`LABEL_TITLE` 18、`LABEL_OVERLAY_TITLE` 20、`LABEL_HUD_LARGE` 34）只改字号不换字体。十来处编辑器 / 沙盒直接拿 `cjk_font()` 画字。
- 文案里不同的汉字现在约一千六百个（data + ui + core + 帮助页扫出来 1574 个）。

## 2. 改法

### 2.1 文件

| 路径 | 内容 |
|---|---|
| `assets/fonts/wenkai_regular.ttf`、`wenkai_medium.ttf` | 霞鹜文楷裁字后的子集（原文件各 25 MB，裁后预计一两 MB） |
| `assets/fonts/zhuque_fangsong.ttf` | 朱雀仿宋子集（上游是技术预览 0.212，字库可能不全 —— 缺的字由后备补，见 2.3） |
| `assets/fonts/mashanzheng.ttf` | 马善政子集（只裁大标题会用到的字也行，但按同一张字集裁最省事） |
| `assets/fonts/LICENSES/OFL_LXGWWenKai.txt`、`OFL_ZhuqueFangsong.txt`、`OFL_MaShanZheng.txt` | 三份授权原文随包带上。朱雀仿宋 npm 包里没有，**从上游仓库（TrionesType/zhuque）补 OFL.txt**，美术那份从字体里读出的声明留作对照 |
| `assets/fonts/charset.txt` | 裁字用的字集（生成物，入库，方便对照与复现） |
| `assets/fonts/README.md` | 来源、版本、裁字命令、怎么重裁 |

原始字体（未裁）**不入库**：留在 `/mnt/project-files/art/fonts/chosen/` 与作者机器上（待定 4）。

### 2.2 裁字

- `tools/font_charset.py`：扫 `data/**/*.json`、`ui/**/*.gd`、`core/**/*.gd`、`docs/help_pages/**`，收所有非 ASCII 字符，再并上一组固定字集（ASCII 全部、CJK 标点与全角符号、中文数字〇一二三四五六七八九十百千万、罗马数字 Ⅰ–Ⅻ、现有读数用到的符号 ♥ ◆ ★ ▶ ⏸ ⏭ ‖ ×、省略号与引号），写成 `assets/fonts/charset.txt`（一行一个字，排序，diff 友好）。
- `tools/subset_fonts.sh`：对四个源文件各跑一遍 `pyftsubset <源> --text-file=assets/fonts/charset.txt --layout-features='*' --name-IDs='*' --output-file=assets/fonts/<名>.ttf`（fonttools 用 `python3 -m pip install fonttools`，一次）。
- 文案新增了字 → 重跑两条命令、提交子集与 `charset.txt`。**兜底**：2.4 的覆盖测试会红，列出缺的字。

### 2.3 代码

- `UiPalette`：
  - `cjk_font()` → `FontVariation`，`base_font = load("res://assets/fonts/wenkai_regular.ttf")`，`fallbacks = [现在那个 SystemFont]`（缺字走系统字体，不出方块）；`cjk_font_bold()` → 同样包 `wenkai_medium.ttf`（真 Medium，不再靠 `font_weight = 700` 描粗）。
  - 新 `title_font()` → 朱雀仿宋，`fallbacks = [wenkai_medium 的变体]`（预览版缺字时标题里混进文楷 Medium，粗细接近）；新 `display_font()` → 马善政，`fallbacks = [title_font()]`。
  - 四个 `FontFile` 用 `static var` 缓存一次。文件不在（测试夹具、裁错）时各函数退回现在的 `SystemFont`，不崩。
- `UiTheme._fill`：`LABEL_TITLE`、`LABEL_OVERLAY_TITLE`、`PANEL_NAMEPLATE` 里的名字（`Nameplate` 已用 `LABEL_TITLE`）`set_font("font", 变体, title_font())`；新变体 `LABEL_DISPLAY`（`display_font()`，字号 `DISPLAY_SIZE = 40`）给主菜单游戏名、开局屏第三页与开场事件的章节名、宝箱屏的说明字（待定 3）。按钮、读数、富文本正文照旧默认字体 = 文楷；富文本 `[b]` = 文楷 Medium。
- 各编辑器 / 沙盒 `cjk_font()` 不改，自动换成文楷。
- 导入参数（`.import`）：`antialiasing = 1`（灰度）、`hinting = 1`（轻）、`subpixel_positioning = 1`、`multichannel_signed_distance_field = false`、`oversampling = 0`（随窗口缩放）；四个文件一样。
- 字高：文楷与仿宋的行高比雅黑略高，`Label` 最小高度会涨一两像素；不改字号，排版靠容器。UI 棘轮不涨（都是主题里设的）。

### 2.4 测试

- `tests/ui/test_theme.gd`：「富文本粗体是字重 700 的系统字体」改成「粗体是另一份 `FontFile`（Medium），不等于默认字体」；默认字体非空照旧。
- 新 `tests/ui/test_fonts_168.gd`：四个字体文件能 `load`；`has_char` 对「的」「撤」「Ⅳ」「♥」为真；**覆盖测试**：扫 data / ui / core / 帮助页里的所有非 ASCII 字符，逐个 `wenkai_regular.has_char`，缺的列出来并红（提示重跑裁字）；朱雀仿宋同样扫但只警告（预览版缺字由后备补）。
- `tools/check_content.gd` 加同一条覆盖检查（内容校验时顺手跑）。

## 3. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 裁不裁 | A 裁字 + 覆盖测试（四个文件共几 MB）；B 全字库入库（文楷两份 50 MB） | **A**：仓库和安装包都受不了 B；缺字有测试兜底，还有系统字体后备 |
| 2 | 文楷粗体 | A Medium 文件；B 引擎描粗 Regular | **A**：作者定的；描粗发糊（157 已踩过） |
| 3 | 马善政用在哪 | A 只用于主菜单游戏名、章节名、宝箱屏说明（`LABEL_DISPLAY`）；B 也用于叠层标题条 | **A**：美术说它在小字号下认不出，叠层标题 20 号偏小 |
| 4 | 原始字体放哪 | A 不入库，留在共享目录与作者机器；B git LFS | **A**：仓库没用 LFS，子集可从原始文件随时重裁 |

## 4. 改动范围

| 文件 | 改什么 |
|---|---|
| `assets/fonts/`（新：四个子集 ttf + `.import`、`LICENSES/`、`charset.txt`、`README.md`） | 2.1 |
| `tools/font_charset.py`、`tools/subset_fonts.sh`（新） | 2.2 |
| `ui/ui_palette.gd`（`cjk_font / cjk_font_bold / title_font / display_font`）、`ui/ui_theme.gd`（标题变体换字体、`LABEL_DISPLAY`） | 2.3 |
| `ui/game/main_menu.gd`、`setup_screen.gd`（第三页章节名）、`event_screen.gd`（开场事件标题）、`chest_screen.gd` | 2.3 `LABEL_DISPLAY` |
| `tests/ui/test_theme.gd`、`tests/ui/test_fonts_168.gd`（新）、`tools/check_content.gd` | 2.4 |
| `docs/architecture.md` 8.x（主题）加「字体」一段 | |
