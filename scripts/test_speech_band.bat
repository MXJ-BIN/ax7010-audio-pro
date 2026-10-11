@echo off
setlocal
cd /d "%~dp0.."
if not exist build mkdir build
"C:\Users\t'x\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" scripts\gen_speech_vectors.py
if errorlevel 1 exit /b 1
call "C:\AMDDesignTools26.1\2026.1\Vivado\settings64.bat"
cd build\speech_filter_test
call vivado -mode batch -source ../../scripts/test_speech_band.tcl
if errorlevel 1 exit /b 1
"C:\Users\t'x\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" ../../scripts/check_speech_response.py
exit /b %errorlevel%
