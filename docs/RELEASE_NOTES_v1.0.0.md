# 秒转 PDF v1.0.0

把 Word、PPT、Excel、图片直接变成 PDF。不打开文档，不用等 Office 启动。

**独立版**：转换引擎已打包进应用，目标 Mac 不需要安装 DeepSeek Harness、
LibreOffice、Node.js 或 Office，装好即可离线使用。

## 下载

| 你的 Mac | 文件 |
| --- | --- |
| Apple Silicon（M1 / M2 / M3 / M4） | `pdf-maker-1.0.0-macos-arm64.zip` |
| Intel 芯片 | `pdf-maker-1.0.0-macos-x64.zip` |

在   →「关于本机」里可以看到芯片型号。

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| pdf-maker-1.0.0-macos-arm64.zip | 65.2 MB | `055cc807851dcd6f7820fadb9dc8d3e5fcf979b23d20f45ccfbf4cf882b60afa` |
| pdf-maker-1.0.0-macos-x64.zip | 67.4 MB | `00db16d1061a7947a2d79808858ae2883a82782345d3e32d568fc0095d209e64` |

## 安装

1. 解压下载的 zip。
2. 右键 `安装.command` → **打开**。
   第一次会被 macOS 拦一下，右键选「打开」即可；仍不行就到
   **系统设置 → 隐私与安全性** 点「仍要打开」。
3. 看到「✓ 安装完成」就好了。

装好后：

- 应用：`~/Applications/秒转 PDF.app`
- 右键快速操作：`~/Library/Services/秒转 PDF.workflow`

## 怎么用

- **右键**：Finder 里选中文件（可多选，也可选文件夹）→ 快速操作 → 秒转 PDF。
- **拖窗口**：打开「秒转 PDF」，把文件拖进虚线框。
- **拖 Dock 图标**：效果同右键。

PDF 生成在源文件旁边，同名自动编号；原文件不会被改动。

支持 Word（`.doc` `.docx` `.odt`）、PowerPoint（`.ppt` `.pptx` `.odp`）、
Excel（`.xls` `.xlsx` `.ods`）、图片（`.png` `.jpg` `.heic` `.tif` `.bmp` `.gif` `.webp` 等）。
PDF 会跳过；`.pages` / `.key` / `.numbers` 暂不支持。

## 第一次使用

转换时需要读取「文稿 / 桌面 / 下载」里的文件，macOS 会弹一次权限窗，点**允许**。
全部在本机完成，不联网、不上传文件。

## 已知情况

- 应用为 **ad-hoc 签名**（没有 Apple 开发者证书），首次打开需要右键 →「打开」。
  这是 macOS 的正常拦截，不是文件损坏。
- 首次转换要启动引擎，约 10–20 秒；之后同一批文件每个 2–5 秒。
- macOS 13（Ventura）及以上；Intel 与 Apple Silicon 请下载对应版本。

## 卸载

双击安装包里的 `卸载.command`，或运行源码目录里的 `./uninstall.sh`。

会删除应用、右键快速操作、后台进程和缓存，已生成的 PDF 不受影响。

## 许可证

- 应用本身：MIT。
- 转换引擎：`@deepseek-ai/libreoffice-kit` 与 LibreOffice，MPL-2.0；
  许可证与第三方声明已随包放在 `Contents/Resources/engine/licenses/`。
