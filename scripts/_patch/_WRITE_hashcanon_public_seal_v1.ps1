param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $t = $Text.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("PARSE_GATE_MISSING: " + $Path) }
  $t=$null; $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and $e.Count -gt 0){ $x=$e[0]; throw ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message) }
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

# --- dirs ---
$Docs = Join-Path $RepoRoot "docs"
$Schemas = Join-Path $RepoRoot "schemas"
$Scripts = Join-Path $RepoRoot "scripts"
$Workflows = Join-Path $RepoRoot ".github\workflows"
$TVRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet"
EnsureDir $Docs
EnsureDir $Schemas
EnsureDir $Scripts
EnsureDir $Workflows
EnsureDir $TVRoot

# =========================================================
# 1) docs/HASHCANON_SPEC_v1.md
# =========================================================
$specPath = Join-Path $Docs "HASHCANON_SPEC_v1.md"
$spec = @(
  "# HashCanon v1 — Spec"
  ""
  "- UTF-8 **no BOM**"
  "- Line endings: **LF**"
  "- Canonical JSON: stable property ordering, no insignificant whitespace, stable escaping"
  ""
  "## Option A — PacketId law"
  "- `manifest.json` MUST NOT contain `packet_id`."
  "- PacketId = SHA-256(bytes(manifest.json))."
  "- `packet_id.txt` stores PacketId as 64 hex lowercase."
  "- `sha256sums.txt` is generated **last** over final on-disk bytes of required files."
  ""
  "## Required files (minimum)"
  "- `manifest.json` (canonical JSON bytes)"
  "- `packet_id.txt` (PacketId)"
  "- `sha256sums.txt` (hash coverage)"
  "- `payload/**` (application payload)"
  ""
  "## Verification invariants"
  "- Verifier MUST NOT mutate packet contents."
  "- Recompute PacketId from `manifest.json` bytes and compare to `packet_id.txt` and (if applicable) directory name."
  "- Verify `sha256sums.txt` entries match on-disk bytes; reject missing/extra entries."
  "- Reject traversal or absolute paths in sha256sums entries."
  ""
  "## Tier-0 selftest"
  "- Tier-0 is DONE when a clean machine can run the unified selftest runner and obtain deterministic PASS/FAIL plus an auditable evidence pack (hashes + logs)."
) -join "`n"
Write-Utf8NoBomLf $specPath $spec
Write-Host ("WROTE: " + $specPath) -ForegroundColor Green

# =========================================================
# 2) docs/DEFINITION_OF_DONE_TIER0.md
# =========================================================
$dodPath = Join-Path $Docs "DEFINITION_OF_DONE_TIER0.md"
$dod = @(
  "# HashCanon Tier-0 — Definition of Done"
  ""
  "Tier-0 is DONE when all of the following are true:"
  ""
  "- `scripts/_RUN_hashcanon_tier0_selftest_v1.ps1` runs GREEN under PowerShell 5.1 StrictMode Latest."
  "- `scripts/_selftest_hashcanon_optionA_v1.ps1` runs GREEN and emits a selftest receipt."
  "- `schemas/hashcanon.selftest_receipt.v1.json` and `schemas/hashcanon.tier0_evidence_pack.v1.json` exist and validate the emitted objects structurally."
  "- `scripts/hashcanon_verify_packet_optionA_v1.ps1` verifies the minimal vector deterministically."
  "- `scripts/_selftest_hashcanon_negative_suite_v1.ps1` runs GREEN by asserting deterministic FAIL on ≥3 negative vectors."
  "- Golden vector `test_vectors/hashcanon_optionA/minimal_packet` exists and can be regenerated deterministically."
  "- GitHub Actions runs Tier-0 selftest on push/PR and is GREEN."
) -join "`n"
Write-Utf8NoBomLf $dodPath $dod
Write-Host ("WROTE: " + $dodPath) -ForegroundColor Green

# =========================================================
# 3) docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md
# =========================================================
$wbsPath = Join-Path $Docs "WBS_HASHCANON_PROGRESS_LEDGER_v1.md"
$wbs = @(
  "# HashCanon — WBS / Progress Ledger v1"
  ""
  "## Completed"
  "- [x] Tier-0 unified runner (`scripts/_RUN_hashcanon_tier0_selftest_v1.ps1`)"
  "- [x] Positive selftest (`scripts/_selftest_hashcanon_optionA_v1.ps1`)"
  "- [x] Selftest receipt schema (`schemas/hashcanon.selftest_receipt.v1.json`)"
  "- [x] Evidence pack emission (`hashcanon.tier0_evidence_pack.v1` object emitted as NDJSON)"
  ""
  "## In progress / next"
  "- [ ] Tier-0 evidence pack schema (`schemas/hashcanon.tier0_evidence_pack.v1.json`)"
  "- [ ] Minimal Option A packet golden vector under `test_vectors/`"
  "- [ ] Standalone verifier script (Option A) + negative suite runner"
  "- [ ] GitHub Actions Tier-0 CI"
  ""
  "## Tier-0 seal checklist"
  "- [ ] Spec present"
  "- [ ] DoD present"
  "- [ ] WBS present"
  "- [ ] Positive selftest GREEN"
  "- [ ] Negative suite GREEN"
  "- [ ] CI GREEN"
) -join "`n"
Write-Utf8NoBomLf $wbsPath $wbs
Write-Host ("WROTE: " + $wbsPath) -ForegroundColor Green

# =========================================================
# 4) schemas/hashcanon.tier0_evidence_pack.v1.json
# =========================================================
$evSchemaPath = Join-Path $Schemas "hashcanon.tier0_evidence_pack.v1.json"
$evSchema = @(
  "{"
  "  `"$schema`": `"https://json-schema.org/draft/2020-12/schema`","
  "  `"$id`": `"hashcanon.tier0_evidence_pack.v1`","
  "  `"title`": `"HashCanon Tier-0 Evidence Pack v1`","
  "  `"type`": `"object`","
  "  `"additionalProperties`": false,"
  "  `"required`": [ `"schema`", `"utc`", `"repo_root`", `"ok`", `"artifacts`" ],"
  "  `"properties`": {"
  "    `"schema`": { `"const`": `"hashcanon.tier0_evidence_pack.v1`" },"
  "    `"utc`": { `"type`": `"string`", `"minLength`": 1 },"
  "    `"repo_root`": { `"type`": `"string`", `"minLength`": 1 },"
  "    `"ok`": { `"type`": `"boolean`" },"
  "    `"artifacts`": {"
  "      `"type`": `"object`","
  "      `"additionalProperties`": false,"
  "      `"required`": ["
  "        `"tier0_runner`","
  "        `"selftest`","
  "        `"schema_selftest_receipt`","
  "        `"tier0_stdout`","
  "        `"tier0_stderr`","
  "        `"selftest_receipt`","
  "        `"run_stdout`","
  "        `"run_stderr`"
  "      ],"
  "      `"properties`": {"
  "        `"tier0_runner`": { `"$ref`": `"#/$defs/artifactRel`" },"
  "        `"selftest`": { `"$ref`": `"#/$defs/artifactRel`" },"
  "        `"schema_selftest_receipt`": { `"$ref`": `"#/$defs/artifactRel`" },"
  "        `"tier0_stdout`": { `"$ref`": `"#/$defs/artifactRel`" },"
  "        `"tier0_stderr`": { `"$ref`": `"#/$defs/artifactRel`" },"
  "        `"selftest_receipt`": { `"$ref`": `"#/$defs/artifactAbsOrRel`" },"
  "        `"run_stdout`": { `"$ref`": `"#/$defs/artifactAbsOrRel`" },"
  "        `"run_stderr`": { `"$ref`": `"#/$defs/artifactAbsOrRel`" }
  "      }"
  "    }"
  "  },"
  "  `"$defs`": {"
  "    `"artifactRel`": {"
  "      `"type`": `"object`","
  "      `"additionalProperties`": false,"
  "      `"required`": [ `"path`", `"sha256`" ],"
  "      `"properties`": {"
  "        `"path`": { `"type`": `"string`", `"minLength`": 1 },"
  "        `"sha256`": { `"type`": `"string`", `"pattern`": `"^[0-9a-f]{64}$`" }"
  "      }"
  "    },"
  "    `"artifactAbsOrRel`": {"
  "      `"type`": `"object`","
  "      `"additionalProperties`": false,"
  "      `"required`": [ `"path`", `"sha256`" ],"
  "      `"properties`": {"
  "        `"path`": { `"type`": `"string`", `"minLength`": 1 },"
  "        `"sha256`": { `"type`": `"string`", `"pattern`": `"^[0-9a-f]{64}$`" }"
  "      }"
  "    }"
  "  }"
  "}"
) -join "`n"
Write-Utf8NoBomLf $evSchemaPath $evSchema
Write-Host ("WROTE: " + $evSchemaPath) -ForegroundColor Green

# =========================================================
# 5) Minimal vector README + deterministic generator
# =========================================================
$tvReadme = Join-Path $TVRoot "README.md"
$tvR = @(
  "# HashCanon Option A — Minimal Packet Vector"
  ""
  "This folder contains a deterministic minimal HashCanon Option A packet vector."
  ""
  "## Layout"
  "- `packet/<PacketId>/manifest.json` (canonical JSON, no `packet_id` field)"
  "- `packet/<PacketId>/packet_id.txt` (PacketId = SHA-256(manifest.json bytes))"
  "- `packet/<PacketId>/sha256sums.txt` (hash coverage for required files + payload)"
  "- `packet/<PacketId>/payload/hello.txt`"
  ""
  "## Generate/re-generate"
  "```powershell"
  "$PSExe = Join-Path $env:WINDIR \"System32\\WindowsPowerShell\\v1.0\\powershell.exe\""
  "& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 -RepoRoot . | Out-Host"
  "```"
  ""
  "## Verify"
  "```powershell"
  "& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_verify_packet_optionA_v1.ps1 -PacketDir test_vectors/hashcanon_optionA/minimal_packet/packet/<PacketId> | Out-Host"
  "```"
) -join "`n"
Write-Utf8NoBomLf $tvReadme $tvR
Write-Host ("WROTE: " + $tvReadme) -ForegroundColor Green

# scripts/hashcanon_make_minimal_packet_optionA_v1.ps1
$mkPath = Join-Path $Scripts "hashcanon_make_minimal_packet_optionA_v1.ps1"
$mk = @(
  "param([Parameter(Mandatory=$true)][string]$RepoRoot)"
  "$ErrorActionPreference=`"Stop`""
  "Set-StrictMode -Version Latest"
  ""
  "function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ throw `"EnsureDir: empty path`" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }"
  "function Write-Utf8NoBomLf([string]$Path,[string]$Text){ $dir=Split-Path -Parent $Path; if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }; $t=$Text.Replace(`"`r`n`",`"`n`").Replace(`"`r`",`"`n`"); if(-not $t.EndsWith(`"`n`")){ $t += `"`n`" }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t)) }"
  "function Sha256HexBytes([byte[]]$b){ $sha=[System.Security.Cryptography.SHA256]::Create(); try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }; ($h | ForEach-Object { $_.ToString(`"x2`") }) -join `"`" }"
  "function Sha256HexFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw (`"SHA256_MISSING_FILE: `" + $Path) }; $b=[System.IO.File]::ReadAllBytes($Path); Sha256HexBytes $b }"
  ""
  "$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path"
  "$root = Join-Path $RepoRoot `"test_vectors\hashcanon_optionA\minimal_packet\packet`""
  "EnsureDir $root"
  ""
  "# Deterministic minimal payload"
  "$payloadRel = `"payload/hello.txt`""
  ""
  "# Minimal canonical manifest JSON (no packet_id field)"
  "$manifest = `"{`"schema`":`"hashcanon.manifest.optionA.v1`",`"payload_rel`":`"$payloadRel`"} `""
  "$manifest = $manifest.Trim()"
  "$enc = New-Object System.Text.UTF8Encoding($false)"
  "$manifestBytes = $enc.GetBytes(($manifest.Replace(`"`r`n`",`"`n`").Replace(`"`r`",`"`n`")))"
  "$packetId = Sha256HexBytes $manifestBytes"
  ""
  "$pktDir = Join-Path $root $packetId"
  "if(Test-Path -LiteralPath $pktDir -PathType Container){ Remove-Item -LiteralPath $pktDir -Recurse -Force }"
  "EnsureDir $pktDir"
  "EnsureDir (Join-Path $pktDir `"payload`")"
  ""
  "$manifestPath = Join-Path $pktDir `"manifest.json`""
  "$pidPath = Join-Path $pktDir `"packet_id.txt`""
  "$sumPath = Join-Path $pktDir `"sha256sums.txt`""
  "$helloPath = Join-Path $pktDir `"payload\hello.txt`""
  ""
  "Write-Utf8NoBomLf $manifestPath $manifest"
  "Write-Utf8NoBomLf $pidPath $packetId"
  "Write-Utf8NoBomLf $helloPath `"hello`""
  ""
  "# sha256sums over final on-disk bytes (exclude sha256sums itself)"
  "$lines = New-Object System.Collections.Generic.List[string]"
  "[void]$lines.Add((Sha256HexFile $manifestPath) + `"  manifest.json`")"
  "[void]$lines.Add((Sha256HexFile $pidPath) + `"  packet_id.txt`")"
  "[void]$lines.Add((Sha256HexFile $helloPath) + `"  payload/hello.txt`")"
  "$sumTxt = (@($lines.ToArray()) -join `"`n`") + `"`n`""
  "Write-Utf8NoBomLf $sumPath $sumTxt"
  ""
  "Write-Host `"MINIMAL_PACKET_ID=`" + $packetId -ForegroundColor Green"
  "Write-Host (`"PACKET_DIR=`" + $pktDir) -ForegroundColor Green"
) -join "`n"
Write-Utf8NoBomLf $mkPath $mk
Parse-GateFile $mkPath
Write-Host ("WROTE+PARSE_OK: " + $mkPath) -ForegroundColor Green

# =========================================================
# 6) scripts/hashcanon_verify_packet_optionA_v1.ps1 + negative suite
# =========================================================
$verPath = Join-Path $Scripts "hashcanon_verify_packet_optionA_v1.ps1"
$ver = @(
  "param([Parameter(Mandatory=$true)][string]$PacketDir)"
  "$ErrorActionPreference=`"Stop`""
  "Set-StrictMode -Version Latest"
  ""
  "function Sha256HexBytes([byte[]]$b){ $sha=[System.Security.Cryptography.SHA256]::Create(); try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }; ($h | ForEach-Object { $_.ToString(`"x2`") }) -join `"`" }"
  "function Sha256HexFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw (`"VERIFY_MISSING_FILE: `" + $Path) }; $b=[System.IO.File]::ReadAllBytes($Path); Sha256HexBytes $b }"
  ""
  "$PacketDir = (Resolve-Path -LiteralPath $PacketDir).Path"
  "$manifest = Join-Path $PacketDir `"manifest.json`""
  "$pid = Join-Path $PacketDir `"packet_id.txt`""
  "$sums = Join-Path $PacketDir `"sha256sums.txt`""
  "if(-not (Test-Path -LiteralPath $manifest -PathType Leaf)){ throw `"HC_VERIFY_MISSING_MANIFEST`" }"
  "if(-not (Test-Path -LiteralPath $pid -PathType Leaf)){ throw `"HC_VERIFY_MISSING_PACKET_ID`" }"
  "if(-not (Test-Path -LiteralPath $sums -PathType Leaf)){ throw `"HC_VERIFY_MISSING_SHA256SUMS`" }"
  ""
  "$mBytes = [System.IO.File]::ReadAllBytes($manifest)"
  "$mText = (New-Object System.Text.UTF8Encoding($false)).GetString($mBytes)"
  "if($mText -match `"(?:^|[^a-zA-Z0-9_])packet_id(?:[^a-zA-Z0-9_]|$)`"){ throw `"HC_VERIFY_MANIFEST_CONTAINS_PACKET_ID_FIELD`" }"
  "$expected = Sha256HexBytes $mBytes"
  "$pidTxt = ((New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($pid))).Trim()"
  "if($pidTxt -ne $expected){ throw `"HC_VERIFY_PACKET_ID_MISMATCH`" }"
  ""
  "$dirName = (Split-Path -Leaf $PacketDir)"
  "if($dirName -match `"^[0-9a-f]{64}$`" -and $dirName -ne $expected){ throw `"HC_VERIFY_DIRNAME_PACKETID_MISMATCH`" }"
  ""
  "# sha256sums coverage: each line is `<sha>  <relpath>`; reject traversal/absolute"
  "$sumText = (New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($sums))"
  "$lines = @(@($sumText -split `"`n`") | Where-Object { $_.Trim().Length -gt 0 })"
  "if($lines.Count -lt 1){ throw `"HC_VERIFY_SHA256SUMS_EMPTY`" }"
  ""
  "$seen = New-Object System.Collections.Generic.HashSet[string]"
  "foreach($ln in $lines){"
  "  $m = [regex]::Match($ln, `"^(?<h>[0-9a-f]{64})\s\s(?<p>.+)$`")"
  "  if(-not $m.Success){ throw `"HC_VERIFY_SHA256SUMS_BAD_LINE`" }"
  "  $h = $m.Groups[`"h`"].Value"
  "  $rp = $m.Groups[`"p`"].Value.Trim()"
  "  if([string]::IsNullOrWhiteSpace($rp)){ throw `"HC_VERIFY_SHA256SUMS_EMPTY_PATH`" }"
  "  if($rp -match `"^[A-Za-z]:\\`" -or $rp.StartsWith(`"/`") -or $rp.StartsWith(`"\\`")){ throw `"HC_VERIFY_SHA256SUMS_ABSOLUTE_PATH`" }"
  "  if($rp.Contains(`"..\`") -or $rp.Contains(`"../`")){ throw `"HC_VERIFY_SHA256SUMS_TRAVERSAL`" }"
  "  $rp = $rp.Replace(`"\`",`"/`")"
  "  $ap = Join-Path $PacketDir ($rp.Replace(`"/`", [System.IO.Path]::DirectorySeparatorChar))"
  "  if(-not (Test-Path -LiteralPath $ap -PathType Leaf)){ throw `"HC_VERIFY_SHA256SUMS_MISSING_FILE`" }"
  "  $actual = Sha256HexFile $ap"
  "  if($actual -ne $h){ throw `"HC_VERIFY_SHA256_MISMATCH`" }"
  "  [void]$seen.Add($rp)"
  "}"
  ""
  "# Require minimal required files to be covered"
  "if(-not $seen.Contains(`"manifest.json`")){ throw `"HC_VERIFY_SHA256SUMS_MISSING_MANIFEST_ENTRY`" }"
  "if(-not $seen.Contains(`"packet_id.txt`")){ throw `"HC_VERIFY_SHA256SUMS_MISSING_PACKETID_ENTRY`" }"
  ""
  "Write-Host `"HC_VERIFY_OK`" -ForegroundColor Green"
  "Write-Host (`"PACKET_ID=`" + $expected) -ForegroundColor Green"
) -join "`n"
Write-Utf8NoBomLf $verPath $ver
Parse-GateFile $verPath
Write-Host ("WROTE+PARSE_OK: " + $verPath) -ForegroundColor Green

$negPath = Join-Path $Scripts "_selftest_hashcanon_negative_suite_v1.ps1"
$neg = @(
  "param([Parameter(Mandatory=$true)][string]$RepoRoot)"
  "$ErrorActionPreference=`"Stop`""
  "Set-StrictMode -Version Latest"
  ""
  "function EnsureDir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ throw `"EnsureDir: empty path`" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }"
  "function CopyTree([string]$src,[string]$dst){ if(Test-Path -LiteralPath $dst -PathType Container){ Remove-Item -LiteralPath $dst -Recurse -Force }; New-Item -ItemType Directory -Force -Path $dst | Out-Null; Copy-Item -LiteralPath (Join-Path $src `"*`") -Destination $dst -Recurse -Force }"
  ""
  "$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path"
  "$PSExe = Join-Path $env:WINDIR `"System32\WindowsPowerShell\v1.0\powershell.exe`""
  "if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ throw (`"MISSING_POWERSHELL_EXE: `" + $PSExe) }"
  "$Verifier = Join-Path $RepoRoot `"scripts\hashcanon_verify_packet_optionA_v1.ps1`""
  "if(-not (Test-Path -LiteralPath $Verifier -PathType Leaf)){ throw `"NEG_MISSING_VERIFIER`" }"
  ""
  "# Ensure minimal vector exists (generate)"
  "$Mk = Join-Path $RepoRoot `"scripts\hashcanon_make_minimal_packet_optionA_v1.ps1`""
  "if(-not (Test-Path -LiteralPath $Mk -PathType Leaf)){ throw `"NEG_MISSING_MINIMAL_GENERATOR`" }"
  "$p0 = Start-Process -FilePath $PSExe -ArgumentList @(`"-NoProfile`",`"-NonInteractive`",`"-ExecutionPolicy`",`"Bypass`",`"-File`",$Mk,`"-RepoRoot`",$RepoRoot) -Wait -PassThru"
  "if($p0.ExitCode -ne 0){ throw (`"NEG_MINIMAL_GENERATE_FAILED exit_code=`" + $p0.ExitCode) }"
  ""
  "$pktRoot = Join-Path $RepoRoot `"test_vectors\hashcanon_optionA\minimal_packet\packet`""
  "$pktDir = Get-ChildItem -LiteralPath $pktRoot -Directory | Select-Object -First 1"
  "if(-not $pktDir){ throw `"NEG_NO_PACKET_DIR_FOUND`" }"
  "$good = $pktDir.FullName"
  ""
  "$stamp = [DateTime]::UtcNow.ToString(`"yyyyMMdd_HHmmss`")"
  "$scratch = Join-Path $RepoRoot `"scripts\_scratch`""
  "EnsureDir $scratch"
  "$root = Join-Path $scratch (`"neg_suite_`" + $stamp)"
  "EnsureDir $root"
  ""
  "function RunExpectFail([string]$case,[string]$dir,[string]$token){"
  "  $out = Join-Path $root (`"out_`" + $case + `".log`")"
  "  $err = Join-Path $root (`"err_`" + $case + `".log`")"
  "  $p = Start-Process -FilePath $PSExe -ArgumentList @(`"-NoProfile`",`"-NonInteractive`",`"-ExecutionPolicy`",`"Bypass`",`"-File`",$Verifier,`"-PacketDir`",$dir) -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err"
  "  $errTxt = [System.IO.File]::ReadAllText($err,(New-Object System.Text.UTF8Encoding($false)))"
  "  if($p.ExitCode -eq 0){ throw (`"NEG_EXPECT_FAIL_BUT_OK: `"+$case) }"
  "  if(-not ($errTxt -like (`"*`"+$token+`"*`"))){ throw (`"NEG_MISSING_TOKEN: `"+$case+`" token=`"+$token) }"
  "  Write-Host (`"NEG_OK: `"+$case) -ForegroundColor Green"
  "}"
  ""
  "# Case 1: tamper sha256sums"
  "$c1 = Join-Path $root `"case1_tamper_sha256sums`""
  "CopyTree $good $c1"
  "$sum = Join-Path $c1 `"sha256sums.txt`""
  "$txt = [System.IO.File]::ReadAllText($sum,(New-Object System.Text.UTF8Encoding($false)))"
  "$txt2 = $txt.Replace(`"a`",`"b`")"
  "[System.IO.File]::WriteAllText($sum,$txt2,(New-Object System.Text.UTF8Encoding($false)))"
  "RunExpectFail `"case1`" $c1 `"HC_VERIFY_SHA256_MISMATCH`""
  ""
  "# Case 2: missing manifest.json"
  "$c2 = Join-Path $root `"case2_missing_manifest`""
  "CopyTree $good $c2"
  "Remove-Item -LiteralPath (Join-Path $c2 `"manifest.json`") -Force"
  "RunExpectFail `"case2`" $c2 `"HC_VERIFY_MISSING_MANIFEST`""
  ""
  "# Case 3: packet_id mismatch"
  "$c3 = Join-Path $root `"case3_packetid_mismatch`""
  "CopyTree $good $c3"
  "[System.IO.File]::WriteAllText((Join-Path $c3 `"packet_id.txt`"), (`"0`"*64)+`"`n`",(New-Object System.Text.UTF8Encoding($false)))"
  "RunExpectFail `"case3`" $c3 `"HC_VERIFY_PACKET_ID_MISMATCH`""
  ""
  "Write-Host `"HASHCANON_NEGATIVE_SUITE_OK`" -ForegroundColor Green"
) -join "`n"
Write-Utf8NoBomLf $negPath $neg
Parse-GateFile $negPath
Write-Host ("WROTE+PARSE_OK: " + $negPath) -ForegroundColor Green

# =========================================================
# 7) GitHub Actions workflow
# =========================================================
$wf = Join-Path $Workflows "hashcanon_tier0.yml"
$wfText = @(
  "name: hashcanon-tier0"
  "on:"
  "  push:"
  "    branches: [ `\"main`\" ]"
  "  pull_request:"
  "    branches: [ `\"main`\" ]"
  ""
  "jobs:"
  "  tier0:"
  "    runs-on: windows-latest"
  "    steps:"
  "      - uses: actions/checkout@v4"
  "      - name: Run Tier-0 unified runner"
  "        shell: pwsh"
  "        run: |"
  "          $ErrorActionPreference = `\"Stop`\""
  "          $RepoRoot = (Resolve-Path -LiteralPath `".`").Path"
  "          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 -RepoRoot $RepoRoot"
  "      - name: Run negative suite"
  "        shell: pwsh"
  "        run: |"
  "          $ErrorActionPreference = `\"Stop`\""
  "          $RepoRoot = (Resolve-Path -LiteralPath `".`").Path"
  "          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_selftest_hashcanon_negative_suite_v1.ps1 -RepoRoot $RepoRoot"
) -join "`n"
Write-Utf8NoBomLf $wf $wfText
Write-Host ("WROTE: " + $wf) -ForegroundColor Green

# =========================================================
# Generate minimal packet vector now
# =========================================================
$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
$p = Start-Process -FilePath $PSExe -ArgumentList @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$mkPath,"-RepoRoot",$RepoRoot) -Wait -PassThru
if($p.ExitCode -ne 0){ throw ("MINIMAL_VECTOR_GENERATE_FAILED exit_code=" + $p.ExitCode) }
Write-Host "MINIMAL_VECTOR_GENERATED_OK" -ForegroundColor Green

Write-Host "HASHCANON_PUBLIC_SEAL_FILES_WRITTEN_OK" -ForegroundColor Green
