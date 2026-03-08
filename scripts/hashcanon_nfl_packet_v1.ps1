param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PacketRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$m){ throw ("HASHCANON_NFL_PACKET_FAIL:" + $m) }

function Utf8NoBom(){
  New-Object System.Text.UTF8Encoding($false)
}

function NormalizeLf([string]$t){
  if($null -eq $t){ return "" }
  $u = ($t -replace "`r`n","`n") -replace "`r","`n"
  if(-not $u.EndsWith("`n")){ $u += "`n" }
  return $u
}

function WriteUtf8NoBomLfText([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $u = NormalizeLf $Text
  [System.IO.File]::WriteAllBytes($Path,(Utf8NoBom).GetBytes($u))
}

function Sha256HexFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Fail ("HASH_MISSING_FILE:" + $Path)
  }
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function RelPath([string]$Root,[string]$Full){
  $bs = [char]92
  $slash = [char]47

  $r = (Resolve-Path -LiteralPath $Root).Path.TrimEnd($bs)
  $f = (Resolve-Path -LiteralPath $Full).Path

  if($f.Substring(0,$r.Length).ToLowerInvariant() -ne $r.ToLowerInvariant()){
    Fail ("REL_OUTSIDE_ROOT:" + $f)
  }

  $rel = $f.Substring($r.Length).TrimStart($bs)
  return $rel.Replace($bs,$slash)
}

function RequireNoTraversal([string]$rel){
  if($rel -match '(^|/)\.\.($|/)'){ Fail ("TRAVERSAL_PATH:" + $rel) }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PacketRoot = (Resolve-Path -LiteralPath $PacketRoot).Path

if(-not (Test-Path -LiteralPath $PacketRoot -PathType Container)){
  Fail ("MISSING_PACKET_ROOT:" + $PacketRoot)
}

$Files = Get-ChildItem -LiteralPath $PacketRoot -Recurse -File | Sort-Object FullName

if($Files.Count -lt 1){
  Fail "NO_PACKET_FILES"
}

$Rows = New-Object System.Collections.Generic.List[string]
$Included = New-Object System.Collections.Generic.List[string]

foreach($f in $Files){

  $rel = RelPath $PacketRoot $f.FullName
  RequireNoTraversal $rel

  $hash = Sha256HexFile $f.FullName

  $Included.Add($rel) | Out-Null
  $Rows.Add(($hash + "  " + $rel)) | Out-Null
}

$CanonText = (($Rows.ToArray() -join "`n") + "`n")

$tmp = Join-Path $env:TEMP ("hashcanon_tmp_" + [guid]::NewGuid().ToString("D") + ".txt")

WriteUtf8NoBomLfText $tmp $CanonText

$Digest = Sha256HexFile $tmp

Remove-Item -LiteralPath $tmp -Force

$result = [ordered]@{
  schema = "hashcanon.nfl.packet.v1"
  ok = $true
  packet_root = $PacketRoot
  included_file_count = $Included.Count
  digest_sha256 = $Digest
  included_files = $Included.ToArray()
}

$result

Write-Output "HASHCANON_NFL_PACKET_OK"
Write-Output ("DIGEST_SHA256=" + $Digest)
Write-Output ("INCLUDED_FILE_COUNT=" + $Included.Count)