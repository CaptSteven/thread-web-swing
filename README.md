# THREAD — 双键蛛丝对战

Godot 4.7.2 制作的 2D 火柴人原型：通过蛛丝与惯性穿越上下平台，同时使用武器射击。支持单人靶场和双人局域网对战。

## 启动

1. 安装 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) 标准版。
2. 克隆或下载此仓库。
3. 在 Godot 中导入 `web-swing-demo/project.godot`，按 F5 运行。

macOS 用户也可以把 `Godot.app` 放在仓库根目录，双击 `Play Demo.command`。引擎、缓存和生成的压缩包不包含在仓库中。

## 操作

- 鼠标：瞄准，不提供预测落点辅助。
- 按住左键：连接蛛丝并弹性牵引；松开后保留惯性。
- 按住右键：连续射击，不影响已有蛛丝落点。
- Esc：房间菜单；R：单人练习重置。

蛛丝受力过大、过长、到达持续时间或越过粘着点后会断开；所有断线都有线段下坠淡出动画。地图主要由上下平台和少量中间障碍构成。

## 联网

两人连接同一局域网，一人创建房间，另一人输入房主 IP 加入。每人 100 血、每发 20 伤害、2 秒复活，房主统一计算物理和命中。使用 UDP 24816，详细步骤见 [联机说明](web-swing-demo/LAN-PLAY.md)。

当前没有公网匹配、中继、客户端预测或延迟补偿，主要用于低延迟局域网试玩。

## 检查

用本机 Godot 可执行文件运行：

```sh
godot --headless --path web-swing-demo --script res://check_demo.gd
godot --headless --path web-swing-demo --script res://check_combat.gd
```

联网检查需要在两个终端分别运行：

```sh
godot --headless --path web-swing-demo --script res://check_network.gd -- --host --net-test
godot --headless --path web-swing-demo --script res://check_network.gd -- --join-local --net-test
```

`check_network_lifecycle.gd` 使用相同参数，可检查断开和重新加入。联网测试占用 UDP 24816，运行时请先关闭已有房间。
