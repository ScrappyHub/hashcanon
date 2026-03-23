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
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw ("PARSE_GATE_MISSING: " + $Path)
  }
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
  if($errors -and $errors.Count -gt 0){
    $x = $errors[0]
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
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw ("SHA256_MISSING_FILE: " + $Path)
  }
  $b = [System.IO.File]::ReadAllBytes($Path)
  Sha256HexBytes $b
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PSExe    = (Get-Command powershell.exe -ErrorAction Stop).Source

$SchemasDir = Join-Path $RepoRoot "schemas"
$ScriptsDir = Join-Path $RepoRoot "scripts"
$DocsDir    = Join-Path $RepoRoot "docs"
$ProofsDir  = Join-Path $RepoRoot "proofs"

EnsureDir $SchemasDir
EnsureDir $ScriptsDir
EnsureDir $DocsDir
EnsureDir $ProofsDir

$VerifySchemaPath = Join-Path $SchemasDir "hashcanon.verify_receipt.v1.json"
$StatusSchemaPath = Join-Path $SchemasDir "hashcanon.status_snapshot.v1.json"
$VerifyPath       = Join-Path $ScriptsDir "hashcanon_verify_packet_optionA_v1.ps1"
$StatusPath       = Join-Path $ScriptsDir "hashcanon_build_status_snapshot_v1.ps1"
$StatusSelfPath   = Join-Path $ScriptsDir "_selftest_hashcanon_status_snapshot_v1.ps1"
$ContractDocPath  = Join-Path $DocsDir "HASHCANON_WATCHTOWER_CONTRACT_v1.md"

$VerifySchemaText = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "hashcanon.verify_receipt.v1",
  "title": "HashCanon Verify Receipt v1",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema",
    "ok",
    "utc",
    "packet_dir",
    "packet_id",
    "manifest_sha256",
    "packet_id_txt_sha256",
    "sha256sums_sha256",
    "verified_files"
  ],
  "properties": {
    "schema": { "const": "hashcanon.verify_receipt.v1" },
    "ok": { "type": "boolean" },
    "utc": { "type": "string", "minLength": 1 },
    "packet_dir": { "type": "string", "minLength": 1 },
    "packet_id": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "manifest_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "packet_id_txt_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "sha256sums_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "verified_files": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 }
    }
  }
}
'@

$StatusSchemaText = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "hashcanon.status_snapshot.v1",
  "title": "HashCanon Status Snapshot v1",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema",
    "ok",
    "utc",
    "repo_root",
    "full_green_runner_present",
    "full_green_receipt_schema_present",
    "verify_receipt_schema_present",
    "status_snapshot_schema_present",
    "minimal_packet_present",
    "nfl_selftest_present",
    "latest_full_green_dir"
  ],
  "properties": {
    "schema": { "const": "hashcanon.status_snapshot.v1" },
    "ok": { "type": "boolean" },
    "utc": { "type": "string", "minLength": 1 },
    "repo_root": { "type": "string", "minLength": 1 },
    "full_green_runner_present": { "type": "boolean" },
    "full_green_receipt_schema_present": { "type": "boolean" },
    "verify_receipt_schema_present": { "type": "boolean" },
    "status_snapshot_schema_present": { "type": "boolean" },
    "minimal_packet_present": { "type": "boolean" },
    "nfl_selftest_present": { "type": "boolean" },
    "latest_full_green_dir": {
      "anyOf": [
        { "type": "null" },
        { "type": "string", "minLength": 1 }
      ]
    }
  }
}
'@

$VerifyText = @'
param(
  [Parameter(Mandatory=$true)][string]$PacketDir,
  [Parameter(Mandatory=$false)][string]$ReceiptPath
)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Sha256HexBytes([byte[]]$b){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Sha256HexFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw ("VERIFY_MISSING_FILE: " + $Path)
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

$PacketDir = (Resolve-Path -LiteralPath $PacketDir).Path

$manifestPath   = Join-Path $PacketDir "manifest.json"
$packetIdPath   = Join-Path $PacketDir "packet_id.txt"
$sha256sumsPath = Join-Path $PacketDir "sha256sums.txt"

if(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){ throw "HC_VERIFY_MISSING_MANIFEST" }
if(-not (Test-Path -LiteralPath $packetIdPath -PathType Leaf)){ throw "HC_VERIFY_MISSING_PACKET_ID" }
if(-not (Test-Path -LiteralPath $sha256sumsPath -PathType Leaf)){ throw "HC_VERIFY_MISSING_SHA256SUMS" }

$mBytes = [System.IO.File]::ReadAllBytes($manifestPath)
$mText = (New-Object System.Text.UTF8Encoding($false)).GetString($mBytes)
if($mText -match "(?:^|[^a-zA-Z0-9_])packet_id(?:[^a-zA-Z0-9_]|$)"){ throw "HC_VERIFY_MANIFEST_CONTAINS_PACKET_ID_FIELD" }

$expected = Sha256HexBytes $mBytes
$packetIdText = ((New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($packetIdPath))).Trim()
if($packetIdText -ne $expected){ throw "HC_VERIFY_PACKET_ID_MISMATCH" }

$dirName = (Split-Path -Leaf $PacketDir)
if($dirName -match "^[0-9a-f]{64}$" -and $dirName -ne $expected){ throw "HC_VERIFY_DIRNAME_PACKETID_MISMATCH" }

$sumText = (New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($sha256sumsPath))
$lines = @(@($sumText -split "`n") | Where-Object { $_.Trim().Length -gt 0 })
if($lines.Count -lt 1){ throw "HC_VERIFY_SHA256SUMS_EMPTY" }

$seen = New-Object System.Collections.Generic.HashSet[string]
foreach($ln in $lines){
  $m = [regex]::Match($ln, "^(?<h>[0-9a-f]{64})\s\s(?<p>.+)$")
  if(-not $m.Success){ throw "HC_VERIFY_SHA256SUMS_BAD_LINE" }

  $h  = $m.Groups["h"].Value
  $rp = $m.Groups["p"].Value.Trim()

  if([string]::IsNullOrWhiteSpace($rp)){ throw "HC_VERIFY_SHA256SUMS_EMPTY_PATH" }
  if($rp -match "^[A-Za-z]:\\" -or $rp.StartsWith("/") -or $rp.StartsWith([string][char]92)){ throw "HC_VERIFY_SHA256SUMS_ABSOLUTE_PATH" }
  if($rp.Contains("..\") -or $rp.Contains("../")){ throw "HC_VERIFY_SHA256SUMS_TRAVERSAL" }

  $rp = $rp.Replace("\","/")
  $ap = Join-Path $PacketDir ($rp.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
  if(-not (Test-Path -LiteralPath $ap -PathType Leaf)){ throw "HC_VERIFY_SHA256SUMS_MISSING_FILE" }

  $actual = Sha256HexFile $ap
  if($actual -ne $h){ throw "HC_VERIFY_SHA256_MISMATCH" }

  [void]$seen.Add($rp)
}

if(-not $seen.Contains("manifest.json")){ throw "HC_VERIFY_SHA256SUMS_MISSING_MANIFEST_ENTRY" }
if(-not $seen.Contains("packet_id.txt")){ throw "HC_VERIFY_SHA256SUMS_MISSING_PACKETID_ENTRY" }

if(-not [string]::IsNullOrWhiteSpace($ReceiptPath)){
  $receipt = [ordered]@{
    schema = "hashcanon.verify_receipt.v1"
    ok = $true
    utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    packet_dir = $PacketDir
    packet_id = $expected
    manifest_sha256 = (Sha256HexFile $manifestPath)
    packet_id_txt_sha256 = (Sha256HexFile $packetIdPath)
    sha256sums_sha256 = (Sha256HexFile $sha256sumsPath)
    verified_files = @($seen | Sort-Object)
  }
  $line = ($receipt | ConvertTo-Json -Depth 8 -Compress)
  Write-Utf8NoBomLf $ReceiptPath ($line + "`n")
}

Write-Host "HC_VERIFY_OK" -ForegroundColor Green
Write-Host ("PACKET_ID=" + $expected) -ForegroundColor Green
'@

$StatusText = @'
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
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$fullGreenRunner = Join-Path $RepoRoot "scripts\_RUN_hashcanon_full_green_v1.ps1"
$fullGreenSchema = Join-Path $RepoRoot "schemas\hashcanon.full_green_receipt.v1.json"
$verifySchema    = Join-Path $RepoRoot "schemas\hashcanon.verify_receipt.v1.json"
$statusSchema    = Join-Path $RepoRoot "schemas\hashcanon.status_snapshot.v1.json"
$nflSelftest     = Join-Path $RepoRoot "scripts\selftest_hashcanon_nfl_packet_v1.ps1"

$pktRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"
$pktDirs = @()
if(Test-Path -LiteralPath $pktRoot -PathType Container){
  $pktDirs = @(Get-ChildItem -LiteralPath $pktRoot -Directory | Sort-Object Name -Descending)
}
$minimalPacketPresent = ($pktDirs.Count -gt 0)

$fullGreenRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_full_green"
$latestFullGreenDir = $null
if(Test-Path -LiteralPath $fullGreenRoot -PathType Container){
  $dirs = @(Get-ChildItem -LiteralPath $fullGreenRoot -Directory | Sort-Object Name -Descending)
  if($dirs.Count -gt 0){ $latestFullGreenDir = $dirs[0].FullName }
}

$status = [ordered]@{
  schema = "hashcanon.status_snapshot.v1"
  ok = $true
  utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
  repo_root = $RepoRoot
  full_green_runner_present = (Test-Path -LiteralPath $fullGreenRunner -PathType Leaf)
  full_green_receipt_schema_present = (Test-Path -LiteralPath $fullGreenSchema -PathType Leaf)
  verify_receipt_schema_present = (Test-Path -LiteralPath $verifySchema -PathType Leaf)
  status_snapshot_schema_present = (Test-Path -LiteralPath $statusSchema -PathType Leaf)
  minimal_packet_present = $minimalPacketPresent
  nfl_selftest_present = (Test-Path -LiteralPath $nflSelftest -PathType Leaf)
  latest_full_green_dir = $latestFullGreenDir
}

$StatusRoot = Join-Path $RepoRoot "proofs\status"
EnsureDir $StatusRoot
$StatusPath = Join-Path $StatusRoot "hashcanon_status_snapshot_v1.json"
$json = ($status | ConvertTo-Json -Depth 6)
Write-Utf8NoBomLf $StatusPath $json

Write-Host "HASHCANON_STATUS_SNAPSHOT_OK" -ForegroundColor Green
Write-Host ("STATUS_PATH=" + $StatusPath) -ForegroundColor Green
'@

$StatusSelfText = @'
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
'@

$ContractDocText = @'
# HashCanon WatchTower Contract v1

This document defines the WatchTower-facing contract emitted by HashCanon.

## Surfaces

### 1. Verify receipt
- schema: `hashcanon.verify_receipt.v1`
- file location: `proofs/receipts/hashcanon_verify/*.ndjson`

Purpose:
- provide deterministic machine-readable evidence that a packet verified successfully
- surface packet identity and file-hash evidence for downstream monitoring

### 2. Status snapshot
- schema: `hashcanon.status_snapshot.v1`
- file location: `proofs/status/hashcanon_status_snapshot_v1.json`

Purpose:
- provide a current machine-readable status view of HashCanon's essential public proof surfaces
- allow WatchTower to poll or ingest a single status document

## Current invariants

- verification is non-mutating
- packet identity derives from final manifest bytes
- minimal authoritative packet exists under `test_vectors/hashcanon_optionA/minimal_packet`
- full-green runner exists and emits receipts
- NFL selftest exists and is invocable by the full-green runner

## WatchTower consumption model

WatchTower should:
1. ingest verify receipts as append-only verification evidence
2. ingest status snapshot as current-state health metadata
3. treat both as machine-facing contract surfaces, not UI artifacts
'@

Write-Utf8NoBomLf $VerifySchemaPath $VerifySchemaText
Write-Utf8NoBomLf $StatusSchemaPath $StatusSchemaText
Write-Utf8NoBomLf $VerifyPath $VerifyText
Write-Utf8NoBomLf $StatusPath $StatusText
Write-Utf8NoBomLf $StatusSelfPath $StatusSelfText
Write-Utf8NoBomLf $ContractDocPath $ContractDocText

Parse-GateFile $VerifyPath
Parse-GateFile $StatusPath
Parse-GateFile $StatusSelfPath

$Positive = Join-Path $RepoRoot "scripts\_selftest_hashcanon_optionA_v1.ps1"
$Negative = Join-Path $RepoRoot "scripts\_selftest_hashcanon_negative_suite_v1.ps1"
$NflSelf  = Join-Path $RepoRoot "scripts\selftest_hashcanon_nfl_packet_v1.ps1"

foreach($p in @($Positive,$Negative,$NflSelf)){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){
    throw ("WATCHTOWER_CONTRACT_MISSING_PREREQ: " + $p)
  }
}

$p1 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Positive,"-RepoRoot",$RepoRoot
) -Wait -PassThru
if($p1.ExitCode -ne 0){ throw ("PATCH_POSITIVE_FAILED exit_code=" + $p1.ExitCode) }

$p2 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$Negative,"-RepoRoot",$RepoRoot
) -Wait -PassThru
if($p2.ExitCode -ne 0){ throw ("PATCH_NEGATIVE_FAILED exit_code=" + $p2.ExitCode) }

$VerifyReceiptRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_verify"
EnsureDir $VerifyReceiptRoot
$VerifyReceiptPath = Join-Path $VerifyReceiptRoot ([DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss") + ".ndjson")

$PktRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"
$PktDirs = @(@(Get-ChildItem -LiteralPath $PktRoot -Directory | Sort-Object Name -Descending))
if($PktDirs.Count -lt 1){ throw "PATCH_NO_PACKET_DIR_FOUND" }
$PktDir = $PktDirs[0].FullName

$p3 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$VerifyPath,"-PacketDir",$PktDir,"-ReceiptPath",$VerifyReceiptPath
) -Wait -PassThru
if($p3.ExitCode -ne 0){ throw ("PATCH_VERIFY_FAILED exit_code=" + $p3.ExitCode) }

$NflRoot = Join-Path $RepoRoot "proofs\receipts\hashcanon_nfl"
EnsureDir $NflRoot
$NflLog = Join-Path $NflRoot ([DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss") + ".log")
$NflErr = $NflLog + ".err"

$p4 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$NflSelf,"-RepoRoot",$RepoRoot
) -Wait -PassThru -RedirectStandardOutput $NflLog -RedirectStandardError $NflErr
if($p4.ExitCode -ne 0){ throw ("PATCH_NFL_SELFTEST_FAILED exit_code=" + $p4.ExitCode) }

$p5 = Start-Process -FilePath $PSExe -ArgumentList @(
  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
  "-File",$StatusSelfPath,"-RepoRoot",$RepoRoot
) -Wait -PassThru
if($p5.ExitCode -ne 0){ throw ("PATCH_STATUS_SELFTEST_FAILED exit_code=" + $p5.ExitCode) }

$StatusSnapshotPath = Join-Path $RepoRoot "proofs\status\hashcanon_status_snapshot_v1.json"
if(-not (Test-Path -LiteralPath $StatusSnapshotPath -PathType Leaf)){
  throw "PATCH_STATUS_SNAPSHOT_MISSING"
}

Write-Host "HASHCANON_WATCHTOWER_CONTRACT_V1_OK" -ForegroundColor Green
Write-Host ("VERIFY_SCHEMA=" + $VerifySchemaPath) -ForegroundColor Green
Write-Host ("STATUS_SCHEMA=" + $StatusSchemaPath) -ForegroundColor Green
Write-Host ("VERIFY_SCRIPT=" + $VerifyPath) -ForegroundColor Green
Write-Host ("STATUS_SCRIPT=" + $StatusPath) -ForegroundColor Green
Write-Host ("STATUS_SELFTEST=" + $StatusSelfPath) -ForegroundColor Green
Write-Host ("CONTRACT_DOC=" + $ContractDocPath) -ForegroundColor Green
Write-Host ("VERIFY_RECEIPT=" + $VerifyReceiptPath) -ForegroundColor Green
Write-Host ("NFL_LOG=" + $NflLog) -ForegroundColor Green
Write-Host ("STATUS_SNAPSHOT=" + $StatusSnapshotPath) -ForegroundColor Green