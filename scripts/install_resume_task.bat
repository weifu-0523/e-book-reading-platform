@echo off
REM ============================================================
REM 安装 M4.6-fix9 定时任务（需要右键"以管理员身份运行"）
REM 一次性运行：双击或右键管理员运行，注册成功后可删除本文件
REM ============================================================

echo.
echo === 安装 M4.6-fix9 定时任务 ===
echo 触发时间：2026-07-06 01:00:00
echo 任务内容：唤醒 ZCode 客户端，让 agent 读 RESUME.md 续任务
echo.

REM 自检：是否以管理员身份运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 本脚本需要管理员权限。
    echo 请右键本文件 ^> 以管理员身份运行。
    pause
    exit /b 1
)

REM 创建任务
schtasks /Create /TN "ZhiYue_M4_6_fix9_Resume" ^
    /TR "H:\projiect\电子书阅读平台\scripts\resume_m4_6_fix9.bat" ^
    /SC ONCE ^
    /ST 01:00 ^
    /SD 2026/07/06 ^
    /RL HIGHEST ^
    /F

if %errorLevel% neq 0 (
    echo.
    echo [失败] schtasks 创建失败，错误码 %errorLevel%
    pause
    exit /b %errorLevel%
)

echo.
echo [成功] 定时任务已注册：
schtasks /Query /TN "ZhiYue_M4_6_fix9_Resume" /V /FO LIST | findstr /C:"任务名" /C:"下次运行时间" /C:"状态"

echo.
echo 01:00 会自动唤起 ZCode 客户端。届时在 ZCode 窗口输入：
echo   读取 H:\projiect\电子书阅读平台\RESUME.md，按里面的指示继续 M4.6-fix9 任务
echo.
echo 任务完成后清理命令（任意终端运行）：
echo   schtasks /Delete /TN "ZhiYue_M4_6_fix9_Resume" /F
echo.
pause
