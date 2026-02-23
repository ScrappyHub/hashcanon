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

function Parse-GateFile([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("PARSE_GATE_MISSING: " + $Path) }
  $t=$null
  $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and $e.Count -gt 0){
    $x=$e[0]
    throw ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$Docs = Join-Path $RepoRoot "docs"
$Schemas = Join-Path $RepoRoot "schemas"
$Scripts = Join-Path $RepoRoot "scripts"
$Workflows = Join-Path $RepoRoot ".github\workflows"
$TVRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet"
$TVPacketRoot = Join-Path $TVRoot "packet"

EnsureDir $Docs
EnsureDir $Schemas
EnsureDir $Scripts
EnsureDir $Workflows
EnsureDir $TVRoot
EnsureDir $TVPacketRoot

# =========================================================
# docs/HASHCANON_SPEC_v1.md
# =========================================================
$specPath = Join-Path $Docs "HASHCANON_SPEC_v1.md"
$specLines = @(
  "# HashCanon v1 — Spec",
  "",
  "HashCanon v1 is the ecosystem universal deterministic transport physics layer. It defines canonical bytes, PacketId derivation, finalization ordering, sha256sums coverage rules, and verifier non-mutation invariants for directory-bundle packets (Option A default).",
  "",
  "## Canonical bytes",
  "- UTF-8 (no BOM)",
  "- Line endings: LF",
  "- Canonical JSON: stable property ordering, no insignificant whitespace, stable escaping",
  "",
  "## Option A — PacketId law",
  "- manifest.json MUST NOT contain packet_id.",
  "- PacketId = SHA-256(bytes(manifest.json)).",
  "- packet_id.txt stores PacketId as 64 lowercase hex.",
  "- sha256sums.txt is generated last over final on-disk bytes of required files (and payload files).",
  "",
  "## Required files (minimum)",
  "- manifest.json (canonical JSON bytes)",
  "- packet_id.txt (PacketId)",
  "- sha256sums.txt (hash coverage)",
  "- payload/** (application payload)",
  "",
  "## Verification invariants",
  "- Verifier MUST NOT mutate packet contents.",
  "- Recompute PacketId from manifest.json bytes and compare to packet_id.txt and (if applicable) directory name.",
  "- Verify sha256sums.txt entries match on-disk bytes; reject missing/extra entries.",
  "- Reject traversal or absolute paths in sha256sums entries.",
  "",
  "## Tier-0 selftest",
  "Tier-0 is DONE when a clean machine can run the unified Tier-0 selftest runner and obtain deterministic PASS/FAIL plus an auditable evidence pack (hashes + logs)."
)
Write-Utf8NoBomLf $specPath ((@($specLines) -join "`n") + "`n")

# =========================================================
# docs/DEFINITION_OF_DONE_TIER0.md
# =========================================================
$dodPath = Join-Path $Docs "DEFINITION_OF_DONE_TIER0.md"
$dodLines = @(
  "# HashCanon Tier-0 — Definition of Done",
  "",
  "Tier-0 is DONE when all of the following are true:",
  "",
  "- scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 runs GREEN under PowerShell 5.1 StrictMode Latest.",
  "- scripts/_selftest_hashcanon_optionA_v1.ps1 runs GREEN and emits a deterministic receipt artifact.",
  "- schemas/hashcanon.tier0_evidence_pack.v1.json exists and emitted objects match structurally.",
  "- scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 deterministically regenerates the minimal vector.",
  "- scripts/hashcanon_verify_packet_optionA_v1.ps1 verifies the minimal vector deterministically (non-mutating).",
  "- scripts/_selftest_hashcanon_negative_suite_v1.ps1 runs GREEN by asserting deterministic FAIL on >= 3 negative cases.",
  "- GitHub Actions runs Tier-0 + negative suite on push/PR and is GREEN."
)
Write-Utf8NoBomLf $dodPath ((@($dodLines) -join "`n") + "`n")

# =========================================================
# docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md
# =========================================================
$wbsPath = Join-Path $Docs "WBS_HASHCANON_PROGRESS_LEDGER_v1.md"
$wbsLines = @(
  "# HashCanon — WBS / Progress Ledger v1",
  "",
  "## Tier-0 seal items",
  "- [ ] Spec (docs/HASHCANON_SPEC_v1.md)",
  "- [ ] DoD (docs/DEFINITION_OF_DONE_TIER0.md)",
  "- [ ] WBS (docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md)",
  "- [ ] Minimal vector generator (scripts/hashcanon_make_minimal_packet_optionA_v1.ps1)",
  "- [ ] Verifier (scripts/hashcanon_verify_packet_optionA_v1.ps1)",
  "- [ ] Positive selftest (scripts/_selftest_hashcanon_optionA_v1.ps1)",
  "- [ ] Negative suite (scripts/_selftest_hashcanon_negative_suite_v1.ps1)",
  "- [ ] Tier-0 unified runner (scripts/_RUN_hashcanon_tier0_selftest_v1.ps1)",
  "- [ ] CI workflow (.github/workflows/hashcanon_tier0.yml)",
  "",
  "## Completed",
  "- [x] Deterministic write discipline (UTF-8 no BOM + LF)",
  "- [x] Parse-gate discipline (runner + scripts)"
)
Write-Utf8NoBomLf $wbsPath ((@($wbsLines) -join "`n") + "`n")

# =========================================================
# schemas/hashcanon.tier0_evidence_pack.v1.json
# =========================================================
$evSchemaPath = Join-Path $Schemas "hashcanon.tier0_evidence_pack.v1.json"
$evSchemaLines = @(
  "{",
  "  ""$schema"": ""https://json-schema.org/draft/2020-12/schema"",",
  "  ""$id"": ""hashcanon.tier0_evidence_pack.v1"",",
  "  ""title"": ""HashCanon Tier-0 Evidence Pack v1"",",
  "  ""type"": ""object"",",
  "  ""additionalProperties"": false,",
  "  ""required"": [ ""schema"", ""utc"", ""repo_root"", ""ok"", ""artifacts"" ],",
  "  ""properties"": {",
  "    ""schema"": { ""const"": ""hashcanon.tier0_evidence_pack.v1"" },",
  "    ""utc"": { ""type"": ""string"", ""minLength"": 1 },",
  "    ""repo_root"": { ""type"": ""string"", ""minLength"": 1 },",
  "    ""ok"": { ""type"": ""boolean"" },",
  "    ""artifacts"": {",
  "      ""type"": ""object"",",
  "      ""additionalProperties"": false,",
  "      ""required"": [ ""tier0_runner"", ""selftest"", ""negative_suite"", ""evidence_ndjson"", ""sha256sums"", ""stdout"", ""stderr"" ],",
  "      ""properties"": {",
  "        ""tier0_runner"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""selftest"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""negative_suite"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""evidence_ndjson"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""sha256sums"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""stdout"": { ""$ref"": ""#/$defs/artifact"" },",
  "        ""stderr"": { ""$ref"": ""#/$defs/artifact"" }",
  "      }",
  "    }",
  "  },",
  "  ""$defs"": {",
  "    ""artifact"": {",
  "      ""type"": ""object"",",
  "      ""additionalProperties"": false,",
  "      ""required"": [ ""path"", ""sha256"" ],",
  "      ""properties"": {",
  "        ""path"": { ""type"": ""string"", ""minLength"": 1 },",
  "        ""sha256"": { ""type"": ""string"", ""pattern"": ""^[0-9a-f]{64}$"" }",
  "      }",
  "    }",
  "  }",
  "}"
)
Write-Utf8NoBomLf $evSchemaPath ((@($evSchemaLines) -join "`n") + "`n")

# =========================================================
# test_vectors/hashcanon_optionA/minimal_packet/README.md
# =========================================================
$tvReadme = Join-Path $TVRoot "README.md"
$tvLines = @(
  "# HashCanon Option A — Minimal Packet Vector",
  "",
  "Layout:",
  "- packet/<PacketId>/manifest.json",
  "- packet/<PacketId>/packet_id.txt",
  "- packet/<PacketId>/sha256sums.txt",
  "- packet/<PacketId>/payload/hello.txt",
  "",
  "Generate:",
  "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 -RepoRoot .",
  "",
  "Verify:",
  "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_verify_packet_optionA_v1.ps1 -PacketDir test_vectors/hashcanon_optionA/minimal_packet/packet/<PacketId>"
)
Write-Utf8NoBomLf $tvReadme ((@($tvLines) -join "`n") + "`n")

# =========================================================
# scripts/hashcanon_make_minimal_packet_optionA_v1.ps1
# =========================================================
$mkPath = Join-Path $Scripts "hashcanon_make_minimal_packet_optionA_v1.ps1"
$mkLines = @(
  'param([Parameter(Mandatory=$true)][string]$RepoRoot)',
  '',
  '$ErrorActionPreference="Stop"',
  'Set-StrictMode -Version Latest',
  '',
  'function EnsureDir([string]$p){',
  '  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }',
  '  if(-not (Test-Path -LiteralPath $p -PathType Container)){',
  '    New-Item -ItemType Directory -Force -Path $p | Out-Null',
  '  }',
  '}',
  '',
  'function Write-Utf8NoBomLf([string]$Path,[string]$Text){',
  '  $dir = Split-Path -Parent $Path',
  '  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){',
  '    New-Item -ItemType Directory -Force -Path $dir | Out-Null',
  '  }',
  '  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"',
  '  if(-not $t.EndsWith("`n")){ $t += "`n" }',
  '  $enc = New-Object System.Text.UTF8Encoding($false)',
  '  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))',
  '}',
  '',
  'function Sha256HexBytes([byte[]]$b){',
  '  $sha=[System.Security.Cryptography.SHA256]::Create()',
  '  try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }',
  '  ($h | ForEach-Object { $_.ToString("x2") }) -join ""',
  '}',
  '',
  'function Sha256HexFile([string]$Path){',
  '  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("SHA256_MISSING_FILE: " + $Path) }',
  '  $b=[System.IO.File]::ReadAllBytes($Path)',
  '  Sha256HexBytes $b',
  '}',
  '',
  '$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path',
  '$root = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"',
  'EnsureDir $root',
  '',
  '$manifest = ''{"schema":"hashcanon.manifest.optionA.v1","payload_rel":"payload/hello.txt"}''',
  '$manifest = $manifest.Trim()',
  '',
  '$enc = New-Object System.Text.UTF8Encoding($false)',
  '$mBytes = $enc.GetBytes((($manifest -replace "`r`n","`n") -replace "`r","`n"))',
  '$packetId = Sha256HexBytes $mBytes',
  '',
  '$pktDir = Join-Path $root $packetId',
  'if(Test-Path -LiteralPath $pktDir -PathType Container){',
  '  Remove-Item -LiteralPath $pktDir -Recurse -Force',
  '}',
  'EnsureDir $pktDir',
  'EnsureDir (Join-Path $pktDir "payload")',
  '',
  '$manifestPath = Join-Path $pktDir "manifest.json"',
  '$pidPath = Join-Path $pktDir "packet_id.txt"',
  '$sumPath = Join-Path $pktDir "sha256sums.txt"',
  '$helloPath = Join-Path $pktDir "payload\hello.txt"',
  '',
  'Write-Utf8NoBomLf $manifestPath $manifest',
  'Write-Utf8NoBomLf $pidPath $packetId',
  'Write-Utf8NoBomLf $helloPath "hello"',
  '',
  '$lines = New-Object System.Collections.Generic.List[string]',
  '[void]$lines.Add((Sha256HexFile $manifestPath) + "  manifest.json")',
  '[void]$lines.Add((Sha256HexFile $pidPath) + "  packet_id.txt")',
  '[void]$lines.Add((Sha256HexFile $helloPath) + "  payload/hello.txt")',
  '$sumTxt = (@($lines.ToArray()) -join "`n") + "`n"',
  'Write-Utf8NoBomLf $sumPath $sumTxt',
  '',
  'Write-Host ("MINIMAL_PACKET_ID=" + $packetId) -ForegroundColor Green',
  'Write-Host ("PACKET_DIR=" + $pktDir) -ForegroundColor Green'
)
Write-Utf8NoBomLf $mkPath ((@($mkLines) -join "`n") + "`n")

# =========================================================
# scripts/hashcanon_verify_packet_optionA_v1.ps1
# =========================================================
$verPath = Join-Path $Scripts "hashcanon_verify_packet_optionA_v1.ps1"
$verLines = @(
  'param([Parameter(Mandatory=$true)][string]$PacketDir)',
  '',
  '$ErrorActionPreference="Stop"',
  'Set-StrictMode -Version Latest',
  '',
  'function Sha256HexBytes([byte[]]$b){',
  '  $sha=[System.Security.Cryptography.SHA256]::Create()',
  '  try{ $h=$sha.ComputeHash($b) } finally { $sha.Dispose() }',
  '  ($h | ForEach-Object { $_.ToString("x2") }) -join ""',
  '}',
  '',
  'function Sha256HexFile([string]$Path){',
  '  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("VERIFY_MISSING_FILE: " + $Path) }',
  '  $b=[System.IO.File]::ReadAllBytes($Path)',
  '  Sha256HexBytes $b',
  '}',
  '',
  '$PacketDir = (Resolve-Path -LiteralPath $PacketDir).Path',
  '$manifest = Join-Path $PacketDir "manifest.json"',
  '$pid = Join-Path $PacketDir "packet_id.txt"',
  '$sums = Join-Path $PacketDir "sha256sums.txt"',
  '',
  'if(-not (Test-Path -LiteralPath $manifest -PathType Leaf)){ throw "HC_VERIFY_MISSING_MANIFEST" }',
  'if(-not (Test-Path -LiteralPath $pid -PathType Leaf)){ throw "HC_VERIFY_MISSING_PACKET_ID" }',
  'if(-not (Test-Path -LiteralPath $sums -PathType Leaf)){ throw "HC_VERIFY_MISSING_SHA256SUMS" }',
  '',
  '$mBytes = [System.IO.File]::ReadAllBytes($manifest)',
  '$mText = (New-Object System.Text.UTF8Encoding($false)).GetString($mBytes)',
  'if($mText -match "(?:^|[^a-zA-Z0-9_])packet_id(?:[^a-zA-Z0-9_]|$)"){ throw "HC_VERIFY_MANIFEST_CONTAINS_PACKET_ID_FIELD" }',
  '',
  '$expected = Sha256HexBytes $mBytes',
  '$pidTxt = ((New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($pid))).Trim()',
  'if($pidTxt -ne $expected){ throw "HC_VERIFY_PACKET_ID_MISMATCH" }',
  '',
  '$dirName = (Split-Path -Leaf $PacketDir)',
  'if($dirName -match "^[0-9a-f]{64}$" -and $dirName -ne $expected){ throw "HC_VERIFY_DIRNAME_PACKETID_MISMATCH" }',
  '',
  '$sumText = (New-Object System.Text.UTF8Encoding($false)).GetString([System.IO.File]::ReadAllBytes($sums))',
  '$lines = @(@($sumText -split "`n") | Where-Object { $_.Trim().Length -gt 0 })',
  'if($lines.Count -lt 1){ throw "HC_VERIFY_SHA256SUMS_EMPTY" }',
  '',
  '$seen = New-Object System.Collections.Generic.HashSet[string]',
  'foreach($ln in $lines){',
  '  $m = [regex]::Match($ln, "^(?<h>[0-9a-f]{64})\s\s(?<p>.+)$")',
  '  if(-not $m.Success){ throw "HC_VERIFY_SHA256SUMS_BAD_LINE" }',
  '  $h = $m.Groups["h"].Value',
  '  $rp = $m.Groups["p"].Value.Trim()',
  '  if([string]::IsNullOrWhiteSpace($rp)){ throw "HC_VERIFY_SHA256SUMS_EMPTY_PATH" }',
  '  if($rp -match "^[A-Za-z]:\\" -or $rp.StartsWith("/") -or $rp.StartsWith("\\")){ throw "HC_VERIFY_SHA256SUMS_ABSOLUTE_PATH" }',
  '  if($rp.Contains("..\") -or $rp.Contains("../")){ throw "HC_VERIFY_SHA256SUMS_TRAVERSAL" }',
  '',
  '  $rp = $rp.Replace("\","/")',
  '  $ap = Join-Path $PacketDir ($rp.Replace("/", [System.IO.Path]::DirectorySeparatorChar))',
  '  if(-not (Test-Path -LiteralPath $ap -PathType Leaf)){ throw "HC_VERIFY_SHA256SUMS_MISSING_FILE" }',
  '  $actual = Sha256HexFile $ap',
  '  if($actual -ne $h){ throw "HC_VERIFY_SHA256_MISMATCH" }',
  '  [void]$seen.Add($rp)',
  '}',
  '',
  'if(-not $seen.Contains("manifest.json")){ throw "HC_VERIFY_SHA256SUMS_MISSING_MANIFEST_ENTRY" }',
  'if(-not $seen.Contains("packet_id.txt")){ throw "HC_VERIFY_SHA256SUMS_MISSING_PACKETID_ENTRY" }',
  '',
  'Write-Host "HC_VERIFY_OK" -ForegroundColor Green',
  'Write-Host ("PACKET_ID=" + $expected) -ForegroundColor Green'
)
Write-Utf8NoBomLf $verPath ((@($verLines) -join "`n") + "`n")

# =========================================================
# scripts/_selftest_hashcanon_negative_suite_v1.ps1  (MISSING IN YOUR REPO)
# =========================================================
$negPath = Join-Path $Scripts "_selftest_hashcanon_negative_suite_v1.ps1"
$negLines = @(
  'param([Parameter(Mandatory=$true)][string]$RepoRoot)',
  '',
  '$ErrorActionPreference="Stop"',
  'Set-StrictMode -Version Latest',
  '',
  'function EnsureDir([string]$p){',
  '  if([string]::IsNullOrWhiteSpace($p)){ throw "EnsureDir: empty path" }',
  '  if(-not (Test-Path -LiteralPath $p -PathType Container)){',
  '    New-Item -ItemType Directory -Force -Path $p | Out-Null',
  '  }',
  '}',
  '',
  'function CopyTree([string]$src,[string]$dst){',
  '  if(Test-Path -LiteralPath $dst -PathType Container){',
  '    Remove-Item -LiteralPath $dst -Recurse -Force',
  '  }',
  '  New-Item -ItemType Directory -Force -Path $dst | Out-Null',
  '  Copy-Item -LiteralPath (Join-Path $src "*") -Destination $dst -Recurse -Force',
  '}',
  '',
  '$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path',
  '$PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"',
  'if(-not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ throw ("MISSING_POWERSHELL_EXE: " + $PSExe) }',
  '',
  '$Verifier = Join-Path $RepoRoot "scripts\hashcanon_verify_packet_optionA_v1.ps1"',
  '$Mk = Join-Path $RepoRoot "scripts\hashcanon_make_minimal_packet_optionA_v1.ps1"',
  'if(-not (Test-Path -LiteralPath $Verifier -PathType Leaf)){ throw "NEG_MISSING_VERIFIER" }',
  'if(-not (Test-Path -LiteralPath $Mk -PathType Leaf)){ throw "NEG_MISSING_MINIMAL_GENERATOR" }',
  '',
  '$p0 = Start-Process -FilePath $PSExe -ArgumentList @(',
  '  "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",',
  '  "-File",$Mk,"-RepoRoot",$RepoRoot',
  ') -Wait -PassThru',
  'if($p0.ExitCode -ne 0){ throw ("NEG_MINIMAL_GENERATE_FAILED exit_code=" + $p0.ExitCode) }',
  '',
  '$pktRoot = Join-Path $RepoRoot "test_vectors\hashcanon_optionA\minimal_packet\packet"',
  '$dirs = @(@(Get-ChildItem -LiteralPath $pktRoot -Directory -ErrorAction Stop))',
  'if($dirs.Count -lt 1){ throw "NEG_NO_PACKET_DIR_FOUND" }',
  '$good = $dirs[0].FullName',
  '',
  '$scratch = Join-Path $RepoRoot "scripts\_scratch"',
  'EnsureDir $scratch',
  '$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmss")',
  '$root = Join-Path $scratch ("neg_suite_" + $stamp)',
  'EnsureDir $root',
  '',
  'function RunExpectFail([string]$case,[string]$dir,[string]$token){',
  '  $out = Join-Path $root ("out_" + $case + ".log")',
  '  $err = Join-Path $root ("err_" + $case + ".log")',
  '  $p = Start-Process -FilePath $PSExe -ArgumentList @(',
  '    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",',
  '    "-File",$Verifier,"-PacketDir",$dir',
  '  ) -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err',
  '  $errTxt = [System.IO.File]::ReadAllText($err,(New-Object System.Text.UTF8Encoding($false)))',
  '  if($p.ExitCode -eq 0){ throw ("NEG_EXPECT_FAIL_BUT_OK: " + $case) }',
  '  if(-not ($errTxt -like ("*" + $token + "*"))){ throw ("NEG_MISSING_TOKEN: " + $case + " token=" + $token) }',
  '  Write-Host ("NEG_OK: " + $case) -ForegroundColor Green',
  '}',
  '',
  '# Case 1: tamper sha256sums',
  '$c1 = Join-Path $root "case1_tamper_sha256sums"',
  'CopyTree $good $c1',
  '$sum = Join-Path $c1 "sha256sums.txt"',
  '$txt = [System.IO.File]::ReadAllText($sum,(New-Object System.Text.UTF8Encoding($false)))',
  '$txt2 = $txt.Replace("a","b")',
  '[System.IO.File]::WriteAllText($sum,$txt2,(New-Object System.Text.UTF8Encoding($false)))',
  'RunExpectFail "case1" $c1 "HC_VERIFY_SHA256_MISMATCH"',
  '',
  '# Case 2: missing manifest.json',
  '$c2 = Join-Path $root "case2_missing_manifest"',
  'CopyTree $good $c2',
  'Remove-Item -LiteralPath (Join-Path $c2 "manifest.json") -Force',
  'RunExpectFail "case2" $c2 "HC_VERIFY_MISSING_MANIFEST"',
  '',
  '# Case 3: packet_id mismatch',
  '$c3 = Join-Path $root "case3_packetid_mismatch"',
  'CopyTree $good $c3',
  '[System.IO.File]::WriteAllText((Join-Path $c3 "packet_id.txt"), ("0"*64) + "`n", (New-Object System.Text.UTF8Encoding($false)))',
  'RunExpectFail "case3" $c3 "HC_VERIFY_PACKET_ID_MISMATCH"',
  '',
  'Write-Host "HASHCANON_NEGATIVE_SUITE_OK" -ForegroundColor Green'
)
Write-Utf8NoBomLf $negPath ((@($negLines) -join "`n") + "`n")

# =========================================================
# .github/workflows/hashcanon_tier0.yml
# =========================================================
$wf = Join-Path $Workflows "hashcanon_tier0.yml"
$wfLines = @(
  "name: hashcanon-tier0",
  "on:",
  "  push:",
  "    branches: [ ""main"" ]",
  "  pull_request:",
  "    branches: [ ""main"" ]",
  "",
  "jobs:",
  "  tier0:",
  "    runs-on: windows-latest",
  "    steps:",
  "      - uses: actions/checkout@v4",
  "      - name: Run Tier-0 unified runner",
  "        shell: pwsh",
  "        run: |",
  "          `$ErrorActionPreference = ""Stop""",
  "          `$RepoRoot = (Resolve-Path -LiteralPath ""."").Path",
  "          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 -RepoRoot `$RepoRoot",
  "      - name: Run negative suite",
  "        shell: pwsh",
  "        run: |",
  "          `$ErrorActionPreference = ""Stop""",
  "          `$RepoRoot = (Resolve-Path -LiteralPath ""."").Path",
  "          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_selftest_hashcanon_negative_suite_v1.ps1 -RepoRoot `$RepoRoot"
)
Write-Utf8NoBomLf $wf ((@($wfLines) -join "`n") + "`n")

# =========================================================
# Parse-gate all files written by this runner
# =========================================================
Parse-GateFile $mkPath
Parse-GateFile $verPath
Parse-GateFile $negPath

Write-Host "HASHCANON_PUBLIC_SEAL_V3_OK" -ForegroundColor Green
Write-Host ("WROTE_DOCS=" + $Docs) -ForegroundColor Green
Write-Host ("WROTE_SCHEMAS=" + $Schemas) -ForegroundColor Green
Write-Host ("WROTE_WORKFLOW=" + $wf) -ForegroundColor Green
