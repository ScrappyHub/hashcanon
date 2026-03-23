param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$fullGreenRunner = Join-Path $RepoRoot "scripts\_RUN_hashcanon_full_green_v1.ps1"
$fullGreenSchema = Join-Path $RepoRoot "schemas\hashcanon.full_green_receipt.v1.json"
$verifySchema    = Join-Path $RepoRoot "schemas\hashcanon.verify_receipt.v1.json"
$statusSchema    = Join-Path $RepoRoot "schemas\hashcanon.status_snapshot.v1.json"
$nflSelftest     = Join-Path $RepoRoot "scripts\selftest_hashcanon_nfl_packet_v1.ps1"

$pktRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"
$pktDirs = @()
if(Test-Path -LiteralPath $pktRoot -PathType Container){
  $pktDirs = @(Get-ChildItem -LiteralPath $pktRoot -Directory | Sort-Object Name -Descending)
}
$minimalPacketPresent = ($pktDirs.Count -gt 0)

$fullGreenRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_full_green"
$latestFullGreenDir = $null
if(Test-Path -LiteralPath $fullGreenRoot -PathType Container){
  $dirs = @(Get-ChildItem -LiteralPath $fullGreenRoot -Directory | Sort-Object Name -Descending)
  if($dirs.Count -gt 0){ $latestFullGreenDir = $dirs[0].FullName }
}

$status = [ordered]@{
  schema = "hashcanon.status_snapshot.v1"
  ok = $true
  utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  repo_root = $RepoRoot
  full_green_runner_present = (Test-Path -LiteralPath $fullGreenRunner -PathType Leaf)
  full_green_receipt_schema_present = (Test-Path -LiteralPath $fullGreenSchema -PathType Leaf)
  verify_receipt_schema_present = (Test-Path -LiteralPath $verifySchema -PathType Leaf)
  status_snapshot_schema_present = (Test-Path -LiteralPath $statusSchema -PathType Leaf)
  minimal_packet_present = $minimalPacketPresent
  nfl_selftest_present = (Test-Path -LiteralPath $nflSelftest -PathType Leaf)
  latest_full_green_dir = $latestFullGreenDir
}

$StatusRoot = Join-Path $RepoRoot "proofs\status"
EnsureDir $StatusRoot
$StatusPath = Join-Path $StatusRoot "hashcanon_status_snapshot_v1.json"
$json = ($status | ConvertTo-Json -Depth 6)
Write-Utf8NoBomLf $StatusPath $json

Write-Host "HASHCANON_STATUS_SNAPSHOT_OK" -ForegroundColor Green
Write-Host ("STATUS_PATH=" + $StatusPath) -ForegroundColor Green
