# HashCanon

HashCanon is the deterministic packet-physics and canonical-bytes layer for Covenant Systems style directory-bundle transport.

## What it is

- Canonical bytes discipline: UTF-8 no BOM, LF line endings
- PacketId derivation law for Option A style packets
- sha256sums coverage rules over final on-disk bytes
- Non-mutating verification invariants
- Tier-0 selftest runner and evidence-pack emission

## Current public surface

- `scripts/_RUN_hashcanon_tier0_selftest_v1.ps1`
- `scripts/_selftest_hashcanon_optionA_v1.ps1`
- `scripts/_selftest_hashcanon_negative_suite_v1.ps1`
- `scripts/hashcanon_make_minimal_packet_optionA_v1.ps1`
- `scripts/hashcanon_verify_packet_optionA_v1.ps1`
- `schemas/hashcanon.selftest_receipt.v1.json`
- `schemas/hashcanon.tier0_evidence_pack.v1.json`
- `docs/HASHCANON_SPEC_v1.md`
- `docs/DEFINITION_OF_DONE_TIER0.md`
- `docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md`

## Status

Tier-0 is close to sealed. Positive runner/evidence flow exists. The remaining requirement is proving the standalone verifier and negative suite GREEN end-to-end.

## Repository goals

- Deterministic write -> parse-gate -> run discipline
- Stable packet identity and verification behavior
- Auditable receipts and evidence packs
- Clear public spec / DoD / WBS surface

## Next locked work

1. Prove `scripts/hashcanon_verify_packet_optionA_v1.ps1`
2. Prove `scripts/hashcanon_make_minimal_packet_optionA_v1.ps1`
3. Re-run negative suite until GREEN
4. Confirm GitHub Actions runs GREEN on `main`

## License / release posture

License and release posture to be finalized as the public Tier-0 seal completes.
