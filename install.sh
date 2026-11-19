#!/bin/bash
# 开发用：把 dist 里当前架构的安装包装到 ~/Applications，并注册 Finder 快速操作。
# 目标用户不需要跑这个脚本——他们用安装包里的「安装.command」。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

case "$(uname -m)" in
    arm64)  LABEL="Apple Silicon" ;;
    *)      LABEL="Intel" ;;
esac

PKG="${1:-$ROOT/dist/安装包（$LABEL）}"
APP_SRC="$PKG/秒转 PDF.app"
WF_SRC="$PKG/秒转 PDF.workflow"
APP_DST="$HOME/Applications/秒转 PDF.app"
WF_DST="$HOME/Library/Services/秒转 PDF.workflow"
SUPPORT="$HOME/Library/Application Support/PDFQuick"

if [ ! -d "$APP_SRC" ] || [ ! -d "$WF_SRC" ]; then
    echo "还没有构建，请先运行：./build.sh --host-only" >&2
    exit 1
fi

echo "==> 退出正在运行的旧版本"
killall -q PDFQuick 2>/dev/null || true
if [ -f "$SUPPORT/daemon.pid" ]; then
    OLD_PID="$(cat "$SUPPORT/daemon.pid" 2>/dev/null || true)"
    if [ -n "${OLD_PID:-}" ] && ps -p "$OLD_PID" -o command= 2>/dev/null | grep -q "daemon.mjs"; then
        kill "$OLD_PID" >/dev/null 2>&1 || true
        sleep 1
        kill -9 "$OLD_PID" >/dev/null 2>&1 || true
    fi
fi
rm -f "$SUPPORT/daemon.pid" "$SUPPORT/daemon.sock"
sleep 1

echo "==> 安装应用（$LABEL）"
mkdir -p "$HOME/Applications" "$HOME/Library/Services"
rm -rf "$APP_DST" "$WF_DST"
/usr/bin/ditto "$APP_SRC" "$APP_DST"
/usr/bin/ditto "$WF_SRC" "$WF_DST"

/usr/bin/xattr -cr "$APP_DST" 2>/dev/null || true
/usr/bin/codesign --force --sign - "$APP_DST" >/dev/null 2>&1 || true

echo "==> 注册 Finder 快速操作"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP_DST" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -read_bundle "$WF_DST" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
sleep 1

echo "==> 启动一次，让系统记住应用"
open "$APP_DST"

echo
echo "安装完成。"
echo "  · 右键文件 →「快速操作」→「秒转 PDF」"
echo "  · 或打开「秒转 PDF」，把文件拖进小窗口"
