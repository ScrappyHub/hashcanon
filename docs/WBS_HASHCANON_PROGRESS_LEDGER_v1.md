# HashCanon - WBS / Progress Ledger v1

## Tier-0 seal items
- [ ] Spec (docs/HASHCANON_SPEC_v1.md)
- [ ] DoD (docs/DEFINITION_OF_DONE_TIER0.md)
- [ ] WBS (docs/WBS_HASHCANON_PROGRESS_LEDGER_v1.md)
- [ ] Minimal vector generator (scripts/hashcanon_make_minimal_packet_optionA_v1.ps1)
- [ ] Verifier (scripts/hashcanon_verify_packet_optionA_v1.ps1)
- [ ] Positive selftest (scripts/_selftest_hashcanon_optionA_v1.ps1)
- [ ] Negative suite (scripts/_selftest_hashcanon_negative_suite_v1.ps1)
- [ ] Tier-0 unified runner (scripts/_RUN_hashcanon_tier0_selftest_v1.ps1)
- [ ] CI workflow (.github/workflows/hashcanon_tier0.yml)

## Completed
- [x] Deterministic write discipline (UTF-8 no BOM + LF)
- [x] Parse-gate discipline (runner + scripts)
