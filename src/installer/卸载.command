#!/bin/bash
# 秒转 PDF · 卸载脚本（安装包内使用）
cd "$(dirname "$0")" || exit 1
set -uo pipefail

APP_DST="$HOME/Applications/秒转 PDF.app"
WF_DST="$HOME/Library/Services/秒转 PDF.workflow"
SUPPORT="$HOME/Library/Application Support/PDFQuick"

echo "======================================"
echo "   秒转 PDF  卸载"
echo "======================================"
echo
printf "确定卸载「秒转 PDF」吗？已经生成的 PDF 不受影响。(y/N) "
read -r answer
case "$answer" in
    y|Y) ;;
    *) echo "已取消。"; exit 0 ;;
esac

echo "→ 退出应用与后台服务"
killall -q PDFQuick 2>/dev/null
if [ -f "$SUPPORT/daemon.pid" ]; then
    DAEMON_PID="$(cat "$SUPPORT/daemon.pid" 2>/dev/null || true)"
    if [ -n "${DAEMON_PID:-}" ] && ps -p "$DAEMON_PID" -o command= 2>/dev/null | grep -q "daemon.mjs"; then
        kill "$DAEMON_PID" 2>/dev/null
        sleep 2
        kill -9 "$DAEMON_PID" 2>/dev/null
    fi
fi
sleep 1

echo "→ 删除应用与右键快速操作"
rm -rf "$APP_DST" "$WF_DST"
rm -rf "$SUPPORT"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1

echo
echo "已卸载。"
echo
echo "按回车关闭窗口。"
read -r _
