@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vivado\settings64.bat
if not exist "%~dp0..\build\fft_test" mkdir "%~dp0..\build\fft_test"
cd /d "%~dp0..\build\fft_test"
call vivado -mode batch -source ../../scripts/test_fft.tcl
exit /b %errorlevel%
