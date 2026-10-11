@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vitis\settings64.bat
cd /d "%~dp0.."
call xsdb scripts/read_diagnostics.tcl > build\diagnostics.log 2>&1
type build\diagnostics.log
findstr /B /C:"DIAGNOSTIC_READ_PASS" build\diagnostics.log >nul
if errorlevel 1 exit /b 1
exit /b 0
