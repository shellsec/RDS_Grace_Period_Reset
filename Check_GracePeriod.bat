@echo off
chcp 65001 >nul
:: RDS宽限期检查脚本
:: 用于验证RDS宽限期是否已重置为120天

echo ========================================
echo RDS宽限期状态检查工具
echo ========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [错误] 需要管理员权限！
    echo 请右键点击脚本选择"以管理员身份运行"
    pause
    exit /b 1
)

:: 方法1: 检查注册表
echo [方法1] 检查注册表GracePeriod项...
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" >nul 2>&1
if errorlevel 1 (
    echo [信息] GracePeriod注册表项不存在
    echo [提示] 如果刚执行重置脚本，这是正常现象
    echo [提示] 系统会在重启或服务重启后重新创建并重置为120天
) else (
    echo [成功] GracePeriod注册表项存在
    echo [信息] 正在读取注册表项内容...
    reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod"
)

echo.
echo [方法2] 检查TermService服务状态...
sc query TermService | find "RUNNING" >nul
if errorlevel 1 (
    echo [警告] 远程桌面服务未运行
) else (
    echo [成功] 远程桌面服务正在运行
)

echo.
echo [方法3] 尝试通过PowerShell查询宽限期天数...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $ts = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices -ErrorAction SilentlyContinue; if ($ts -and $ts.GracePeriodDays) { Write-Host '[成功] 宽限期剩余天数:' $ts.GracePeriodDays '天' -ForegroundColor Green; if ($ts.GracePeriodDays -eq 120) { Write-Host '[信息] 宽限期已成功重置为120天' -ForegroundColor Green } elseif ($ts.GracePeriodDays -gt 100) { Write-Host '[信息] 宽限期接近120天，可能已重置' -ForegroundColor Yellow } else { Write-Host '[警告] 宽限期剩余不足100天，可能需要重置' -ForegroundColor Red } } else { Write-Host '[信息] 无法通过WMI查询宽限期天数' -ForegroundColor Yellow } } catch { Write-Host '[信息] WMI查询失败（可能系统版本不支持）' -ForegroundColor Yellow }" 2>nul
if errorlevel 1 (
    echo [信息] PowerShell查询失败（可能执行策略受限）
)

echo.
echo ========================================
echo 检查完成
echo.
echo 重要提示:
echo 1. 如果宽限期显示为120天，说明重置成功
echo 2. 如果显示其他数值，可能需要重启服务器
echo 3. 建议重新登录RDS会话查看实际的宽限期提示
echo 4. 最佳验证方式：重新连接RDS，查看是否显示"120天"
echo ========================================
echo.
pause
