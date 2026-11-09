# Evaluation Methodology (P1-EVAL-HARNESS)

## 1. Overview
This document describes how the measurement infrastructure for project "Dastyar" runs, both locally (by a human) and in CI (via `agent-ci.yml`). The goal is to build trustworthy evidence BEFORE changing any behavior.

## 2. Running Locally (Human)
- **Schema & Docs**: `eval/SCHEMA.md` and `eval/scenario.schema.json` define the structure.
- **Metrics**: `tool/eval/metrics.dart` provides pure Dart implementations of Wilson intervals, bootstrap F1, etc.
- **Scenarios**: 40 seed scenarios in `eval/scenarios_dev/` (author="agent-seed", needs_human_review=true).
- **Validator**: `tool/eval/validate_scenarios.dart` checks required fields, enum values, unique ids, and split correctness. Run with `dart run tool/eval/validate_scenarios.dart`.
- **Locked Test Split**: `eval/scenarios_test/README.md` (Frozen). Manifest check via `tool/eval/check_test_lock.dart`.
- **Unanswerable Set**: `eval/unanswerable.json` (30 questions, tagged out_of_domain | not_in_corpus).
- **Baseline Runner**: `test/eval/baseline_test.dart` replays dev scenarios and prints results between `BASELINE-BEGIN` and `BASELINE-END`.

## 3. Running in CI (agent-ci.yml)
- **Trigger**: Push on `arena/bb42a511-dastyar` or `workflow_dispatch`.
- **Steps**:
  1. Checkout and setup Flutter (`3.47.6`, `stable`).
  2. `flutter pub get`.
  3. `flutter analyze --no-fatal-infos` (stores output in `analyze.txt`).
  4. `flutter test --reporter expanded` (stores output in `test.txt`, includes `baseline_test.dart`).
  5. Conditional `dart run tool/eval/validate_scenarios.dart` (if file exists).
  6. Upload artifacts (`analyze.txt`, `test.txt`).
- **Evidence**: CI run ID and log excerpts (see report).

## 4. Dev/Test Discipline
- **Dev Scenarios**: 40 seed scenarios in `eval/scenarios_dev/`. These are SEEDS, not the 300-scenario target. They are for measurement, not tuning.
- **Test Split**: Frozen in `eval/scenarios_test/`. Populated by humans only. Manifest lock ensures integrity.
- **Unanswerable Set**: 30 questions in `eval/unanswerable.json`. Flagged for human review.
- **Baseline Numbers**: Reported with n and 95% CI. Limits: based on synthetic seed data; not evidence for acceptance targets.

## 5. IntentNet Note (P0 Finding)
- **Training Script**: `brain/train_intent.py` exists (verified in P0-AUDIT).
- **How to run**: `python3 tools/check.py intent` (verified in P0-AUDIT).
- **Accuracy**: Shipped model's 96.5% is on synthetic data from the training distribution (P0 finding). **MUST NEVER** be quoted as real accuracy for the app behavior.
- **Constraint**: NO generative LLM/large neural model. IntentNet is a small linear/naive-Bayes signal (FNV-1a + softmax) allowed as one signal among several.

## 6. Acceptance Targets
- **CI Analyze**: "No issues found" (0 errors).
- **CI Tests**: Count >= 529 (baseline) + new tests (metrics, validator, lock, baseline). All green.
- **Baseline Numbers**: Topic retention, false-link rate, OOD precision/recall, slot F1, exact-article accuracy, law top-1, article-in-top-3, risk-coverage points.
- **Visible Change**: None (measurement only).

## 7. Risks / Open Questions
- **CI Execution**: Sandbox cannot run Dart/Flutter; relies on GitHub Actions (`agent-ci.yml`).
- **Engine Entry Point**: Assumed `KnowledgeEngine` in `lib/core/engine.dart` based on `docs/audit/dependency_map.md`.
- **Asset Loading**: Engine may require device/plugin; adapter in `baseline_test.dart` handles this by reporting what is NOT measurable.

STOP.
