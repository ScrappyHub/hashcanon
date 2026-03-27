param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$VectorRoot = "C:\dev\cpr\test_vectors\packet_constitution_v1\minimal"
$Packet = Join-Path $RepoRoot "proofs\_hashcanon_cpr_selftest_packet"
$Script = Join-Path $RepoRoot "scripts\hashcanon_verify_packet_with_cpr_v1.ps1"

if(Test-Path $Packet){
  Remove-Item -LiteralPath $Packet -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $Packet | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Packet "payload") | Out-Null

Copy-Item -LiteralPath (Join-Path $VectorRoot "manifest.json")  -Destination (Join-Path $Packet "manifest.json") -Force
Copy-Item -LiteralPath (Join-Path $VectorRoot "packet_id.txt")  -Destination (Join-Path $Packet "packet_id.txt") -Force
Copy-Item -LiteralPath (Join-Path $VectorRoot "sha256sums.txt") -Destination (Join-Path $Packet "sha256sums.txt") -Force
Copy-Item -LiteralPath (Join-Path $VectorRoot "payload\hello.txt") -Destination (Join-Path $Packet "payload\hello.txt") -Force

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Script,
  "-RepoRoot",$RepoRoot,
  "-PacketPath",$Packet
) -Wait -PassThru -NoNewWindow

if($p.ExitCode -ne 0){
  throw "HASHCANON_CPR_SELFTEST_FAIL"
}

Write-Host "HASHCANON_CPR_SELFTEST_OK" -ForegroundColor Green