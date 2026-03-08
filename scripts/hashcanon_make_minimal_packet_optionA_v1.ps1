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
$root = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"
EnsureDir $root

$manifest = '{"schema":"hashcanon.manifest.optionA.v1","payload_rel":"payload/hello.txt"}'
$manifest = $manifest.Trim()

$enc = New-Object System.Text.UTF8Encoding($false)

# Write to a temp manifest first so PacketId is derived from final on-disk bytes.
$tmpDir = Join-Path $root "_tmp_build"
if(Test-Path -LiteralPath $tmpDir -PathType Container){
  Remove-Item -LiteralPath $tmpDir -Recurse -Force
}
EnsureDir $tmpDir

$tmpManifestPath = Join-Path $tmpDir "manifest.json"
Write-Utf8NoBomLf $tmpManifestPath $manifest

$mBytes = [System.IO.File]::ReadAllBytes($tmpManifestPath)
$packetId = Sha256HexBytes $mBytes

$pktDir = Join-Path $root $packetId
if(Test-Path -LiteralPath $pktDir -PathType Container){
  Remove-Item -LiteralPath $pktDir -Recurse -Force
}
EnsureDir $pktDir
EnsureDir (Join-Path $pktDir "payload")

$manifestPath = Join-Path $pktDir "manifest.json"
$packetIdPath = Join-Path $pktDir "packet_id.txt"
$sha256sumsPath = Join-Path $pktDir "sha256sums.txt"
$helloPath = Join-Path $pktDir "payload\hello.txt"

# Move/copy final files into packet dir.
Copy-Item -LiteralPath $tmpManifestPath -Destination $manifestPath -Force
Write-Utf8NoBomLf $packetIdPath $packetId
Write-Utf8NoBomLf $helloPath "hello"

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add((Sha256HexFile $manifestPath) + "  manifest.json")
[void]$lines.Add((Sha256HexFile $packetIdPath) + "  packet_id.txt")
[void]$lines.Add((Sha256HexFile $helloPath) + "  payload/hello.txt")
$sumTxt = (@($lines.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $sha256sumsPath $sumTxt

Remove-Item -LiteralPath $tmpDir -Recurse -Force

Write-Host ("MINIMAL_PACKET_ID=" + $packetId) -ForegroundColor Green
Write-Host ("PACKET_DIR=" + $pktDir) -ForegroundColor Green
