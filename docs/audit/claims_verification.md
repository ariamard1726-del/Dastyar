# Claims 1-5 Verification (P0-AUDIT)

| # | Verdict | Evidence Path:Lines | Note |
|---|---------|---------------------|------|
| 1 | **CONFIRMED** | lib/ui/chat_controller.dart:135-185<br>lib/domain/legal_counselor.dart:120-160<br>lib/domain/dialogue/conversation_memory.dart:10-50 | Goal Frame scattered: `ChatController` (engine/draft/counsel), `LegalCounselor` (dialogue planner/RAG), `dialogue/*` (slots/memory), `lawyer/*` (case_reasoner/lawyer_voice). Three engines: `ChatController.submit` chain, `LegalCounselor.step`, `Assistant.askWithAlternatives`. |
| 2 | **CONFIRMED** | lib/ui/chat_controller.dart:265-315 | `ChatController.submit` is ~14-step if/return chain (draft, lawyerGuide, activeCounsel, pendingList, resumeCounsel, explicitDraft, sessionChip, caseReasoning, smallTalk, strictCriminal, lawyerGuide, guideFollowUp, implicitDraft, startCounsel, vagueIntake, lawOverview, then `_ask`). Order is convention-based. |
| 3 | **CONFIRMED** | lib/domain/dialogue/small_talk_layer.dart:180-240<br>lib/ui/chat_controller.dart:290 | `_handleSmallTalk` filters greetings/thanks/distress/etc. (`SmallTalkIntent`). Anything returning `null` (including legal signals via `_legalSignalRe`) reaches `_ask` (article retrieval). |
| 4 | **PARTIAL** | lib/core/engine.dart:885-910<br>lib/core/engine.dart:58 | BM25F parameters exist (`_k1`, `_b`, `_wT`, `_wB`, `_wC`). Evidence shows `rank` uses BM25F scoring. Claim "almost always returns something" (e.g. "lost cheque" -> Constitution Principle 50) is consistent with `_rankInternal` returning hits unless `_chunks.isEmpty` or `_lowCover` threshold. Specific examples ("lost cheque", "unilateral termination", "sale of minor's property") need manual asset/test check; code confirms BM25F always scores unless empty. |
| 5 | **CONFIRMED** | lib/domain/search/retrieval_pipeline.dart:45-65 | Thresholds `refuseBelow = 0.50` and `bridgeBelow = 0.65` defined in `RetrievalPipeline`. `KnowledgeEngine.coverage` calculates coverage (0.0 to 1.0). No calibration logs or dataset evidence in code (only constants). |

---
**Evidence Details:**
- Claim 1: `ChatController` imports `LegalCounselor`, `dialogue/*`, `lawyer/*` and `Assistant`. `LegalCounselor` has its own `CounselorTurn` engine. `Assistant` has `askWithAlternatives`.
- Claim 2: `ChatController.submit` (lines 265-315) lists ~14 checks before `_ask`.
- Claim 3: `SmallTalkLayer.tryHandle` returns `null` if `_hasLegalSignalIn(phrase)` or `_startsWithConfirmation(phrase)` in active context (lines 180-240). `ChatController` calls `_handleSmallTalk` (line 290) and if false, proceeds to `_ask`.
- Claim 4: `KnowledgeEngine` uses BM25F (`_rankInternal`, lines 885-910). Coverage thresholds in `RetrievalPipeline` (lines 45-65).
- Claim 5: Constants `refuseBelow = 0.50` and `bridgeBelow = 0.65` in `RetrievalPipeline`. No calibration method found in `lib/` or `test/`.

