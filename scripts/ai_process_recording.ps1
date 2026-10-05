param(
 [Parameter(Mandatory=$true)][string]$InputFile,
 [ValidateSet('before','after')][string]$Channel='after',
 [ValidateRange(0.01,120)][double]$Seconds=30,
 [ValidateRange(-24,30)][double]$InputGainDb=18,
 [string]$OutputPrefix=(Join-Path $PSScriptRoot ('../captures/ai_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))),
 [string]$Python='C:/Users/BIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)
$ErrorActionPreference='Stop'
$OutputPrefix=[IO.Path]::GetFullPath($OutputPrefix)
& $Python (Join-Path $PSScriptRoot 'ai_recording.py') prepare --input $InputFile --prefix $OutputPrefix --channel $Channel --seconds $Seconds --gain-db $InputGainDb
if($LASTEXITCODE -ne 0){throw 'Input preparation failed; board not modified'}
$request=Get-Content -LiteralPath ($OutputPrefix+'.request.json') -Raw | ConvertFrom-Json
& 'D:/AMDDesignTools/2026.1/Vitis/bin/xsdb.bat' (Join-Path $PSScriptRoot 'run_ai_eval.tcl') ($OutputPrefix+'.input.bin') ($OutputPrefix+'.output.bin') ($OutputPrefix+'.result.txt') $request.frames $request.input_crc32 | Tee-Object -FilePath ($OutputPrefix+'.run.log')
$runLog=Get-Content -LiteralPath ($OutputPrefix+'.run.log') -Raw
if($LASTEXITCODE -ne 0 -or $runLog -notmatch '(?m)^AI_EVAL_INFERENCE_PASS ' -or $runLog -notmatch '(?m)^AI_EVAL_RESTORE_PASS') {throw 'PS inference/export failed; review restore status in .run.log'}
& $Python (Join-Path $PSScriptRoot 'ai_recording.py') finish --prefix $OutputPrefix
if($LASTEXITCODE -ne 0){throw 'Output validation failed'}
Write-Host "Saved matched-level 48 kHz comparison: ${OutputPrefix}_before.wav and ${OutputPrefix}_ai.wav"
Write-Host 'Inference ran on AX7010 PS. Live firmware has been restored to speech-band defaults.'
