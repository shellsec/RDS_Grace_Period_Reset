@echo off
rem Create RDS Grace Period Reset Scheduled Task

echo ========================================
echo 创建RDS宽限期重置计划任务
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
set TASK_NAME=RDS_Grace_Period_Reset
set SCRIPT_PATH=%~dp0RDS_Grace_Period_Reset.bat

echo.
echo [信息] 任务名称: %TASK_NAME%
echo [信息] 脚本路径: %SCRIPT_PATH%
echo.

:: 检查脚本文件是否存在
if not exist "%SCRIPT_PATH%" (
    echo [错误] 找不到RDS_Grace_Period_Reset.bat文件！
    echo 请确保该脚本文件在同一目录下
    pause
    exit /b 1
)

echo [步骤1] 删除已存在的同名任务...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

echo [步骤2] 创建新的计划任务...
echo [信息] 任务配置：
echo   - 任务名称: %TASK_NAME%
echo   - 执行频率: 每3个月执行一次
echo   - 执行时间: 凌晨2:00
echo   - 运行权限: 系统最高权限
echo   - 执行模式: 自动重启（计划任务调用）
echo.

:: 创建计划任务，传递auto参数以实现自动重启
schtasks /create /tn "%TASK_NAME%" /tr "\"%SCRIPT_PATH%\" auto" /sc monthly /mo 3 /st 02:00 /ru "SYSTEM" /rl highest /f

if errorlevel 1 (
    echo [错误] 计划任务创建失败！
    echo 错误代码: %errorLevel%
    pause
    exit /b 1
) else (
    echo [成功] 计划任务创建成功！
    echo.
    echo 任务摘要：
    echo - 任务名称: %TASK_NAME%
    echo - 执行频率: 每3个月执行一次
    echo - 执行时间: 凌晨2:00
    echo - 运行权限: 系统权限
    echo - 自动重启: 是（计划任务调用时自动重启）
    echo.
)

echo [步骤3] 验证任务创建...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [错误] 任务验证失败
) else (
    echo [成功] 任务验证通过
    echo.
    echo 显示任务详细信息：
    schtasks /query /tn "%TASK_NAME%" /fo list /v
)

echo.
echo ========================================
echo 计划任务创建操作完成！
echo.
echo 重要提示：
echo 1. 任务将每3个月自动执行一次
echo 2. 执行时会自动重启RDS服务
echo 3. 执行完成后会自动重启服务器
echo 4. 可通过任务计划程序手动管理任务
echo 5. 建议定期检查任务执行状态
echo ========================================
echo.

choice /c YN /m "是否立即测试运行一次任务 (Y/N)"
if errorlevel 2 (
    echo 已取消测试运行
) else (
    echo.
    echo 正在测试运行任务...
    schtasks /run /tn "%TASK_NAME%"
    if errorlevel 1 (
        echo [错误] 任务触发失败
    ) else (
        echo [成功] 任务已触发运行
        echo 请等待任务执行完成
        echo 注意：任务执行完成后将自动重启服务器
    )
)

echo.
pause
