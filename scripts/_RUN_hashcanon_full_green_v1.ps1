param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
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
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

$Positive = Join-Path $RepoRoot "scripts\_selftest_hashcanon_optionA_v1.ps1"
$Negative = Join-Path $RepoRoot "scripts\_selftest_hashcanon_negative_suite_v1.ps1"
$NflSelf  = Join-Path $RepoRoot "scripts\selftest_hashcanon_nfl_packet_v1.ps1"

foreach($p in @($Positive,$Negative,$NflSelf)){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){
    throw ("FULL_GREEN_MISSING_SCRIPT: " + $p)
  }
}

$ReceiptRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_full_green"
EnsureDir $ReceiptRoot

$runId = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
$runDir = Join-Path $ReceiptRoot $runId
EnsureDir $runDir

$posOut = Join-Path $runDir "positive.stdout.log"
$posErr = Join-Path $runDir "positive.stderr.log"
$negOut = Join-Path $runDir "negative.stdout.log"
$negErr = Join-Path $runDir "negative.stderr.log"
$nflOut = Join-Path $runDir "nfl.stdout.log"
$nflErr = Join-Path $runDir "nfl.stderr.log"

$p1 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Positive,"-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $posOut -RedirectStandardError $posErr

if($p1.ExitCode -ne 0){ throw ("FULL_GREEN_POSITIVE_FAILED exit_code=" + $p1.ExitCode) }

$p2 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Negative,"-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $negOut -RedirectStandardError $negErr

if($p2.ExitCode -ne 0){ throw ("FULL_GREEN_NEGATIVE_FAILED exit_code=" + $p2.ExitCode) }

$p3 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$NflSelf,"-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $nflOut -RedirectStandardError $nflErr

if($p3.ExitCode -ne 0){ throw ("FULL_GREEN_NFL_FAILED exit_code=" + $p3.ExitCode) }

$receiptPath = Join-Path $runDir "result.ndjson"
$sumPath = Join-Path $runDir "sha256sums.txt"

$receipt = [ordered]@{
  schema = "hashcanon.full_green_receipt.v1"
  ok = $true
  repo_root = $RepoRoot
  run_dir = $runDir
  artifacts = [ordered]@{
    full_green_runner = [ordered]@{ path = "scripts/_RUN_hashcanon_full_green_v1.ps1"; sha256 = (Sha256HexFile $MyInvocation.MyCommand.Path) }
    positive_selftest = [ordered]@{ path = "scripts/_selftest_hashcanon_optionA_v1.ps1"; sha256 = (Sha256HexFile $Positive) }
    negative_selftest = [ordered]@{ path = "scripts/_selftest_hashcanon_negative_suite_v1.ps1"; sha256 = (Sha256HexFile $Negative) }
    nfl_selftest      = [ordered]@{ path = "scripts/selftest_hashcanon_nfl_packet_v1.ps1"; sha256 = (Sha256HexFile $NflSelf) }
    positive_stdout   = [ordered]@{ path = $posOut; sha256 = (Sha256HexFile $posOut) }
    positive_stderr   = [ordered]@{ path = $posErr; sha256 = (Sha256HexFile $posErr) }
    negative_stdout   = [ordered]@{ path = $negOut; sha256 = (Sha256HexFile $negOut) }
    negative_stderr   = [ordered]@{ path = $negErr; sha256 = (Sha256HexFile $negErr) }
    nfl_stdout        = [ordered]@{ path = $nflOut; sha256 = (Sha256HexFile $nflOut) }
    nfl_stderr        = [ordered]@{ path = $nflErr; sha256 = (Sha256HexFile $nflErr) }
  }
}

$line = ($receipt | ConvertTo-Json -Depth 10 -Compress)
Write-Utf8NoBomLf $receiptPath ($line + "`n")

$sumLines = New-Object System.Collections.Generic.List[string]
[void]$sumLines.Add((Sha256HexFile $receiptPath) + "  result.ndjson")
[void]$sumLines.Add((Sha256HexFile $posOut) + "  positive.stdout.log")
[void]$sumLines.Add((Sha256HexFile $posErr) + "  positive.stderr.log")
[void]$sumLines.Add((Sha256HexFile $negOut) + "  negative.stdout.log")
[void]$sumLines.Add((Sha256HexFile $negErr) + "  negative.stderr.log")
[void]$sumLines.Add((Sha256HexFile $nflOut) + "  nfl.stdout.log")
[void]$sumLines.Add((Sha256HexFile $nflErr) + "  nfl.stderr.log")
Write-Utf8NoBomLf $sumPath ((@($sumLines.ToArray()) -join "`n") + "`n")

Write-Host "HASHCANON_FULL_GREEN_OK" -ForegroundColor Green
Write-Host ("RUN_DIR=" + $runDir) -ForegroundColor Green
Write-Host ("RECEIPT=" + $receiptPath) -ForegroundColor Green
Write-Host ("SHA256SUMS=" + $sumPath) -ForegroundColor Green
