#!/bin/bash
# 构建「秒转 PDF」独立版：应用 + Finder 快速操作 + 两套安装包
#
# 与原版的区别：转换引擎（Node 运行时 + LibreOffice Kit）打包进应用本体，
# 目标 Mac 不需要安装 DeepSeek Harness、LibreOffice 或任何其他东西。
#
# 用法：
#   ./build.sh                # 编译 + 两个架构的安装包
#   ./build.sh --host-only    # 只打当前架构（开发调试用，快很多）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
BUILD="$ROOT/build"
VENDOR="$ROOT/vendor"
STAGE_ROOT="$(mktemp -d /tmp/pdfquick-build.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"' EXIT

APP_NAME="秒转 PDF"
HOST_ONLY=0
[ "${1:-}" = "--host-only" ] && HOST_ONLY=1

HOST_ARCH="$(uname -m)"   # arm64 / x86_64

# 架构 -> (Swift target, 引擎包后缀, 安装包名)
arr_target=(); arr_engine=(); arr_label=()
if [ "$HOST_ONLY" = "1" ]; then
    if [ "$HOST_ARCH" = "arm64" ]; then
        arr_target=(arm64); arr_engine=(arm64); arr_label=("Apple Silicon")
    else
        arr_target=(x86_64); arr_engine=(x64); arr_label=("Intel")
    fi
else
    arr_target=(x86_64 arm64)
    arr_engine=(x64 arm64)
    arr_label=("Intel" "Apple Silicon")
fi

mkdir -p "$DIST" "$BUILD/tmp" "$BUILD/modulecache"

# ---------------------------------------------------------------- 图标
echo "==> 准备图标"
# 图标源文件是 src/icon/make-icon.py；仓库里同时放了生成好的 AppIcon.icns，
# 这样没有 Pillow 的机器也能直接构建。
if [ "${PDFQUICK_REBUILD_ICON:-0}" = "1" ] && "${PDFQUICK_PYTHON:-python3}" -c 'import PIL' >/dev/null 2>&1; then
    "${PDFQUICK_PYTHON:-python3}" src/icon/make-icon.py >/dev/null
    cp "$BUILD/AppIcon.icns" src/icon/AppIcon.icns
elif [ -f src/icon/AppIcon.icns ]; then
    mkdir -p "$BUILD"
    cp src/icon/AppIcon.icns "$BUILD/AppIcon.icns"
else
    echo "    缺少图标：src/icon/AppIcon.icns 不存在" >&2
    exit 1
fi

# ------------------------------------------------------- 编译（通用二进制）
echo "==> 编译 Swift 应用（x86_64 + arm64 通用二进制）"
for arch in x86_64 arm64; do
    TMPDIR="$BUILD/tmp" swiftc \
        -swift-version 5 \
        -target "${arch}-apple-macos13.0" \
        -O \
        -module-cache-path "$BUILD/modulecache" \
        -o "$BUILD/PDFQuick-${arch}" \
        src/app/*.swift
done
/usr/bin/lipo -create "$BUILD/PDFQuick-x86_64" "$BUILD/PDFQuick-arm64" \
    -output "$BUILD/PDFQuick-universal"
echo "    $(/usr/bin/lipo -archs "$BUILD/PDFQuick-universal")"

# ------------------------------------------------- 逐个架构组装应用包
assemble_app() {
    local engine_arch="$1"     # x64 / arm64
    local stage="$2"
    local engine_src="$VENDOR/engine-$engine_arch"

    [ -x "$engine_src/bin/dsoffice" ] || {
        echo "缺少 $engine_arch 转换引擎：$engine_src（先运行 ./fetch-engine.sh）" >&2; exit 1; }

    mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources/engine"

    cp "$BUILD/PDFQuick-universal" "$stage/Contents/MacOS/PDFQuick"
    chmod 755 "$stage/Contents/MacOS/PDFQuick"
    cp src/app/Info.plist "$stage/Contents/Info.plist"
    cp "$BUILD/AppIcon.icns" "$stage/Contents/Resources/AppIcon.icns"

    # 转换引擎：dsoffice 可执行文件 + LibreOffice 资源，由 Swift 直接调用。
    # 不含 Node.js —— 这是安装包从约 290 MB 降到约 165 MB 的关键。
    local engine_dir="$stage/Contents/Resources/engine"
    /usr/bin/ditto "$engine_src/bin" "$engine_dir/bin"
    /usr/bin/ditto "$engine_src/program" "$engine_dir/program"
    /usr/bin/ditto "$engine_src/licenses" "$engine_dir/licenses"
    cp "$engine_src/package.json" "$engine_dir/package.json"
    cp "$engine_src/prebuilds.json" "$engine_dir/prebuilds.json"
    # 引擎的构建脚本入包，满足 MPL-2.0 的源码可得性要求
    [ -d "$engine_src/sources" ] && /usr/bin/ditto "$engine_src/sources" "$engine_dir/sources"

    # 工作区在 iCloud/文稿目录里，文件会带上 provenance 等扩展属性，签名前要清掉。
    /usr/bin/xattr -cr "$stage" 2>/dev/null || true
    if /usr/bin/codesign --force --sign - "$stage" >/dev/null 2>&1; then
        echo "    $engine_arch：ad-hoc 签名完成"
    else
        echo "    警告（$engine_arch）：ad-hoc 签名失败（应用仍可在本机运行）"
    fi
}

# --------------------------------------------------------- 生成安装包
make_package() {
    local engine_arch="$1"
    local label="$2"
    local app_src="$3"
    local pkg="$DIST/安装包（$label）"
    local zip="$DIST/秒转 PDF（$label）.zip"

    rm -rf "$pkg" "$zip"
    mkdir -p "$pkg"
    /usr/bin/ditto "$app_src" "$pkg/$APP_NAME.app"
    /usr/bin/ditto "$DIST/$APP_NAME.workflow" "$pkg/$APP_NAME.workflow"
    cp src/installer/安装.command "$pkg/安装.command"
    cp src/installer/卸载.command "$pkg/卸载.command"
    cp src/installer/安装说明.txt "$pkg/安装说明.txt"
    chmod +x "$pkg/安装.command" "$pkg/卸载.command"

    /usr/bin/xattr -cr "$pkg" 2>/dev/null || true
    /usr/bin/ditto -c -k --norsrc --keepParent "$pkg" "$zip"
    echo "    $pkg"
    echo "    $zip"
}

echo "==> 生成 Finder 快速操作"
/usr/bin/python3 src/workflow/build-workflow.py "$DIST/$APP_NAME.workflow" >/dev/null

echo "==> 组装并打包"
# 一次只保留一个架构的中间产物：应用约 280 MB，两个同时存在很容易把磁盘塞满。
for i in "${!arr_engine[@]}"; do
    engine_arch="${arr_engine[$i]}"
    label="${arr_label[$i]}"
    stage="$STAGE_ROOT/app-$engine_arch"
    echo "  · $label（$engine_arch）"
    assemble_app "$engine_arch" "$stage"
    make_package "$engine_arch" "$label" "$stage"
    rm -rf "$stage"
done

echo
echo "==> 完成"
du -sh "$DIST/安装包"* "$DIST"/*.zip 2>/dev/null | sed 's/^/    /'
