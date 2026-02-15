param(
  [string]$VpcHost = 'moltbook-vps',
  [int]$GatewayPort = 18789,
  [int]$LocalGatewayPort = 18790,
  [string]$NodeDisplayName = 'win10',
  [switch]$LaunchChrome = $true,
  [string]$ChromeProfileDir = '',
  [string]$ChromeUrl = 'https://example.com',
  [bool]$WarmupRelay = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$logDir = Join-Path $repoRoot 'logs'
$nodeOut = Join-Path $logDir 'node-host.out.log'
$nodeErr = Join-Path $logDir 'node-host.err.log'
$defaultProfileDir = Join-Path $repoRoot 'chrome-profile-openclaw'
$extensionPath = Join-Path $env:USERPROFILE '.openclaw\browser\chrome-extension'

function Get-NodeHostProcesses {
  return Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -match 'openclaw(\.mjs)?\s+node\s+run'
  }
}

function Test-Listening {
  param([int]$Port)
  try {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop
    return $conn.Count -gt 0
  } catch {
    $lines = netstat -ano | Select-String ":$Port" | ForEach-Object { $_.Line }
    return ($lines | Where-Object { $_ -match 'LISTENING' }).Count -gt 0
  }
}

function Wait-Listening {
  param([int]$Port, [int]$TimeoutSec = 15)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-Listening -Port $Port) { return $true }
    Start-Sleep -Milliseconds 300
  }
  return $false
}

function Test-NodeHostConnected {
  param([int]$Pid, [int]$GatewayPort)
  try {
    $conns = Get-NetTCPConnection -State Established -OwningProcess $Pid -ErrorAction Stop
    return ($conns | Where-Object { $_.RemoteAddress -eq '127.0.0.1' -and $_.RemotePort -eq $GatewayPort }).Count -gt 0
  } catch {
    $lines = netstat -ano | Select-String ":$GatewayPort" | ForEach-Object { $_.Line }
    return ($lines | Where-Object { $_ -match ("\s" + [regex]::Escape($Pid) + '$') }).Count -gt 0
  }
}

function Get-GatewayToken {
  $raw = & ssh $VpcHost "cat ~/.openclaw/openclaw.json"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
    throw "Failed to read ~/.openclaw/openclaw.json from $VpcHost"
  }
  $data = $raw | ConvertFrom-Json
  $token = $data.gateway.auth.token
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'Gateway token not found in openclaw.json'
  }
  return $token.Trim()
}

function Ensure-SSHTunnel {
  if (Test-Listening -Port $LocalGatewayPort) {
    Write-Host "SSH tunnel already listening on 127.0.0.1:$LocalGatewayPort"
    return
  }

  $existing = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'ssh.exe' -and $_.CommandLine -match (":$LocalGatewayPort:127\\.0\\.0\\.1:$GatewayPort")
  }
  foreach ($p in $existing) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
  }

  $sshArgs = @(
    "-N",
    "-L","$LocalGatewayPort:127.0.0.1:$GatewayPort",
    "-o","ExitOnForwardFailure=yes",
    "-o","BatchMode=yes",
    "-o","ConnectTimeout=5",
    "-o","ServerAliveInterval=30",
    "-o","ServerAliveCountMax=3",
    $VpcHost
  )
  $proc = Start-Process -FilePath ssh -ArgumentList $sshArgs -WindowStyle Hidden -PassThru

  if (-not (Wait-Listening -Port $LocalGatewayPort -TimeoutSec 20)) {
    if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
      throw "SSH tunnel failed to start (ssh exited). Check SSH auth/config for $VpcHost"
    }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw "SSH tunnel failed to listen on 127.0.0.1:$LocalGatewayPort"
  }
  Write-Host "SSH tunnel up: 127.0.0.1:$LocalGatewayPort -> $VpcHost:127.0.0.1:$GatewayPort"
}

function Start-NodeHost {
  $existingNodes = Get-NodeHostProcesses
  if (Test-Listening -Port 18792) {
    $connected = $false
    foreach ($p in $existingNodes) {
      if (Test-NodeHostConnected -Pid $p.ProcessId -GatewayPort $LocalGatewayPort) {
        $connected = $true
        break
      }
    }
    if ($connected) {
      Write-Host 'Relay already listening on 127.0.0.1:18792 (node host connected)'
      return
    }
    foreach ($p in $existingNodes) {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
  } elseif ($existingNodes) {
    foreach ($p in $existingNodes) {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
  }

  $token = Get-GatewayToken

  $cmd = @(
    "set OPENCLAW_GATEWAY_TOKEN=$token",
    'set NO_PROXY=*',
    'set HTTP_PROXY=',
    'set HTTPS_PROXY=',
    "openclaw node run --host 127.0.0.1 --port $LocalGatewayPort --display-name $NodeDisplayName"
  ) -join '&'

  Start-Process -FilePath cmd -ArgumentList '/c', $cmd -RedirectStandardOutput $nodeOut -RedirectStandardError $nodeErr -WindowStyle Hidden

  if (-not (Wait-Listening -Port 18792 -TimeoutSec 15)) {
    if ($WarmupRelay) {
      Write-Host 'Relay not listening yet (will warm up on next step).'
      return
    }
    Write-Host 'Warning: relay not listening yet. Check logs:'
    Write-Host "  $nodeOut"
    Write-Host "  $nodeErr"
    return
  }

  Write-Host 'Relay up: 127.0.0.1:18792'
}

function Warmup-Relay {
  if (-not $WarmupRelay) { return }
  Start-Sleep -Seconds 2
  try {
    & ssh $VpcHost "openclaw browser profiles" | Out-Null
    Write-Host 'Relay warmup: openclaw browser profiles'
  } catch {
    Write-Host 'Warning: relay warmup failed (will start on first browser command).'
  }
}


function Get-ChromeExe {
  $cmd = Get-Command chrome -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { return $c }
  }
  return $null
}

function Test-ExtensionInstalled {
  param([string]$ProfileDir)
  $pref = Join-Path $ProfileDir 'Default\Secure Preferences'
  if (-not (Test-Path $pref)) { return $false }
  $escaped = $extensionPath.Replace('\', '\\')
  $hit = Select-String -Path $pref -SimpleMatch $escaped -ErrorAction SilentlyContinue
  return $null -ne $hit
}

function Launch-Chrome {
  if (-not $LaunchChrome) { return }
  $chrome = Get-ChromeExe
  if (-not $chrome) {
    Write-Host 'Chrome not found. Skipping launch.'
    return
  }

  $profileDir = $ChromeProfileDir
  if ([string]::IsNullOrWhiteSpace($profileDir)) {
    $profileDir = $defaultProfileDir
  }
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

  $args = @(
    "--user-data-dir=$profileDir",
    '--no-first-run',
    '--no-default-browser-check',
    '--new-window'
  )

  if (-not (Test-ExtensionInstalled -ProfileDir $profileDir)) {
    $args += 'chrome://extensions'
  }
  if (-not [string]::IsNullOrWhiteSpace($ChromeUrl)) {
    $args += $ChromeUrl
  }

  Start-Process -FilePath $chrome -ArgumentList $args
}

Write-Host 'Starting OpenClaw remote browser relay (official mode)...'
Ensure-SSHTunnel
Start-NodeHost
Warmup-Relay
Launch-Chrome

Write-Host ''
Write-Host 'Ready. Next:'
Write-Host '- Open Chrome (dedicated profile).' 
Write-Host '- If chrome://extensions opened: enable Developer mode and Load unpacked from the extension path below.'
Write-Host "  $extensionPath"
Write-Host '- Click the OpenClaw Browser Relay icon on the tab to attach.'
Write-Host '- Then run on VPS: openclaw browser tabs / snapshot'
