@echo off
setlocal
call D:\AMDDesignTools\2026.1\Vivado\settings64.bat
cd /d "%~dp0.."
call vivado -mode batch -source scripts/build_bitstream.tcl -log build/build_bitstream.log -journal build/build_bitstream.jou
exit /b %errorlevel%
