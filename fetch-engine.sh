#!/bin/bash
# 下载应用要内置的转换引擎（开发机执行一次即可，产物在 vendor/）
#
#   引擎：@deepseek-ai/libreoffice-kit-darwin-{x64,arm64}（LibreOffice，MPL-2.0）
#   来源：npm registry 的预编译包，直接解压，不需要 Node / npm。
#
# 版本升级时改 KIT_VERSION，再重新跑 ./fetch-engine.sh 和 ./build.sh。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

KIT_VERSION="${KIT_VERSION:-0.2.3}"
VENDOR="$ROOT/vendor"
mkdir -p "$VENDOR"

echo "==> 下载转换引擎 @deepseek-ai/libreoffice-kit@$KIT_VERSION"

for arch in x64 arm64; do
    package="libreoffice-kit-darwin-$arch"
    engine_dir="$VENDOR/engine-$arch"
    if [ -x "$engine_dir/bin/dsoffice" ]; then
        echo "    已存在，跳过：$arch"
        continue
    fi

    url="https://registry.npmjs.org/@deepseek-ai/$package/-/$package-$KIT_VERSION.tgz"
    echo "  · $arch"
    rm -rf "$engine_dir"
    mkdir -p "$engine_dir"
    # npm 包内层是 package/ 目录，strip 掉
    curl -fL --retry 3 --progress-bar "$url" | tar xzf - -C "$engine_dir" --strip-components=1

    [ -x "$engine_dir/bin/dsoffice" ] || {
        echo "安装失败：缺少 bin/dsoffice（${arch}）" >&2
        exit 1
    }
    chmod +x "$engine_dir/bin/dsoffice"
done

echo
echo "==> 完成"
du -sh "$VENDOR"/engine-*/ | sed 's/^/    /'
