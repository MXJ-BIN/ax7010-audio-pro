@echo off
setlocal
call "%~dp0run_sim.bat"
if errorlevel 1 exit /b 1
call "%~dp0test_speech_band.bat"
if errorlevel 1 exit /b 1
call "%~dp0create_project.bat"
if errorlevel 1 exit /b 1
call "%~dp0build_bitstream.bat"
if errorlevel 1 exit /b 1
call "%~dp0create_vitis.bat"
if errorlevel 1 exit /b 1
echo BUILD_ALL_PASS. Open UART first, then run run_doa_uart.bat.
exit /b 0
