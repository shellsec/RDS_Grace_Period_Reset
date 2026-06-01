@echo off
rem Delete RDS Grace Period Reset Scheduled Tasks

echo ========================================
echo 删除RDS宽限期重置计划任务
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限才能删除计划任务
    echo 请右键点击脚本选择"以管理员身份运行"
    pause
    exit /b 1
) else (
    echo [信息] 检测到管理员权限，继续执行...
)

:: 设置任务名称
set TASK_NAME_1=RDS_Grace_Period_Reset
set TASK_NAME_2=RDS_Grace_Period_Reset_NoReboot

echo.
echo 检测到的RDS相关计划任务：
echo ----------------------------------------

:: 检查任务是否存在
set TASK1_EXISTS=0
set TASK2_EXISTS=0

schtasks /query /tn "%TASK_NAME_1%" >nul 2>&1
if errorlevel 1 (
    echo [ ] 未找到任务: %TASK_NAME_1%
) else (
    echo [+] 找到任务: %TASK_NAME_1% （标准版-需重启）
    set TASK1_EXISTS=1
)

schtasks /query /tn "%TASK_NAME_2%" >nul 2>&1
if errorlevel 1 (
    echo [ ] 未找到任务: %TASK_NAME_2%
) else (
    echo [+] 找到任务: %TASK_NAME_2% （无重启版）
    set TASK2_EXISTS=1
)

echo ----------------------------------------
echo.

:: 如果用户没有找到任何任务
if %TASK1_EXISTS%==0 if %TASK2_EXISTS%==0 (
    echo [信息] 未检测到任何RDS宽限期重置相关的计划任务
    echo 可能的原因：
    echo 1. 任务尚未创建
    echo 2. 任务已被手动删除
    echo 3. 任务名称不匹配
    echo.
    echo 提示：可通过以下命令查看所有计划任务：
    echo schtasks /query /fo table
    echo.
    pause
    exit /b 0
)

:: 用户选择逻辑
echo 选择删除操作：
echo 1. 删除所有找到的RDS重置任务（推荐）
echo 2. 显示任务详细信息后再决定
echo 3. 取消操作
echo.

choice /c 123 /m "请选择操作"
set user_choice=%errorLevel%

if %user_choice%==3 goto :cancel
if %user_choice%==2 goto :show_details
if %user_choice%==1 goto :delete_all

:delete_all
echo.
echo ========================================
echo 开始删除计划任务...
echo ========================================

if %TASK1_EXISTS%==1 (
    echo.
    echo [步骤1] 删除标准版任务: %TASK_NAME_1%
    schtasks /delete /tn "%TASK_NAME_1%" /f
    if errorlevel 1 (
        echo [错误] 标准版任务删除失败，错误代码: %errorLevel%
    ) else (
        echo [成功] 标准版任务已删除
    )
)

if %TASK2_EXISTS%==1 (
    echo.
    echo [步骤2] 删除无重启版任务: %TASK_NAME_2%
    schtasks /delete /tn "%TASK_NAME_2%" /f
    if errorlevel 1 (
        echo [错误] 无重启版任务删除失败，错误代码: %errorLevel%
    ) else (
        echo [成功] 无重启版任务已删除
    )
)
goto :verify_deletion

:show_details
echo.
echo ========================================
echo 计划任务详细信息
echo ========================================

if %TASK1_EXISTS%==1 (
    echo.
    echo 【标准版任务详情】
    echo 任务名称: %TASK_NAME_1%
    echo ----------------------------------------
    schtasks /query /tn "%TASK_NAME_1%" /fo list /v | findstr /C:"任务名" /C:"下次运行时间" /C:"上次运行时间" /C:"状态" /C:"计划任务状态" /C:"上次运行结果"
    echo ----------------------------------------
)

if %TASK2_EXISTS%==1 (
    echo.
    echo 【无重启版任务详情】
    echo 任务名称: %TASK_NAME_2%
    echo ----------------------------------------
    schtasks /query /tn "%TASK_NAME_2%" /fo list /v | findstr /C:"任务名" /C:"下次运行时间" /C:"上次运行时间" /C:"状态" /C:"计划任务状态" /C:"上次运行结果"
    echo ----------------------------------------
)

echo.
choice /c YN /m "查看完成后是否继续删除这些任务 (Y/N)"
if errorlevel 2 (
    goto :cancel
) else (
    goto :delete_all
)

:verify_deletion
echo.
echo [步骤3] 验证删除结果...

schtasks /query /tn "%TASK_NAME_1%" >nul 2>&1
if errorlevel 1 (
    echo [确认] 标准版任务已成功删除
) else (
    echo [警告] 标准版任务仍然存在
)

schtasks /query /tn "%TASK_NAME_2%" >nul 2>&1
if errorlevel 1 (
    echo [确认] 无重启版任务已成功删除
) else (
    echo [警告] 无重启版任务仍然存在
)

echo.
echo [步骤4] 检查相关文件及选项...
echo.
echo 相关的脚本文件：
if exist "%~dp0RDS_Grace_Period_Reset.bat" echo - RDS_Grace_Period_Reset.bat
if exist "%~dp0RDS_Grace_Period_Reset_NoReboot.bat" echo - RDS_Grace_Period_Reset_NoReboot.bat
if exist "%~dp0Create_Scheduled_Task.bat" echo - Create_Scheduled_Task.bat
if exist "%~dp0Create_Scheduled_Task_NoReboot.bat" echo - Create_Scheduled_Task_NoReboot.bat
if exist "%~dp0Monitor_RDS_Task.bat" echo - Monitor_RDS_Task.bat

echo.
echo 相关的日志和备份文件：
dir /b "%~dp0RDS_Reset_Log_*.txt" 2>nul
dir /b "%~dp0RCM_Backup_*.reg" 2>nul

echo.
choice /c YN /m "是否删除所有相关的日志和备份文件 (Y/N)"
if errorlevel 2 (
    echo [信息] 已保留相关文件
) else (
    echo.
    echo 删除日志和备份文件...
    del /f /q "%~dp0RDS_Reset_Log_*.txt" >nul 2>&1
    del /f /q "%~dp0RCM_Backup_*.reg" >nul 2>&1
    del /f /q "%~dp0Monitor_RDS_Task.bat" >nul 2>&1
    echo [成功] 相关文件已删除
)

goto :success

:cancel
echo.
echo [信息] 用户取消操作，未删除任何计划任务
goto :end

:success
echo.
echo ========================================
echo 计划任务删除完成！
echo ========================================
echo.
echo 删除摘要：
echo - RDS宽限期重置相关的计划任务已删除
echo - 系统将不再自动执行重置操作
echo - 相关脚本文件已保留，可手动执行
echo.
echo 注意事项：
echo 1. 删除任务后需要手动执行RDS重置
echo 2. 如需重新启用自动执行，请运行：
echo    - Create_Scheduled_Task.bat （标准版）
echo    - Create_Scheduled_Task_NoReboot.bat （无重启版）
echo 3. 所有的脚本文件仍可手动执行
echo ========================================

:end
echo.
pause
