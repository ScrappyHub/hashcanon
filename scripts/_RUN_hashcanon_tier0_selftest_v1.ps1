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
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("PARSE_GATE_MISSING: " + $Path) }
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and $e.Count -gt 0){
    $x=$e[0]
    throw ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

function Sha256HexBytes([byte[]]$b){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Sha256HexFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("SHA256_MISSING_FILE: " + $Path) }
  $b=[System.IO.File]::ReadAllBytes($Path)
  Sha256HexBytes $b
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$Scratch = Join-Path $RepoRoot "scripts\_scratch"
EnsureDir $Scratch

$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ throw ("MISSING_POWERSHELL_EXE: " + $PSExe) }

# Parse-gate key scripts
$Selftest = Join-Path $RepoRoot "scripts\_selftest_hashcanon_optionA_v1.ps1"
if(-not (Test-Path -LiteralPath $Selftest -PathType Leaf)){ throw ("MISSING_SELFTEST: " + $Selftest) }
Parse-GateFile $Selftest
Write-Host ("SELFTEST_PARSE_OK: " + $Selftest) -ForegroundColor Green

$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss")
$tierOut = Join-Path $Scratch ("tier0_stdout_" + $stamp + ".log")
$tierErr = Join-Path $Scratch ("tier0_stderr_" + $stamp + ".log")

# Run selftest as child powershell.exe (captured logs)
$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile",
  "-NonInteractive",
  "-ExecutionPolicy","Bypass",
  "-File",$Selftest,
  "-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $tierOut -RedirectStandardError $tierErr
if($p.ExitCode -ne 0){ throw ("SELFTEST_FAILED exit_code=" + $p.ExitCode) }
Write-Host ("TIER0_STDOUT_LOG: " + $tierOut) -ForegroundColor DarkGray
Write-Host ("TIER0_STDERR_LOG: " + $tierErr) -ForegroundColor DarkGray

# Extract artifact paths from selftest stdout
$stdoutTxt = [System.IO.File]::ReadAllText($tierOut, (New-Object System.Text.UTF8Encoding($false)))
$mReceipt = [regex]::Match($stdoutTxt, "(?m)^RECEIPT=(?<p>.+)\s*$")
if(-not $mReceipt.Success){ throw "TIER0_MISSING_RECEIPT_LINE" }
$receiptPath = $mReceipt.Groups["p"].Value.Trim()
if(-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)){ throw ("TIER0_RECEIPT_MISSING: " + $receiptPath) }

$mRunOut = [regex]::Match($stdoutTxt, "(?m)^RUN_STDOUT_LOG:\s*(?<p>.+)\s*$")
$mRunErr = [regex]::Match($stdoutTxt, "(?m)^RUN_STDERR_LOG:\s*(?<p>.+)\s*$")
if(-not $mRunOut.Success){ throw "TIER0_MISSING_RUN_STDOUT_LINE" }
if(-not $mRunErr.Success){ throw "TIER0_MISSING_RUN_STDERR_LINE" }
$runOut = $mRunOut.Groups["p"].Value.Trim()
$runErr = $mRunErr.Groups["p"].Value.Trim()
if(-not (Test-Path -LiteralPath $runOut -PathType Leaf)){ throw ("TIER0_RUN_STDOUT_MISSING: " + $runOut) }
if(-not (Test-Path -LiteralPath $runErr -PathType Leaf)){ throw ("TIER0_RUN_STDERR_MISSING: " + $runErr) }

# Evidence pack receipt (hashes) + optional sha256sums.txt
$EvidenceDir = Join-Path $RepoRoot "proofs\receipts\hashcanon_tier0"
EnsureDir $EvidenceDir
$evidencePath = Join-Path $EvidenceDir ($stamp + ".ndjson")
$sumsPath = Join-Path $EvidenceDir ($stamp + ".sha256sums.txt")

$schemaFile = Join-Path $RepoRoot "schemas\hashcanon.selftest_receipt.v1.json"
if(-not (Test-Path -LiteralPath $schemaFile -PathType Leaf)){ throw ("MISSING_SCHEMA_FILE: " + $schemaFile) }

$ev = @{
  schema    = "hashcanon.tier0_evidence_pack.v1"
  utc       = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  repo_root = $RepoRoot
  ok        = $true
  artifacts = @{
    tier0_runner  = @{ path = "scripts/_RUN_hashcanon_tier0_selftest_v1.ps1"; sha256 = (Sha256HexFile $MyInvocation.MyCommand.Path) }
    selftest      = @{ path = "scripts/_selftest_hashcanon_optionA_v1.ps1"; sha256 = (Sha256HexFile $Selftest) }
    schema_selftest_receipt = @{ path = "schemas/hashcanon.selftest_receipt.v1.json"; sha256 = (Sha256HexFile $schemaFile) }
    tier0_stdout  = @{ path = ("scripts/_scratch/" + (Split-Path -Leaf $tierOut)); sha256 = (Sha256HexFile $tierOut) }
    tier0_stderr  = @{ path = ("scripts/_scratch/" + (Split-Path -Leaf $tierErr)); sha256 = (Sha256HexFile $tierErr) }
    selftest_receipt = @{ path = (Resolve-Path -LiteralPath $receiptPath).Path; sha256 = (Sha256HexFile $receiptPath) }
    run_stdout    = @{ path = (Resolve-Path -LiteralPath $runOut).Path; sha256 = (Sha256HexFile $runOut) }
    run_stderr    = @{ path = (Resolve-Path -LiteralPath $runErr).Path; sha256 = (Sha256HexFile $runErr) }
  }
}

$line = ($ev | ConvertTo-Json -Depth 12 -Compress)
Write-Utf8NoBomLf $evidencePath ($line + "`n")
if(-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)){ throw ("EVIDENCE_WRITE_FAILED: " + $evidencePath) }

$sumLines = New-Object System.Collections.Generic.List[string]
[void]$sumLines.Add(($ev.artifacts.tier0_runner.sha256 + "  " + $ev.artifacts.tier0_runner.path))
[void]$sumLines.Add(($ev.artifacts.selftest.sha256 + "  " + $ev.artifacts.selftest.path))
[void]$sumLines.Add(($ev.artifacts.schema_selftest_receipt.sha256 + "  " + $ev.artifacts.schema_selftest_receipt.path))
[void]$sumLines.Add(($ev.artifacts.tier0_stdout.sha256 + "  " + $ev.artifacts.tier0_stdout.path))
[void]$sumLines.Add(($ev.artifacts.tier0_stderr.sha256 + "  " + $ev.artifacts.tier0_stderr.path))
[void]$sumLines.Add(($ev.artifacts.selftest_receipt.sha256 + "  " + $ev.artifacts.selftest_receipt.path))
[void]$sumLines.Add(($ev.artifacts.run_stdout.sha256 + "  " + $ev.artifacts.run_stdout.path))
[void]$sumLines.Add(($ev.artifacts.run_stderr.sha256 + "  " + $ev.artifacts.run_stderr.path))
$sumText = (@($sumLines.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $sumsPath $sumText

Write-Host "HASHCANON_TIER0_OK" -ForegroundColor Green
Write-Host ("EVIDENCE=" + $evidencePath) -ForegroundColor Green
Write-Host ("SHA256SUMS=" + $sumsPath) -ForegroundColor Green
