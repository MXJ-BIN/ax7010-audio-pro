param(
 [string]$Output=(Join-Path $PSScriptRoot ('../captures/long_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.wav')),
 [string]$Python='C:/Users/BIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)
$ErrorActionPreference='Stop'
$Output=[IO.Path]::GetFullPath($Output)
foreach($file in @($Output,($Output+'.json'),($Output+'.bin'),($Output+'.ddr.txt'),($Output+'.bin.part'))){
 if(Test-Path -LiteralPath $file){throw "Output exists: $file"}
}
if(!(Test-Path -LiteralPath $Python)){throw 'Python not found; pass -Python with a Python 3.8+ executable'}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Output))
& 'D:/AMDDesignTools/2026.1/Vitis/bin/xsdb.bat' (Join-Path $PSScriptRoot 'export_ddr.tcl') ($Output+'.bin') ($Output+'.ddr.txt')
if($LASTEXITCODE -ne 0){throw 'JTAG export failed; incomplete raw files retained for diagnosis'}
& $Python (Join-Path $PSScriptRoot 'ddr_to_wav.py') ($Output+'.bin') ($Output+'.ddr.txt') $Output
if($LASTEXITCODE -ne 0){throw 'Audio CRC validation failed; output is not accepted'}
Remove-Item -LiteralPath ($Output+'.bin')
Write-Host "Saved: $Output"
