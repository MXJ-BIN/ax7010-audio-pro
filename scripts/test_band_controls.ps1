param([string]$Port='COM6')
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadTimeout=200;$serial.WriteTimeout=2000
$lines=[Collections.Generic.List[string]]::new()
function Wait-Reply([string]$Pattern,[int]$Seconds=10){
 $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
 while([DateTime]::UtcNow -lt $deadline){
  try{$line=$serial.ReadLine().TrimEnd([char]13)}catch [TimeoutException]{continue}
  $lines.Add($line);Write-Host $line
  if($line -match $Pattern){return $line}
 }
 throw "Reply timeout: $Pattern"
}
function Send([string]$Command,[string]$Pattern){$serial.Write($Command+"`n");return Wait-Reply $Pattern}
try{
 $serial.Open();$serial.DiscardInBuffer()
 foreach($test in @(@('off',0),@('voice',1),@('wind',2),@('narrow',3))){
  $mode=$test[1];$expected='{0:X8}' -f ([uint32]($mode*268435456)+[uint32]0x02800020)
  [void](Send ("band "+$test[0]) ("^BAND=$mode OPTIONS=$expected "))
  [void](Send 's' ("band=$mode band_clip=0 band_overrun=0 doa_overrun=0 fft_overrun=0"))
  [void](Wait-Reply ("^HW GAINS=40404040 OPTIONS=$expected "))
 }
 [void](Send 'p' '^CTRL=')
 [void](Send 's' 'band=1 band_clip=0 band_overrun=0 doa_overrun=0 fft_overrun=0')
 [void](Wait-Reply '^HW GAINS=40404040 OPTIONS=32800020 ')
 [void](Send 'band wind' '^BAND=2 OPTIONS=22800020 ')
 $state=Send 'vol 128' '^CTRL=([0-9a-fA-F]{8}) '
 if($state -notmatch '^CTRL=([0-9a-fA-F]{8}) '){throw 'Missing control register'}
 if(([Convert]::ToUInt32($Matches[1],16) -band 1) -ne 1){throw 'Band control failed to enable PS override'}
 [void](Send 'rec 10' '^REC_STARTED ')
 [void](Send 'band off' '^REC_BUSY:')
 [void](Send 's' 'band=2 band_clip=0 band_overrun=0 doa_overrun=0 fft_overrun=0')
 [void](Wait-Reply '^HW GAINS=40404040 OPTIONS=22800020 ')
 [void](Send 'stop' '^REC_READY frames=')
 [void](Send 'band voice' '^BAND=1 OPTIONS=12800020 ')
 [void](Send 's' 'band=1 band_clip=0 band_overrun=0 doa_overrun=0 fft_overrun=0')
 Write-Host 'BAND_CONTROL_RECORD_LOCK_PASS'
}finally{
 if($serial.IsOpen){$serial.Close()};$serial.Dispose()
 $lines | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../build/band_control.log') -Encoding UTF8
}
