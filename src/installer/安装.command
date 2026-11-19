#!/bin/bash
# 秒转 PDF · 安装脚本（安装包内使用）
cd "$(dirname "$0")" || exit 1
set -uo pipefail

APP_SRC="$PWD/秒转 PDF.app"
WF_SRC="$PWD/秒转 PDF.workflow"
APP_DST="$HOME/Applications/秒转 PDF.app"
WF_DST="$HOME/Library/Services/秒转 PDF.workflow"
SUPPORT="$HOME/Library/Application Support/PDFQuick"

pause_exit() { echo; echo "按回车关闭窗口。"; read -r _; }
fail() { echo; echo "✗ $1"; pause_exit; exit 1; }

clear
echo "======================================"
echo "   秒转 PDF  安装"
echo "======================================"
echo

[ -d "$APP_SRC" ] || fail "安装包不完整：缺少「秒转 PDF.app」"
[ -d "$WF_SRC" ] || fail "安装包不完整：缺少「秒转 PDF.workflow」"
[ -x "$APP_SRC/Contents/Resources/engine/bin/dsoffice" ] || fail "应用不完整：缺少内置转换引擎。请重新下载安装包。"

ARCH="$(uname -m)"
case "$ARCH" in
    arm64)   VARIANT="Apple Silicon"; NEED_ARCH="arm64" ;;
    x86_64)  VARIANT="Intel";         NEED_ARCH="x86_64" ;;
    *)       VARIANT="$ARCH";         NEED_ARCH="" ;;
esac
echo "本机：$VARIANT（$ARCH）"
echo "转换引擎已内置在应用里，不需要安装 DeepSeek Harness 或其他软件。"

# 装错架构时提前拦住，否则转换时才失败，很难排查。
ENGINE_ARCHS="$(/usr/bin/lipo -archs "$APP_SRC/Contents/Resources/engine/bin/dsoffice" 2>/dev/null || true)"
if [ -n "$NEED_ARCH" ] && [ -n "$ENGINE_ARCHS" ]; then
    case " $ENGINE_ARCHS " in
        *" $NEED_ARCH "*) ;;
        *)
            echo
            echo "✗ 这个安装包不是给本机用的。"
            echo "  本机是 $VARIANT（$ARCH），但安装包里的引擎是：$ENGINE_ARCHS"
            echo "  请下载对应版本：Apple Silicon 版 / Intel 版。"
            pause_exit
            exit 1
            ;;
    esac
fi
echo

echo "→ 退出正在运行的旧版本"
killall -q PDFQuick 2>/dev/null
if [ -f "$SUPPORT/daemon.pid" ]; then
    DAEMON_PID="$(cat "$SUPPORT/daemon.pid" 2>/dev/null || true)"
    if [ -n "${DAEMON_PID:-}" ] && ps -p "$DAEMON_PID" -o command= 2>/dev/null | grep -q "daemon.mjs"; then
        kill "$DAEMON_PID" 2>/dev/null
        sleep 1
        kill -9 "$DAEMON_PID" 2>/dev/null
    fi
fi
rm -f "$SUPPORT/daemon.pid" "$SUPPORT/daemon.sock" 2>/dev/null

echo "→ 安装应用到 ~/Applications"
mkdir -p "$HOME/Applications" "$HOME/Library/Services"
rm -rf "$APP_DST" "$WF_DST"
/usr/bin/ditto "$APP_SRC" "$APP_DST" || fail "复制应用失败"
/usr/bin/ditto "$WF_SRC" "$WF_DST" || fail "复制快速操作失败"

# 从别的电脑拷过来会带隔离属性，清掉，否则 Gatekeeper 会拦截。
/usr/bin/xattr -cr "$APP_DST" 2>/dev/null
/usr/bin/xattr -cr "$WF_DST" 2>/dev/null
# 重新做一次 ad-hoc 签名，让系统认这个新位置。
/usr/bin/codesign --force --sign - "$APP_DST" >/dev/null 2>&1

echo "→ 注册 Finder 右键「快速操作」"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP_DST" >/dev/null 2>&1
/System/Library/CoreServices/pbs -read_bundle "$WF_DST" >/dev/null 2>&1
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1
sleep 1

echo "→ 启动应用"
open "$APP_DST"

echo
echo "✓ 安装完成！"
echo
echo "  用法：右键文件 →「快速操作」→「秒转 PDF」"
echo "        或打开「秒转 PDF」，把文件拖进小窗口。"
echo
echo "  第一次转换时，macOS 会问是否允许访问「文稿 / 桌面 / 下载」，请点「允许」。"
echo
echo "  如果右键菜单里暂时看不到：注销后重新登录一次。"
pause_exit
