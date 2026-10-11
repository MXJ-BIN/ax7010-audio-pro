param([string]$Port='COM6')
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadTimeout=100;$serial.WriteTimeout=2000
$record=[Text.StringBuilder]::new()
function Collect([int]$Milliseconds){
 $s=[Text.StringBuilder]::new();$buffer=[byte[]]::new(4096);$timer=[Diagnostics.Stopwatch]::StartNew()
 while($timer.ElapsedMilliseconds -lt $Milliseconds){
  try{$n=$serial.Read($buffer,0,$buffer.Length)}catch [TimeoutException]{continue}
  [void]$s.Append([Text.Encoding]::ASCII.GetString($buffer,0,$n))
 }
 $text=$s.ToString();[void]$record.Append($text);return $text
}
function Send([string]$Command,[string]$Expected){
 $serial.Write($Command+"`n");$reply=Collect 650
 if($reply -notmatch $Expected){throw "Bad reply for $Command : $reply"}
 return $reply
}
try{
 $serial.Open();$serial.DiscardInBuffer()
 $idle=Collect 1800
 if($idle.Length -ne 0){throw "Default console is not quiet: $idle"}
 [void](Send 's' 'seq=.*fft_overrun=0')
 [void](Send 'log on' 'LOG=ON rate=1Hz')
 $trace=Collect 2600
 $count=[regex]::Matches($trace,'seq=').Count
 if($count -lt 2 -or $count -gt 3){throw "Unexpected log rate: $count"}
 $serial.Write('angle ')
 $editing=Collect 1400
 if($editing -notmatch 'angle ' -or $editing -match 'seq='){throw 'Echo/log suppression while typing failed'}
 [void](Send '45' 'CTRL=135FAF1F')
 [void](Send 'log off' 'LOG=OFF')
 if((Collect 1500).Length -ne 0){throw 'Log did not stop'}
 [void](Send ("vol 95"+[char]8+'6') 'OPTIONS=12600020')
 $serial.Write('unfinished'+[char]3)
 $reply=Collect 650
 if($reply -notmatch 'LOG=OFF'){throw 'Ctrl-C recovery failed'}
 [void](Send 'a' 'CTRL=135FAF3F')
 [void](Send 'vol 128' 'OPTIONS=12800020')
 Write-Output 'UART_QUIET_ECHO_LOG_EDITING_PASS'
}finally{
 if($serial.IsOpen){$serial.Close()};$serial.Dispose()
 $record.ToString() | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../build/uart_console_test.log') -Encoding UTF8
}
