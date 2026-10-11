param(
 [string]$Port = 'COM6',
 [string]$Output = (Join-Path $PSScriptRoot ('../captures/audio_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.wav'))
)
$ErrorActionPreference = 'Stop'
$Output = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $Output) { throw "Output already exists: $Output" }
if (Test-Path -LiteralPath ($Output + '.json')) { throw 'Metadata already exists' }
$serial = [IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$serial.ReadBufferSize = 262144
$serial.ReadTimeout = 1000
$serial.WriteTimeout = 2000
$writer = $null
function Read-ByteLine([DateTime]$Deadline) {
 $builder = [Text.StringBuilder]::new()
 while ([DateTime]::UtcNow -lt $Deadline) {
  try { $b = $serial.ReadByte() } catch [TimeoutException] { continue }
  if ($b -eq 10) { return $builder.ToString().TrimEnd([char]13) }
  if ($builder.Length -ge 2048) { throw 'Unexpected long serial text line' }
  [void]$builder.Append([char]$b)
 }
 throw 'Timeout waiting for board response'
}
try {
 $serial.Open()
 $serial.DiscardInBuffer()
 $serial.DiscardOutBuffer()
 $serial.Write("v`n")
 $deadline = [DateTime]::UtcNow.AddSeconds(15)
 do { $line = Read-ByteLine $deadline; Write-Host $line } until ($line -match '^CAPTURE_READY samples=32768$')
 $serial.Write("d`n")
 $deadline = [DateTime]::UtcNow.AddSeconds(15)
 do { $line = Read-ByteLine $deadline } until ($line -match '^AUDIO_BEGIN ')
 if ($line -notmatch '^AUDIO_BEGIN bytes=131072 rate=48828 channels=2 bits=16 ctrl=([0-9a-fA-F]{8}) gains=([0-9a-fA-F]{8}) opts=([0-9a-fA-F]{8})$') { throw "Unexpected audio header: $line" }
 $ctrl=$Matches[1]; $gains=$Matches[2]; $opts=$Matches[3]
 $data = [byte[]]::new(131072)
 $offset = 0
 $deadline = [DateTime]::UtcNow.AddSeconds(40)
 while ($offset -lt $data.Length) {
  if ([DateTime]::UtcNow -ge $deadline) { throw "Audio transfer timed out at $offset bytes" }
  try { $offset += $serial.Read($data,$offset,$data.Length-$offset) } catch [TimeoutException] { continue }
 }
 $deadline = [DateTime]::UtcNow.AddSeconds(5)
 do { $line = Read-ByteLine $deadline } until ($line -eq 'AUDIO_END')
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Output))
 $writer = [IO.BinaryWriter]::new([IO.File]::Open($Output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None))
 $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $writer.Write([uint32](36+$data.Length))
 $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $writer.Write([uint32]16)
 $writer.Write([uint16]1); $writer.Write([uint16]2); $writer.Write([uint32]48828)
 $writer.Write([uint32](48828*4)); $writer.Write([uint16]4); $writer.Write([uint16]16)
 $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([uint32]$data.Length); $writer.Write($data)
 $writer.Dispose(); $writer=$null
 @{ sample_rate_actual=48828.125; frames=32768; channels=@('raw_hp_mic0','processed_pre_quarter'); ctrl=$ctrl; gains=$gains; options=$opts; note='Channels have processing latency and different gain. This is not an SNR measurement.' } | ConvertTo-Json | Set-Content -LiteralPath ($Output+'.json') -Encoding UTF8
 Write-Host "Saved: $Output (0.671 s; left raw mic0, right processed)"
} finally {
 if ($null -ne $writer) { $writer.Dispose() }
 if ($serial.IsOpen) { $serial.Close() }
 $serial.Dispose()
}
