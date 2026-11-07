#!/bin/bash

# 激活应用并唤起工作台
osascript << 'APPLESCRIPT'
tell application "全局记忆精灵" to activate
delay 0.5
tell application "System Events"
    keystroke "0" using {command down, control down}
end tell
APPLESCRIPT

sleep 1.5

# 获取工作台窗口 bounds: {x, y, w, h}
BOUNDS=$(osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "全局记忆精灵"
        set frontmost to true
        set w to first window
        set {x, y} to position of w
        set {w_width, w_height} to size of w
        return "" & x & "," & y & "," & w_width & "," & w_height
    end tell
end tell
APPLESCRIPT
)

echo "工作台窗口 bounds: $BOUNDS"
screencapture -x -R "$BOUNDS" /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_dashboard_exact.png

# 唤起设置窗口
osascript << 'APPLESCRIPT'
tell application "全局记忆精灵" to activate
delay 0.5
tell application "System Events"
    keystroke "," using {command down}
end tell
APPLESCRIPT

sleep 1.5

SETTINGS_BOUNDS=$(osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "全局记忆精灵"
        set frontmost to true
        set w to first window whose title contains "设置"
        set {x, y} to position of w
        set {w_width, w_height} to size of w
        return "" & x & "," & y & "," & w_width & "," & w_height
    end tell
end tell
APPLESCRIPT
)

echo "设置窗口 bounds: $SETTINGS_BOUNDS"
screencapture -x -R "$SETTINGS_BOUNDS" /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_settings_exact.png

echo "截取完成！"
