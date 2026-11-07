import subprocess
import time
import os

def run_cmd(cmd):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return p.stdout.strip()

print("1. 启动最新版 全局记忆精灵.app...")
subprocess.run("open /Users/lianb/.gemini/antigravity/scratch/context-flow/全局记忆精灵.app", shell=True)
time.sleep(2)

os.makedirs("/Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots", exist_ok=True)
os.makedirs("/Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54", exist_ok=True)

# 唤起工作台时间轴
print("2. 唤起工作台时间轴...")
run_cmd("""osascript -e '
tell application "全局记忆精灵" to activate
tell application "System Events"
    keystroke "0" using {command down, control down}
end tell
'""")
time.sleep(2)

print("3. 截取修复后的工作台全景 (对应截图 1)...")
run_cmd("screencapture -x -R 50,50,1180,760 /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_01_dashboard_timeline.png")
run_cmd("cp /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_01_dashboard_timeline.png /Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots/01_dashboard_timeline.png")

# 唤起设置窗口 AI 面板
print("4. 唤起设置窗口 AI 面板...")
run_cmd("""osascript -e '
tell application "全局记忆精灵" to activate
tell application "System Events"
    keystroke "," using {command down}
end tell
'""")
time.sleep(1.5)

print("5. 截取修复后的设置 AI 面板 (对应截图 2)...")
run_cmd("screencapture -x -R 100,100,720,680 /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_02_settings_ai.png")
run_cmd("cp /Users/lianb/.gemini/antigravity/brain/939106cc-a6f7-48b1-912c-39d153abcb54/verified_02_settings_ai.png /Users/lianb/.gemini/antigravity/scratch/context-flow/docs/screenshots/settings_ai.png")

print("全部验证截图完成！")
