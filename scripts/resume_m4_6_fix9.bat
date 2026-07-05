@echo off
REM ============================================================
REM M4.6-fix9 Resume Task — 2026-07-06 01:00
REM 唤起 ZCode 客户端，打开电子书阅读平台项目，让 agent 读 RESUME.md 续任务
REM ============================================================

REM 切到项目目录（用于后续可能的构建/测试命令）
cd /d "H:\projiect\电子书阅读平台"

REM 唤起 ZCode 客户端（Electron 单实例：若已运行则聚焦窗口，否则启动）
start "" "H:\zcode\ZCode.exe"

REM 给 ZCode 一点时间启动/聚焦
timeout /t 3 /nobreak >nul

REM 用 PowerShell 把"继续指令"写到一个临时文件，并尝试用 zcode:// deep link 打开项目
REM （deep link 是 ZCode 注册的协议，能携带参数唤起；若不支持项目路径参数，仅唤起客户端）
powershell -NoProfile -Command "Start-Process 'zcode://open' -ErrorAction SilentlyContinue"

REM 写一行唤醒日志（便于排查定时任务是否真的触发）
echo [%date% %time%] M4.6-fix9 resume task triggered >> "%TEMP%\zhiyue_resume_task.log"

REM ============================================================
REM 注意：本脚本无法"自动向 agent 发送消息"。
REM 定时任务触发后，ZCode 客户端窗口会打开。请用户在窗口里输入：
REM   "读取 H:\projiect\电子书阅读平台\RESUME.md，按里面的指示继续 M4.6-fix9 任务"
REM agent 会读 RESUME.md 自动续上。
REM
REM 如果用户在睡觉：醒来后看到 ZCode 窗口已打开，输入上面那句话即可。
REM ============================================================
