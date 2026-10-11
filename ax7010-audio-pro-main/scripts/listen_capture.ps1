param(
 [Parameter(Mandatory=$true)][string]$InputFile,
 [switch]$NoPlay,
 [string]$Python='C:/Users/BIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)
$ErrorActionPreference='Stop'
$InputFile=[IO.Path]::GetFullPath($InputFile)
$stem=Join-Path ([IO.Path]::GetDirectoryName($InputFile)) ([IO.Path]::GetFileNameWithoutExtension($InputFile))
$paths=@(($stem+'_before.wav'),($stem+'_after.wav'))
& $Python (Join-Path $PSScriptRoot 'split_capture.py') $InputFile --reuse
if($LASTEXITCODE -ne 0){throw 'Audio split failed'}
Write-Host 'BEFORE = high-pass mic0; AFTER = processed output before quarter attenuation.'
Write-Host 'Original amplitudes retained; loudness differences do not establish noise reduction.'
if(!$NoPlay){
 foreach($channel in 0,1){
  [void](Read-Host $(if($channel -eq 0){'Press Enter to hear BEFORE'}else{'Press Enter to hear AFTER'}))
  $player=[Media.SoundPlayer]::new($paths[$channel])
  try{$player.Load();$player.PlaySync()}finally{$player.Dispose()}
 }
}
