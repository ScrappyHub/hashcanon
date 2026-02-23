# HashCanon v1 - Spec

HashCanon v1 is the ecosystem universal deterministic transport physics layer.
It defines canonical bytes, PacketId derivation, finalization ordering, sha256sums coverage rules,
and verifier non-mutation invariants for directory-bundle packets (Option A default).

## Canonical bytes
- UTF-8 (no BOM)
- Line endings: LF
- Canonical JSON: stable property ordering, no insignificant whitespace, stable escaping

## Option A - PacketId law
- manifest.json MUST NOT contain packet_id.
- PacketId = SHA-256(bytes(manifest.json)).
- packet_id.txt stores PacketId as 64 lowercase hex.
- sha256sums.txt is generated last over final on-disk bytes of required files (and payload files).

## Required files (minimum)
- manifest.json (canonical JSON bytes)
- packet_id.txt (PacketId)
- sha256sums.txt (hash coverage)
- payload/** (application payload)

## Verification invariants
- Verifier MUST NOT mutate packet contents.
- Recompute PacketId from manifest.json bytes and compare to packet_id.txt and (if applicable) directory name.
- Verify sha256sums.txt entries match on-disk bytes; reject missing/extra entries.
- Reject traversal or absolute paths in sha256sums entries.

## Tier-0 selftest
Tier-0 is DONE when a clean machine can run the unified Tier-0 selftest runner and obtain deterministic PASS/FAIL plus an auditable evidence pack (hashes + logs).
