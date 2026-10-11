param(
 [string]$Port='COM6',
 [ValidateRange(1,2061)][int]$Seconds=10,
 [switch]$Max,
 [string]$Output=(Join-Path $PSScriptRoot ('../captures/long_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.wav')),
 [string]$Python='C:/Users/BIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)
$ErrorActionPreference='Stop'
$recordSeconds=if($Max){2062}else{$Seconds}
$recordCommand=if($Max){'rec max'}else{"rec $Seconds"}
$Output=[IO.Path]::GetFullPath($Output)
foreach($suffix in @('','.json','.bin','.ddr.txt','.bin.part')){
 if(Test-Path -LiteralPath ($Output+$suffix)){throw "Output exists: $Output$suffix"}
}
$serial=[IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadTimeout=100;$serial.WriteTimeout=2000
$started=$false;$complete=$false;$stopSent=$false
$lines=[Collections.Generic.List[string]]::new()
try{
 $serial.Open();$serial.DiscardInBuffer();$serial.Write($recordCommand+"`n")
 $timer=[Diagnostics.Stopwatch]::StartNew();$text=[Text.StringBuilder]::new()
 Write-Host "Recording command: $recordCommand. In this PowerShell window, press Space to stop early."
 while($timer.Elapsed.TotalSeconds -lt $recordSeconds+30){
  if(!$stopSent -and $started -and ![Console]::IsInputRedirected -and [Console]::KeyAvailable){
   $key=[Console]::ReadKey($true)
   if($key.Key -eq [ConsoleKey]::Spacebar){$serial.Write("stop`n");$stopSent=$true}
  }
  if($started){Write-Progress -Activity "Recording: $recordCommand" -Status "Elapsed $([int]$timer.Elapsed.TotalSeconds)s" -PercentComplete ([Math]::Min(99,100*$timer.Elapsed.TotalSeconds/$recordSeconds))}
  try{$b=$serial.ReadByte()}catch [TimeoutException]{continue}
  if($b -ne 10){
   if($text.Length -gt 2048){throw 'Unexpected serial line length'}
   [void]$text.Append([char]$b);continue
  }
  $line=$text.ToString().TrimEnd([char]13);[void]$text.Clear()
  $lines.Add($line);Write-Host $line
  if($line -match '^REC_STARTED '){$started=$true}
  elseif($line -match '^REC_READY frames=(\d+) bytes=(\d+) crc=([0-9a-fA-F]{8}) maxlag=(\d+)$'){
   if(!$started -or [int]$Matches[1] -le 0){throw 'Invalid recording completion'}
   $complete=$true;break
  }elseif($line -match '^(REC_ERROR|CAPTURE_BUSY|CORE_ID_FAIL|UNKNOWN|RANGE:)'){
   throw "Board rejected recording: $line"
  }
 }
 if(!$complete){throw 'Recording completion timed out'}
}finally{
 if($serial.IsOpen){if($started -and !$complete){$serial.Write("stop`n")};$serial.Close()}
 $serial.Dispose();Write-Progress -Activity "Recording: $recordCommand" -Completed
 $lines | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../build/long_record_serial.log') -Encoding UTF8
}
& (Join-Path $PSScriptRoot 'export_long_audio.ps1') -Output $Output -Python $Python
