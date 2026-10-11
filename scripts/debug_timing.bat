@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vivado\settings64.bat
cd /d "%~dp0.."
call vivado -mode batch -source scripts/debug_timing.tcl -log build/debug_timing.log -journal build/debug_timing.jou
exit /b %errorlevel%
