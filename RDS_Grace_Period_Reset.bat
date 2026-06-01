@echo off
rem Windows Server RDS Grace Period Reset - Standard
rem Run as Administrator

echo ========================================
echo Windows Server 2012 R2 RDS宽限期重置工具
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限才能执行此脚本！
    echo 请右键点击脚本选择"以管理员身份运行"
    pause
    exit /b 1
) else (
    echo [信息] 检测到管理员权限，继续执行...
)

echo.
echo [步骤1] 备份当前注册表...
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set mytime=%mytime: =0%
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM" "%~dp0RCM_Backup_%mydate%_%mytime%.reg" >nul 2>&1
if errorlevel 1 (
    echo [警告] 注册表备份失败，但将继续执行
) else (
    echo [成功] 注册表已备份
)

echo.
echo [步骤2] 停止远程桌面服务...
net stop TermService /y >nul 2>&1
if errorlevel 1 (
    echo [警告] 服务停止失败，尝试继续操作
) else (
    echo [成功] 远程桌面服务已停止
)
timeout /t 3 >nul

echo.
echo [步骤3] 删除GracePeriod注册表项...
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /f >nul 2>&1
if errorlevel 1 (
    echo [信息] GracePeriod注册表项删除失败或不存在（可能已删除）
) else (
    echo [成功] GracePeriod注册表项已删除
)

echo.
echo [步骤4] 重新启动远程桌面服务...
net start TermService >nul 2>&1
if errorlevel 1 (
    echo [错误] 远程桌面服务启动失败
) else (
    echo [成功] 远程桌面服务已启动
)

echo.
echo [步骤5] 显示当前系统时间...
echo 当前系统时间: %date% %time%

echo.
echo [步骤6] 验证宽限期重置结果...
timeout /t 5 >nul
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" >nul 2>&1
if errorlevel 1 (
    echo [信息] GracePeriod项已删除，等待系统重新创建...
    echo [提示] 系统将在下次服务启动或服务器重启时重新创建GracePeriod项并重置为120天
) else (
    echo [成功] 系统已重新创建GracePeriod项
    echo [信息] 宽限期应已重置为120天
)

echo.
echo ========================================
echo 脚本执行完成！
echo.
echo 重要提示：
echo 1. 请重新登录远程桌面确认宽限期是否有效
echo 2. RDS宽限期将被重置为120天
echo 3. 建议设置计划任务定期执行此脚本
echo 4. 验证方法：重新登录RDS会话查看宽限期提示
rem 自动清理旧备份（默认保留最新 5 份，可通过环境变量 KEEP_BACKUPS 修改）
if not defined KEEP_BACKUPS set KEEP_BACKUPS=5
if exist "%~dp0Cleanup_Old_Files.bat" (
    call "%~dp0Cleanup_Old_Files.bat" "%~dp0" "RCM_Backup_*.reg" %KEEP_BACKUPS% NoReboot
)
echo ========================================
echo.

:: 检查是否为自动模式（计划任务调用）
if "%1"=="auto" (
    echo [自动模式] 计划任务调用，将自动重启系统...
    echo 系统将在60秒后重启...
    shutdown /r /t 60 /c "RDS宽限期重置已完成，系统将自动重启"
    echo 重启已安排，脚本退出
    exit /b 0
)

:: 手动模式：询问用户
choice /c YN /m "是否立即重启系统以使更改生效 (Y/N)"
if errorlevel 2 (
    echo 请手动重启系统以使更改生效
) else (
    echo.
    echo 系统将在60秒后重启...
    shutdown /r /t 60 /c "RDS宽限期重置已完成，系统将重启"
    echo 如需取消重启，请按任意键...
    pause >nul
    shutdown /a
    echo 重启已取消
)

echo.
pause
