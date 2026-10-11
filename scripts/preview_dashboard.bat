@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vivado\settings64.bat
if not exist "%~dp0..\build\preview" mkdir "%~dp0..\build\preview"
cd /d "%~dp0..\build\preview"
call vivado -mode batch -source ../../scripts/preview_dashboard.tcl
exit /b %errorlevel%
