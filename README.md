<p align="center">
  <img src="docs/icon.png" width="132" alt="秒转 PDF 图标">
</p>

<h1 align="center">秒转 PDF</h1>

<p align="center"><b>右键，转成 PDF。不打开 Word，不联网，不上传。</b></p>

<p align="center">把「转个 PDF」从三分钟，变成三秒。</p>

<p align="center"><b>仅支持 macOS 13 及以上</b>（Apple Silicon / Intel）· 没有 Windows / Linux 版</p>

<p align="center">
  <a href="https://github.com/qijicode1108/pdf-maker/releases/latest"><img alt="release" src="https://img.shields.io/github/v/release/qijicode1108/pdf-maker?color=2f6fed"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple">
  <img alt="universal" src="https://img.shields.io/badge/Apple%20Silicon%20%7C%20Intel-universal-2f6fed">
  <img alt="offline" src="https://img.shields.io/badge/100%25-离线-21a366">
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-green"></a>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="720" alt="秒转 PDF 界面">
</p>

---

## 这其实是件小事，却每周都要做一遍

把一份 Word 发给别人，你得先转成 PDF。正常流程是这样的：

> 找到文件 → 打开 Word → 等它加载完 → 另存为 → 选格式 → 选位置 → 关掉 Word

或者更省事一点：打开某个在线转换网站 → 上传 → 等排队 → 下载 → 然后开始担心这份合同被谁看过了。

**秒转 PDF 把这些统统删掉，只剩下三步：选中文件、右键、等两秒。**

PDF 就出现在原文件旁边，Word 根本没被打开过。

---

## 三个入口，怎么顺手怎么来

| 方式 | 操作 |
| --- | --- |
| **右键（最快）** | Finder 里选中一个或多个文件，甚至整个文件夹 → 右键 → 快速操作 → **秒转 PDF** |
| **拖进小窗** | 打开「秒转 PDF」，把文件拖进虚线框 |
| **拖到 Dock** | 把文件直接拖到程序坞上的图标 |

批量也没问题：一次丢进去几十个文件，它会排队转，窗口里逐条显示进度。

---

## 为什么这么快

普通方案要么启动整个 Office，要么把文件传到别人的服务器。秒转 PDF 走的是第三条路：

- **自带转换引擎。** 应用里打包了 LibreOffice 的无界面转换核心 `dsoffice`，由 Swift 直接调用。不启动 Word / PowerPoint，没有「正在加载文档…」，没有弹窗。
- **图片走系统原生。** PNG / JPG / HEIC 这些交给 macOS 自带的 `sips`，几乎瞬间完成。
- **引擎常驻。** 第一次启动后引擎会保留一段时间（空闲 10 分钟自动退出），连续的第二个、第三个文件会明显更快。

实测（Apple Silicon）：

| 文件 | 结果 |
| --- | --- |
| 126 页 Word | 约 4 秒 |
| 2.8 MB PNG | 1 秒内 |
| 首次转换（冷启动引擎） | 10–20 秒，之后 2–5 秒/个 |

---

## 你的文件不会离开这台 Mac

- **全程离线。** 没有账号、没有上传、没有「云端转换」。
- **原文件只读。** 转换前复制到应用自己的临时目录，结束就清理，原文件一个字节都不会改。
- **失败不留垃圾。** 转换不成功不会生成半截 PDF。

对合同、报价单、简历这类东西来说，这一点比快更重要。

---

## 和别的办法比

|  | 秒转 PDF | Word 另存为 | 在线转换网站 |
| --- | --- | --- | --- |
| 需要装 Office | 否 | 是 | 否 |
| 文件要上传 | **否** | 否 | 是 |
| 批量转换 | 是 | 逐个来 | 看网站 |
| 入口 | 右键 / 拖拽 | 打开应用 | 打开浏览器 |
| 大文件 | 本地处理 | 本地 | 常受上传限制 |
| 断网可用 | **是** | 是 | 否 |

---

## 下载

| 你的 Mac | 下载 |
| --- | --- |
| Apple Silicon（M1 / M2 / M3 / M4） | **[秒转 PDF（Apple Silicon）](https://github.com/qijicode1108/pdf-maker/releases/latest/download/pdf-maker-1.0.0-macos-arm64.zip)** |
| Intel 芯片 | **[秒转 PDF（Intel）](https://github.com/qijicode1108/pdf-maker/releases/latest/download/pdf-maker-1.0.0-macos-x64.zip)** |

不确定的话：左上角  →「关于本机」，看「芯片」那一行。

两个包分别是 65 MB / 67 MB，都自带引擎，**不需要另外安装 Office、LibreOffice 或 Node.js**。

---

## 安装

1. 解压下载的 zip。
2. 右键 `安装.command` → **打开**。
3. 看到「✓ 安装完成」就好了。

> 第一次会被 macOS 拦一下（应用是 ad-hoc 签名，没有买 Apple 开发者证书），
> 右键选「打开」即可；仍不行就到 **系统设置 → 隐私与安全性** 点「仍要打开」。

装好后：

- 应用：`~/Applications/秒转 PDF.app`
- 右键快速操作：`~/Library/Services/秒转 PDF.workflow`

如果右键菜单里暂时看不到，注销重新登录一次即可。

---

## 支持的格式

| 类型 | 格式 |
| --- | --- |
| Word | `.doc` `.docx` `.odt` |
| PowerPoint | `.ppt` `.pptx` `.odp` |
| Excel | `.xls` `.xlsx` `.ods` |
| 图片 | `.png` `.jpg` `.jpeg` `.heic` `.heif` `.tif` `.tiff` `.bmp` `.gif` `.webp` |

PDF 会直接跳过；`.pages` / `.key` / `.numbers` 暂不支持（列表中会标出来）。

---

## PDF 去哪儿了

- 和源文件**同一个文件夹**，同名，扩展名换成 `.pdf`。
- 已经有同名 PDF 时自动编号：`报告.pdf`、`报告 (1).pdf`……
- 不想要编号？右键窗口右下角齿轮 → 勾选「覆盖同名 PDF」。
- 批量转换时，每个文件的结果都会单独标出来：成功、跳过还是失败。

---

## 常见问题

**第一次转换弹权限窗？**
系统会问是否允许访问「文稿 / 桌面 / 下载」文件夹，点**允许**。
转换引擎在应用内部，只是在本机读取文件。

**转换失败了？**
窗口右下角齿轮 →「打开转换日志」，里面有具体原因。加密/带密码的文档需要先取消密码。

**它依赖什么？**
什么都不依赖。独立版把转换引擎打包在应用里，macOS 13 以上、Intel 或 Apple Silicon 都能跑。

**能离线用吗？**
可以，而且只建议离线用——它根本不联网。

**会被杀毒软件拦吗？**
ad-hoc 签名的应用首次打开需要「右键 → 打开」。如果你有 Apple Developer ID，可以按 `docs/PUBLISH.md` 改成正式签名并公证。

---

## 它是怎么工作的

```
秒转 PDF.app/
└── Contents/
    ├── MacOS/PDFQuick              # SwiftUI 主程序（窗口 / 拖拽 / 队列）
    └── Resources/engine/
        ├── bin/dsoffice            # LibreOffice 转换核心（无窗口，MPL-2.0）
        ├── program/                # 引擎资源
        ├── licenses/               # 许可证与第三方声明
        └── sources/                # 引擎构建脚本（MPL-2.0 源码可得性）
```

- **Word / PPT / Excel**：复制到临时目录 → 调用 `dsoffice` 转成 PDF → 搬到源文件旁边。
- **图片**：直接用 `sips`，不启动引擎。
- **右键菜单**：一个 Automator 快速操作，把选中的文件交给应用。
- **后台常驻**：应用自己管理引擎生命周期，空闲自动退出。

---

## 从源码构建

需要 Swift 编译器。旧版 SDK 用 Xcode Command Line Tools 即可；macOS 15 之后
SwiftUI 的属性包装器改成了宏，只装 Command Line Tools 会报
`external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`，
这时需要完整 Xcode。

```bash
./fetch-engine.sh        # 首次：下载 LibreOffice 引擎（约 330 MB，不需要 Node/npm）
./build.sh               # 编译通用二进制，产出两套安装包 + 两个 zip
./build.sh --host-only   # 只打当前架构，开发时更快
./install.sh             # 装到本机
./uninstall.sh           # 卸载
```

版本升级：改 `fetch-engine.sh` 顶部的 `NODE_VERSION` / `KIT_VERSION`，重跑两个脚本。
发布流程（Release、公证、Homebrew）见 [docs/PUBLISH.md](docs/PUBLISH.md)。

---

## 目录结构

```
pdf-quick-standalone/
├── fetch-engine.sh          # 下载转换引擎
├── build.sh                 # 编译 + 组装 + 打两套安装包
├── install.sh / uninstall.sh
├── src/
│   ├── app/                 # SwiftUI 应用
│   ├── installer/           # 安装 / 卸载脚本、安装说明
│   ├── icon/                # 图标生成
│   └── workflow/            # Finder 快速操作
├── docs/                    # 截图、发布说明、交接文档
└── dist/                    # 构建产物（不进 git）
```

---

## 许可证

- 应用本身：**MIT**。
- 转换引擎：`@deepseek-ai/libreoffice-kit` 与 LibreOffice，**MPL-2.0**；
  许可证与第三方声明随包放在 `Contents/Resources/engine/licenses/`。
- 引擎源码：<https://github.com/deepseek-ai/dsh-libreoffice-kit>

---

<p align="center"><sub>如果它帮你省下了几分钟，点个 Star 就是最好的回礼。</sub></p>

---

<details>
<summary><b>English</b></summary>

**PDF in a right-click.** A tiny macOS app that turns Word, PowerPoint, Excel and
images into PDF without opening Office, without the cloud and without uploading
anything.

- Bundles a headless LibreOffice engine (`dsoffice`) and calls it from Swift.
- Finder Quick Action, drag-and-drop window, Dock drop.
- Batch queue, auto-numbering, offline, read-only on your originals.
- Universal binary: Apple Silicon + Intel, macOS 13+.

Download the right build from [Releases](https://github.com/qijicode1108/pdf-maker/releases/latest),
unzip, right-click `安装.command` → Open.

</details>
