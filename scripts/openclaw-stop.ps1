param(
  [int]$LocalGatewayPort = 18790
)

$ErrorActionPreference = 'Stop'

$sshProcs = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -eq 'ssh.exe' -and $_.CommandLine -match (":$LocalGatewayPort:127\\.0\\.0\\.1")
}
foreach ($p in $sshProcs) {
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

$nodeProcs = Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -match 'openclaw(\.mjs)?\s+node\s+run'
}
foreach ($p in $nodeProcs) {
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host 'Stopped SSH tunnel(s) and node host process(es) (if any).'
