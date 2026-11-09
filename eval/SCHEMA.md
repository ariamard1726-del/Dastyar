# Scenario Schema

## Fields
- `id`: Unique identifier (string)
- `split`: "dev" or "test" (string)
- `author`: Author name (string)
- `domain`: Legal domain (string, e.g., "cheque", "eviction", "mahriyeh", "dismissal", "debt")
- `needs_human_review`: Boolean (true/false)
- `turns`: List of turn objects

## Turn Fields
- `user_text`: User input (string)
- `gold_speech_act`: "question" | "inform" | "confirm" | "deny" | "smallTalk" | "metaDialogue" | "outOfDomain" (string)
- `gold_relevance`: "continue" | "related_side" | "topic_switch" | "out_of_domain" (string)
- `gold_slots`: Optional list of slots (string[])
- `gold_law`: Optional law name (string)
- `gold_article`: Optional article number (string)
- `expect_unanswerable`: Boolean (true/false)

## Example
```json
{
  "id": "dev-001",
  "split": "dev",
  "author": "agent-seed",
  "domain": "cheque",
  "needs_human_review": true,
  "turns": [
    {
      "user_text": "چک من گم شده است، چه باید بکنم؟",
      "gold_speech_act": "question",
      "gold_relevance": "continue",
      "gold_slots": ["cheque_lost"],
      "gold_law": "ghanoun_e_sodour_e_check",
      "gold_article": "12",
      "expect_unanswerable": false
    }
  ]
}
```
