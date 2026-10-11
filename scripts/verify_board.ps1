param([string]$Port='COM6')
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadTimeout=500
$serial.WriteTimeout=2000
$serial.NewLine="`n"
$lines=[Collections.Generic.List[string]]::new()
function Wait-Reply([string]$Pattern,[int]$Seconds=10) {
 $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
 while([DateTime]::UtcNow -lt $deadline) {
  try {$line=$serial.ReadLine().TrimEnd([char]13)} catch [TimeoutException] {continue}
  $lines.Add($line)
  Write-Host $line
  if($line -match $Pattern){return $line}
 }
 throw "UART response timeout: $Pattern"
}
function Config-Command([string]$Command) {
 $serial.Write($Command+"`n")
 $line=Wait-Reply '^CTRL=([0-9a-fA-F]{8}) GAINS=([0-9a-fA-F]{8}) OPTIONS=([0-9a-fA-F]{8})$'
 if($line -notmatch '^CTRL=([0-9a-fA-F]{8}) GAINS=([0-9a-fA-F]{8}) OPTIONS=([0-9a-fA-F]{8})$'){throw 'Bad configuration response'}
 return @([Convert]::ToUInt32($Matches[1],16),[Convert]::ToUInt32($Matches[2],16),[Convert]::ToUInt32($Matches[3],16))
}
try {
 $serial.Open()
 $serial.DiscardInBuffer()
 $serial.Write("h`n")
 [void](Wait-Reply '^PRO commands:' 60)
 $state=Config-Command 'angle 45'
 if(($state[0] -band 32) -ne 0 -or (($state[0] -shr 8) -band 511) -ne 431 -or (($state[0] -shr 17) -band 511) -ne 431){throw 'Manual 45-degree target mismatch'}
 $state=Config-Command 'vol 96'
 if((($state[2] -shr 16) -band 255) -ne 96){throw 'Volume setting mismatch'}
 $state=Config-Command 'u'
 if(($state[0] -band 0x08000000) -eq 0){throw 'Mute enable mismatch'}
 $state=Config-Command 'u'
 if(($state[0] -band 0x08000000) -ne 0){throw 'Mute disable mismatch'}
 $state=Config-Command 'n'
 if(($state[0] -band 128) -eq 0){throw 'Gate enable mismatch'}
 [void](Config-Command 'n')
 $state=Config-Command 'g'
 if(($state[0] -band 0x04000000) -eq 0){throw 'AGC enable mismatch'}
 [void](Config-Command 'g')
 $state=Config-Command 'gain 0 72'
 if(($state[1] -band 255) -ne 72){throw 'Mic gain mismatch'}
 [void](Config-Command 'gain 0 64')
 [void](Config-Command 'vol 128')
 $state=Config-Command 'a'
 if(($state[0] -band 32) -eq 0){throw 'Automatic steering mismatch'}
 $serial.Write("vol 129`n")
 [void](Wait-Reply '^RANGE: vol 0..128$')
 $serial.Write("x`n")
 [void](Wait-Reply '^CLIP_CLEARED$')
 $serial.Write("v`n")
 [void](Wait-Reply '^CAPTURE_READY samples=32768$' 15)
 Write-Host 'BOARD_CONTROL_PASS'
} finally {
 if($serial.IsOpen){$serial.Close()}
 $serial.Dispose()
 [IO.Directory]::CreateDirectory((Join-Path $PSScriptRoot '../build')) | Out-Null
 $lines | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../build/board_control.log') -Encoding UTF8
}
