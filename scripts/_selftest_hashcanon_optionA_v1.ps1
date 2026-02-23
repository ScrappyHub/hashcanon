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

$Runner = Join-Path $RepoRoot "scripts\hashcanon_run_test_vectors_optionA_v1.ps1"
if(-not (Test-Path -LiteralPath $Runner -PathType Leaf)){ throw ("MISSING_RUNNER: " + $Runner) }

$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss")
$outLog = Join-Path $Scratch ("runner_stdout_" + $stamp + ".log")
$errLog = Join-Path $Scratch ("runner_stderr_" + $stamp + ".log")

$p = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile",
  "-NonInteractive",
  "-ExecutionPolicy","Bypass",
  "-File",$Runner,
  "-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog

Write-Host ("RUN_STDOUT_LOG: " + $outLog) -ForegroundColor DarkGray
Write-Host ("RUN_STDERR_LOG: " + $errLog) -ForegroundColor DarkGray
if($p.ExitCode -ne 0){ throw ("RUN_FAILED exit_code=" + $p.ExitCode) }

$ReceiptsDir = Join-Path $RepoRoot "proofs\receipts\hashcanon_selftest"
EnsureDir $ReceiptsDir
$receiptPath = Join-Path $ReceiptsDir ($stamp + ".ndjson")

$patchScript = Join-Path $RepoRoot "scripts\hashcanon_patch_fix_pid_collision_v5.ps1"
$patchSha = $null
if(Test-Path -LiteralPath $patchScript -PathType Leaf){
  $patchSha = Sha256HexFile $patchScript
}

$receipt = @{
  schema    = "hashcanon.selftest_receipt.v1"
  utc       = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  repo_root = $RepoRoot
  ok        = $true
  artifacts = @{
    run_script   = @{ path = "scripts/_scratch/_RUN_hashcanon_v1_test_vectors_optionA.ps1"; sha256 = (Sha256HexFile $Runner) }
    patch_script = @{ path = "scripts/_scratch/_PATCH_fix_pid_collision_v5.ps1"; sha256 = $patchSha }
    stdout_log   = @{ path = ("scripts/_scratch/" + (Split-Path -Leaf $outLog)); sha256 = (Sha256HexFile $outLog) }
    stderr_log   = @{ path = ("scripts/_scratch/" + (Split-Path -Leaf $errLog)); sha256 = (Sha256HexFile $errLog) }
  }
}

$line = ($receipt | ConvertTo-Json -Depth 10 -Compress)
Write-Utf8NoBomLf $receiptPath ($line + "`n")
if(-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)){ throw ("RECEIPT_WRITE_FAILED: " + $receiptPath) }

# Validate receipt JSON deterministically (schema + key shas)
$txt = [System.IO.File]::ReadAllText($receiptPath, (New-Object System.Text.UTF8Encoding($false)))
$one = ($txt -split "`n" | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1)
$obj = $one | ConvertFrom-Json
if($obj.schema -ne "hashcanon.selftest_receipt.v1"){ throw ("BAD_SCHEMA: " + $obj.schema) }
if(-not $obj.ok){ throw "RECEIPT_OK_FALSE" }
if(-not $obj.artifacts.run_script.sha256){ throw "MISSING_RUN_SHA256" }
if(-not $obj.artifacts.stdout_log.sha256){ throw "MISSING_STDOUT_SHA256" }
if(-not $obj.artifacts.stderr_log.sha256){ throw "MISSING_STDERR_SHA256" }

Write-Host "SELFTEST_HASHCANON_OK" -ForegroundColor Green
Write-Host ("RECEIPT=" + $receiptPath) -ForegroundColor Green
