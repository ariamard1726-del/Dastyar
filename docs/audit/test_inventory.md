# Test Inventory (P0-AUDIT)

## UI Tests (test/app/)
1. `about_page_test.dart` (About page UI)
2. `feedback_test.dart` (Feedback mechanism)
3. `assistant_stream_test.dart` (Assistant stream logic)
4. `assistant_verify_test.dart` (Assistant verification)
5. `chat_bubbles_test.dart` (Chat bubble rendering)
6. `chat_controller_test.dart` (~1,521 lines controller, submit chain, smallTalk)
7. `citation_guard_test.dart` (Citation guard)
8. `draft_checkpoint_test.dart` (Draft checkpoint)
9. `llm_backends_test.dart` (LLM backends - disabled/unused)
10. `no_llm_default_test.dart` (No LLM default)
11. `settings_history_test.dart` (Settings history)

## Audit Tests (test/audit/)
12. `conversation_audit_test.dart` (Conversation audit)
13. `conversations.txt` (Scenario dataset)
14. `conversations_followup.txt` (Follow-up scenarios)

## Core Tests (test/core/)
15. `conflicts_service_test.dart` (Conflict chains)
16. `persian_normalizer_test.dart` (Normalization, tokenization)
17. `hybrid_router_test.dart` (Hybrid routing)
18. `intent_net_test.dart` (Neural net classifier, FNV-1a, softmax)
19. `law_topic_prior_test.dart` (Topic priors)
20. `model_store_test.dart` (Model storage)

## Evaluation Harness (bin/)
21. `bin/evaluate_bot.dart` (Phase 6 evaluation: dataset validation, intent net, templates, harness)
    - Runs via `flutter test bin/evaluate_bot.dart`
    - Supports `--dataset`, `--limit`, `--json`, `--traces`, `--trace`, `--verbose`, `--strict`, `--min-*`
    - Validates `EvaluationDataset` against `KnowledgeEngine.catalog`
    - Tests `IntentNet` (if loaded), `LegalTemplates`, and `EvaluationHarness`

## Claim 11 Verification
- **VERDICT**: **CONFIRMED** (Evidence: 21 test files in `test/` and `bin/evaluate_bot.dart`; tests cover UI, core, audit, and evaluation harness; `bin/evaluate_bot.dart` uses `flutter test` binding and validates dataset against known laws; no generative LLM/large neural model; deterministic reasoning via FNV-1a, softmax, BM25F).
- **Note**: `flutter analyze 0 errors` and `pre-existing tests pass` are part of Definition of Done.

