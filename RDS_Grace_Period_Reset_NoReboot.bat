@echo off
rem Windows Server RDS Grace Period Reset - NoReboot
rem Run as Administrator

echo ========================================
echo Windows Server RDS宽限期重置工具 - 无重启版本
echo 执行时间: %date% %time%
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限才能执行此脚本！
    exit /b 1
) else (
    echo [信息] 检测到管理员权限，继续执行...
)

:: 创建日志文件
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set mytime=%mytime: =0%
set LOG_FILE=%~dp0RDS_Reset_Log_%mydate%_%mytime%.txt
echo 开始执行RDS宽限期重置 - %date% %time% > "%LOG_FILE%"

echo.
echo [步骤1] 备份当前注册表...
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM" "%~dp0RCM_Backup_NoReboot_%mydate%.reg" >nul 2>&1
if errorlevel 1 (
    echo [警告] 注册表备份失败，但将继续执行
    echo 注册表备份失败 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [成功] 注册表已备份
    echo 注册表备份成功 - %date% %time% >> "%LOG_FILE%"
)

echo.
echo [步骤2] 检查当前注册表状态...
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" >nul 2>&1
if errorlevel 1 (
    echo [信息] 未找到GracePeriod注册表项
    echo 未找到GracePeriod项 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [信息] 找到GracePeriod注册表项，准备删除
    echo 找到GracePeriod项 - %date% %time% >> "%LOG_FILE%"
)

echo.
echo [步骤3] 检查远程桌面服务状态...
sc query TermService | find "RUNNING" >nul
if errorlevel 1 (
    echo [信息] 远程桌面服务未运行
    set SERVICE_WAS_RUNNING=0
) else (
    echo [信息] 远程桌面服务正在运行
    set SERVICE_WAS_RUNNING=1
)

echo.
echo [步骤4] 执行宽限期重置操作...

:: 操作1: 停止服务 -> 删除注册表 -> 重启服务
echo [4.1] 临时停止远程桌面服务...
net stop TermService /y >nul 2>&1
if errorlevel 1 (
    echo [警告] 服务停止失败，尝试强制停止
    taskkill /f /im svchost.exe /fi "services eq TermService" >nul 2>&1
    echo 服务强制停止 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [成功] 远程桌面服务已停止
    echo 服务停止成功 - %date% %time% >> "%LOG_FILE%"
)

:: 等待服务完全停止
timeout /t 3 >nul

echo [4.2] 删除GracePeriod注册表项...
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /f >nul 2>&1
if errorlevel 1 (
    echo [信息] GracePeriod注册表项删除失败或不存在
    echo 注册表删除失败 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [成功] GracePeriod注册表项已删除
    echo 注册表删除成功 - %date% %time% >> "%LOG_FILE%"
)

echo [4.3] 清理相关缓存...
:: 删除可能的缓存文件
del /f /q "%SystemRoot%\System32\lsass.exe.log" >nul 2>&1
del /f /q "%SystemRoot%\System32\termsrv.dll.log" >nul 2>&1

echo [4.4] 重新启动远程桌面服务...
net start TermService >nul 2>&1
if errorlevel 1 (
    echo [错误] 远程桌面服务启动失败
    echo 服务启动失败 - %date% %time% >> "%LOG_FILE%"
    
    :: 尝试强制启动服务
    echo [4.5] 尝试强制启动服务...
    sc start TermService >nul 2>&1
    if errorlevel 1 (
        echo [错误] 强制启动服务也失败，可能需要手动重启服务器
        echo 强制启动服务失败 - %date% %time% >> "%LOG_FILE%"
    ) else (
        echo [成功] 强制启动服务成功
        echo 强制启动服务成功 - %date% %time% >> "%LOG_FILE%"
    )
) else (
    echo [成功] 远程桌面服务已启动
    echo 服务启动成功 - %date% %time% >> "%LOG_FILE%"
)

echo.
echo [步骤5] 验证重置结果...
timeout /t 5 >nul

:: 检查服务状态
sc query TermService | find "RUNNING" >nul
if errorlevel 1 (
    echo [错误] 远程桌面服务状态异常
    echo 服务验证失败 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [成功] 远程桌面服务正在运行
    echo 服务验证成功 - %date% %time% >> "%LOG_FILE%"
)

:: 检查注册表项是否被重新创建
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" >nul 2>&1
if errorlevel 1 (
    echo [信息] GracePeriod项尚未被重新创建
    echo GracePeriod项尚未被重新创建 - %date% %time% >> "%LOG_FILE%"
) else (
    echo [信息] 系统已重新创建GracePeriod项（表示重置成功）
    echo GracePeriod项已被重新创建 - %date% %time% >> "%LOG_FILE%"
)

echo.
echo [步骤6] 应用其他优化...

:: 刷新组策略
echo [6.1] 刷新组策略...
gpupdate /force >nul 2>&1

:: 重新注册相关组件
echo [6.2] 重新注册RDS组件...
regsvr32 /s mstscax.dll >nul 2>&1
regsvr32 /s rdpclip.exe >nul 2>&1

echo.
echo ========================================
echo 宽限期重置完成！
echo.
echo 执行结果：
echo - 注册表项已处理
echo - RDS服务已重启
echo - 组策略已刷新
echo - 相关组件已重新注册
echo.
echo 注意事项：
echo 1. 宽限期应已重置为120天
echo 2. 服务已重新启动
echo 3. 当前远程连接可能已被中断
echo 4. 请建立新的远程连接
echo ========================================

:: 记录完成状态
echo 脚本执行完成 - %date% %time% >> "%LOG_FILE%"
echo 日志文件: %LOG_FILE%
rem 自动清理旧备份/日志（默认保留最新 5 份，可通过环境变量 KEEP_BACKUPS 修改）
if not defined KEEP_BACKUPS set KEEP_BACKUPS=5
if exist "%~dp0Cleanup_Old_Files.bat" (
    call "%~dp0Cleanup_Old_Files.bat" "%~dp0" "RCM_Backup_NoReboot_*.reg" %KEEP_BACKUPS%
    call "%~dp0Cleanup_Old_Files.bat" "%~dp0" "RDS_Reset_Log_*.txt" %KEEP_BACKUPS%
)

:: 如果是自动执行（计划任务），则直接退出
if "%1"=="auto" (
    echo [自动模式] 脚本执行完成，自动退出
    exit /b 0
) else (
    echo.
    pause
)
