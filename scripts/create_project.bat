@echo off
setlocal
call "C:\AMDDesignTools26.1\2026.1\Vivado\settings64.bat"
cd /d "%~dp0.."
call vivado -mode batch -source scripts/create_project.tcl
exit /b %errorlevel%
