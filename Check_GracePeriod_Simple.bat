@echo off
chcp 65001 >nul
:: 简化版RDS宽限期检查脚本
:: 用于快速验证RDS宽限期状态

echo ========================================
echo RDS宽限期快速检查工具
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限！
    pause
    exit /b 1
)

:: 检查注册表项是否存在
echo [检查] 注册表GracePeriod项...
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" >nul 2>&1
if errorlevel 1 (
    echo [状态] GracePeriod项不存在
    echo [说明] 如果刚执行重置，这是正常的
    echo [说明] 系统会在重启后重新创建并重置为120天
) else (
    echo [状态] GracePeriod项存在
    echo [说明] 注册表项已存在，宽限期应已生效
)

echo.
echo [检查] TermService服务状态...
sc query TermService | find "RUNNING" >nul
if errorlevel 1 (
    echo [状态] 服务未运行
) else (
    echo [状态] 服务正在运行
)

echo.
echo ========================================
echo 验证建议:
echo 1. 重新登录RDS会话查看宽限期提示
echo 2. 如果显示120天，说明重置成功
echo 3. 如果未生效，请重启服务器
echo ========================================
echo.
pause

