[English](./README.md) | 中文

# GridMove for macOS

GridMove 是一个用于跨显示器移动窗口，并将窗口吸附到自定义布局的原生 macOS 应用。

**获取 arm64 安装包**：[🔗](https://github.com/mirtlecn/GridMoveForMac/releases/latest/download/GridMove.arm64.dmg)  

> [!NOTE]
> 软件未签名，首次打开需在系统「隐私与安全性」中信任

## 演示

快速移动窗口：从窗口内部任意位置拖动，移动窗口。

https://github.com/user-attachments/assets/9f1a4fec-e022-4667-96c6-9ee199e15887

便捷调整窗口布局：将窗口拖到预设区域，可以立即调整窗口大小和位置。

https://github.com/user-attachments/assets/0373bb1d-1de4-4542-a67e-b6598859bfd1

## 特点

- 速度快，体积轻
- 可通过鼠标、键盘或 CLI 触发操作
- 支持跨显示器移动和调整窗口大小
- 支持将窗口吸附到任意布局
- 可为不同显示器使用不同布局集合
- 可在运行时切换布局组

## 快速开始

- 按住<kbd>中键</kbd>一段时间，对光标下窗口应用布局。
- 按住 <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Alt</kbd>，再按住鼠标左键，对光标下窗口应用布局。
- 在布局模式下，按 <kbd>Option</kbd> 或点击右键进入自由移动模式；再次操作可切回布局模式。
- 在布局模式下，按 <kbd>Shift</kbd> 或滚动鼠标滚轮切换当前布局组。
- 可通过菜单栏或预设快捷键，对当前聚焦窗口应用布局。
- 可通过 CLI 按窗口 ID 应用布局。

## 截图

设置页

<img width="1070" height="860" alt="image" src="https://github.com/user-attachments/assets/166aa636-9722-4b8a-ba0f-1bf90b28252b" />

自定义布局

<img width="1070" height="811" alt="image" src="https://github.com/user-attachments/assets/13fe6dc6-1103-4d9d-a9a5-0fa10faf70bd" />


### CLI

GridMove 会把 CLI 操作转发给正在运行的应用实例。

```bash
path/to/GridMove.app/Contents/MacOS/GridMove -next # 移动当前聚焦窗口
path/to/GridMove.app/Contents/MacOS/GridMove -pre
path/to/GridMove.app/Contents/MacOS/GridMove -layout 4
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center"
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" -window-id 12345 # 移动当前屏幕中的指定窗口
```

## 开发

```bash
# 运行测试
make test
# 本地运行
make dev
# 构建并打包
make build
# 构建发行包
make release
```

## 附加说明

- GridMove 这个名字来自我之前维护的一个 [Windows AHK 应用](https://github.com/mirtlecn/GridMove)。这个项目可以看作它的 macOS 对应版本。
- 整个应用，包括图标、文档和演示视频，都是用 OpenAI Codex 制作的。用户使用的提示词见[这里](docs/prompts.md)。（注：文件 700 KB+。）
- [docs/APP-DESIGN.md](docs/APP-DESIGN.md) — 运行时行为、架构、配置细节和实现说明
- [docs/CONFIG-REFERENCE.jsonc](docs/CONFIG-REFERENCE.jsonc) — 进阶配置：注释的 JSON 配置参考
