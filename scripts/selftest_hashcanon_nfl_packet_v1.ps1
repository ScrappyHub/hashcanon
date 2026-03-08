param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PacketRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$m){ throw ("HASHCANON_NFL_PACKET_SELFTEST_FAIL:" + $m) }

function Get-ResultObject([object[]]$items){
  foreach($x in @(@($items))){
    if($null -eq $x){ continue }

    if($x -is [System.Collections.IDictionary]){
      if($x.Contains("schema")){ return $x }
    }

    if($x.PSObject -and ($x.PSObject.Properties.Name -contains "schema")){
      return $x
    }
  }
  return $null
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PacketRoot = (Resolve-Path -LiteralPath $PacketRoot).Path

$Script = Join-Path (Join-Path $RepoRoot "scripts") "hashcanon_nfl_packet_v1.ps1"

if(-not (Test-Path -LiteralPath $Script -PathType Leaf)){
  Fail ("SCRIPT_MISSING:" + $Script)
}

$r1 = & $Script -RepoRoot $RepoRoot -PacketRoot $PacketRoot
$r2 = & $Script -RepoRoot $RepoRoot -PacketRoot $PacketRoot

$o1 = Get-ResultObject @($r1)
$o2 = Get-ResultObject @($r2)

if($o1 -eq $null){ Fail "RUN1_NO_OBJECT" }
if($o2 -eq $null){ Fail "RUN2_NO_OBJECT" }

$d1 = [string]$o1["digest_sha256"]
$d2 = [string]$o2["digest_sha256"]
$c1 = [int]$o1["included_file_count"]
$c2 = [int]$o2["included_file_count"]

if([string]::IsNullOrWhiteSpace($d1)){ Fail "RUN1_MISSING_DIGEST" }
if([string]::IsNullOrWhiteSpace($d2)){ Fail "RUN2_MISSING_DIGEST" }

if($d1 -ne $d2){
  Fail "DIGEST_DRIFT"
}

if($c1 -ne $c2){
  Fail "COUNT_DRIFT"
}

Write-Output "HASHCANON_NFL_PACKET_SELFTEST_OK"
Write-Output ("DIGEST_SHA256=" + $d1)
Write-Output ("INCLUDED_FILE_COUNT=" + $c1)