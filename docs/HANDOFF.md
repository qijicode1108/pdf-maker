# 秒转 PDF · 换机交接与进度整理

> 整理时间：2026-11-19（新机 macOS 27 / Apple Silicon / arm64）
> 结论：**源码和两个安装包都在，进度没丢。** 只剩「传到 GitHub」这一步没做。

---

## 1. 一句话说清现状

| 事项 | 状态 |
| --- | --- |
| 独立版源码（不依赖 DeepSeek Harness） | ✅ 在 `pdf-quick-standalone/` |
| 替换新 logo（兔子 + 文档） | ✅ 已换，并已打进两套安装包 |
| 两个 macOS 版本（Intel / Apple Silicon） | ✅ 已构建，zip 各约 65 / 67 MB |
| 体积缩小（去掉 Node.js 运行时） | ✅ 应用 157–165 MB，zip 65–67 MB |
| 本机功能验证（引擎转换） | ✅ 实测通过（126 页 docx，约 1 秒） |
| Git 仓库 | ✅ 本地已 `git init` + 首次提交（`d01be16`） |
| **上传 GitHub / 发 Release** | ❌ **未完成**（新机没有账号凭据，也没建仓库） |

旧的、依赖 DeepSeek Harness 的版本仍保留在 `pdf-quick/`，以及桌面上的
`秒转 PDF 安装包/` 和 `秒转 PDF 安装包 2/`（两份内容相同，约 1.2 MB）。
现在要发布的是**独立版**。

---

## 2. 两个项目目录的关系

| 目录 | 说明 | 体积 |
| --- | --- | --- |
| `pdf-quick/` | 第一版。转换引擎来自已安装的 DeepSeek Harness，安装包只有 454 KB。 | 小 |
| `pdf-quick-standalone/` | **当前主线**。把 LibreOffice 引擎（含 dsoffice）直接打进 .app，目标 Mac 不需要 DSH、LibreOffice、Node、Office。 | 大 |

桌面上的两个「秒转 PDF 安装包」文件夹是 `pdf-quick` 的产物，属于旧版备份，不要再改。

---

## 3. 11-16 那天做完的事（按文件时间还原）

1. **09:05** 从旧版拆出 `pdf-quick-standalone`：SwiftUI 应用、快速操作、安装脚本。
2. **17:52–17:58** 引入 `fetch-engine.sh`，改为内置引擎；重写 `EngineRunner.swift`、
   `ConversionCenter.swift`；更新 README、`docs/PUBLISH.md`、安装说明。
3. **18:04** 重写 `build.sh`：一次产出 Intel + Apple Silicon 两套安装包，
   并且「一次只组装一个架构」，避免磁盘被两份 280 MB 中间产物塞满。
4. **18:19–18:20** 换了新 logo（深灰底 + 白兔耳朵 + 文档），生成 `AppIcon.icns`。
5. **18:22** 安装脚本加了架构校验：装错版本会提前拦住。
6. **18:23** 构建完成，产出：
   - `dist/安装包（Apple Silicon）/`、`dist/安装包（Intel）/`
   - `dist/秒转 PDF（Apple Silicon）.zip`（65 MB）
   - `dist/秒转 PDF（Intel）.zip`（67 MB）
7. **17:58** 写了 `docs/PUBLISH.md`，把 GitHub 发布步骤都准备好了 —— 但**没有执行**。

体积是怎么降下来的：旧方案要把 Node.js 运行时一起打包（约 290 MB）；
新方案由 Swift 直接调用 `dsoffice`，去掉 Node，应用降到 157–165 MB，
zip 压完 65–67 MB。

---

## 4. 今天（11-19）的复核结果

- 两套 `.app` 架构正确：
  - Apple Silicon 版引擎是 `arm64`；
  - Intel 版引擎是 `x86_64`；
  - 主程序都是 x86_64 + arm64 通用二进制。
- 四处的 `AppIcon.icns` 哈希完全一致（源码 / build / 两个安装包），
  说明**安装包里确实是新 logo**，没有用旧图标。
- 两个 zip `unzip -t` 全部通过（各 934 个文件），没有损坏。
- 源码文件时间都早于 18:23 的构建，说明**安装包对应的是最终源码**，没有漏打包。
- 用 Apple Silicon 版内置引擎实测转换：126 页 Word → PDF 成功
  （`{"ok":true,"missingFonts":[]}`，约 1 秒），引擎可用。

校验和（发布 Release 时可直接贴）：

```
f8d05d458539d9e60ab9569843f1bbd9103cf4f5314fafe4cfc8547ec8f9a813  秒转 PDF（Apple Silicon）.zip
d8ec372398819a1c8fb757b0a5040339ab202039d0daffe3172f249c8a1d71e7  秒转 PDF（Intel）.zip
```

---

## 5. 当前产物清单

```
pdf-quick-standalone/
├── dist/
│   ├── 安装包（Apple Silicon）/      # 可直接拷走安装
│   ├── 安装包（Intel）/
│   ├── 秒转 PDF（Apple Silicon）.zip # 65 MB，发 Release 用
│   ├── 秒转 PDF（Intel）.zip         # 67 MB，发 Release 用
│   └── 秒转 PDF.workflow            # Finder 快速操作
├── vendor/engine-arm64/  vendor/engine-x64/   # 内置引擎（构建产物，不进 git）
├── build/                            # 编译中间产物（不进 git）
├── src/                              # 全部源码
├── docs/                             # 截图、发布说明、本文档
├── git 首次提交 d01be16              # 23 个文件，约 2 MB
```

---

## 6. 还剩什么（按顺序）

1. **建 GitHub 仓库**（`pdf-quick`），把本地提交推上去。
2. **发 v1.0.0 Release**，上传两个 zip；说明文字用 `docs/RELEASE_NOTES_v1.0.0.md`。
3. **改 README 下载链接**（现在「下载哪个版本」表格还不能点，
   原因就是仓库地址还没定）。
4. 可选：Apple 开发者签名 + 公证（$99/年）。现在 ad-hoc 签名，
   别人下载后要「右键 → 打开」，文档里已写清楚。

推送需要新机上的 GitHub 凭据。**这步需要你提供账号或授权**，见对话里的问题。

---

## 7. 常见操作备忘

```bash
# 重新构建（需要 Xcode CLT；引擎已在 vendor/，不用联网）
cd pdf-quick-standalone
./build.sh              # 两套安装包
./build.sh --host-only  # 只打本机架构，快

# 只剩源码、没有 vendor/ 时，先下载引擎（约 24 MB）
./fetch-engine.sh

# 装到本机（会写 ~/Applications 和 ~/Library/Services）
./install.sh
./uninstall.sh

# 校验安装包
shasum -a 256 dist/*.zip
```

---

## 8. 注意

- `dist/`、`vendor/`、`build/` 已在 `.gitignore` 里，**不要提交**（否则 clone 很慢）。
- GitHub Release 单附件上限 2 GB，两个包 130 MB 左右，没问题。
- 首次打开被 Gatekeeper 拦是 ad-hoc 签名的正常现象，不是包坏了。
- 本地 git 的作者信息暂用旧机上的 `shicode <qijihku@163.com>`，
  需要改的话在推送前 `git commit --amend --reset-author`。
