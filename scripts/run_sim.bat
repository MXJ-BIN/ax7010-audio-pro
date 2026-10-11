@echo off
setlocal
call "C:\AMDDesignTools26.1\2026.1\Vivado\settings64.bat"
if not exist "%~dp0..\build\sim" mkdir "%~dp0..\build\sim"
cd /d "%~dp0..\build\sim"
call vivado -mode batch -source ../../scripts/test.tcl
exit /b %errorlevel%
