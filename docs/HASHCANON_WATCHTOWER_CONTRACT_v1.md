# HashCanon WatchTower Contract v1

This document defines the WatchTower-facing contract emitted by HashCanon.

## Surfaces

### 1. Verify receipt
- schema: `hashcanon.verify_receipt.v1`
- file location: `proofs/receipts/hashcanon_verify/*.ndjson`

Purpose:
- provide deterministic machine-readable evidence that a packet verified successfully
- surface packet identity and file-hash evidence for downstream monitoring

### 2. Status snapshot
- schema: `hashcanon.status_snapshot.v1`
- file location: `proofs/status/hashcanon_status_snapshot_v1.json`

Purpose:
- provide a current machine-readable status view of HashCanon's essential public proof surfaces
- allow WatchTower to poll or ingest a single status document

## Current invariants

- verification is non-mutating
- packet identity derives from final manifest bytes
- minimal authoritative packet exists under `test_vectors/hashcanon_optionA/minimal_packet`
- full-green runner exists and emits receipts
- NFL selftest exists and is invocable by the full-green runner

## WatchTower consumption model

WatchTower should:
1. ingest verify receipts as append-only verification evidence
2. ingest status snapshot as current-state health metadata
3. treat both as machine-facing contract surfaces, not UI artifacts
