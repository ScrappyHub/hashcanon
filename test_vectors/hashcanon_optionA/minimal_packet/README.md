# HashCanon Option A - Minimal Packet Vector

This is the authoritative minimal HashCanon Option A vector.

## Authoritative packet
- packet/fedb16849c5d4359ba70a2d038256e07063c112a31f9f6aa108e0f2dcb5d65d4/

## Contents
- manifest.json
- packet_id.txt
- sha256sums.txt
- payload/hello.txt

## Notes
- packet_id.txt MUST equal SHA-256(final manifest.json bytes)
- sha256sums.txt is generated from final on-disk bytes
- verifier must be non-mutating

## Regenerate
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_make_minimal_packet_optionA_v1.ps1 -RepoRoot .

## Verify
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/hashcanon_verify_packet_optionA_v1.ps1 -PacketDir test_vectors/hashcanon_optionA/minimal_packet/packet/fedb16849c5d4359ba70a2d038256e07063c112a31f9f6aa108e0f2dcb5d65d4
