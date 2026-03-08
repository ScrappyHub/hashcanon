param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function CopyTree([string]$src,[string]$dst){
  if(-not (Test-Path -LiteralPath $src -PathType Container)){ throw ("COPYTREE_SOURCE_MISSING: " + $src) }
  if(Test-Path -LiteralPath $dst -PathType Container){
    Remove-Item -LiteralPath $dst -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$PSExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ throw ('MISSING_POWERSHELL_EXE: ' + $PSExe) }

$Verifier = Join-Path $RepoRoot 'scripts\hashcanon_verify_packet_optionA_v1.ps1'
$Mk = Join-Path $RepoRoot 'scripts\hashcanon_make_minimal_packet_optionA_v1.ps1'
if(-not (Test-Path -LiteralPath $Verifier -PathType Leaf)){ throw 'NEG_MISSING_VERIFIER' }
if(-not (Test-Path -LiteralPath $Mk -PathType Leaf)){ throw 'NEG_MISSING_MINIMAL_GENERATOR' }

$p0 = Start-Process -FilePath $PSExe -ArgumentList @(
  '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
  '-File',$Mk,'-RepoRoot',$RepoRoot
) -Wait -PassThru
if($p0.ExitCode -ne 0){ throw ('NEG_MINIMAL_GENERATE_FAILED exit_code=' + $p0.ExitCode) }

$pktRoot = Join-Path $RepoRoot 'test_vectors\hashcanon_optionA\minimal_packet\packet'
$dirs = @(@(Get-ChildItem -LiteralPath $pktRoot -Directory -ErrorAction Stop | Sort-Object Name -Descending))
if($dirs.Count -lt 1){ throw 'NEG_NO_PACKET_DIR_FOUND' }
$good = $dirs[0].FullName

$scratch = Join-Path $RepoRoot 'scripts\_scratch'
EnsureDir $scratch
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')
$root = Join-Path $scratch ('neg_suite_' + $stamp)
EnsureDir $root

function RunExpectFail([string]$case,[string]$dir,[string]$token){
  $out = Join-Path $root ('out_' + $case + '.log')
  $err = Join-Path $root ('err_' + $case + '.log')

  $p = Start-Process -FilePath $PSExe -ArgumentList @(
    '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
    '-File',$Verifier,'-PacketDir',$dir
  ) -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err

  $errTxt = [System.IO.File]::ReadAllText($err,(New-Object System.Text.UTF8Encoding($false)))
  if($p.ExitCode -eq 0){ throw ('NEG_EXPECT_FAIL_BUT_OK: ' + $case) }
  if(-not ($errTxt -like ('*' + $token + '*'))){ throw ('NEG_MISSING_TOKEN: ' + $case + ' token=' + $token + ' stderr=' + $errTxt) }
  Write-Host ('NEG_OK: ' + $case) -ForegroundColor Green
}

# Case 1: tamper first sha256 only
$c1 = Join-Path $root 'case1_tamper_sha256sums'
CopyTree $good $c1
$sum = Join-Path $c1 'sha256sums.txt'
$sumLines = @([System.IO.File]::ReadAllLines($sum, (New-Object System.Text.UTF8Encoding($false))))
if($sumLines.Count -lt 1){ throw 'NEG_CASE1_EMPTY_SHA256SUMS' }

$first = $sumLines[0]
if($first.Length -lt 64){ throw 'NEG_CASE1_BAD_FIRST_LINE' }

$orig = $first.Substring(0,64)
$rest = $first.Substring(64)
$bad = (('0' * 63) + '1')
if($orig -eq $bad){ $bad = (('f' * 63) + 'e') }

$sumLines[0] = $bad + $rest
[System.IO.File]::WriteAllLines($sum, $sumLines, (New-Object System.Text.UTF8Encoding($false)))
RunExpectFail 'case1' $c1 'HC_VERIFY_SHA256_MISMATCH'

# Case 2: missing manifest.json
$c2 = Join-Path $root 'case2_missing_manifest'
CopyTree $good $c2
Remove-Item -LiteralPath (Join-Path $c2 'manifest.json') -Force
RunExpectFail 'case2' $c2 'HC_VERIFY_MISSING_MANIFEST'

# Case 3: packet_id mismatch
$c3 = Join-Path $root 'case3_packetid_mismatch'
CopyTree $good $c3
[System.IO.File]::WriteAllText((Join-Path $c3 'packet_id.txt'), ('0'*64) + "`n", (New-Object System.Text.UTF8Encoding($false)))
RunExpectFail 'case3' $c3 'HC_VERIFY_PACKET_ID_MISMATCH'

Write-Host 'HASHCANON_NEGATIVE_SUITE_OK' -ForegroundColor Green
