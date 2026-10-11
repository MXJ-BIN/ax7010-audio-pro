@echo off
setlocal
call "C:\AMDDesignTools26.1\2026.1\Vivado\settings64.bat"
if not exist "%~dp0..\build\video_test" mkdir "%~dp0..\build\video_test"
cd /d "%~dp0..\build\video_test"
call vivado -mode batch -source ../../scripts/test_video.tcl
exit /b %errorlevel%
