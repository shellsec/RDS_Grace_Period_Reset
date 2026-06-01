@echo off
setlocal enabledelayedexpansion
rem Keep newest N backup/log files, delete older ones
rem Usage: Cleanup_Old_Files.bat <dir> <pattern> [keep_count] [exclude_keyword]
rem Env override: set KEEP_BACKUPS=10

set "BASE=%~1"
set "PATTERN=%~2"
set "KEEP=%~3"
set "EXCLUDE=%~4"

if "%BASE%"=="" exit /b 1
if "%PATTERN%"=="" exit /b 1
if "%KEEP%"=="" set KEEP=5
if defined KEEP_BACKUPS set KEEP=%KEEP_BACKUPS%

set /a COUNT=0
for /f "delims=" %%F in ('dir /b /o-d "%BASE%%PATTERN%" 2^>nul') do (
    set "SKIP=0"
    if not "%EXCLUDE%"=="" (
        echo %%F| findstr /i "%EXCLUDE%" >nul && set SKIP=1
    )
    if !SKIP!==0 (
        set /a COUNT+=1
        if !COUNT! gtr %KEEP% del /f /q "%BASE%%F" >nul 2>&1
    )
)
exit /b 0
