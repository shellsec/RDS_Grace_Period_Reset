@echo off
chcp 65001 >nul
:: 创建RDS宽限期重置计划任务脚本 - 无重启版本

echo ========================================
echo 创建RDS宽限期重置计划任务 - 无重启版本
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限才能创建计划任务
    echo 请右键点击脚本选择"以管理员身份运行"
    pause
    exit /b 1
) else (
    echo [信息] 检测到管理员权限，继续执行...
)

:: 设置变量
set TASK_NAME=RDS_Grace_Period_Reset_NoReboot
set SCRIPT_PATH=%~dp0RDS_Grace_Period_Reset_NoReboot.bat

echo.
echo [信息] 任务名称: %TASK_NAME%
echo [信息] 脚本路径: %SCRIPT_PATH%
echo.

:: 检查脚本文件是否存在
if not exist "%SCRIPT_PATH%" (
    echo [错误] 找不到RDS_Grace_Period_Reset_NoReboot.bat文件！
    echo 请确保该脚本文件在同一目录下
    pause
    exit /b 1
)

echo 选择计划任务执行频率：
echo 1. 每2个月执行一次（推荐）
echo 2. 每3个月执行一次
echo 3. 每月执行一次（频率最高，最安全）
echo 4. 自定义频率
echo.

choice /c 1234 /m "请选择执行频率"
set freq_choice=%errorLevel%

if %freq_choice%==1 (
    set SCHEDULE_TYPE=monthly
    set SCHEDULE_MODIFIER=2
    set FREQ_DESC=每2个月
)
if %freq_choice%==2 (
    set SCHEDULE_TYPE=monthly
    set SCHEDULE_MODIFIER=3
    set FREQ_DESC=每3个月
)
if %freq_choice%==3 (
    set SCHEDULE_TYPE=monthly
    set SCHEDULE_MODIFIER=1
    set FREQ_DESC=每月
)
if %freq_choice%==4 (
    echo.
    echo 请输入执行间隔月数（1-12个月）:
    set /p SCHEDULE_MODIFIER=
    set SCHEDULE_TYPE=monthly
    set FREQ_DESC=每%SCHEDULE_MODIFIER%个月
)

echo.
echo 选择执行时间：
echo 1. 凌晨2:00（推荐，业务影响最小）
echo 2. 凌晨3:00
echo 3. 凌晨1:00
echo 4. 自定义时间
echo.

choice /c 1234 /m "请选择执行时间"
set time_choice=%errorLevel%

if %time_choice%==1 set EXEC_TIME=02:00
if %time_choice%==2 set EXEC_TIME=03:00
if %time_choice%==3 set EXEC_TIME=01:00
if %time_choice%==4 (
    echo.
    echo 请输入执行时间（格式：HH:MM，例如 02:30）:
    set /p EXEC_TIME=
)

echo.
echo [步骤1] 删除已存在的同名任务...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

echo [步骤2] 创建新的计划任务...
echo [信息] 任务配置：
echo   - 任务名称: %TASK_NAME%
echo   - 执行频率: %FREQ_DESC%
echo   - 执行时间: %EXEC_TIME%
echo   - 运行权限: 系统最高权限
echo   - 执行模式: 无重启（仅重启RDS服务）
echo.

:: 创建计划任务，传递auto参数以实现自动执行
schtasks /create /tn "%TASK_NAME%" /tr "\"%SCRIPT_PATH%\" auto" /sc %SCHEDULE_TYPE% /mo %SCHEDULE_MODIFIER% /st %EXEC_TIME% /ru "SYSTEM" /rl highest /f

if errorlevel 1 (
    echo [错误] 计划任务创建失败！
    echo 错误代码: %errorLevel%
    pause
    exit /b 1
) else (
    echo [成功] 计划任务创建成功！
    echo.
)

echo [步骤3] 配置高级选项...

:: 启用任务（确保系统启动时可用）
schtasks /change /tn "%TASK_NAME%" /enable >nul 2>&1

:: 配置失败时自动重试
schtasks /change /tn "%TASK_NAME%" /ri 10 /et 01:00:00 >nul 2>&1

echo [步骤4] 验证任务创建...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [错误] 任务验证失败
) else (
    echo [成功] 任务验证通过
    echo.
    echo 显示任务详细信息：
    echo ----------------------------------------
    schtasks /query /tn "%TASK_NAME%" /fo list /v | findstr /C:"任务名" /C:"下次运行时间" /C:"上次运行时间" /C:"状态" /C:"计划任务状态"
    echo ----------------------------------------
)

echo.
echo [步骤5] 创建监控脚本...

:: 创建一个简单的监控脚本
set MONITOR_SCRIPT=%~dp0Monitor_RDS_Task.bat
echo @echo off > "%MONITOR_SCRIPT%"
echo chcp 65001 ^>nul >> "%MONITOR_SCRIPT%"
echo :: RDS任务监控脚本 >> "%MONITOR_SCRIPT%"
echo echo 检查RDS宽限期重置任务状态... >> "%MONITOR_SCRIPT%"
echo schtasks /query /tn "%TASK_NAME%" /fo list ^| findstr /C:"状态" /C:"上次运行时间" /C:"下次运行时间" >> "%MONITOR_SCRIPT%"
echo echo. >> "%MONITOR_SCRIPT%"
echo echo 查看最近的日志文件... >> "%MONITOR_SCRIPT%"
echo dir /b /od "%~dp0RDS_Reset_Log_*.txt" 2^>nul >> "%MONITOR_SCRIPT%"
echo pause >> "%MONITOR_SCRIPT%"

if exist "%MONITOR_SCRIPT%" (
    echo [成功] 监控脚本已创建: Monitor_RDS_Task.bat
) else (
    echo [错误] 监控脚本创建失败
)

echo.
echo ========================================
echo 无重启版计划任务创建操作完成！
echo.
echo 任务摘要：
echo - 任务名称: %TASK_NAME%
echo - 执行频率: %FREQ_DESC%
echo - 执行时间: %EXEC_TIME%
echo - 执行方式: 无需重启服务器
echo - 服务中断: 约1-2分钟RDS服务重启
echo - 自动重试: 失败时10分钟后重试
echo.
echo 重要提示：
echo 1. 任务将自动在后台执行
echo 2. 执行时仅会短暂中断远程桌面连接
echo 3. 对业务影响最小
echo 4. 可通过Monitor_RDS_Task.bat查看状态
echo 5. 所有操作都会记录到日志文件
echo ========================================
echo.

choice /c YN /m "是否立即测试运行一次任务 (Y/N)"
if errorlevel 2 (
    echo 已取消测试运行
) else (
    echo.
    echo 正在测试运行任务...
    echo [警告] 任务执行将会中断当前远程连接！
    echo.
    choice /c YN /m "确认继续测试运行 (Y/N)"
    if errorlevel 2 (
        echo 已取消测试运行
    ) else (
        schtasks /run /tn "%TASK_NAME%"
        if errorlevel 1 (
            echo [错误] 任务触发失败
        ) else (
            echo [成功] 任务已触发运行
            echo 请等待1-2分钟后查看执行结果
            echo 可查看生成的日志文件了解详细执行情况
        )
    )
)

echo.
echo 常用命令：
echo - 查看任务状态: 运行 Monitor_RDS_Task.bat
echo - 手动执行任务: schtasks /run /tn "%TASK_NAME%"
echo - 禁用任务: schtasks /change /tn "%TASK_NAME%" /disable
echo - 删除任务: schtasks /delete /tn "%TASK_NAME%" /f
echo.
pause
