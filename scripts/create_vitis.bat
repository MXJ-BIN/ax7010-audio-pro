@echo off
setlocal
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
set JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8
call D:\AMDDesignTools\2026.1\Vitis\settings64.bat
cd /d "%~dp0.."
if not exist build mkdir build
call vitis -s scripts/create_vitis.py > build\vitis_build.log 2>&1
set "task_vitis_rc=%errorlevel%"
findstr /B /C:"DOA_UART_APP_PASS" build\vitis_build.log >nul
if errorlevel 1 set "task_vitis_rc=1"
type build\vitis_build.log
if not "%task_vitis_rc%"=="0" echo VITIS BUILD FAILED. See build\vitis_build.log.
exit /b %task_vitis_rc%
