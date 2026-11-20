# 发布到 GitHub

## 1. 建仓库、推源码

`dist/`、`vendor/`、`build/` 已在 `.gitignore` 里，仓库只存源码（几 MB）：

```bash
cd pdf-quick-standalone
git init
git add .
git commit -m "秒转 PDF：自带转换引擎的独立版"
git branch -M main
git remote add origin git@github.com:<你的账号>/pdf-maker.git
git push -u origin main
```

## 2. 发 Release，上传安装包

```bash
./fetch-engine.sh          # 首次需要，下载引擎预编译包到 vendor/
./build.sh                 # 产出两个 zip
shasum -a 256 dist/*.zip   # 记下校验和，贴到 Release 说明里
```

在 GitHub 上 **Releases → Draft a new release**：

- Tag：`v1.0.0`
- 附件：`秒转 PDF（Apple Silicon）.zip`、`秒转 PDF（Intel）.zip`（各约 80 MB，远低于 2 GB 上限）
- 说明里写清楚：各下哪个、第一次要右键打开、首次转换 10–20 秒

> GitHub 单个 Release 附件上限 2 GB，两个包加起来 210 MB，没问题。
> 但仓库本身不要提交 `dist/`，否则 clone 会很慢。

## 3. 让 README 指向 Release

把 README 顶部换成本仓库的下载链接，例如：

```markdown
[下载 Apple Silicon 版](https://github.com/<账号>/pdf-quick/releases/latest/download/秒转 PDF（Apple Silicon）.zip)
[下载 Intel 版](https://github.com/<账号>/pdf-quick/releases/latest/download/秒转 PDF（Intel）.zip)
```

（文件名里有空格和中文，GitHub 会自动转义；如果链接失效，改用 Release 页面地址更稳。）

## 4. 关于 Gatekeeper（重要）

现在的包是 **ad-hoc 签名**，别人下载后第一次要「右键 → 打开」，
否则会提示「无法验证开发者」。文档里已经写了绕行方法，够用但不优雅。

要彻底解决需要 Apple Developer Program（$99/年）：

```bash
# 1) 用开发者证书签名（替换成你的证书名）
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: 你的名字 (TEAMID)" "dist/秒转 PDF.app"

# 2) 打成 dmg 或 zip 后公证
xcrun notarytool submit "秒转 PDF.zip" --keychain-profile "AC_PASSWORD" --wait

# 3) 装订票据
xcrun stapler staple "秒转 PDF.app"
```

改完之后 `build.sh` 里的 ad-hoc 签名那行替换成上面第一条即可。

## 5. 可选：Homebrew

有 Homebrew Tap 的话，用户可以用：

```bash
brew install --cask <你的tap>/pdf-maker
```

Cask 里指向 Release 的 zip，用 `sha256` 固定版本校验。

## 6. 引擎升级

```bash
# 改 fetch-engine.sh 顶部的 NODE_VERSION / KIT_VERSION
./fetch-engine.sh
./build.sh
# 确认转换正常后再发新 Release
```

升级后建议跑一遍：

```bash
"dist/安装包（Apple Silicon）/秒转 PDF.app/Contents/Resources/engine/bin/dsoffice" \
  --program-directory "dist/安装包（Apple Silicon）/秒转 PDF.app/Contents/Resources/engine/program/LibreOfficeDev.app/Contents/Resources" \
  --input-path "$PWD/样例.docx" --output-path "$PWD/样例.pdf" \
  --profile-directory /tmp/pdfquick-profile --max-output-bytes 536870912 \
  --max-image-resolution 144 --format pdf --recalculate false
```
