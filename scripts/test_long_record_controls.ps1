param([string]$Port='COM6')
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadTimeout=100;$serial.WriteTimeout=2000
$trace=[Collections.Generic.List[string]]::new()
function Wait-Line([string]$Pattern,[int]$Seconds=5){
 $deadline=[DateTime]::UtcNow.AddSeconds($Seconds);$text=[Text.StringBuilder]::new()
 while([DateTime]::UtcNow -lt $deadline){
  try{$b=$serial.ReadByte()}catch [TimeoutException]{continue}
  if($b -eq 10){
   $line=$text.ToString().TrimEnd([char]13);[void]$text.Clear();$trace.Add($line);Write-Host $line
   if($line -match '^REC_ERROR'){throw $line}
   if($line -match $Pattern){return $line}
  }else{[void]$text.Append([char]$b)}
 }
 throw "Timed out: $Pattern"
}
try{
 $serial.Open();$serial.DiscardInBuffer()
 $serial.Write("rec 2062`n");[void](Wait-Line '^RANGE: rec 1..2061')
 $serial.Write("rec max`n");[void](Wait-Line '^REC_STARTED frames=100663296 bytes=402653184')
 $serial.Write("recinfo`n");[void](Wait-Line '^RECINFO state=1 .*goal=100663296 .*ddr_ok=1$')
 $serial.Write("u`n");[void](Wait-Line '^REC_BUSY: stop before changing audio settings$')
 # Wait via serial read timeouts while recording remains continuous.
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while($timer.Elapsed.TotalSeconds -lt 5){try{[void]$serial.ReadByte()}catch [TimeoutException]{continue}}
 $serial.Write("stop`n");$line=Wait-Line '^REC_READY frames=(\d+) bytes=(\d+) crc=([0-9a-fA-F]{8}) maxlag=(\d+)$'
 if($line -notmatch '^REC_READY frames=(\d+) bytes=(\d+) crc=([0-9a-fA-F]{8}) maxlag=(\d+)$'){throw 'Malformed completion'}
 if([int]$Matches[1] -lt 244140 -or [int]$Matches[2] -ne 4*[int]$Matches[1] -or [int]$Matches[4] -ge 32768){throw 'Stop length or ring lag invalid'}
 $serial.Write("recinfo`n");[void](Wait-Line '^RECINFO state=2 .*ddr_ok=1$')
 $serial.Write("s`n");[void](Wait-Line '^seq=.*doa_overrun=0 fft_overrun=0$')
 Write-Host 'LONG_RECORD_MAX_STOP_BUSY_GUARD_PASS'
}finally{
 if($serial.IsOpen){$serial.Close()};$serial.Dispose()
 $trace | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../build/long_record_controls.log') -Encoding UTF8
}
