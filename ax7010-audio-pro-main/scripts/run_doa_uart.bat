@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vitis\settings64.bat
cd /d "%~dp0.."
if not exist build mkdir build
call xsdb scripts/run_doa_uart.tcl %* > build\download.log 2>&1
set "task_download_rc=%errorlevel%"
findstr /B /C:"DOWNLOAD_PASS:" build\download.log >nul
if errorlevel 1 set "task_download_rc=1"
type build\download.log
if not "%task_download_rc%"=="0" echo DOWNLOAD FAILED. See build\download.log.
exit /b %task_download_rc%
