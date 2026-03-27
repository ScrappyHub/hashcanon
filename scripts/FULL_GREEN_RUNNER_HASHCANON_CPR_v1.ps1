param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Self = Join-Path $RepoRoot "scripts\_selftest_hashcanon_cpr_integration_v1.ps1"

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Self,
  "-RepoRoot",$RepoRoot
) -Wait -PassThru -NoNewWindow

if($p.ExitCode -ne 0){
  throw "HASHCANON_CPR_FULL_GREEN_FAIL"
}

Write-Host "HASHCANON_CPR_FULL_GREEN_OK" -ForegroundColor Green