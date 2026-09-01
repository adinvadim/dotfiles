from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.pr_review_census import analyze_census


HEAD = "d09bb9986132106fa0cfd5366d4bf64d77f25441"


def metadata() -> dict[str, object]:
    return {
        "number": 1069,
        "url": "https://github.com/adinvadim-dev/medivey-hq/pull/1069",
        "state": "OPEN",
        "headRefOid": HEAD,
        "reviewDecision": None,
        "viewerLogin": "maintainer",
    }


def finding_thread(*, resolved: bool, outdated: bool) -> dict[str, object]:
    return {
        "id": "thread-1",
        "isResolved": resolved,
        "isOutdated": outdated,
        "comments": [
            {
                "author": {"login": "codex-reviewer"},
                "body": "Please preserve late rules.",
                "createdAt": "2026-09-01T06:00:00Z",
                "url": "https://example.test/finding",
                "path": "server/router.ts",
                "commit": {"oid": "23aee899c3e20b9a40269d08b62deaa464c12aac"},
            },
            {
                "author": {"login": "maintainer"},
                "body": "Fixed in d09bb9986.",
                "createdAt": "2026-09-01T07:00:00Z",
                "url": "https://example.test/reply",
                "path": "server/router.ts",
                "commit": {"oid": HEAD},
            },
        ],
        "commentsTruncated": False,
    }


class ReviewCensusTests(unittest.TestCase):
    def test_conversation_change_request_prevents_false_clear(self) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[],
            reviews=[],
            issue_comments=[
                {
                    "author": {"login": "codex-reviewer"},
                    "body": "[P1] Please preserve the late-rule evaluation.",
                    "createdAt": "2026-09-01T06:00:00Z",
                    "url": "https://example.test/conversation-finding",
                }
            ],
            checks=[{"name": "CI", "state": "SUCCESS", "bucket": "pass"}],
        )

        self.assertFalse(report["ready"])
        self.assertEqual(report["conversationComments"]["outstanding"], 1)
        finding = report["conversationComments"]["items"][0]
        self.assertEqual(finding["author"], "codex-reviewer")
        self.assertIsNone(finding["cleanOnHead"])

    def test_current_head_clean_comment_clears_conversation_finding(self) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[],
            reviews=[],
            issue_comments=[
                {
                    "author": {"login": "codex-reviewer"},
                    "body": "Please preserve the late-rule evaluation.",
                    "createdAt": "2026-09-01T06:00:00Z",
                    "url": "https://example.test/conversation-finding",
                },
                {
                    "author": {"login": "codex-reviewer"},
                    "body": (
                        "Codex Review: Didn't find any major issues.\n\n"
                        "**Reviewed commit:** `d09bb99861`"
                    ),
                    "createdAt": "2026-09-01T07:00:00Z",
                    "url": "https://example.test/conversation-clean",
                },
            ],
            checks=[{"name": "CI", "state": "SUCCESS", "bucket": "pass"}],
        )

        self.assertTrue(report["ready"])
        self.assertEqual(report["conversationComments"]["outstanding"], 0)
        self.assertEqual(
            report["conversationComments"]["items"][0]["cleanOnHead"]["url"],
            "https://example.test/conversation-clean",
        )

    def test_own_conversation_comment_is_not_a_finding(self) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[],
            reviews=[],
            issue_comments=[
                {
                    "author": {"login": "maintainer"},
                    "body": "Please review the updated implementation.",
                    "createdAt": "2026-09-01T06:00:00Z",
                    "url": "https://example.test/own-comment",
                }
            ],
            checks=[{"name": "CI", "state": "SUCCESS", "bucket": "pass"}],
        )

        self.assertTrue(report["ready"])
        self.assertEqual(report["conversationComments"]["total"], 0)

    def test_accepts_explicit_clean_evidence_on_the_current_head(self) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[finding_thread(resolved=True, outdated=True)],
            reviews=[],
            issue_comments=[
                {
                    "author": {"login": "codex-reviewer"},
                    "body": (
                        "Codex Review: Didn't find any major issues.\n\n"
                        "**Reviewed commit:** `d09bb99861`"
                    ),
                    "createdAt": "2026-09-01T07:07:07Z",
                    "url": "https://example.test/clean",
                }
            ],
            checks=[
                {
                    "name": "quality-gates",
                    "state": "SUCCESS",
                    "bucket": "pass",
                    "link": "https://example.test/check",
                    "workflow": "CI",
                }
            ],
        )

        self.assertTrue(report["ready"])
        self.assertEqual(report["threads"]["unresolved"], 0)
        self.assertEqual(report["threads"]["outdated"], 1)
        reviewer = report["reviewers"][0]
        self.assertEqual(reviewer["author"], "codex-reviewer")
        self.assertEqual(reviewer["latestReply"]["author"], "maintainer")
        self.assertEqual(
            reviewer["cleanOnHead"]["url"], "https://example.test/clean"
        )

    def test_outdated_unresolved_thread_stays_outstanding_without_confirmation(
        self,
    ) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[finding_thread(resolved=False, outdated=True)],
            reviews=[],
            issue_comments=[
                {
                    "author": {"login": "codex-reviewer"},
                    "body": (
                        "Codex Review: Didn't find any major issues.\n\n"
                        "**Reviewed commit:** `d68a4ff4d`"
                    ),
                    "createdAt": "2026-09-01T07:07:07Z",
                    "url": "https://example.test/stale-clean",
                }
            ],
            checks=[],
        )

        self.assertFalse(report["ready"])
        self.assertEqual(report["threads"]["unresolved"], 1)
        self.assertEqual(report["threads"]["outdatedUnresolved"], 1)
        self.assertEqual(report["threads"]["outstanding"], 1)
        self.assertIsNone(report["reviewers"][0]["cleanOnHead"])

    def test_later_approval_clears_a_change_request_on_the_same_head(self) -> None:
        report = analyze_census(
            metadata=metadata(),
            threads=[],
            reviews=[
                {
                    "author": {"login": "human-reviewer"},
                    "state": "CHANGES_REQUESTED",
                    "body": "Please fix the claim.",
                    "submittedAt": "2026-09-01T06:00:00Z",
                    "commit": {"oid": HEAD},
                    "url": "https://example.test/request",
                },
                {
                    "author": {"login": "human-reviewer"},
                    "state": "APPROVED",
                    "body": "",
                    "submittedAt": "2026-09-01T07:00:00Z",
                    "commit": {"oid": HEAD},
                    "url": "https://example.test/approval",
                },
            ],
            issue_comments=[],
            checks=[{"name": "CI", "state": "SUCCESS", "bucket": "pass"}],
        )

        self.assertTrue(report["ready"])
        self.assertEqual(report["changeRequests"]["outstanding"], 0)


if __name__ == "__main__":
    unittest.main()
