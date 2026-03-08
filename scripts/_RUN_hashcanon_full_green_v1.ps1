param([Parameter(Mandatory=$true)][string]$RepoRoot)

$ErrorActionPreference = "Stop"
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

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("PARSE_GATE_MISSING: " + $Path) }
  $tok = $null
  $err = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tok,[ref]$err)
  if($err -and $err.Count -gt 0){
    $x = $err[0]
    throw ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

function Sha256HexBytes([byte[]]$b){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try{
    $h = $sha.ComputeHash($b)
  } finally {
    $sha.Dispose()
  }
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Sha256HexFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("SHA256_MISSING_FILE: " + $Path) }
  $b = [System.IO.File]::ReadAllBytes($Path)
  Sha256HexBytes $b
}

function Run-ChildLogged{
  param(
    [Parameter(Mandatory=$true)][string]$PSExe,
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [Parameter(Mandatory=$true)][string]$ErrPath
  )

  $p = Start-Process -FilePath $PSExe -ArgumentList @(
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy","Bypass",
    "-File",$ScriptPath,
    "-RepoRoot",$RepoRoot
  ) -Wait -PassThru -RedirectStandardOutput $OutPath -RedirectStandardError $ErrPath

  return $p
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe    = (Get-Command powershell.exe -ErrorAction Stop).Source

$Tier0Runner = Join-Path $RepoRoot "scripts\_RUN_hashcanon_tier0_selftest_v1.ps1"
$Positive    = Join-Path $RepoRoot "scripts\_selftest_hashcanon_optionA_v1.ps1"
$Negative    = Join-Path $RepoRoot "scripts\_selftest_hashcanon_negative_suite_v1.ps1"
$Generator   = Join-Path $RepoRoot "scripts\hashcanon_make_minimal_packet_optionA_v1.ps1"
$Verifier    = Join-Path $RepoRoot "scripts\hashcanon_verify_packet_optionA_v1.ps1"

Parse-GateFile $Tier0Runner
Parse-GateFile $Positive
Parse-GateFile $Negative
Parse-GateFile $Generator
Parse-GateFile $Verifier

$ReceiptRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_full_green"
EnsureDir $ReceiptRoot

$runId = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
$RunDir = Join-Path $ReceiptRoot $runId
EnsureDir $RunDir

$tier0Out = Join-Path $RunDir "01_tier0_stdout.log"
$tier0Err = Join-Path $RunDir "01_tier0_stderr.log"
$posOut   = Join-Path $RunDir "02_positive_stdout.log"
$posErr   = Join-Path $RunDir "02_positive_stderr.log"
$negOut   = Join-Path $RunDir "03_negative_stdout.log"
$negErr   = Join-Path $RunDir "03_negative_stderr.log"
$sumPath  = Join-Path $RunDir "sha256sums.txt"
$receipt  = Join-Path $RunDir "result.ndjson"

$p1 = Run-ChildLogged -PSExe $PSExe -ScriptPath $Tier0Runner -RepoRoot $RepoRoot -OutPath $tier0Out -ErrPath $tier0Err
if($p1.ExitCode -ne 0){ throw ("FULL_GREEN_TIER0_FAILED exit_code=" + $p1.ExitCode) }

$p2 = Run-ChildLogged -PSExe $PSExe -ScriptPath $Positive -RepoRoot $RepoRoot -OutPath $posOut -ErrPath $posErr
if($p2.ExitCode -ne 0){ throw ("FULL_GREEN_POSITIVE_FAILED exit_code=" + $p2.ExitCode) }

$p3 = Run-ChildLogged -PSExe $PSExe -ScriptPath $Negative -RepoRoot $RepoRoot -OutPath $negOut -ErrPath $negErr
if($p3.ExitCode -ne 0){ throw ("FULL_GREEN_NEGATIVE_FAILED exit_code=" + $p3.ExitCode) }

$sumLines = New-Object System.Collections.Generic.List[string]
[void]$sumLines.Add((Sha256HexFile $Tier0Runner) + "  scripts/_RUN_hashcanon_tier0_selftest_v1.ps1")
[void]$sumLines.Add((Sha256HexFile $Positive) + "  scripts/_selftest_hashcanon_optionA_v1.ps1")
[void]$sumLines.Add((Sha256HexFile $Negative) + "  scripts/_selftest_hashcanon_negative_suite_v1.ps1")
[void]$sumLines.Add((Sha256HexFile $Generator) + "  scripts/hashcanon_make_minimal_packet_optionA_v1.ps1")
[void]$sumLines.Add((Sha256HexFile $Verifier) + "  scripts/hashcanon_verify_packet_optionA_v1.ps1")
[void]$sumLines.Add((Sha256HexFile $tier0Out) + "  01_tier0_stdout.log")
[void]$sumLines.Add((Sha256HexFile $tier0Err) + "  01_tier0_stderr.log")
[void]$sumLines.Add((Sha256HexFile $posOut)   + "  02_positive_stdout.log")
[void]$sumLines.Add((Sha256HexFile $posErr)   + "  02_positive_stderr.log")
[void]$sumLines.Add((Sha256HexFile $negOut)   + "  03_negative_stdout.log")
[void]$sumLines.Add((Sha256HexFile $negErr)   + "  03_negative_stderr.log")
Write-Utf8NoBomLf $sumPath ((@($sumLines.ToArray()) -join "`n") + "`n")

$obj = [ordered]@{
  schema   = "hashcanon.full_green_receipt.v1"
  utc      = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  repo_root= $RepoRoot
  ok       = $true
  run_dir  = $RunDir
  artifacts = [ordered]@{
    tier0_runner = [ordered]@{ path = "scripts/_RUN_hashcanon_tier0_selftest_v1.ps1"; sha256 = (Sha256HexFile $Tier0Runner) }
    positive     = [ordered]@{ path = "scripts/_selftest_hashcanon_optionA_v1.ps1"; sha256 = (Sha256HexFile $Positive) }
    negative     = [ordered]@{ path = "scripts/_selftest_hashcanon_negative_suite_v1.ps1"; sha256 = (Sha256HexFile $Negative) }
    generator    = [ordered]@{ path = "scripts/hashcanon_make_minimal_packet_optionA_v1.ps1"; sha256 = (Sha256HexFile $Generator) }
    verifier     = [ordered]@{ path = "scripts/hashcanon_verify_packet_optionA_v1.ps1"; sha256 = (Sha256HexFile $Verifier) }
    sha256sums   = [ordered]@{ path = "proofs/receipts/hashcanon_full_green/" + $runId + "/sha256sums.txt"; sha256 = (Sha256HexFile $sumPath) }
  }
}

$line = ($obj | ConvertTo-Json -Depth 10 -Compress)
Write-Utf8NoBomLf $receipt ($line + "`n")

Write-Host "HASHCANON_FULL_GREEN_OK" -ForegroundColor Green
Write-Host ("RUN_DIR=" + $RunDir) -ForegroundColor Green
Write-Host ("RECEIPT=" + $receipt) -ForegroundColor Green
Write-Host ("SHA256SUMS=" + $sumPath) -ForegroundColor Green
