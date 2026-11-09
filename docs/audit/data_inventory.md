# Data Inventory (P0-AUDIT)

## Law Texts (41 files)
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Kar/Hoghough_E_Kar.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Kar/ghanoun_e_tamin_e_ejtemaei.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_hemayat_az_atfal.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_hemayat_az_mosarefkonandegan.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_hemayat_e_khanevadeh.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_madani.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_masouliyat_e_madani.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_roabat_e_mojer_va_mostajer.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_tashil_e_ezdevaj.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Tejarat/ghanoun_e_sodour_e_check.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Tejarat/ghanoun_e_tejarat.txt`
- `assets/laws/Hoghough_e_Khosousi/Hoghough_e_Tejarat/layehe_eslah_e_ghanoun_e_tejarat_1347.txt`
- `assets/laws/Hoghough_e_Omumi/Hoghough_e_Asasi/ghanoun_e_asasi.txt`
- `assets/laws/Hoghough_e_Omumi/Hoghough_e_Edari/ghanoun_e_maliathaye_mostaghim.txt`
- `assets/laws/Hoghough_e_Omumi/Hoghough_e_Edari/ghanoun_e_sabt_e_asnad_va_amlak.txt`
- `assets/laws/Hoghough_e_Omumi/Hoghough_e_Keyfari/ghanoun_e_jarayem_e_rayaneh_ei.txt`
- `assets/laws/Hoghough_e_Omumi/Hoghough_e_Keyfari/ghanoun_e_mojazat_e_eslami.txt`
- (24 additional law files in assets/laws/)

## Catalog & Metadata
- `assets/laws_catalog.json` (Law catalog with categories, priorities, aliases)
- `assets/laws/_meta.json` (Law metadata: paths, titles, dates)
- `assets/data_info.json` (Version 0.2, updated 1405/08/10)

## Knowledge & Relationships
- `assets/knowledge.txt` (General knowledge text)
- `assets/relationships.json` (Conflict chains between articles)
- `assets/replies.json` (Reply templates: greeting, ask_more, no_knowledge, etc.)
- `assets/synonyms.txt` (Synonym expansion pairs)

## Brain & Models
- `assets/brain/intent_model.json` (Neural net weights: w1, b1, w2, b2, thresholds, metrics)
- `assets/brain/law_topics.json` (Law topic priors: factors per question)

## Templates
- `assets/templates/*.json` (Legal templates for drafts: 1+ files)

## Evaluation Dataset
- `test/audit/conversations.txt` (Conversation scenarios)
- `test/audit/conversations_followup.txt` (Follow-up scenarios)
- `assets/brain/eval/evaluation_dataset.json` (Default dataset path in evaluate_bot.dart)

## Metadata & Versioning
- Data version: 0.2
- Laws updated: ۱۴۰۵/۰۸/۱۰ (2026-11-09 equivalent in Persian calendar)
- Total assets: 41 law files + 10 JSON/TXT configs + 1+ templates = ~55 files
- Total size: < 200 MB (estimated < 5 MB)

## Claim 12 Verification
- **VERDICT**: **CONFIRMED** (Evidence: assets/laws/ directory contains 41 law texts; assets/laws_catalog.json and assets/_meta.json list them; assets/brain/intent_model.json and assets/brain/law_topics.json contain model weights/priors; assets/templates/ contains templates; assets/data_info.json tracks version 0.2 updated 1405/08/10).
- **Note**: No generative LLM/large neural model; deterministic reasoning via FNV-1a, softmax, BM25F.

