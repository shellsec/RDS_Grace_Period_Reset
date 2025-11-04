# RDS宽限期检查脚本
# 用于验证RDS宽限期是否已重置为120天

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RDS宽限期状态检查工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[错误] 需要管理员权限！" -ForegroundColor Red
    Write-Host "请右键点击脚本选择'以管理员身份运行'" -ForegroundColor Yellow
    pause
    exit 1
}

# 方法1: 通过WMI查询
Write-Host "[方法1] 通过WMI查询宽限期..." -ForegroundColor Yellow
try {
    $tsSetting = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices -ErrorAction SilentlyContinue
    if ($tsSetting) {
        $graceDays = $tsSetting.GracePeriodDays
        if ($graceDays) {
            Write-Host "[成功] 宽限期剩余天数: $graceDays 天" -ForegroundColor Green
            if ($graceDays -eq 120) {
                Write-Host "[信息] ✓ 宽限期已成功重置为120天！" -ForegroundColor Green
            } elseif ($graceDays -gt 100) {
                Write-Host "[信息] 宽限期接近120天，可能已重置" -ForegroundColor Yellow
            } else {
                Write-Host "[警告] 宽限期剩余不足100天，可能需要重置" -ForegroundColor Red
            }
        } else {
            Write-Host "[信息] 无法获取宽限期天数" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[信息] 无法通过WMI查询（可能系统版本不支持）" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[信息] WMI查询失败: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# 方法2: 检查注册表
Write-Host "[方法2] 检查注册表GracePeriod项..." -ForegroundColor Yellow
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod"
if (Test-Path $regPath) {
    Write-Host "[信息] GracePeriod注册表项存在" -ForegroundColor Green
    try {
        $gracePeriod = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($gracePeriod) {
            Write-Host "[信息] 注册表项内容:" -ForegroundColor Cyan
            Get-ItemProperty -Path $regPath | Format-List
        }
    } catch {
        Write-Host "[信息] 无法读取注册表项详情" -ForegroundColor Yellow
    }
} else {
    Write-Host "[信息] GracePeriod注册表项不存在（可能已被删除，等待系统重新创建）" -ForegroundColor Yellow
    Write-Host "[提示] 如果刚执行重置脚本，这是正常现象。系统会在重启或服务重启后重新创建。" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[方法3] 检查TermService服务状态..." -ForegroundColor Yellow
$service = Get-Service -Name TermService -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "[信息] TermService服务状态: $($service.Status)" -ForegroundColor Cyan
    if ($service.Status -eq 'Running') {
        Write-Host "[成功] 远程桌面服务正在运行" -ForegroundColor Green
    } else {
        Write-Host "[警告] 远程桌面服务未运行" -ForegroundColor Red
    }
} else {
    Write-Host "[错误] 无法获取TermService服务信息" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "检查完成" -ForegroundColor Cyan
Write-Host ""
Write-Host "重要提示:" -ForegroundColor Yellow
Write-Host "1. 如果宽限期显示为120天，说明重置成功" -ForegroundColor White
Write-Host "2. 如果显示其他数值，可能需要重启服务器" -ForegroundColor White
Write-Host "3. 建议重新登录RDS会话查看实际的宽限期提示" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
pause

