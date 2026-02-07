#!/bin/bash

# 同意 Android SDK 协议
yes | sdkmanager --licenses

# 获取 Flutter 根目录并应用补丁
export FLUTTER_ROOT=$(flutter doctor -v | grep "Flutter SDK at" | awk '{print $NF}')
if [ -f "lib/scripts/bottom_sheet_patch.diff" ]; then
    cd $FLUTTER_ROOT && git apply $GITHUB_WORKSPACE/lib/scripts/bottom_sheet_patch.diff || true
    cd $GITHUB_WORKSPACE
fi

# 获取依赖
flutter pub get