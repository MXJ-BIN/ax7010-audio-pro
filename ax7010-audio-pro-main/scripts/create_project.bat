@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vivado\settings64.bat
cd /d "%~dp0.."
call vivado -mode batch -source scripts/create_project.tcl
exit /b %errorlevel%
