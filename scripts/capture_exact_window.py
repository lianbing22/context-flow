import Quartz
import subprocess
import time
import os

def capture_window_for_app(app_name, output_path):
    options = Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements
    window_list = Quartz.CGWindowListCopyWindowInfo(options, Quartz.kCGNullWindowID)
    
    for w in window_list:
        owner = w.get(Quartz.kCGWindowOwnerName, '')
        wid = w.get(Quartz.kCGWindowNumber, 0)
        bounds = w.get(Quartz.kCGWindowBounds, {})
        width = bounds.get('Width', 0)
        height = bounds.get('Height', 0)
        
        if owner == app_name and width > 300 and height > 200:
            print(f"找到窗口 {owner}: id={wid}, {width}x{height}")
            # 使用 screencapture -l <windowid> 截取特定窗口，包含阴影或不含阴影
            subprocess.run(f"screencapture -x -l {wid} -o {output_path}", shell=True)
            return True
    return False

# 1. 激活并前置工作台
print("激活全局记忆精灵工作台...")
subprocess.run("""osascript -e '
tell application "全局记忆精灵" to activate
tell application "System Events"
    keystroke "0" using {command down, control down}
end tell
'""", shell=True)
time.sleep(1.5)

ok = capture_window_for_app("全局记忆精灵", "/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_dashboard_exact.png")
if ok:
    print("成功截取工作台窗口！")
else:
    print("未找到工作台窗口！")

# 2. 唤起设置窗口
print("唤起设置窗口...")
subprocess.run("""osascript -e '
tell application "全局记忆精灵" to activate
tell application "System Events"
    keystroke "," using {command down}
end tell
'""", shell=True)
time.sleep(1.5)

ok = capture_window_for_app("全局记忆精灵", "/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_settings_exact.png")
if ok:
    print("成功截取设置窗口！")
else:
    print("未找到设置窗口！")

