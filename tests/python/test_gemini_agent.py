"""آزمون‌های بدون شبکه برای قرارداد اتصال و مرزهای امنیتی ایجنت."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
from urllib.error import HTTPError, URLError

from tools import gemini_agent as agent

KEY = "test-only-not-a-real-credential"


class Response:
    def __init__(self, body):
        self.body = json.dumps(body).encode()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, limit):
        return self.body[:limit]


def success_body(text="پاسخ آزمایشی", **extra):
    return {
        "candidates": [{"content": {"parts": [{"text": text}]}, "finishReason": "STOP"}],
        "modelVersion": "gemini-3.5-flash-lite",
        "usageMetadata": {"totalTokenCount": 42},
        **extra,
    }


class GenerateTests(unittest.TestCase):
    def call(self, opener, **kwargs):
        return agent.generate(KEY, agent.DEFAULT_MODEL, "system", "user", opener=opener, **kwargs)

    def test_missing_key_fails_before_network(self):
        opener = mock.Mock()
        with self.assertRaisesRegex(agent.AgentError, "missing"):
            agent.generate("", agent.DEFAULT_MODEL, "s", "u", opener=opener)
        opener.assert_not_called()

    def test_key_is_header_only_and_never_in_url_or_prompt(self):
        opener = mock.Mock(return_value=Response(success_body()))
        reply = self.call(opener)
        request = opener.call_args.args[0]
        self.assertEqual(request.get_header("X-goog-api-key"), KEY)
        self.assertNotIn(KEY, request.full_url)
        self.assertNotIn(KEY, request.data.decode())
        self.assertTrue(request.full_url.startswith("https://generativelanguage.googleapis.com/"))
        self.assertEqual(reply.text, "پاسخ آزمایشی")
        self.assertEqual(reply.total_tokens, 42)
        self.assertNotIn("temperature", request.data.decode())

    def test_invalid_model_cannot_change_endpoint(self):
        for model in ("../secret", "https://evil.example", "model?key=secret", "a/b"):
            with self.subTest(model=model), self.assertRaises(agent.AgentError):
                agent.generate(KEY, model, "s", "u", opener=mock.Mock())

    def test_permanent_http_error_fails_without_retry_or_raw_body(self):
        error = HTTPError("https://example", 403, KEY, {}, io.BytesIO(KEY.encode()))
        opener = mock.Mock(side_effect=error)
        sleep = mock.Mock()
        with self.assertRaises(agent.AgentError) as caught:
            self.call(opener, sleep=sleep)
        self.assertNotIn(KEY, str(caught.exception))
        self.assertIn("403", str(caught.exception))
        self.assertEqual(opener.call_count, 1)
        sleep.assert_not_called()

    def test_transient_error_retries_then_succeeds(self):
        opener = mock.Mock(side_effect=[
            HTTPError("https://example", 503, "unavailable", {}, None),
            Response(success_body()),
        ])
        sleep = mock.Mock()
        reply = self.call(opener, sleep=sleep)
        self.assertEqual(reply.attempts, 2)
        self.assertEqual(opener.call_count, 2)
        sleep.assert_called_once_with(2.0)

    def test_rate_limit_exhaustion_fails(self):
        opener = mock.Mock(side_effect=HTTPError("url", 429, KEY, {}, None))
        with self.assertRaisesRegex(agent.AgentError, "429"):
            self.call(opener, sleep=mock.Mock())
        self.assertEqual(opener.call_count, 3)

    def test_network_exhaustion_fails(self):
        opener = mock.Mock(side_effect=URLError(KEY))
        with self.assertRaises(agent.AgentError) as caught:
            self.call(opener, sleep=mock.Mock())
        self.assertNotIn(KEY, str(caught.exception))
        self.assertEqual(opener.call_count, 3)

    def test_invalid_or_empty_responses_fail(self):
        bodies = [{}, {"error": {"message": KEY}}, {"candidates": []},
                  success_body(""), success_body(promptFeedback={"blockReason": "SAFETY"}),
                  success_body(candidates=[{"finishReason": "MAX_TOKENS", "content": {"parts": [{"text": "partial"}]}}])]
        for body in bodies:
            with self.subTest(body=body), self.assertRaises(agent.AgentError):
                self.call(mock.Mock(return_value=Response(body)))

    def test_invalid_json_fails(self):
        response = Response({})
        response.body = b"not json"
        with self.assertRaisesRegex(agent.AgentError, "invalid JSON"):
            self.call(mock.Mock(return_value=response))

    def test_secret_is_redacted_from_model_output(self):
        opener = mock.Mock(return_value=Response(success_body(f"echo: {KEY}")))
        self.assertNotIn(KEY, self.call(opener).text)

    def test_redirect_handler_refuses_new_destination(self):
        self.assertIsNone(agent.NoRedirects().redirect_request(None, None, 302, "", {}, "https://evil.example"))


class ContextAndOutputTests(unittest.TestCase):
    def test_context_is_allowlisted_and_bounded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "GEMINI.md").write_text("راهنمای پروژه" * 3000, encoding="utf-8")
            (root / ".env").write_text(KEY, encoding="utf-8")
            context = agent.repository_context(root)
            self.assertIn("راهنمای پروژه", context)
            self.assertNotIn(KEY, context)
            self.assertLessEqual(len(context), 24100)

    def test_untrusted_text_is_json_data_not_shell_interpolation(self):
        env = {"EVENT_NAME": "issues", "ISSUE_TITLE": "title", "ISSUE_BODY": "$(touch /tmp/injected)\nEOF"}
        prompt = agent.build_user_prompt(env, Path("/nonexistent"))
        data = json.loads(prompt.split("\n", 1)[1])
        self.assertEqual(data["issue_body"], env["ISSUE_BODY"])
        self.assertIn("Untrusted", prompt)

    def test_connection_prompt_does_not_send_repository_or_issue_content(self):
        env = {"EVENT_NAME": "workflow_dispatch", "ISSUE_BODY": KEY}
        self.assertNotIn(KEY, agent.build_user_prompt(env, Path.cwd()))

    def test_output_is_single_line_json_and_resists_heredoc_injection(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            summary = Path(directory) / "summary"
            env = {"GITHUB_OUTPUT": str(output), "GITHUB_STEP_SUMMARY": str(summary)}
            reply = agent.GeminiReply("answer\nEOF\nresult=spoofed", "model", 10, 1)
            with contextlib.redirect_stdout(io.StringIO()):
                agent.publish(reply, False, env)
            name, value = output.read_text().strip().split("=", 1)
            self.assertEqual(name, "result")
            self.assertEqual(json.loads(value)["answer"], reply.text)
            self.assertIn("PASS", summary.read_text())

    def test_main_missing_secret_returns_nonzero_and_no_secret(self):
        stderr = io.StringIO()
        with mock.patch.dict(agent.os.environ, {"GEMINI_API_KEY": ""}, clear=True), contextlib.redirect_stderr(stderr):
            self.assertEqual(agent.main(), 1)
        self.assertIn("GEMINI_CONNECTION_FAILED", stderr.getvalue())

    def test_main_requires_successful_marker_for_connection_test(self):
        with mock.patch.dict(agent.os.environ, {"GEMINI_API_KEY": KEY}, clear=True), \
             mock.patch.object(agent, "generate", return_value=agent.GeminiReply("API error", "m", 0, 1)), \
             contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(agent.main(), 1)
        self.assertIn("marker did not match", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
