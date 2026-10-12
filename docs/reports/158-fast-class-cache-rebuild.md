# 方案：更新代码后的启动 —— 类缓存由游戏自己秒级重写，全量 `--import` 只在新素材到了才跑、且不再挡着游戏（158）

> 作者原话（2026-10-12，架构设计）：「游戏首次启动的时间太久了」→ 问清：「更新后慢，半分钟以上」。
> 性质：架构 · 实施（开发期工具，不碰玩法）。待定按推荐。

## 1. 现状与原因

- 量过：正式启动里的内容加载（道具 / 敌人 / 事件 / 百科等全部定义 + 主题）headless 共约 0.3 秒。不是它。
- 作者只在**拉了新代码后的第一次**慢，半分钟以上：这是 115 的自救路径 —— `.godot/` 不进仓库（102），别人加了 `class_name` 之后本地的 `.godot/global_script_class_cache.cfg` 过期，`DevNav._check_class_cache` 发现缺类 → 起一个 `godot --headless --import` 子进程（**整个编辑器子系统启动 + 扫全项目 + 导入**）→ 导完再重开游戏。半分钟花在那个编辑器进程上，不在我们的代码里。Windows 上杀毒软件扫描会再翻倍。
- 渲染器（Forward+ / D3D12）不是这条的原因（每次启动都慢才是它），先不动；要改是另一条一行的设置，以后再说。

## 2. 改法：三件

### 2.1 类缓存由 `DevNav` 自己写（进程内，不起编辑器）

`global_script_class_cache.cfg` 只是一份 `ConfigFile`：`list = [ {base, class, icon, is_abstract, is_tool, language, path} … ]`，按 `class` 排序（4.7 的样子，见本机导出的那份）。它需要的信息全在 `.gd` 文件头几行里，不需要编辑器：

- 新建 `tools/class_cache.gd`（**不写 `class_name`**，静态方法；DevNav 用 `preload` 拿 —— 它自己就是在缓存坏了的时候跑的）：
  - `scan(root := "res://") -> Array[Dictionary]`：`DirAccess` 递归，跳过 `.godot/`、`addons/`、`.claude/`、带 `.gdignore` 的目录、隐藏目录；每个 `.gd` 读前面到第一个非注释非注解非空行为止的那几行，取 `class_name X`、`extends Y`、`@tool`、`@abstract`。
  - `base`：`extends` 后面是裸标识符就是它（原生类或别的全局类，和编辑器写法一致）；是 `"res://…"` 路径就解析那份脚本（有 `class_name` 用它，没有就继续往上找原生基类）；没写 `extends` 的是 `RefCounted`。项目里现在 0 处路径式 `extends`，但要处理。
  - `write(entries, path := "res://.godot/global_script_class_cache.cfg")`：`ConfigFile` 写 `list`，`icon = ""`、`language = &"GDScript"`，排序同编辑器。`.godot/` 不存在就先建。
- `DevNav._check_class_cache`：缺类 → **先** `ClassCache.write(ClassCache.scan())`（<1 秒）→ 立刻 `_finish_rebuild()` 重开（带 `cache-rebuilt`）。重开后还缺才回落红字（现有逻辑）。盖板文字改成「脚本缓存过期，已重写，正在重新打开……」。
- 不再在这条路上起 `--import`。`stale_classes()` 的判定不变。

### 2.2 新素材的导入：只在真缺时跑，而且不挡游戏

类缓存修好之后，另一种「更新后坏了」是别人加了图片（`assets/`）而本地 `.godot/imported/` 里没有导出的 `.ctex`。这才需要真正的 `--import`，但它**不该挡住游戏**：所有图片钩子都是「有图用图、没图占位」（事件图、宝箱皮肤、节点图标、157 的框 / 光标）。

- `tools/class_cache.gd` 旁加 `tools/import_check.gd`（同样无 `class_name`）：遍历 `*.import` 文件，读 `[deps] dest_files`，任一目标不存在 → 「有未导入的素材」。
- `DevNav`：启动时（缓存检查之后）发现未导入素材 → 后台起 `--import`（现有 `start_rebuild` 的子进程写法），**不盖板、不重开**，右上角一条小字「新素材导入中……下次启动生效」，导完小字消失。这一次游戏里那几张图走占位。
- `run_game.sh / .bat`：去掉无条件的 `--import`，改成和 DevNav 一样「缺了才导」—— 直接 `godot --path .` 即可，脚本只剩一行（或删掉，README 写明普通快捷方式就行）。`tools/test.sh` 的 `--import` 不动（测试要的是编辑器导出的那份，拿来当 2.3 的对照）。

### 2.3 测试：和编辑器写的那份逐条对照

`tests/tools/test_class_cache.gd`（`tools/test.sh` 先 `--import`，所以跑测试时 `.godot/global_script_class_cache.cfg` 是编辑器刚写的）：

- `ClassCache.scan()` 写到临时路径，读回来和编辑器那份 **逐条相等**（class、base、path、is_tool、is_abstract；icon 与 language 常量）。Godot 升级改了格式这条测试先红，不会悄悄坏。
- `import_check`：复制一份 `.import` 到临时目录、删掉它的目标 → 判「未导入」；完整的 → 判「已导入」。
- 现有 `test_dev_nav`（115）的 `relaunch_args` / `already_rebuilt` 不动。

## 3. 效果

更新代码后第一次启动：原来「开游戏 → 半分钟编辑器导入 → 重开」变成「开游戏 → 不到一秒重写缓存 → 重开」；拉到新图片时游戏照开，导入在后面跑。导出包（`OS.has_feature("template")`）这两条检查本来就跳过，不受影响。

## 4. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | `uid_cache.bin` 不跟着重建，新脚本的 `uid://` 引用按路径回落（有一条警告） | A 接受，等作者开编辑器时自然重建；B 也自己写（二进制格式，不稳） | **A** |
| 2 | 缺素材时 | A 后台导、不重开，占位先顶着；B 盖板等导完再重开（现在的样子） | **A** |
| 3 | `run_game` 脚本 | A 删掉，README 说普通快捷方式；B 留着但只在缺时导 | **A** |

## 5. 改动范围

| 文件 | 改什么 |
|---|---|
| `tools/class_cache.gd`（新）、`tools/import_check.gd`（新） | 2.1 / 2.2 |
| `ui/dev_nav.gd` | 缺类 → 进程内重写 + 重开；缺素材 → 后台导入 + 小字 |
| `tools/run_game.sh`、`run_game.bat`、README 的启动说明 | 2.2 |
| `tests/tools/test_class_cache.gd`（新） | 2.3 |
| `docs/architecture.md` 15 节（开发期工具）、`.gitignore` 注释（102 那段补一句：缓存由游戏自己重写） | |

## 落地记录（2026-10-12）

三项待定按推荐，只有一处出入（第 3 条）。

| 节 | 落在哪 | 和方案的出入 |
|---|---|---|
| 2.1 类缓存 | `tools/class_cache.gd`（`scan` / `write` / `read` / `head_of`）；`DevNav._check_class_cache` 缺类 → `rewrite_cache()`（写缓存、盖「已重写，正在重新打开……」、下一帧带原参数重开） | **`addons/` 也要扫**：编辑器写的那份里有 `addons/godot_ai` 的 56 个类，不扫就对不上；跳过的是 `.godot` / `.git` / `.claude`（里面有别的 worktree）、带 `.gdignore` 的、隐藏目录。写出来的和编辑器那份**逐字节一样**（要写成不带类型的数组，否则是 `Array[Dictionary]([…])`）。实测全项目 505 个类约 0.08 秒。端到端试过：删掉缓存里一条 → 跑游戏 → 缓存写回、和原来逐字节一样、重开。原来的「起 `--import` 自救」去掉了（`start_rebuild` 删除），重开过还缺照旧回落红字 |
| 2.2 素材 | `tools/import_check.gd`（`.import` 的目标不在、或素材旁边连 `.import` 都没有 = 没导）；`DevNav._check_assets`：缓存齐全时检查，没导的 → 后台 `--import`，右上角小字，导完撤掉，不重开 | — |
| 2.2 run_game | `run_game.sh` / `.bat` 去掉 `--import`，只剩启动一行 | 待定 3 推荐删掉；**留着**（只剩一行），免得作者本地已有的快捷方式指向它时打不开 |
| 2.3 测试 | `tests/tools/test_class_cache.gd`：和编辑器那份逐条 + 逐字节对照、各种文件头写法、`import_check` | — |
