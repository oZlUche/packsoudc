# 运行游戏无响应卡住（v6.99，作者电脑）

日期：2026-11-21（意大利时间 12:40 前后）
版本：main 584cc1d（v6.99）
环境：作者笔记本，RTX 3050 Laptop + Iris Xe，32 GB 内存，Godot 4.7.2 编辑器版从源码运行

## 结论

卡住不是游戏代码的问题，是整机「已提交内存」用到了上限。游戏启动时显卡驱动和游戏本身要的那几百 MB 分配不到，于是 D3D12、Vulkan 都建不起设备，退回 OpenGL 后编译着色器又报内存不足，窗口长时间无响应。

今天新加的炼金页、一键炼金、全仓库可炼都没有参与：复现时游戏还没走到主菜单就已经分配失败。

## 实测数据

| 项 | 数值 |
|---|---|
| 已提交内存 / 上限 | 30.9 GB / 32.3 GB（游戏没开时） |
| 页面文件 | 实际只有 `C:\pagefile.sys` 在用，上限 512 MB；F、G 盘各配置了 20 GB，但没在用 |
| 所有进程私有内存之和 | 15.6 GB |
| 换页池 + 非换页池 | 2.0 GB + 1.4 GB |
| 找不到归属的已提交内存 | 约 12 GB（不属于任何进程，多半是驱动或共享内存段，重启能清） |
| 物理内存可用 | 约 12 GB（物理内存还有，缺的是提交额度） |

游戏从启动到主菜单的自身占用（每 0.6 秒采一次，共 30 秒）：

| 时间 | 私有内存 | 整机已提交 | 窗口响应 |
|---|---|---|---|
| 0.6 s | 415 MB | 31.2 GB | 否（编译脚本） |
| 7.8 s | 674 MB | 32.1 GB | 是 |
| 8.4–17.4 s | 693–727 MB | 32.0–32.3 GB | 否（导演 `_ready` 载内容，整机顶在上限） |
| 18 s 起 | 约 900 MB | 32.1–32.3 GB | 是 |

峰值 931 MB，这是正常量级（全部贴图按 RGBA 算约 690 MB，主菜单只用三张背景约 32 MB）。整机离上限只剩几百 MB，所以第一个大一点的分配就失败。这次复现里失败在主菜单背景图：

```
ERROR: Parameter "mem" is null.
   at: alloc_static (core/os/memory.cpp:104)
       [0] load_texture (res://ui/game/event_image.gd:17)
       [1] art (res://ui/ui_theme.gd:1036)
       [2] start (res://ui/game/menu_backdrop.gd:59)
       [3] open (res://ui/game/main_menu.gd:55)
```

## 作者那次卡住的经过（按日志还原）

1. 刚拉完 v6.99，新文件里有 `FaithContext`、`MaterialBias`、`CommissionBook`、`Nursery` 等新类，类缓存还是旧的，第一次启动全部脚本编译失败（`godot2026-11-21T12.42.53.log`）。这是预期内的，`DevNav` 按 158 的做法重写缓存后带原参数重开；之后编辑器也重建过缓存，现在 `.godot/global_script_class_cache.cfg` 里这几个类都在。
2. 重开的那次（`godot.log`）显卡建设备失败：

```
ERROR: Couldn't create Vulkan device (VkResult error -3).
WARNING: Your video card drivers seem not to support Direct3D 12 or Vulkan, switching to OpenGL 3.
ERROR: SceneShaderGLES3: Program linking failed:
(0) : fatal error C9999: out of memory - internal malloc failed
```

上一次同一台机器正常启动时 D3D12 一次成功，所以这不是驱动不支持，是当时分配不到内存。

## 区分

- 实际游戏问题：无。游戏占用和 v6.9x 之前同一量级，炼金页每格只载两张小图（`alchemy_panel.gd` 267、279 行），不遍历仓库载贴图。
- 测试工具问题：无。
- 预期日志：拉新版后第一次启动的「找不到类」是 158 的自救流程，会自己重写缓存重开。
- 未覆盖：没能在内存正常的状态下复测（需要作者重启电脑）；那 12 GB 没找到具体是谁占的。

## 建议作者做的（系统设置，我没有改）

1. 重启电脑，清掉那约 12 GB 无主的已提交内存。F、G 盘的页面文件已经配了 20 GB 却没生效，多半也是等重启才生效；重启后提交上限会从 32 GB 涨到 70 GB 左右。
2. 如果重启后页面文件仍只有 C 盘 512 MB：系统属性 → 高级 → 性能设置 → 高级 → 虚拟内存，改成「自动管理所有驱动器的分页文件大小」，或者给 C 盘也放宽。
3. 重启后再跑一次游戏，若还卡，任务管理器「性能 → 内存」看「已提交」那一行是不是又接近上限，再叫我查。
