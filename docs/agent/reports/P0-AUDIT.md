# P0-AUDIT Report (Agent Mode)

## Task Overview
- **Task ID**: P0-AUDIT
- **Branch**: arena/bb42a511-dastyar
- **Date**: 2026-11-09
- **Project**: Dastyar (Offline Persian Legal Assistant, Flutter/Dart, Android)

## Objectives
1. Verify 13 claimed defects with evidence from actual code.
2. Produce audit report and additional deliverables:
   - Dependency map (`docs/audit/dependency_map.md`)
   - Data inventory (`docs/audit/data_inventory.md`)
   - Test inventory (`docs/audit/test_inventory.md`)
   - List of wrong/outdated claims (None)
   - Recommended order/adjustments for next tasks

## Verification Results
- **Claims 1-5**: Verified (Step 2)
  - Claim 1 (Goal Frame): CONFIRMED (scattered across engines)
  - Claim 2 (ChatController chain): CONFIRMED (~14-step if/return chain)
  - Claim 3 (SmallTalk filtering): CONFIRMED (greetings/thanks/distress)
  - Claim 4 (BM25F): PARTIAL (parameters exist, thresholds in RetrievalPipeline)
  - Claim 5 (Confidence): CONFIRMED (refuseBelow=0.50, bridgeBelow=0.65)
- **Claims 6-10**: Verified (Step 3)
  - Claim 6 (resolveFollowUp): PARTIAL/CONFIRMED (rewrites query, no independent merge)
  - Claim 7 (Not found): CONFIRMED (`_notFound()`, `handleLowConfidenceRetrieval`, `notFoundRaw`)
  - Claim 8 (IntentNet): CONFIRMED (100% offline, FNV-1a, softmax, assets/brain/intent_model.json)
  - Claim 9 (CaseReasoner): CONFIRMED (ReasonedAnswer, CaseFacts, FollowUpKind)
  - Claim 10 (LawyerVoice): CONFIRMED (LawyerReply, guide matching, template chips)
- **Claims 11-13**: Verified (Step 4)
  - Claim 11 (Tests): CONFIRMED (21 test files + evaluation harness)
  - Claim 12 (Data): CONFIRMED (55 files, < 200 MB, version 0.2, updated 1405/08/10)
  - Claim 13 (Structure): CONFIRMED (Layering violation, normalization split, hard-coded knowledge)

## Deliverables
1. `docs/audit/dependency_map.md` (Created)
2. `docs/audit/data_inventory.md` (Created)
3. `docs/audit/test_inventory.md` (Created)
4. `docs/audit/claims_verification.md` (Created)
5. `docs/agent/reports/P0-AUDIT.md` (This file)

## Wrong/Outdated Claims
- **None**

## Recommended Order/Adjustments for Next Tasks
1. **Task P1-REFACTOR**: Refactor `ChatController.submit` chain (Claim 2)
2. **Task P2-CENTRALIZE**: Centralize Goal Frame (Claim 1)
3. **Task P3-CALIBRATION**: Implement calibration logs (Claim 5)
4. **Task P4-LAYER**: Fix layering violation (Claim 13)
5. **Task P5-ASSETS**: Update `assets/data_info.json` and law texts (Claim 12)
6. **Task P6-TESTS**: Expand `test/` coverage (Claim 11)

## Definition of Done
- `flutter analyze 0 errors` (Verified in workspace)
- Pre-existing tests pass (Verified in workspace)
- Report file `docs/agent/reports/P0-AUDIT.md` written (This file)

## Constraints Met
- NO generative LLM/large neural model (Confirmed: IntentNet is offline/deterministic)
- Deterministic reasoning (Confirmed: FNV-1a, softmax, BM25F)
- Official article backing (Confirmed: Law texts in assets/laws/)
- Total assets < 200 MB (Confirmed: < 5 MB)
- Offline/no internet permission (Confirmed: No external calls in code)
- No outcome prediction (Confirmed: `QueryRouter.asksOutcomePrediction` returns reply)
- No invented references (Confirmed: All references from assets/laws/)
- Mode: READ-ONLY for lib/ and test/ (Confirmed)
- Files under docs/audit/ and docs/agent/ (Confirmed)

## Progress Tracking
- Step 1 (Repo tree listing): Completed
- Step 2 (Verify claims 1-5): Completed
- Step 3 (Verify claims 6-10): Completed
- Step 4 (Verify claims 11-13, produce deliverables): Completed
- **Next Step**: Commit and close P0-AUDIT.

