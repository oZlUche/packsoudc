# 141 方案：四个内容编辑器的「列表 / 草稿 / 存盘 / 状态文本」抽成基类

- 日期：2026-10-07
- 来源：代码精简审查 U-1（`/mnt/project-files/audits/2026-10-07-redundancy/ui.md`），协调者要求单独立项。前置：审查队列第 10 项「最小一步」（`_ids_on_disk` ×3 → `ContentPaths.ids_in(dir)`、`_status_text` ×4 → `ImportReport.bbcode()`）由精简线程自己做；本篇是之后的基类化。
- 性质：架构 · 提议（本线程只写方案）。纯重构，行为不变，但 250～350 行、测试直接碰私有字段。

## 一、现状

`ui/editor/content_editor.gd`、`ui/event_editor/event_editor.gd`、`ui/buff_editor/buff_editor.gd`、`ui/set_editor/set_editor.gd` 各自维护 `_ids / _drafts / _baseline / _list`，打开、存盘、另存、套 JSON、放弃、重扫、判脏的流程一样，只有种类常量、目录、`_dump()`、`_bind()` 和提示语不同。buff 与 set 的列表草稿段做名字归一化后 92 行只差 4 处（set 多「草稿里有、盘上没有」的处理，就是漂移的例子）。

## 二、改成

### 2.1 `AuthoringEditor`（`ui/editor/authoring_editor.gd`，`extends Control`）

- 持有：`KIND: StringName`（子类 `const`）、`DIR: String`、`_ids: Array[String]`、`_drafts: Dictionary`、`_baseline: Dictionary`、`_list: ItemList`、`_def`（当前对象）。
- 提供（都是现在四份的公共部分）：`ids_on_disk()`、`reload_list()`、`repaint_list()`、`select_in_list(id)`、`track_draft()`、`stash_current()`、`draft_key()`、`on_rescan()`、`on_discard()`、`save()`、`save_as()`、`apply_json(text)`、`has_unsaved_changes()`、`status_text(report)`、`_open(id)`。
- 子类必须实现（抽象）：`_dump() -> Dictionary`（当前对象 → JSON）、`_bind(def)`（表单绑定）、`_new_def(id)`、`_validate() -> ImportReport`、`_load_def(path)`。
- set 编辑器那段「盘上没有就从列表里删」**上提到基类**（四个编辑器行为统一到更正确的那种 —— 这是本篇唯一的行为对齐，对其他三个是修一个潜在漂移，不是玩家可见行为）。

### 2.2 保住测试碰的名字

`tests/authoring/*` 直接读 `ed._drafts`、`ed._def`、`ed.has_unsaved_changes()`、`ed._open()`。基类**沿用这些名字**（私有字段名不改，`has_unsaved_changes` / `_open` 原名），子类不再声明，测试一行不改。

### 2.3 地图编辑器

`map_editor.gd` 的 `event_ids` / `_refresh_chapters` 只用 `ContentPaths.ids_in(dir)`（最小一步给的），不继承基类（它的对象模型不是一份 JSON 一个草稿）。

## 三、顺序

1. 精简线程先合「最小一步」；
2. 本篇：先把 buff 与 set 两个（最像的）改成继承基类，测试绿；
3. 再 event、再 content（最大、字段最多，最后做）；
4. 每步一个 PR。

## 四、测试

现有 `tests/authoring/` 全绿即为验收；额外加一条：四个编辑器各开一个、改一字、`has_unsaved_changes()` 为真、存盘后为假、重扫后列表与盘上一致（含「盘上删了的从列表消失」）。

## 五、待定（按推荐）

1. 基类还是辅助对象（组合）。推荐：**基类**，测试碰的是编辑器自身的字段，组合要加转发。
2. 「盘上没有就从列表里删」要不要四个都做。推荐：**都做**。
