#!/bin/bash
# 卸载「秒转 PDF」：应用、右键快速操作、后台服务和数据。
set -euo pipefail

APP_DST="$HOME/Applications/秒转 PDF.app"
WF_DST="$HOME/Library/Services/秒转 PDF.workflow"
SUPPORT="$HOME/Library/Application Support/PDFQuick"

echo "==> 退出应用与后台服务"
osascript -e 'tell application "秒转 PDF" to quit' >/dev/null 2>&1 || true
if [ -f "$SUPPORT/daemon.pid" ]; then
    DAEMON_PID="$(cat "$SUPPORT/daemon.pid" 2>/dev/null || true)"
    if [ -n "${DAEMON_PID:-}" ] && ps -p "$DAEMON_PID" -o command= 2>/dev/null | grep -q "daemon.mjs"; then
        kill "$DAEMON_PID" >/dev/null 2>&1 || true
        sleep 2
        kill -9 "$DAEMON_PID" >/dev/null 2>&1 || true
    fi
fi
sleep 1

echo "==> 删除应用与快速操作"
rm -rf "$APP_DST" "$WF_DST"

echo "==> 删除缓存与日志"
rm -rf "$SUPPORT"

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

echo "已卸载。"
