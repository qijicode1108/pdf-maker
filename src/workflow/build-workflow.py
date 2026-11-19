#!/usr/bin/env python3
"""生成 Finder 右键「快速操作 / 秒转 PDF」工作流。

以系统自带的 Show Map.workflow 为模板（保证 Automator 结构合法），
替换成调用本应用的 shell 脚本。
"""

import os
import plistlib
import shutil
import sys

TEMPLATE = "/System/Library/Services/Show Map.workflow"
SCRIPT = """APP="$HOME/Applications/秒转 PDF.app"
[ -d "$APP" ] || APP="/Applications/秒转 PDF.app"
if [ ! -d "$APP" ]; then
    osascript -e 'display alert "找不到「秒转 PDF」" message "请先运行安装脚本 install.command。"' >/dev/null 2>&1
    exit 0
fi
# 一次传多个文件最快；个别类型不被 LaunchServices 接受时，退回逐个打开。
if ! open -a "$APP" "$@" 2>/dev/null; then
    for file in "$@"; do
        open -a "$APP" "$file" 2>/dev/null || true
    done
fi
"""


def main(target):
    if os.path.exists(target):
        shutil.rmtree(target)
    contents = os.path.join(target, "Contents")
    resources = os.path.join(contents, "Resources")
    os.makedirs(resources, exist_ok=True)

    with open(os.path.join(TEMPLATE, "Contents", "Resources", "document.wflow"), "rb") as handle:
        document = plistlib.load(handle)

    action = document["actions"][0]["action"]
    parameters = action["ActionParameters"]
    parameters["COMMAND_STRING"] = SCRIPT
    parameters["inputMethod"] = 1
    parameters["shell"] = "/bin/bash"
    parameters["CheckedForUserDefaultShell"] = True
    action["CanShowSelectedItemsWhenRun"] = True
    action["arguments"]["0"]["default value"] = 1
    document["workflowMetaData"] = {
        "applicationBundleIDsByPath": {},
        "applicationPaths": [],
        "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "outputTypeIdentifier": "com.apple.Automator.nothing",
        "presentationMode": 15,
        "processesInput": 0,
        "serviceApplicationBundleID": "com.apple.finder",
        "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
        "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": 0,
        "systemImageName": "NSActionTemplate",
        "useAutomaticInputType": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    }

    with open(os.path.join(resources, "document.wflow"), "wb") as handle:
        plistlib.dump(document, handle, fmt=plistlib.FMT_XML)

    info = {
        "CFBundleDevelopmentRegion": "zh_CN",
        "CFBundleIdentifier": "com.qiji.pdfquick.quickaction",
        "CFBundleName": "秒转 PDF",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "NSServices": [
            {
                "NSMenuItem": {"default": "秒转 PDF"},
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
                "NSSendFileTypes": ["public.item"],
            }
        ],
    }
    with open(os.path.join(contents, "Info.plist"), "wb") as handle:
        plistlib.dump(info, handle, fmt=plistlib.FMT_XML)

    with open(os.path.join(contents, "version.plist"), "wb") as handle:
        plistlib.dump({
            "BuildVersion": "1053",
            "CFBundleShortVersionString": "1.0",
            "ProjectName": "Automator",
            "SourceVersion": "528000000000000",
        }, handle, fmt=plistlib.FMT_XML)

    print(target)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dist/秒转 PDF.workflow"))
