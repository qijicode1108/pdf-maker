#!/bin/bash
cd "$(dirname "$0")" || exit 1
./install.sh
echo
echo "按回车关闭窗口。"
read -r _
