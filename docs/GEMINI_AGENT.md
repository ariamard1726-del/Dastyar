# Gemini Repository Agent

This repository has two separate Gemini integrations:

1. **Gemini Repository Agent** (`.github/workflows/gemini-agent.yml`) automatically answers new issues and explicit `/gemini ...` follow-up comments. It reads a small, allowlisted project context and posts a response. It does not execute model-generated commands or modify code.
2. **Autonomous Agent** (the pre-existing `.github/workflows/agent.yml`) is a manually dispatched coding workflow that can propose Dart changes in a pull request. It is not triggered by issue text.

## Credential setup

The repository owner must store a Google AI Studio key as the GitHub Actions repository secret **`GEMINI_API_KEY`**:

- GitHub → Dastyar → Settings → Secrets and variables → Actions → New repository secret.
- Or, in an authenticated terminal outside this chat: `gh secret set GEMINI_API_KEY --repo ariamard1726-del/Dastyar`. Enter the value at the protected prompt; do not put it in command arguments, shell history, an issue, or a file committed to Git.

GitHub secrets are write-only. Neither this agent nor an administrator can retrieve an existing secret's plaintext through the GitHub API. A successful API generation run verifies that the injected secret works; a green workflow alone is not sufficient evidence.

The workflow injects the secret only into the generation step as `GEMINI_API_KEY`. The separate comment job receives only the generated result and an `issues: write` GitHub token. The key is sent only in the `x-goog-api-key` header to the fixed HTTPS Gemini endpoint, never in a URL, prompt, artifact, or comment. HTTP error bodies are not logged. Redirects are rejected. GitHub masks registered secrets, and the script additionally redacts the key from generated output.

Never use `pull_request_target` for this integration. Issue events execute the workflow from the default branch, not code supplied in an issue. Only OWNER, MEMBER and COLLABORATOR requests are accepted; bot comments and pull-request conversation comments are excluded.

## Model and cost boundary

The default is `gemini-3.5-flash-lite`, a stable model with a free API tier. An owner can override it with the Actions repository variable `GEMINI_MODEL`. The script rejects URLs and paths rather than accepting an arbitrary endpoint.

A free-tier-eligible model does **not** guarantee that a particular Google project is on the free tier. Billing, regional availability and quotas are controlled by the Google project associated with the secret. Check the project's tier and current [model pricing](https://ai.google.dev/gemini-api/docs/pricing). This integration uses no paid bot subscription or external server. GitHub Actions usage on a private repository is subject to the account's Actions allowance.

**Privacy:** issue title/body, the invoking comment, and bounded excerpts of `GEMINI.md`, `README.md`, `pubspec.yaml` and `docs/ARCHITECTURE.md` are sent to Google. Do not put personal legal case information or credentials in agent issues. Google's free tier may use submitted content to improve its products; review its [terms](https://ai.google.dev/gemini-api/terms) before using private project content. The manual coding workflow separately sends selected Dart files and analyzer output.

## Activation and operation

The workflow must be present on the repository's default branch (`main`) for issue events and the manual Run workflow button to work. A feature-branch copy alone does not activate issue automation.

- Open an issue as the owner/collaborator: the agent responds automatically.
- Follow up with a comment beginning `/gemini `: the agent responds to that comment with the issue title/body as context.
- Run **Actions → Gemini Repository Agent → Run workflow** for a no-comment connection test. It requires a real Gemini response equal to `GEMINI_CONNECTION_OK`.

The generation job has read-only repository access. Missing credentials, authentication failures, unavailable models, exhausted quotas, network failures, blocked/empty/truncated responses and failed test markers make the job fail. Transient failures receive at most three attempts. For issue events, a separate job posts either the answer or an explicit failure notice with the run link; that notice does not turn the failed generation job green.

## Verification

Local, no network or credentials required:

```sh
python -m unittest discover -s tests/python -v
```

The same tests run in the Gemini workflow before the API request and in the repository Test workflow.

End-to-end verification:

1. Merge the integration into `main`.
2. Create a temporary issue titled `Test Gemini Agent Connection`.
3. Confirm the `issues`-event run of Gemini Repository Agent succeeds.
4. Inspect the generation step and the bot's issue comment; confirm the run SHA matches the activated workflow commit.
5. Close the temporary issue after recording its URL and the passing run URL. Closing it does not trigger another generation.

Troubleshoot HTTP 403 by checking the secret, Generative Language API enablement and key restrictions; HTTP 404 by checking model availability; HTTP 429 by checking project quota/rate limits. A missing secret must be recreated by the owner through GitHub's secret UI or an authenticated local CLI. Do not paste it into a chat or issue.
