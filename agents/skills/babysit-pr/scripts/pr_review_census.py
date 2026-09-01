from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse


class CensusError(RuntimeError):
    pass


def _object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CensusError(f"{label} must be an object")
    return value


def _list(value: object, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise CensusError(f"{label} must be a list")
    return value


def _string(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise CensusError(f"{label} must be a non-empty string")
    return value


def _optional_string(value: object) -> str | None:
    return value if isinstance(value, str) and value else None


def _author(value: object, label: str) -> str:
    author = _object(value, label)
    return _string(author.get("login"), f"{label}.login")


def _commit_oid(value: object) -> str | None:
    if value is None:
        return None
    return _optional_string(_object(value, "commit").get("oid"))


def _is_current_head(candidate: str | None, head: str) -> bool:
    return bool(candidate and len(candidate) >= 7 and head.startswith(candidate))


_CLEAN_PHRASES = re.compile(
    r"(?:didn['’]t find any (?:major )?issues|no (?:major )?issues|no findings|\blgtm\b|looks good to me)",
    re.IGNORECASE,
)
_FINDING_PHRASES = re.compile(
    r"(?:\[P[0-3]\]|\b(?:please|must|should|needs? to|fix|change|remove|add|"
    r"update|rename|avoid|ensure|could you|can you)\b|"
    r"\b(?:this|that|it)\s+(?:drops?|loses?|breaks?|duplicates?|leaks?|"
    r"bypasses?|ignores?|misses?)\b)",
    re.IGNORECASE,
)
_REVIEWED_COMMIT = re.compile(
    r"reviewed commit:\*{0,2}\s*`?([0-9a-f]{7,40})`?", re.IGNORECASE
)


def _is_finding_text(body: str) -> bool:
    return not _CLEAN_PHRASES.search(body) and bool(_FINDING_PHRASES.search(body))


def _clean_evidence(
    *,
    head: str,
    reviews: Iterable[dict[str, Any]],
    issue_comments: Iterable[dict[str, Any]],
) -> list[dict[str, Any]]:
    evidence: list[dict[str, Any]] = []
    for raw_review in reviews:
        review = _object(raw_review, "review")
        author = _author(review.get("author"), "review.author")
        state = _string(review.get("state"), "review.state")
        body = review.get("body") if isinstance(review.get("body"), str) else ""
        commit_oid = _commit_oid(review.get("commit"))
        if not _is_current_head(commit_oid, head):
            continue
        if state != "APPROVED" and not _CLEAN_PHRASES.search(body):
            continue
        evidence.append(
            {
                "author": author,
                "at": _string(review.get("submittedAt"), "review.submittedAt"),
                "url": _optional_string(review.get("url")),
                "kind": "approval" if state == "APPROVED" else "clean_review",
                "commit": commit_oid,
            }
        )

    for raw_comment in issue_comments:
        comment = _object(raw_comment, "issue comment")
        body = comment.get("body") if isinstance(comment.get("body"), str) else ""
        commit_match = _REVIEWED_COMMIT.search(body)
        commit_oid = commit_match.group(1) if commit_match else None
        if not _is_current_head(commit_oid, head) or not _CLEAN_PHRASES.search(body):
            continue
        evidence.append(
            {
                "author": _author(comment.get("author"), "issue comment.author"),
                "at": _string(comment.get("createdAt"), "issue comment.createdAt"),
                "url": _optional_string(comment.get("url")),
                "kind": "clean_comment",
                "commit": commit_oid,
            }
        )
    return sorted(evidence, key=lambda item: item["at"])


def _latest_clean(
    evidence: Iterable[dict[str, Any]], author: str, after: str
) -> dict[str, Any] | None:
    matches = [
        item
        for item in evidence
        if item["author"] == author and item["at"] > after
    ]
    return matches[-1] if matches else None


def _comment_summary(raw_comment: object, label: str) -> dict[str, Any]:
    comment = _object(raw_comment, label)
    return {
        "author": _author(comment.get("author"), f"{label}.author"),
        "at": _string(comment.get("createdAt"), f"{label}.createdAt"),
        "url": _optional_string(comment.get("url")),
        "body": comment.get("body") if isinstance(comment.get("body"), str) else "",
        "commit": _commit_oid(comment.get("commit")),
    }


def analyze_census(
    *,
    metadata: dict[str, Any],
    threads: list[dict[str, Any]],
    reviews: list[dict[str, Any]],
    issue_comments: list[dict[str, Any]],
    checks: list[dict[str, Any]],
) -> dict[str, Any]:
    meta = _object(metadata, "metadata")
    head = _string(meta.get("headRefOid"), "metadata.headRefOid")
    clean_evidence = _clean_evidence(
        head=head, reviews=reviews, issue_comments=issue_comments
    )

    reviewer_findings: list[dict[str, Any]] = []
    unresolved = 0
    outdated = 0
    outdated_unresolved = 0
    outstanding_threads = 0
    truncated_threads = 0
    for raw_thread in threads:
        thread = _object(raw_thread, "thread")
        comments = _list(thread.get("comments"), "thread.comments")
        if not comments:
            raise CensusError("review thread has no comments")
        first = _comment_summary(comments[0], "thread.comments[0]")
        latest = _comment_summary(comments[-1], "thread.comments[-1]")
        is_resolved = thread.get("isResolved") is True
        is_outdated = thread.get("isOutdated") is True
        clean = _latest_clean(clean_evidence, first["author"], first["at"])
        is_unresolved = not is_resolved
        is_outstanding = is_unresolved and clean is None
        unresolved += int(is_unresolved)
        outdated += int(is_outdated)
        outdated_unresolved += int(is_unresolved and is_outdated)
        outstanding_threads += int(is_outstanding)
        truncated_threads += int(thread.get("commentsTruncated") is True)
        reviewer_findings.append(
            {
                "threadId": _string(thread.get("id"), "thread.id"),
                "author": first["author"],
                "path": _optional_string(thread.get("path"))
                or _optional_string(_object(comments[0], "thread comment").get("path")),
                "resolved": is_resolved,
                "outdated": is_outdated,
                "outstanding": is_outstanding,
                "finding": first,
                "latestReply": latest,
                "cleanOnHead": clean,
                "commentsTruncated": thread.get("commentsTruncated") is True,
            }
        )

    change_requests: list[dict[str, Any]] = []
    for raw_review in reviews:
        review = _object(raw_review, "review")
        if review.get("state") != "CHANGES_REQUESTED":
            continue
        author = _author(review.get("author"), "review.author")
        submitted_at = _string(review.get("submittedAt"), "review.submittedAt")
        clean = _latest_clean(clean_evidence, author, submitted_at)
        change_requests.append(
            {
                "author": author,
                "at": submitted_at,
                "url": _optional_string(review.get("url")),
                "commit": _commit_oid(review.get("commit")),
                "cleanOnHead": clean,
                "outstanding": clean is None,
            }
        )

    viewer_login = _optional_string(meta.get("viewerLogin"))
    conversation_findings: list[dict[str, Any]] = []
    for raw_comment in issue_comments:
        comment = _comment_summary(raw_comment, "issue comment")
        if comment["author"] == viewer_login or not _is_finding_text(
            comment["body"]
        ):
            continue
        clean = _latest_clean(clean_evidence, comment["author"], comment["at"])
        conversation_findings.append(
            {
                **comment,
                "cleanOnHead": clean,
                "outstanding": clean is None,
            }
        )

    normalized_checks: list[dict[str, Any]] = []
    buckets: Counter[str] = Counter()
    for raw_check in checks:
        check = _object(raw_check, "check")
        bucket = _string(check.get("bucket"), "check.bucket")
        buckets[bucket] += 1
        normalized_checks.append(
            {
                "name": _string(check.get("name"), "check.name"),
                "state": _optional_string(check.get("state")),
                "bucket": bucket,
                "workflow": _optional_string(check.get("workflow")),
                "link": _optional_string(check.get("link")),
            }
        )
    ci_ready = bool(normalized_checks) and all(
        check["bucket"] in {"pass", "skipping"} for check in normalized_checks
    )
    outstanding_change_requests = sum(
        int(item["outstanding"]) for item in change_requests
    )
    outstanding_conversation_comments = sum(
        int(item["outstanding"]) for item in conversation_findings
    )
    ready = (
        meta.get("state") == "OPEN"
        and outstanding_threads == 0
        and outstanding_change_requests == 0
        and outstanding_conversation_comments == 0
        and truncated_threads == 0
        and ci_ready
    )

    return {
        "pullRequest": {
            "number": meta.get("number"),
            "url": _string(meta.get("url"), "metadata.url"),
            "state": _string(meta.get("state"), "metadata.state"),
            "head": head,
            "reviewDecision": _optional_string(meta.get("reviewDecision")),
        },
        "threads": {
            "total": len(threads),
            "unresolved": unresolved,
            "outdated": outdated,
            "outdatedUnresolved": outdated_unresolved,
            "outstanding": outstanding_threads,
            "truncated": truncated_threads,
        },
        "reviewers": reviewer_findings,
        "changeRequests": {
            "total": len(change_requests),
            "outstanding": outstanding_change_requests,
            "items": change_requests,
        },
        "conversationComments": {
            "total": len(conversation_findings),
            "outstanding": outstanding_conversation_comments,
            "items": conversation_findings,
        },
        "ci": {
            "ready": ci_ready,
            "buckets": dict(sorted(buckets.items())),
            "checks": normalized_checks,
        },
        "ready": ready,
    }


class GhClient:
    def __init__(self, binary: str) -> None:
        self.binary = binary

    def run_json(self, args: list[str], *, allow_failure: bool = False) -> Any:
        result = subprocess.run(
            [self.binary, *args], capture_output=True, text=True, check=False
        )
        if result.returncode != 0 and not allow_failure:
            detail = result.stderr.strip() or result.stdout.strip()
            raise CensusError(f"gh {' '.join(args[:3])} failed: {detail}")
        try:
            return json.loads(result.stdout or "null")
        except json.JSONDecodeError as error:
            raise CensusError(f"gh returned invalid JSON: {error}") from error

    def graphql(self, query: str, variables: dict[str, object]) -> dict[str, Any]:
        args = ["api", "graphql", "-f", f"query={query}"]
        for key, value in variables.items():
            flag = "-F" if isinstance(value, int) else "-f"
            args.extend([flag, f"{key}={value}"])
        payload = _object(self.run_json(args), "GraphQL response")
        errors = payload.get("errors")
        if errors:
            raise CensusError(f"GraphQL returned errors: {json.dumps(errors)}")
        return payload


_METADATA_FIELDS = "number,url,state,headRefOid,reviewDecision"
_THREADS_QUERY = """
query($owner:String!,$name:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$name){pullRequest(number:$number){
    reviewThreads(first:100,after:$cursor){
      nodes{id isResolved isOutdated comments(first:100){
        nodes{author{login}body createdAt url path commit{oid}}
        pageInfo{hasNextPage endCursor}
      }}
      pageInfo{hasNextPage endCursor}
    }
  }}
}
"""
_THREAD_COMMENTS_QUERY = """
query($id:ID!,$cursor:String){node(id:$id){... on PullRequestReviewThread{
  comments(first:100,after:$cursor){
    nodes{author{login}body createdAt url path commit{oid}}
    pageInfo{hasNextPage endCursor}
  }
}}}
"""
_REVIEWS_QUERY = """
query($owner:String!,$name:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$name){pullRequest(number:$number){
    reviews(first:100,after:$cursor){
      nodes{author{login}state body submittedAt url commit{oid}}
      pageInfo{hasNextPage endCursor}
    }
  }}
}
"""
_COMMENTS_QUERY = """
query($owner:String!,$name:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$name){pullRequest(number:$number){
    comments(first:100,after:$cursor){
      nodes{author{login}body createdAt url}
      pageInfo{hasNextPage endCursor}
    }
  }}
}
"""


def _connection(payload: dict[str, Any], name: str) -> dict[str, Any]:
    data = _object(payload.get("data"), "GraphQL data")
    repository = _object(data.get("repository"), "GraphQL repository")
    pull_request = _object(repository.get("pullRequest"), "GraphQL pullRequest")
    return _object(pull_request.get(name), f"GraphQL {name}")


def _page_info(connection: dict[str, Any], label: str) -> tuple[bool, str | None]:
    page_info = _object(connection.get("pageInfo"), f"{label}.pageInfo")
    return page_info.get("hasNextPage") is True, _optional_string(
        page_info.get("endCursor")
    )


def _fetch_flat_connection(
    client: GhClient,
    *,
    query: str,
    connection_name: str,
    variables: dict[str, object],
) -> list[dict[str, Any]]:
    cursor: str | None = None
    items: list[dict[str, Any]] = []
    while True:
        page_variables = dict(variables)
        if cursor:
            page_variables["cursor"] = cursor
        connection = _connection(
            client.graphql(query, page_variables), connection_name
        )
        items.extend(
            _object(node, f"{connection_name}.node")
            for node in _list(connection.get("nodes"), f"{connection_name}.nodes")
        )
        has_next, cursor = _page_info(connection, connection_name)
        if not has_next:
            return items
        if not cursor:
            raise CensusError(f"{connection_name} pagination omitted endCursor")


def _fetch_threads(
    client: GhClient, variables: dict[str, object]
) -> list[dict[str, Any]]:
    threads = _fetch_flat_connection(
        client,
        query=_THREADS_QUERY,
        connection_name="reviewThreads",
        variables=variables,
    )
    for thread in threads:
        comments_connection = _object(thread.get("comments"), "thread.comments")
        comments = [
            _object(item, "thread comment")
            for item in _list(comments_connection.get("nodes"), "thread.comments.nodes")
        ]
        has_next, cursor = _page_info(comments_connection, "thread.comments")
        while has_next:
            if not cursor:
                raise CensusError("thread comment pagination omitted endCursor")
            payload = client.graphql(
                _THREAD_COMMENTS_QUERY,
                {"id": _string(thread.get("id"), "thread.id"), "cursor": cursor},
            )
            data = _object(payload.get("data"), "GraphQL data")
            node = _object(data.get("node"), "GraphQL thread node")
            next_connection = _object(node.get("comments"), "thread.comments")
            comments.extend(
                _object(item, "thread comment")
                for item in _list(
                    next_connection.get("nodes"), "thread.comments.nodes"
                )
            )
            has_next, cursor = _page_info(next_connection, "thread.comments")
        thread["path"] = _optional_string(comments[0].get("path")) if comments else None
        thread["comments"] = comments
        thread["commentsTruncated"] = False
    return threads


def _resolve_target(
    client: GhClient, selector: str | None, repository: str | None
) -> tuple[dict[str, Any], str, str]:
    args = ["pr", "view"]
    if selector:
        args.append(selector)
    if repository:
        args.extend(["--repo", repository])
    args.extend(["--json", _METADATA_FIELDS])
    metadata = _object(client.run_json(args), "pull request metadata")
    parsed = urlparse(_string(metadata.get("url"), "metadata.url"))
    path_parts = [part for part in parsed.path.split("/") if part]
    if len(path_parts) < 4 or path_parts[2] != "pull":
        raise CensusError("could not resolve repository from pull request URL")
    return metadata, path_parts[0], path_parts[1]


def collect_census(
    client: GhClient, selector: str | None, repository: str | None
) -> dict[str, Any]:
    metadata, owner, name = _resolve_target(client, selector, repository)
    viewer = _object(client.run_json(["api", "user"]), "viewer")
    metadata["viewerLogin"] = _string(viewer.get("login"), "viewer.login")
    number = metadata.get("number")
    if not isinstance(number, int) or number <= 0:
        raise CensusError("metadata.number must be a positive integer")
    variables: dict[str, object] = {
        "owner": owner,
        "name": name,
        "number": number,
    }
    threads = _fetch_threads(client, variables)
    reviews = _fetch_flat_connection(
        client,
        query=_REVIEWS_QUERY,
        connection_name="reviews",
        variables=variables,
    )
    issue_comments = _fetch_flat_connection(
        client,
        query=_COMMENTS_QUERY,
        connection_name="comments",
        variables=variables,
    )
    checks_raw = client.run_json(
        [
            "pr",
            "checks",
            str(number),
            "--repo",
            f"{owner}/{name}",
            "--json",
            "name,state,bucket,link,workflow",
        ],
        allow_failure=True,
    )
    checks = [
        _object(check, "check") for check in _list(checks_raw, "checks")
    ]
    return analyze_census(
        metadata=metadata,
        threads=threads,
        reviews=reviews,
        issue_comments=issue_comments,
        checks=checks,
    )


def render_text(report: dict[str, Any]) -> str:
    pr = _object(report.get("pullRequest"), "report.pullRequest")
    threads = _object(report.get("threads"), "report.threads")
    ci = _object(report.get("ci"), "report.ci")
    lines = [
        f"PR #{pr['number']} {pr['state']} head={str(pr['head'])[:12]}",
        (
            "threads: "
            f"{threads['unresolved']} unresolved, "
            f"{threads['outdated']} outdated, "
            f"{threads['outdatedUnresolved']} outdated+unresolved, "
            f"{threads['outstanding']} awaiting reviewer confirmation"
        ),
    ]
    reviewers = _list(report.get("reviewers"), "report.reviewers")
    for raw_reviewer in reviewers:
        reviewer = _object(raw_reviewer, "report.reviewer")
        latest = _object(reviewer.get("latestReply"), "reviewer.latestReply")
        clean = reviewer.get("cleanOnHead")
        clean_text = "none"
        if isinstance(clean, dict):
            clean_text = f"{clean.get('kind')} at {clean.get('at')}"
        flags = ["resolved" if reviewer.get("resolved") else "unresolved"]
        if reviewer.get("outdated"):
            flags.append("outdated")
        lines.append(
            f"- @{reviewer['author']} [{', '.join(flags)}] "
            f"latest=@{latest['author']} {latest['at']} clean-on-head={clean_text}"
        )
    buckets = _object(ci.get("buckets"), "report.ci.buckets")
    bucket_text = ", ".join(f"{key}={value}" for key, value in buckets.items())
    lines.append(f"CI: {bucket_text or 'no checks'}")
    change_requests = _object(
        report.get("changeRequests"), "report.changeRequests"
    )
    lines.append(
        f"change requests awaiting confirmation: {change_requests['outstanding']}"
    )
    conversation_comments = _object(
        report.get("conversationComments"), "report.conversationComments"
    )
    lines.append(
        "conversation findings awaiting confirmation: "
        f"{conversation_comments['outstanding']}"
    )
    lines.append("CLEAR" if report.get("ready") is True else "NOT CLEAR")
    return "\n".join(lines)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="pr-review-census",
        description="Report review-thread, reviewer-confirmation, and CI evidence for a pull request.",
    )
    parser.add_argument("selector", nargs="?", help="PR number, URL, or branch; defaults to the current branch")
    parser.add_argument("--repo", metavar="OWNER/REPO")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    parser.add_argument("--wait", action="store_true", help="Poll until the census is clear")
    parser.add_argument("--interval", type=int, default=60, metavar="SECONDS")
    parser.add_argument("--timeout", type=int, default=0, metavar="SECONDS", help="Stop waiting after this many seconds; 0 waits indefinitely")
    args = parser.parse_args(argv)
    if args.interval < 10:
        parser.error("--interval must be at least 10 seconds")
    if args.timeout < 0:
        parser.error("--timeout cannot be negative")
    return args


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    binary = shutil.which("gh")
    if not binary:
        print("pr-review-census: gh is not installed", file=sys.stderr)
        return 2
    client = GhClient(binary)
    started = time.monotonic()
    previous_signature: str | None = None
    while True:
        try:
            report = collect_census(client, args.selector, args.repo)
        except CensusError as error:
            print(f"pr-review-census: {error}", file=sys.stderr)
            return 2
        signature = json.dumps(report, sort_keys=True)
        if signature != previous_signature:
            if previous_signature is not None and not args.json:
                print("---")
            print(
                json.dumps(report, indent=2, sort_keys=True)
                if args.json
                else render_text(report)
            )
            previous_signature = signature
        if report.get("ready") is True:
            return 0
        if not args.wait:
            return 1
        if args.timeout and time.monotonic() - started >= args.timeout:
            return 3
        try:
            time.sleep(args.interval)
        except KeyboardInterrupt:
            return 130


if __name__ == "__main__":
    raise SystemExit(main())
