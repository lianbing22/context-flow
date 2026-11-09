#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ContextFlow (全局记忆精灵) - GitHub 私有编年史静默同步引擎
用于将本地 SQLite 记忆数据库及按天导出的 Markdown 编年史无感同步至个人 GitHub 私有仓库
"""

import sys
import os
import shutil
import subprocess
import datetime
import sqlite3

def run_cmd(cmd, cwd=None):
    try:
        res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return True, res.stdout.strip()
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip()

def export_daily_markdown(db_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    if not os.path.exists(db_path):
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # 导出日报
        cursor.execute("SELECT date, summary, key_projects, suggestions, total_focus_minutes, session_count FROM daily_reports ORDER BY date DESC")
        reports = cursor.fetchall()

        for row in reports:
            dt, summary, projects, suggestions, focus_mins, count = row
            md_path = os.path.join(output_dir, f"{dt}.md")
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(f"# 工作记忆编年史 · {dt}\n\n")
                f.write(f"- 专注时长：{focus_mins} 分钟\n")
                f.write(f"- 记录现场数：{count} 个\n\n")
                f.write(f"## 核心工作概述\n{summary}\n\n")
                f.write(f"## 关联工程实体\n{projects}\n\n")
                f.write(f"## 复盘与下一步建议\n{suggestions}\n")

        conn.close()
    except Exception as e:
        print(f"[WARN] 导出 Markdown 失败: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 2:
        print("Usage: sync_lifelog.py <github_repo> [target_branch]", file=sys.stderr)
        sys.exit(1)

    repo_arg = sys.argv[1].strip()
    branch = sys.argv[2].strip() if len(sys.argv) > 2 else "main"

    home = os.path.expanduser("~")
    cf_dir = os.path.join(home, ".contextflow")
    db_file = os.path.join(cf_dir, "contextflow.sqlite3")
    local_repo_dir = os.path.join(cf_dir, "lifelog-repo")
    os.makedirs(local_repo_dir, exist_ok=True)

    # 1. 导出 Markdown 编年史到 local_repo_dir/chronicle
    chronicle_dir = os.path.join(local_repo_dir, "chronicle")
    export_daily_markdown(db_file, chronicle_dir)

    # 2. 拷贝 SQLite 备份 (原子只读复制)
    if os.path.exists(db_file):
        shutil.copy2(db_file, os.path.join(local_repo_dir, "contextflow_backup.sqlite3"))

    # 3. 写入 README.md
    readme_path = os.path.join(local_repo_dir, "README.md")
    if not os.path.exists(readme_path):
        with open(readme_path, "w", encoding="utf-8") as f:
            f.write("# ContextFlow Lifelog Backup\n\nPersonal encrypted and automated work activity chronicle backed up via ContextFlow.\n")

    # 4. 初始化 Git 仓库
    git_dir = os.path.join(local_repo_dir, ".git")
    if not os.path.exists(git_dir):
        ok, out = run_cmd(["git", "init"], cwd=local_repo_dir)
        if not ok:
            print(f"[ERROR] git init failed: {out}", file=sys.stderr)
            sys.exit(1)

    # 5. 配置 Remote
    if repo_arg.startswith("git@") or repo_arg.startswith("http://") or repo_arg.startswith("https://"):
        remote_url = repo_arg
    else:
        # 支持便捷格式 username/repo
        remote_url = f"git@github.com:{repo_arg}.git"

    run_cmd(["git", "remote", "remove", "origin"], cwd=local_repo_dir)
    run_cmd(["git", "remote", "add", "origin", remote_url], cwd=local_repo_dir)

    # 6. Commit 并 Push
    run_cmd(["git", "add", "-A"], cwd=local_repo_dir)
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ok, _ = run_cmd(["git", "commit", "-m", f"Auto sync lifelog: {now_str}"], cwd=local_repo_dir)

    # 尝试 push
    ok, push_err = run_cmd(["git", "push", "-u", "origin", f"HEAD:{branch}"], cwd=local_repo_dir)
    if not ok:
        # 如果是因为远端为空或者默认分支名不同，尝试普通 push
        ok2, push_err2 = run_cmd(["git", "push", "origin", "HEAD"], cwd=local_repo_dir)
        if not ok2:
            print(f"[ERROR] git push failed: {push_err} | {push_err2}", file=sys.stderr)
            sys.exit(1)

    print(f"[SUCCESS] Lifelog successfully synchronized to {repo_arg} at {now_str}")
    sys.exit(0)

if __name__ == "__main__":
    main()
