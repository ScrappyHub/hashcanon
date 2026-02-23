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

$Docs = Join-Path $RepoRoot 'docs'
$Schemas = Join-Path $RepoRoot 'schemas'
$Scripts = Join-Path $RepoRoot 'scripts'
$Workflows = Join-Path $RepoRoot '.github\workflows'
$TVRoot = Join-Path $RepoRoot 'test_vectors\hashcanon_optionA\minimal_packet'
$TVPacketRoot = Join-Path $TVRoot 'packet'

EnsureDir $Docs
EnsureDir $Schemas
EnsureDir $Scripts
EnsureDir $Workflows
EnsureDir $TVRoot
EnsureDir $TVPacketRoot

# ----------------------------
# docs/HASHCANON_SPEC_v1.md  (ASCII-only)
# ----------------------------
$specPath = Join-Path $Docs 'HASHCANON_SPEC_v1.md'
$specLines = @(
  '# HashCanon v1 - Spec',
  '',
  'HashCanon v1 is the ecosystem universal deterministic transport physics layer.',
  'It defines canonical bytes, PacketId derivation, finalization ordering, sha256sums coverage rules,',
  'and verifier non-mutation invariants for directory-bundle packets (Option A default).',
  '',
  '## Canonical bytes',
  '- UTF-8 (no BOM)',
  '- Line endings: LF',
  '- Canonical JSON: stable property ordering, no insignificant whitespace, stable escaping',
  '',
  '## Option A - PacketId law',
  '- manifest.json MUST NOT contain packet_id.',
  '- PacketId = SHA-256(bytes(manifest.json)).',
  '- packet_id.txt stores PacketId as 64 lowercase hex.',
  '- sha256sums.txt is generated last over final on-disk bytes of required files (and payload files).',
  '',
  '## Required files (minimum)',
  '- manifest.json (canonical JSON bytes)',
  '- packet_id.txt (PacketId)',
  '- sha256sums.txt (hash coverage)',
  '- payload/** (application payload)',
  '',
  '## Verification invariants',
  '- Verifier MUST NOT mutate packet contents.',
  '- Recompute PacketId from manifest.json bytes and compare to packet_id.txt and (if applicable) directory name.',
  '- Verify sha256sums.txt entries match on-disk bytes; reject missing/extra entries.',
  '- Reject traversal or absolute paths in sha256sums entries.',
  '',
  '## Tier-0 selftest',
  'Tier-0 is DONE when a clean machine can run the unified Tier-0 selftest runner and obtain deterministic PASS/FAIL plus an auditable evidence pack (hashes + logs).'
)
Write-Utf8NoBomLf $specPath ((@($specLines) -join "`n") + "`n")

# ----------------------------
# docs/DEFINITION_OF_DONE_TIER0.md
# ----------------------------
$dodPath = Join-Path $Docs 'DEFINITION_OF_DONE_TIER0.md'
$dodLines = @(
  '# HashCanon Tier-0 - Definition of Done',
  '',
  'Tier-0 is DONE when all of the following are true:',
  '',
  '- scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 runs GREEN under PowerShell 5.1 StrictMode Latest.',
  '- scripts/_selftest_hashcanon_optionA_v1.ps1 runs GREEN and emits a deterministic receipt artifact.',
  '- schemas/hashcanon.tier0_evidence_pack.v1.json exists and emitted objects match structurally.',
  '- scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 deterministically regenerates the minimal vector.',
  '- scripts/hashcanon_verify_packet_optionA_v1.ps1 verifies the minimal vector deterministically (non-mutating).',
  '- scripts/_selftest_hashcanon_negative_suite_v1.ps1 runs GREEN by asserting deterministic FAIL on >= 3 negative cases.',
  '- GitHub Actions runs Tier-0 + negative suite on push/PR and is GREEN.'
)
Write-Utf8NoBomLf $dodPath ((@($dodLines) -join "`n") + "`n")

# ----------------------------
# docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md
# ----------------------------
$wbsPath = Join-Path $Docs 'WBS_HASHCANON_PROGRESS_LEDGER_v1.md'
$wbsLines = @(
  '# HashCanon - WBS / Progress Ledger v1',
  '',
  '## Tier-0 seal items',
  '- [ ] Spec (docs/HASHCANON_SPEC_v1.md)',
  '- [ ] DoD (docs/DEFINITION_OF_DONE_TIER0.md)',
  '- [ ] WBS (docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md)',
  '- [ ] Minimal vector generator (scripts/hashcanon_make_minimal_packet_optionA_v1.ps1)',
  '- [ ] Verifier (scripts/hashcanon_verify_packet_optionA_v1.ps1)',
  '- [ ] Positive selftest (scripts/_selftest_hashcanon_optionA_v1.ps1)',
  '- [ ] Negative suite (scripts/_selftest_hashcanon_negative_suite_v1.ps1)',
  '- [ ] Tier-0 unified runner (scripts/_RUN_hashcanon_tier0_selftest_v1.ps1)',
  '- [ ] CI workflow (.github/workflows/hashcanon_tier0.yml)',
  '',
  '## Completed',
  '- [x] Deterministic write discipline (UTF-8 no BOM + LF)',
  '- [x] Parse-gate discipline (runner + scripts)'
)
Write-Utf8NoBomLf $wbsPath ((@($wbsLines) -join "`n") + "`n")

# ----------------------------
# schemas/hashcanon.tier0_evidence_pack.v1.json  (single-quoted lines => no $ expansion)
# ----------------------------
$evSchemaPath = Join-Path $Schemas 'hashcanon.tier0_evidence_pack.v1.json'
$evSchemaLines = @(
  '{',
  '  "$schema": "https://json-schema.org/draft/2020-12/schema",',
  '  "$id": "hashcanon.tier0_evidence_pack.v1",',
  '  "title": "HashCanon Tier-0 Evidence Pack v1",',
  '  "type": "object",',
  '  "additionalProperties": false,',
  '  "required": [ "schema", "utc", "repo_root", "ok", "artifacts" ],',
  '  "properties": {',
  '    "schema": { "const": "hashcanon.tier0_evidence_pack.v1" },',
  '    "utc": { "type": "string", "minLength": 1 },',
  '    "repo_root": { "type": "string", "minLength": 1 },',
  '    "ok": { "type": "boolean" },',
  '    "artifacts": {',
  '      "type": "object",',
  '      "additionalProperties": false,',
  '      "required": [ "tier0_runner", "selftest", "negative_suite", "evidence_ndjson", "sha256sums", "stdout", "stderr" ],',
  '      "properties": {',
  '        "tier0_runner": { "$ref": "#/$defs/artifact" },',
  '        "selftest": { "$ref": "#/$defs/artifact" },',
  '        "negative_suite": { "$ref": "#/$defs/artifact" },',
  '        "evidence_ndjson": { "$ref": "#/$defs/artifact" },',
  '        "sha256sums": { "$ref": "#/$defs/artifact" },',
  '        "stdout": { "$ref": "#/$defs/artifact" },',
  '        "stderr": { "$ref": "#/$defs/artifact" }',
  '      }',
  '    }',
  '  },',
  '  "$defs": {',
  '    "artifact": {',
  '      "type": "object",',
  '      "additionalProperties": false,',
  '      "required": [ "path", "sha256" ],',
  '      "properties": {',
  '        "path": { "type": "string", "minLength": 1 },',
  '        "sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" }',
  '      }',
  '    }',
  '  }',
  '}'
)
Write-Utf8NoBomLf $evSchemaPath ((@($evSchemaLines) -join "`n") + "`n")

# ----------------------------
# .github/workflows/hashcanon_tier0.yml
# ----------------------------
$wf = Join-Path $Workflows 'hashcanon_tier0.yml'
$wfLines = @(
  'name: hashcanon-tier0',
  'on:',
  '  push:',
  '    branches: [ "main" ]',
  '  pull_request:',
  '    branches: [ "main" ]',
  '',
  'jobs:',
  '  tier0:',
  '    runs-on: windows-latest',
  '    steps:',
  '      - uses: actions/checkout@v4',
  '      - name: Run Tier-0 unified runner',
  '        shell: pwsh',
  '        run: |',
  '          $ErrorActionPreference = "Stop"',
  '          $RepoRoot = (Resolve-Path -LiteralPath ".").Path',
  '          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 -RepoRoot $RepoRoot',
  '      - name: Run negative suite',
  '        shell: pwsh',
  '        run: |',
  '          $ErrorActionPreference = "Stop"',
  '          $RepoRoot = (Resolve-Path -LiteralPath ".").Path',
  '          powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/_selftest_hashcanon_negative_suite_v1.ps1 -RepoRoot $RepoRoot'
)
Write-Utf8NoBomLf $wf ((@($wfLines) -join "`n") + "`n")

# ----------------------------
# Parse-gate runner outputs we touched here
# ----------------------------
Parse-GateFile $specPath
Parse-GateFile $dodPath
Parse-GateFile $wbsPath
Parse-GateFile $evSchemaPath

Write-Host 'HASHCANON_PUBLIC_SEAL_V4_OK' -ForegroundColor Green
Write-Host ('WROTE_DOCS=' + $Docs) -ForegroundColor Green
Write-Host ('WROTE_SCHEMAS=' + $Schemas) -ForegroundColor Green
Write-Host ('WROTE_WORKFLOW=' + $wf) -ForegroundColor Green
