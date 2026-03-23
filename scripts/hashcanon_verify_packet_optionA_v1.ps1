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
