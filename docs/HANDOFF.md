# 秒转 PDF · 换机交接与进度整理

> 更新时间：2026-11-19 11:30（新机 macOS 27 / Apple Silicon / arm64）
> 结论：**源码和两套安装包都在，进度没丢；已装到这台 Mac 并实测通过。**
> 只剩「上传 GitHub」——你准备建新账号，先跳过。

---

## 1. 现状

| 事项 | 状态 |
| --- | --- |
| 独立版源码（不依赖 DeepSeek Harness） | ✅ `pdf-quick-standalone/` |
| 替换新 logo（兔子 + 文档） | ✅ 已打进两套安装包 |
| 两个 macOS 版本（Intel / Apple Silicon） | ✅ zip 65.2 / 67.4 MB |
| 体积缩小（去掉 Node.js 运行时） | ✅ 应用 157–165 MB |
| 本机安装 + 真实转换 | ✅ 11-19 已装到 `~/Applications`，Word / 图片均转换成功 |
| 安装脚本在 macOS bash 3.2 下的崩溃 | ✅ 已修，并重新打包 |
| Git 仓库 | ✅ 本地 `main`，3 个提交 |
| **上传 GitHub / 发 Release** | ⏸ 等你的新 GitHub 账号 |

旧的、依赖 DeepSeek Harness 的版本仍在 `pdf-quick/`，安装包备份在
`pdf-quick/dist/秒转 PDF 安装包.zip`（454 KB）。
桌面原来那两个同名安装包文件夹（内容重复且已过时，误装会覆盖新版）
已于 11-19 删除。现在发布的是**独立版**。

---

## 2. 两个项目目录

| 目录 | 说明 |
| --- | --- |
| `pdf-quick/` | 第一版，引擎来自已安装的 DeepSeek Harness，安装包 454 KB |
| `pdf-quick-standalone/` | **主线**。LibreOffice 引擎（dsoffice）打进 .app，目标机不需要 DSH / LibreOffice / Node / Office |

---

## 3. 11-16 完成的事（按文件时间还原）

1. **09:05** 拆出独立版：SwiftUI 应用、Finder 快速操作、安装脚本。
2. **17:52–17:58** 引入 `fetch-engine.sh` 内置引擎；重写 `EngineRunner.swift`、
   `ConversionCenter.swift`；更新 README、`docs/PUBLISH.md`、安装说明。
3. **18:04** 重写 `build.sh`：一次产出两个架构，且一次只组装一个架构，
   避免两份 280 MB 中间产物同时占盘。
4. **18:19–18:20** 换新 logo（深灰底 + 白兔耳朵 + 文档），生成 `AppIcon.icns`。
5. **18:22** 安装脚本加架构校验（装错版本提前拦住）。
6. **18:23** 构建完成，产出两套 `安装包（…）/` 和两个 zip。
7. **17:58** 写好 `docs/PUBLISH.md` 的发布流程，但**没有执行**。

体积：旧方案带 Node 运行时约 290 MB；新方案 Swift 直接调 `dsoffice`，
应用 157–165 MB，zip 压完 65–67 MB。

---

## 4. 11-19 复核、修复与实测

### 4.1 复核（都对）

- 两套 `.app` 引擎架构正确：Apple Silicon 版 `arm64`，Intel 版 `x86_64`；
  主程序都是通用二进制。
- 源码、`build/`、两个安装包里的 `AppIcon.icns` 哈希完全一致（`7cc5487…`），
  确认包内是新 logo。
- 两个 zip `unzip -t` 全部通过（各 934 个文件）。
- 源码时间都早于 18:23 的构建，说明包对应最终代码。

### 4.2 发现并修掉一个会挡住用户的 bug

升级后的系统（以及用户的终端）跑的是 macOS 自带 **bash 3.2**，它会把
「紧跟中文的变量名」一起吞掉：

```bash
echo "本机：$VARIANT（$ARCH）"     # 实际被解析成 $VARIANT（  → unbound variable
```

`安装.command` 第 31 行正是这个写法，且脚本开了 `set -u`，
结果安装直接报 `VARIANT�: unbound variable` 退出。旧机上没暴露，
可能是用较新的 bash 跑的。

修复：所有「变量后紧跟中文」的位置改成 `${VARIANT}（…）` 形式，
共 11 处（`install.sh`、`build.sh`、`fetch-engine.sh`、`src/installer/安装.command`）。
修完用修复版 `安装.command` 完整重装了一遍，输出正常。

### 4.3 新机不能直接重新编译（重要）

在 macOS 27 + 只有 Command Line Tools 的环境里执行 `./build.sh` 会失败：

```
external macro implementation type 'SwiftUIMacros.StateMacro' could not be found
```

新 SDK 里 SwiftUI 的 `@State` 等改成了宏，宏插件随完整 Xcode 提供，
CLT 里没有。**现有二进制本身没问题**，所以这次只替换了包里的安装脚本并重新打 zip，
没有重编应用。以后要从源码重建，需要装完整 Xcode（约十几 GB）；
旧版 SDK 上 CLT 仍然够用。

### 4.4 端到端实测（装在这台 Mac 上）

- 安装位置：`~/Applications/秒转 PDF.app`、
  `~/Library/Services/秒转 PDF.workflow`；`pbs` 里已能查到
  `com.qiji.pdfquick.quickaction` 服务。
- 用「打开方式 / 快速操作」同一条路径（`open -a`）转换：
  - `测试文档.docx`（63 KB，126 页）→ `测试文档.pdf` 363 KB，4 秒内；
  - `测试图片.png`（2.8 MB）→ `测试图片.pdf` 162 KB，1 页；
  - 两份 PDF 都是合法 PDF 1.7。
- 转换日志写在 `~/Library/Application Support/PDFQuick/client.log`。

---

## 5. 当前产物与校验和

```
pdf-quick-standalone/
├── dist/
│   ├── 安装包（Apple Silicon）/  安装包（Intel）/   # 可直接拷走安装
│   ├── 秒转 PDF（Apple Silicon）.zip   65.2 MB
│   ├── 秒转 PDF（Intel）.zip           67.4 MB
│   └── 秒转 PDF.workflow
├── vendor/engine-arm64/  vendor/engine-x64/   # 内置引擎（不进 git）
├── build/                                     # 编译产物（不进 git）
├── src/  docs/                                # 源码与文档
└── .git（main，3 个提交）                      # 25 个文件，约 2 MB
```

```
055cc807851dcd6f7820fadb9dc8d3e5fcf979b23d20f45ccfbf4cf882b60afa  秒转 PDF（Apple Silicon）.zip
00db16d1061a7947a2d79808858ae2883a82782345d3e32d568fc0095d209e64  秒转 PDF（Intel）.zip
```

（应用二进制与 11-16 构建一致，只是包内 `安装.command` 换成了修复版。）

---

## 6. 下一步：GitHub（等你账号）

你选的是「装 gh CLI + 浏览器授权一次，我自动建仓 / 发 Release」。
建好账号后告诉我用户名，我按下面做：

```bash
# 1. 下载 gh 到工作区并登录（你只需在浏览器输入一次设备码）
gh auth login --hostname github.com --git-protocol https --web

# 2. 建仓库并推送（源码约 2 MB）
gh repo create pdf-quick --public --source=. --remote=origin --push

# 3. 发 v1.0.0 Release，上传两个 zip
gh release create v1.0.0 "dist/秒转 PDF（Apple Silicon）.zip" "dist/秒转 PDF（Intel）.zip" \
  --title "秒转 PDF v1.0.0" --notes-file docs/RELEASE_NOTES_v1.0.0.md

# 4. 把 README「下载哪个版本」表格换成 Release 链接
```

发布说明已写好：`docs/RELEASE_NOTES_v1.0.0.md`（含校验和、安装步骤、已知情况）。

---

## 7. 常用命令

```bash
cd pdf-quick-standalone
./build.sh              # 重建两套安装包（需要完整 Xcode，见 4.3）
./build.sh --host-only  # 只打本机架构
./fetch-engine.sh       # 缺 vendor/ 时下载引擎（约 330 MB）
./install.sh            # 装到本机
./uninstall.sh          # 卸载
shasum -a 256 dist/*.zip
```

---

## 8. 注意

- **写 shell 时变量后面紧跟中文必须用 `${VAR}`**，否则 bash 3.2 会解析错（见 4.2）。
- `dist/`、`vendor/`、`build/` 已在 `.gitignore`，不要提交。
- GitHub Release 单附件上限 2 GB，两个包共约 133 MB，没问题。
- 应用是 ad-hoc 签名，首次打开需右键 →「打开」，属正常现象。
- 本地 git 作者信息暂用旧机的 `shicode <qijihku@163.com>`；
  要改的话在推送前 `git commit --amend --reset-author`。
