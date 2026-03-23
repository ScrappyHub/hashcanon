param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe    = (Get-Command powershell.exe -ErrorAction Stop).Source
$Script   = Join-Path $RepoRoot "scripts\hashcanon_build_status_snapshot_v1.ps1"

if(-not (Test-Path -LiteralPath $Script -PathType Leaf)){
  throw "STATUS_SELFTEST_SCRIPT_MISSING"
}

$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Script,"-RepoRoot",$RepoRoot
) -Wait -PassThru

if($p.ExitCode -ne 0){
  throw ("STATUS_SELFTEST_FAILED exit_code=" + $p.ExitCode)
}

$StatusPath = Join-Path $RepoRoot "proofs\status\hashcanon_status_snapshot_v1.json"
if(-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)){
  throw "STATUS_SELFTEST_OUTPUT_MISSING"
}

Write-Host "HASHCANON_STATUS_SELFTEST_OK" -ForegroundColor Green
Write-Host ("STATUS_PATH=" + $StatusPath) -ForegroundColor Green
