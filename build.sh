#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="全局记忆精灵"
APP_BUNDLE="${DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "==> 正在准备构建 ${APP_NAME}.app ..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制 Info.plist
cp "${DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> 正在使用 swiftc 编译源代码..."
swiftc \
  -O \
  -target arm64-apple-macosx14.0 \
  -framework Cocoa \
  -framework SwiftUI \
  -framework UserNotifications \
  -framework CoreGraphics \
  -framework Vision \
  "${DIR}/Sources/"*.swift \
  -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "==> 正在执行深度代码签名 (锁定 'app.memoryelf' 指定要求以彻底防止系统反复请求权限)..."
codesign --force --deep --sign - --identifier "app.memoryelf" -r='designated => identifier "app.memoryelf"' "${APP_BUNDLE}"

# 保持对旧路径 ContextFlow.app 的兼容软链接
ln -sfn "${APP_NAME}.app" "${DIR}/ContextFlow.app"

echo "==> 构建成功！"
echo "应用路径: ${APP_BUNDLE}"
