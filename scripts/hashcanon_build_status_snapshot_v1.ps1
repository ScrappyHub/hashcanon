param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$false)][string]$OutPath
)

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

function Sha256HexBytes([byte[]]$b){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Sha256HexFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw ("SHA256_MISSING_FILE: " + $Path)
  }
  $b=[System.IO.File]::ReadAllBytes($Path)
  Sha256HexBytes $b
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if([string]::IsNullOrWhiteSpace($OutPath)){
  $OutPath = Join-Path $RepoRoot "proofs\status\hashcanon_status_snapshot_v1.json"
}

$OutDir = Split-Path -Parent $OutPath
EnsureDir $OutDir

$ReadmePath   = Join-Path $RepoRoot "README.md"
$SpecPath     = Join-Path $RepoRoot "docs\HASHCANON_SPEC_v1.md"
$DoDPath      = Join-Path $RepoRoot "docs\DEFINITION_OF_DONE_TIER0.md"
$WbsPath      = Join-Path $RepoRoot "docs\WBS_HASHCANON_PROGRESS_LEDGER_v1.md"
$RunnerPath   = Join-Path $RepoRoot "scripts\_RUN_hashcanon_full_green_v1.ps1"
$VerifyPath   = Join-Path $RepoRoot "scripts\hashcanon_verify_packet_optionA_v1.ps1"
$PacketRoot   = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"

$packetDirs = @()
if(Test-Path -LiteralPath $PacketRoot -PathType Container){
  $packetDirs = @(Get-ChildItem -LiteralPath $PacketRoot -Directory -ErrorAction Stop | Sort-Object Name -Descending)
}

$latestPacketId = $null
if($packetDirs.Count -gt 0){
  $latestPacketId = $packetDirs[0].Name
}

$obj = [ordered]@{
  schema = "hashcanon.status_snapshot.v1"
  ok = $true
  repo_root = $RepoRoot
  generated_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  surfaces = [ordered]@{
    readme = [ordered]@{
      present = (Test-Path -LiteralPath $ReadmePath -PathType Leaf)
      path = $ReadmePath
    }
    spec = [ordered]@{
      present = (Test-Path -LiteralPath $SpecPath -PathType Leaf)
      path = $SpecPath
    }
    definition_of_done = [ordered]@{
      present = (Test-Path -LiteralPath $DoDPath -PathType Leaf)
      path = $DoDPath
    }
    wbs = [ordered]@{
      present = (Test-Path -LiteralPath $WbsPath -PathType Leaf)
      path = $WbsPath
    }
    full_green_runner = [ordered]@{
      present = (Test-Path -LiteralPath $RunnerPath -PathType Leaf)
      path = $RunnerPath
    }
    verifier = [ordered]@{
      present = (Test-Path -LiteralPath $VerifyPath -PathType Leaf)
      path = $VerifyPath
    }
    latest_optionA_packet_id = $latestPacketId
  }
}

$json = ($obj | ConvertTo-Json -Depth 10)
Write-Utf8NoBomLf $OutPath $json

Write-Host "HASHCANON_STATUS_SNAPSHOT_OK" -ForegroundColor Green
Write-Host ("STATUS_SNAPSHOT=" + $OutPath) -ForegroundColor Green
