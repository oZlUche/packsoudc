# 001 · 仓库初始化与开发环境

对应架构文档：第 9 节「目录结构」、第 10 节「实施顺序」阶段 1 的前置准备。

## 目标

把这个此前只有引擎模板与编辑器插件的空白工程，变成一个纳入版本控制、能在命令行跑无头验证的开发环境，为 M1 网格背包系统开工做准备。

## 产出

| 文件／目录 | 说明 |
|---|---|
| `.gitignore` | 重写，见下方「关键决策」 |
| `docs/reports/` | 开发报告目录，含 `README.md` 索引与报告结构约定 |
| `core/inventory/` | M1 逻辑层目录（空） |
| `ui/inventory/` | M1 表现层目录（空） |
| `data/items/`、`data/shapes/` | 物品与形状资产目录（空） |
| `tests/` | 无头测试目录（空） |

仓库以 `git init` 建立在项目根 `G:\oziuc\背包搜打撤`，首次提交纳入 300 个文件。

## 关键决策

### 1. `addons/ziva_agent` 排除在版本控制之外

该插件占 **1.5 GB**，其中 `bin` 684 MB、`zivacode` 707 MB，全部是二进制。

把它提交进 git 会造成几个不可逆的后果：每次 clone 拉取 1.5 GB、二进制无法增量压缩导致每次更新都整份重存、仓库体积超出常见托管平台的限制。而它是**开发期工具，游戏代码完全不依赖它**，因此写入 `.gitignore`，由各开发机自行安装。

### 2. `addons/godot_ai` 予以保留

体积 2.5 MB，全部是 GDScript 文本，且 `project.godot` 里声明了它的 autoload (`_mcp_game_helper`) 与 editor plugin。若将它排除，新 clone 的工程一打开就会因引用缺失文件而报错。

代价是它会进入版本历史，架构文档第 11 节已记录「正式导出前必须摘除该 autoload」，此处不重复处理。

### 3. 目录骨架只建 M1 需要的部分

架构文档第 9 节列出了完整目录结构，但本次只创建 `core/inventory`、`ui/inventory`、`data/items`、`data/shapes`、`tests`。

`core/battle`、`core/map`、`core/run` 等目录等到对应阶段实际写代码时再建。提前铺一堆只放 `.gitkeep` 的空目录，除了制造噪音没有任何收益。

### 4. 未创建远程仓库

`git init` 与首次提交都在本地完成。创建远程仓库并推送属于对外发布动作，需要先确认托管平台与仓库可见性，留给使用者决定（见「遗留」）。

## 验证

Godot 编辑器可执行文件不在 `PATH` 上，实际位置为 `E:\Godot\Godot_v4.7.1-stable_win64.exe`。命令行验证请使用 console 变体，它会把输出写到 stdout：

```bash
"/e/Godot/Godot_v4.7.1-stable_win64_console.exe" --version
```

实际输出：

```
4.7.1.stable.official.a13da4feb
```

`%APPDATA%\Godot_v4.7.2-stable_win64.exe` 是一个目录而非可执行文件（内含 WebView2 缓存），不要误用。

暂存区体积核查：最大文件为 `addons/godot_ai/mcp_dock.gd`，116 KB，无异常大文件。

```bash
git ls-files | sed 's#/.*##' | sort | uniq -c
```

```
      1 .editorconfig
      1 .gitattributes
      1 .gitignore
    293 addons
      1 docs
      1 icon.svg
      1 icon.svg.import
      1 project.godot
```

## 遗留

- **远程仓库未建立。** 需确认托管平台（GitHub／Gitee／自建）与可见性（公开／私有）后再推送。
- 引擎版本存在轻微错位：`project.godot` 声明 `config/features = ("4.7", ...)`，编辑器为 4.7.1，`editor_settings-4.7.tres` 存在。目前无影响，若后续出现资源导入异常应优先排查此处。
- 项目尚无 `LICENSE`，视发布计划决定是否补。

## 下一步

**002 · 背包数据层**：实现 `ItemShape`（异形占格与四向旋转）、`ItemDef`（静态定义）、`ItemInstance`（运行时实例），对应架构文档 3.1 节。
