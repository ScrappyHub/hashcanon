param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }; $t=$Text.Replace("`r`n","`n").Replace("`r","`n"); if(-not $t.EndsWith("`n")){ $t+="`n" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t)) }
function Parse-GateFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("PARSE_GATE_MISSING: " + $Path) }; $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e); if($e -and $e.Count -gt 0){ $x=$e[0]; Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) } }

# Locate runner deterministically (hashcanon)
$Scratch = Join-Path $RepoRoot "scripts\_scratch"
EnsureDir $Scratch
$RunPath = Join-Path $Scratch "_RUN_packet_constitution_v1_test_vectors_optionA.ps1"
if(-not (Test-Path -LiteralPath $RunPath -PathType Leaf)){
  $cand = Get-ChildItem -LiteralPath $Scratch -File -Force | Sort-Object FullName | Where-Object { $_.Name -match "RUN_.*test_vectors.*optionA" } | Select-Object -First 1
  if(-not $cand){ Die ("MISSING_RUN_SCRIPT: " + $RunPath) }
  $RunPath = $cand.FullName
}

$raw  = [System.IO.File]::ReadAllText($RunPath, (New-Object System.Text.UTF8Encoding($false)))
$raw2 = $raw

# 1) Replace literal $pid tokens with literal $packetIdHex (case-insensitive).
# IMPORTANT: patterns/replacements are SINGLE-QUOTED so PowerShell does not expand $pid/$packetIdHex.
# In .NET replacement, $$ emits a literal $ in the output.
$raw2 = [regex]::Replace($raw2, '(?i)\$pid\b', '$$packetIdHex')

# 2) Ensure $packetIdHex is assigned if referenced.
$uses = [regex]::Matches($raw2, '(?i)\$packetIdHex\b')
if($uses.Count -gt 0){
  $hasAssign = [regex]::IsMatch($raw2, '(?im)^\s*\$packetIdHex\s*=' )
  if(-not $hasAssign){
    $m = [regex]::Match($raw2, '(?im)^\s*\$(?<v>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*Sha256Hex(File|Bytes)\b.*$')
    if(-not $m.Success){ Die "NO_ASSIGNMENT_FOUND_FOR_PACKETIDHEX: cannot find Sha256Hex(File|Bytes) assignment to mirror" }
    $srcVar = $m.Groups["v"].Value
    $line   = $m.Value
    $assign = '$packetIdHex = $' + $srcVar
    $inject = $line + "`n" + $assign
    $raw2 = $raw2.Replace($line, $inject)
  }
}

# 3) Assert no $pid remains and something changed
if([regex]::IsMatch($raw2, '(?i)\$pid\b')){ Die "PATCH_INCOMPLETE: `$pid still present after rewrite" }
if($raw2 -eq $raw){ Die "PATCH_NO_CHANGE: nothing changed (already fixed?)" }

Write-Utf8NoBomLf $RunPath $raw2
Parse-GateFile $RunPath
Write-Host ("PATCH_OK+PARSE_OK: " + $RunPath) -ForegroundColor Green
