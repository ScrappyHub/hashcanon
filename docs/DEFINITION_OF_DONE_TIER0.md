# HashCanon Tier-0 - Definition of Done

Tier-0 is DONE when all of the following are true:

- scripts/_RUN_hashcanon_tier0_selftest_v1.ps1 runs GREEN under PowerShell 5.1 StrictMode Latest.
- scripts/_selftest_hashcanon_optionA_v1.ps1 runs GREEN and emits a deterministic receipt artifact.
- schemas/hashcanon.tier0_evidence_pack.v1.json exists and emitted objects match structurally.
- scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 deterministically regenerates the minimal vector.
- scripts/hashcanon_verify_packet_optionA_v1.ps1 verifies the minimal vector deterministically (non-mutating).
- scripts/_selftest_hashcanon_negative_suite_v1.ps1 runs GREEN by asserting deterministic FAIL on >= 3 negative cases.
- GitHub Actions runs Tier-0 + negative suite on push/PR and is GREEN.
