param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}
function Read-Bytes([string]$Path){ [System.IO.File]::ReadAllBytes($Path) }
function Sha256HexBytes([byte[]]$b){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $h = $sha.ComputeHash($b)
    $sb = New-Object System.Text.StringBuilder
    foreach($x in $h){ [void]$sb.AppendFormat("{0:x2}", $x) }
    return $sb.ToString()
  } finally { $sha.Dispose() }
}
function Sha256HexFile([string]$Path){ Sha256HexBytes (Read-Bytes $Path) }

# CanonJson v1: minimal deterministic JSON for dictionaries/arrays/strings/bools/null/numbers
function Escape-JsonString([string]$s){
  $sb = New-Object System.Text.StringBuilder
  for($i=0;$i -lt $s.Length;$i++){
    $c = [int][char]$s[$i]
    if($c -eq 34){ [void]$sb.Append('\"') }
    elseif($c -eq 92){ [void]$sb.Append('\\') }
    elseif($c -eq 8){ [void]$sb.Append('\b') }
    elseif($c -eq 9){ [void]$sb.Append('\t') }
    elseif($c -eq 10){ [void]$sb.Append('\n') }
    elseif($c -eq 12){ [void]$sb.Append('\f') }
    elseif($c -eq 13){ [void]$sb.Append('\r') }
    elseif($c -lt 32){ [void]$sb.AppendFormat('\u{0:x4}',$c) }
    else{ [void]$sb.Append([char]$c) }
  }
  return $sb.ToString()
}
function CanonJson([object]$v){
  if($null -eq $v){ return "null" }
  if($v -is [string]){ return '"' + (Escape-JsonString $v) + '"' }
  if($v -is [bool]){ if($v){ return "true" } else { return "false" } }
  if($v -is [int] -or $v -is [long] -or $v -is [decimal] -or $v -is [double] -or $v -is [single]){
    if($v -is [double] -or $v -is [single]){
      if([double]::IsNaN([double]$v) -or [double]::IsInfinity([double]$v)){ Die "CANONJSON_DISALLOWS_NAN_INF" }
    }
    $s = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $v)
    if($s -eq "-0"){ $s = "0" }
    return $s
  }
  if($v -is [System.Collections.IDictionary]){
    $keys = New-Object System.Collections.Generic.List[string]
    foreach($k in $v.Keys){ [void]$keys.Add([string]$k) }
    $keys.Sort([System.StringComparer]::Ordinal)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach($k in $keys){
      $parts.Add( (CanonJson $k) + ":" + (CanonJson $v[$k]) ) | Out-Null
    }
    return "{" + (($parts.ToArray()) -join ",") + "}"
  }
  if($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])){
    $parts = New-Object System.Collections.Generic.List[string]
    foreach($x in $v){ $parts.Add((CanonJson $x)) | Out-Null }
    return "[" + (($parts.ToArray()) -join ",") + "]"
  }
  Die ("CANONJSON_UNSUPPORTED_TYPE: " + $v.GetType().FullName)
}

function Write-CanonJsonFile([string]$Path, [object]$Obj){
  $json = (CanonJson $Obj)
  # Canonical JSON bytes are UTF-8 no BOM + LF
  Write-Utf8NoBomLf $Path $json
}

function Normalize-RelPath([string]$p){
  # lock sha256sums paths to forward slashes
  return ($p -replace "\\\\","/")
}

function Build-Sha256Sums([string]$Root, [string[]]$RelFiles, [string]$OutPath){
  $lines = New-Object System.Collections.Generic.List[string]
  $sorted = @($RelFiles | Sort-Object)
  foreach($rf in $sorted){
    $abs = Join-Path $Root $rf
    if(-not (Test-Path -LiteralPath $abs -PathType Leaf)){ Die ("SHA256SUMS_MISSING_FILE: " + $rf) }
    $hex = Sha256HexFile $abs
    $rp = (Normalize-RelPath $rf)
    # format locked: "<hex><two spaces><path>"
    [void]$lines.Add(($hex + "  " + $rp))
  }
  $text = (($lines.ToArray()) -join "`n") + "`n"
  Write-Utf8NoBomLf $OutPath $text
}

function Verify-Packet-OptionA([string]$PacketRoot){
  $manifest = Join-Path $PacketRoot "manifest.json"
  $packetIdTxt = Join-Path $PacketRoot "packet_id.txt"
  $shaSums = Join-Path $PacketRoot "sha256sums.txt"
  if(-not (Test-Path -LiteralPath $manifest -PathType Leaf)){ Die "VERIFY_MISSING_manifest.json" }
  if(-not (Test-Path -LiteralPath $packetIdTxt -PathType Leaf)){ Die "VERIFY_MISSING_packet_id.txt" }
  if(-not (Test-Path -LiteralPath $shaSums -PathType Leaf)){ Die "VERIFY_MISSING_sha256sums.txt" }

  $manifestBytes = Read-Bytes $manifest
  $recomputed = Sha256HexBytes $manifestBytes
  $packetIdHex = ([System.Text.Encoding]::UTF8.GetString((Read-Bytes $packetIdTxt))).Replace("`r`n","`n").Replace("`r","`n").Trim()
  if($packetIdHex -ne $recomputed){ Die ("VERIFY_PACKET_ID_MISMATCH expected=" + $packetIdHex + " recomputed=" + $recomputed) }

  $sumText = ([System.Text.Encoding]::UTF8.GetString((Read-Bytes $shaSums))).Replace("`r`n","`n").Replace("`r","`n")
  $lines = @($sumText -split "`n") | Where-Object { $_ -and $_.Trim().Length -gt 0 }
  foreach($ln in $lines){
    # parse: hex + two spaces + path
    $m = [regex]::Match($ln, "^(?<hex>[0-9a-f]{64})  (?<path>.+)$")
    if(-not $m.Success){ Die ("VERIFY_SHA256SUMS_BAD_LINE: " + $ln) }
    $hex = $m.Groups["hex"].Value
    $rp = $m.Groups["path"].Value
    $abs = Join-Path $PacketRoot ($rp -replace "/","\\")
    if(-not (Test-Path -LiteralPath $abs -PathType Leaf)){ Die ("VERIFY_SHA256SUMS_MISSING: " + $rp) }
    $hx2 = Sha256HexFile $abs
    if($hx2 -ne $hex){ Die ("VERIFY_SHA256SUMS_MISMATCH: " + $rp) }
  }

  $res = New-Object System.Collections.Hashtable
  $res["ok"] = $true
  $res["packet_id"] = $packetIdHex
  $res["packet_constitution"] = "v1"
  $res["option"] = "A"
  $res["notes"] = @("sha256sums_ok","packet_id_ok")
  return $res
}

# --------------------------------------------------
# Build test_vectors/packet_constitution_v1 pack
# --------------------------------------------------
$TVRoot = Join-Path $RepoRoot "test_vectors\packet_constitution_v1"
$MinRoot = Join-Path $TVRoot "minimal_packet"
$Golden = Join-Path $TVRoot "golden"
Ensure-Dir $TVRoot; Ensure-Dir $MinRoot; Ensure-Dir $Golden
Ensure-Dir (Join-Path $MinRoot "payload")
Ensure-Dir (Join-Path $MinRoot "signatures")

# 1) Write payload/** first
$payloadHello = Join-Path $MinRoot "payload\hello.txt"
Write-Utf8NoBomLf $payloadHello "hello packet constitution v1"

# 2) Write manifest.json WITHOUT packet_id (Option A)
$manifestPath = Join-Path $MinRoot "manifest.json"
$manifestObj = New-Object System.Collections.Hashtable
$manifestObj["schema"] = "packet.manifest.v1"
$manifestObj["option"] = "A"
$manifestObj["producer"] = "test_vectors"
$manifestObj["payload"] = @("payload/hello.txt")
$manifestObj["signatures"] = @("signatures/manifest.sig")
Write-CanonJsonFile $manifestPath $manifestObj

# 3) Write detached signatures AFTER payload + manifest exist
$sigPath = Join-Path $MinRoot "signatures\manifest.sig"
Write-Utf8NoBomLf $sigPath "UNSIGNED_PLACEHOLDER_SIG_V1"

# 4) Compute PacketId from canonical bytes of manifest-without-id (manifest.json bytes on disk)
$packetIdHex = Sha256HexFile $manifestPath

# 5) Persist PacketId: packet_id.txt (Option A)
$pidPath = Join-Path $MinRoot "packet_id.txt"
Write-Utf8NoBomLf $pidPath $packetIdHex

# 6) Generate sha256sums.txt LAST (exclude itself)
$shaPath = Join-Path $MinRoot "sha256sums.txt"
$required = @(
  "manifest.json",
  "packet_id.txt",
  "payload\hello.txt",
  "signatures\manifest.sig"
)
Build-Sha256Sums $MinRoot $required $shaPath

# 7) Emit golden outputs (expected == actual)
$goldManifest = Join-Path $Golden "manifest_without_id.canonjson"
$goldPid = Join-Path $Golden "expected_packet_id.txt"
$goldSums = Join-Path $Golden "expected_sha256sums.txt"
$goldVerify = Join-Path $Golden "expected_verify_result.json"

[System.IO.File]::WriteAllBytes($goldManifest, (Read-Bytes $manifestPath))
Write-Utf8NoBomLf $goldPid $packetIdHex
[System.IO.File]::WriteAllBytes($goldSums, (Read-Bytes $shaPath))

$verifyObj = Verify-Packet-OptionA $MinRoot
# deterministic JSON of verify result
Write-CanonJsonFile $goldVerify $verifyObj

Write-Host ("TV_OK: " + $TVRoot) -ForegroundColor Green
Write-Host ("MIN_PACKET_OK: " + $MinRoot) -ForegroundColor Green
Write-Host ("PACKET_ID: " + $packetIdHex) -ForegroundColor Cyan

# Deterministic re-verify (proves the verify path matches the golden artifacts)
$v2 = Verify-Packet-OptionA $MinRoot
Write-Host ("VERIFY_OK: packet_id=" + $v2["packet_id"]) -ForegroundColor Green

