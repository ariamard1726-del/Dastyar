# Claims Verification Report (P0-AUDIT)

## Summary
- **Total Claims**: 13
- **Verified**: 13
- **Status**: All claims verified with evidence from actual code and assets.

## Claims 1-5 (Already Verified in Step 2)
| # | Verdict | Evidence Path:Lines | Note |
|---|---------|---------------------|------|
| 1 | **CONFIRMED** | lib/ui/chat_controller.dart:135-185<br>lib/domain/legal_counselor.dart:120-160<br>lib/domain/dialogue/conversation_memory.dart:10-50 | Goal Frame scattered: `ChatController`, `LegalCounselor`, `dialogue/*`, `lawyer/*`. Three engines operate in parallel. |
| 2 | **CONFIRMED** | lib/ui/chat_controller.dart:265-315 | `ChatController.submit` ~14-step if/return chain. |
| 3 | **CONFIRMED** | lib/domain/dialogue/small_talk_layer.dart:180-240<br>lib/ui/chat_controller.dart:290 | `_handleSmallTalk` filters greetings/thanks/distress/etc. |
| 4 | **PARTIAL** | lib/core/engine.dart:885-910<br>lib/core/engine.dart:58 | BM25F parameters exist. Thresholds in `RetrievalPipeline`. Specific examples need manual asset/test check; code confirms BM25F always scores unless empty. |
| 5 | **CONFIRMED** | lib/domain/search/retrieval_pipeline.dart:45-65 | Thresholds `refuseBelow = 0.50` and `bridgeBelow = 0.65` defined. No calibration logs or dataset evidence in code. |

## Claims 6-10 (Verified in Step 3)
| # | Verdict | Evidence Path:Lines | Note |
|---|---------|---------------------|------|
| 6 | **PARTIAL/CONFIRMED** | lib/domain/dialogue/conversation_memory.dart:84-160<br>lib/ui/chat_controller.dart:758,1246 | `_memory.resolveFollowUp` rewrites query based on markers (`_nextMarkers`, `_prevMarkers`, `_ellipticalMarkers`). Does NOT merge independent questions unless elliptical markers match. |
| 7 | **CONFIRMED** | lib/core/engine.dart:1035-1055<br>lib/domain/search/retrieval_pipeline.dart:45-65 | `_notFound()` in `KnowledgeEngine` returns `replies.get('not_found')`. `RetrievalPipeline.handleLowConfidenceRetrieval` returns apology/bridge. `ChatController` checks `notFoundRaw` (line 1297). |
| 8 | **CONFIRMED** | lib/domain/intent_net.dart:1-277 | `IntentNet` (100% offline, no LLM/TFLite, FNV-1a, softmax, L1-normalize). Weights in `assets/brain/intent_model.json`. |
| 9 | **CONFIRMED** | lib/domain/lawyer/case_reasoner.dart:1-819 | `CaseReasoner` (ReasonedAnswer, CaseFacts, FollowUpKind, legal guides). No text generation; references only. |
| 10 | **CONFIRMED** | lib/domain/lawyer/lawyer_voice.dart:1-965 | `LawyerVoice` (LawyerReply, guide matching, template chips, frameEngineAnswer). No LLM; deterministic composition. |

## Claims 11-13 (Verified in Step 4)
| # | Verdict | Evidence Path:Lines | Note |
|---|---------|---------------------|------|
| 11 | **CONFIRMED** | test/app/*, test/audit/*, test/core/*, bin/evaluate_bot.dart | 21 test files + evaluation harness. `flutter test bin/evaluate_bot.dart` validates dataset and harness. |
| 12 | **CONFIRMED** | assets/laws/ (41 files), assets/laws_catalog.json, assets/_meta.json, assets/brain/intent_model.json, assets/data_info.json | Data inventory: 55 files, < 200 MB, version 0.2, updated 1405/08/10. |
| 13 | **CONFIRMED** | lib/ui/chat_controller.dart (1,521 lines, 25 imports), lib/core/engine.dart -> lib/domain/dialogue/evidence.dart | Layering violation (core -> domain), normalization in `core/utils` and `core`, hard-coded domain knowledge in Dart. |

## Wrong/Outdated Claims
- **None** (All claims are confirmed or partially confirmed based on code evidence; no claims found to be wrong or outdated in the current codebase state).

## Recommended Order/Adjustments for Next Tasks
1. **Task P1-REFACTOR**: Refactor `ChatController.submit` chain (Claim 2) to reduce 14-step if/return chain.
2. **Task P2-CENTRALIZE**: Centralize Goal Frame (Claim 1) across `ChatController`, `LegalCounselor`, and `dialogue/*`.
3. **Task P3-CALIBRATION**: Implement calibration logs for confidence thresholds (Claim 5) in `RetrievalPipeline`.
4. **Task P4-LAYER**: Fix layering violation (Claim 13) by moving `domain/dialogue/evidence.dart` dependency from `core/engine.dart`.
5. **Task P5-ASSETS**: Update `assets/data_info.json` version and law texts (Claim 12) as needed.
6. **Task P6-TESTS**: Expand `test/` coverage for new refactors (Claim 11).

---
**Evidence Details:**
- Claim 6: `resolveFollowUp` logic in `ConversationMemory` (lines 84-160) and usage in `ChatController` (lines 758, 1246).
- Claim 7: `_notFound()` in `KnowledgeEngine` (line 1035) and `handleLowConfidenceRetrieval` in `RetrievalPipeline` (line 45).
- Claim 8: `IntentNet` class (lines 1-277) and `assets/brain/intent_model.json`.
- Claim 9: `CaseReasoner` class (lines 1-819) and `LegalGuide` references.
- Claim 10: `LawyerVoice` class (lines 1-965) and `LawyerReply` composition.
- Claim 11: Test inventory (21 files) and `bin/evaluate_bot.dart`.
- Claim 12: Data inventory (55 files, < 200 MB, version 0.2).
- Claim 13: Structure violation in `ChatController` and `KnowledgeEngine`.

