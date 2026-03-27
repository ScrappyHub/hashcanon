param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PacketPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw ("HASHCANON_CPR_VERIFY_FAIL:" + $m) }

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path,$t,$enc)
}

function CanonJson([hashtable]$obj){
  $keys = $obj.Keys | Sort-Object
  $parts = @()
  foreach($k in $keys){
    $v = $obj[$k]
    if($v -is [string]){
      $parts += ('"{0}":"{1}"' -f $k, ($v.Replace('"','\"')))
    } else {
      $parts += ('"{0}":{1}' -f $k, $v)
    }
  }
  return '{' + ($parts -join ',') + '}'
}

$CPR = "C:\dev\cpr\scripts\verify_packet_v1.ps1"
if(-not (Test-Path $CPR)){ Die "CPR_SCRIPT_MISSING" }

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$CPR,
  "-RepoRoot","C:\dev\cpr",
  "-PacketPath",$PacketPath
) -Wait -PassThru -NoNewWindow

$result = "FAIL"
$code   = "CPR_VERIFY_NONZERO"

if($p.ExitCode -eq 0){
  $result = "PASS"
  $code   = "OK"
}

$receipt = @{
  schema       = "hashcanon.cpr.receipt.v1"
  event_type   = "verify"
  packet_path  = $PacketPath.Replace("\","/")
  result       = $result
  code         = $code
  delegated_to = "CPR"
}

$line = CanonJson $receipt

$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\hashcanon.cpr.ndjson"
if(-not (Test-Path (Split-Path $ReceiptPath))){
  New-Item -ItemType Directory -Force -Path (Split-Path $ReceiptPath) | Out-Null
}

Add-Content -Path $ReceiptPath -Value $line

if($p.ExitCode -ne 0){
  Die $code
}

Write-Host "HASHCANON_CPR_VERIFY_OK" -ForegroundColor Green