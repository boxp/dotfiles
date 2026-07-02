#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare two files and post the diff as a GitHub PR review comment."
    )
    parser.add_argument("--repo", required=True, help="GitHub repository in owner/repo form")
    parser.add_argument("--pr", required=True, type=int, help="Pull request number")
    parser.add_argument("--reference-path", required=True, help="Path to the reference file")
    parser.add_argument(
        "--implementation-path", required=True, help="Path to the implementation file"
    )
    parser.add_argument(
        "--comment-path", required=True, help="Repository path in the PR where the review comment is attached"
    )
    parser.add_argument("--line", required=True, type=int, help="Line number for the review comment")
    parser.add_argument(
        "--side",
        choices=("LEFT", "RIGHT"),
        default="RIGHT",
        help="Diff side for the review comment",
    )
    parser.add_argument("--reference-label", help="Label shown for the reference file")
    parser.add_argument("--implementation-label", help="Label shown for the implementation file")
    parser.add_argument(
        "--max-diff-lines",
        type=int,
        default=160,
        help="Maximum diff lines included in the comment body",
    )
    parser.add_argument(
        "--title",
        default="参考実装との差分",
        help="Heading shown at the top of the comment",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the comment body instead of posting it",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def build_diff(
    reference_text: str,
    implementation_text: str,
    ref_label: str,
    impl_label: str,
) -> list[str]:
    return list(
        difflib.unified_diff(
            reference_text.splitlines(),
            implementation_text.splitlines(),
            fromfile=ref_label,
            tofile=impl_label,
            lineterm="",
            n=3,
        )
    )


def summarize_diff(diff_lines: list[str]) -> tuple[int, int, int]:
    additions = 0
    removals = 0
    hunks = 0
    for line in diff_lines:
        if line.startswith("@@"):
            hunks += 1
        elif line.startswith("+") and not line.startswith("+++"):
            additions += 1
        elif line.startswith("-") and not line.startswith("---"):
            removals += 1
    return additions, removals, hunks


def truncate_diff(diff_lines: list[str], max_lines: int) -> tuple[list[str], int]:
    if max_lines <= 0 or len(diff_lines) <= max_lines:
        return diff_lines, 0
    truncated = len(diff_lines) - max_lines
    return diff_lines[:max_lines], truncated


def render_comment(
    *,
    title: str,
    repo: str,
    pr_number: int,
    reference_path: Path,
    implementation_path: Path,
    reference_label: str,
    implementation_label: str,
    diff_lines: list[str],
    max_diff_lines: int,
) -> str:
    additions, removals, hunks = summarize_diff(diff_lines)
    visible_diff, truncated_count = truncate_diff(diff_lines, max_diff_lines)
    diff_exists = bool(diff_lines)

    lines = [
        f"## {title}",
        "",
        f"- Repository: `{repo}`",
        f"- PR: `#{pr_number}`",
        f"- Reference: `{reference_label}` (`{reference_path}`)",
        f"- Implementation: `{implementation_label}` (`{implementation_path}`)",
    ]

    if diff_exists:
        lines.extend(
            [
                f"- Added lines: `{additions}`",
                f"- Removed lines: `{removals}`",
                f"- Hunks: `{hunks}`",
                "",
                "### Diff",
                "",
                "```diff",
                *visible_diff,
                "```",
            ]
        )
        if truncated_count:
            lines.extend(
                [
                    "",
                    f"_Diff was truncated. `{truncated_count}` lines were omitted. Increase `--max-diff-lines` if needed._",
                ]
            )
    else:
        lines.extend(
            [
                "",
                "差分はありませんでした。",
            ]
        )

    return "\n".join(lines) + "\n"


def ensure_prerequisites(reference_path: Path, implementation_path: Path, dry_run: bool) -> None:
    missing = [str(path) for path in (reference_path, implementation_path) if not path.is_file()]
    if missing:
        raise SystemExit(f"Input file not found: {', '.join(missing)}")
    if not dry_run and shutil.which("gh") is None:
        raise SystemExit("`gh` command not found")


def get_pr_head_sha(repo: str, pr_number: int) -> str:
    result = subprocess.run(
        ["gh", "pr", "view", str(pr_number), "--repo", repo, "--json", "headRefOid", "--jq", ".headRefOid"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def post_review_comment(
    repo: str,
    pr_number: int,
    body: str,
    comment_path: str,
    line: int,
    side: str,
) -> None:
    commit_id = get_pr_head_sha(repo, pr_number)
    subprocess.run(
        [
            "gh",
            "api",
            f"repos/{repo}/pulls/{pr_number}/comments",
            "--method",
            "POST",
            "-f",
            f"body={body}",
            "-f",
            f"commit_id={commit_id}",
            "-f",
            f"path={comment_path}",
            "-F",
            f"line={line}",
            "-f",
            f"side={side}",
        ],
        check=True,
    )


def main() -> int:
    args = parse_args()
    reference_path = Path(args.reference_path).expanduser().resolve()
    implementation_path = Path(args.implementation_path).expanduser().resolve()
    ensure_prerequisites(reference_path, implementation_path, args.dry_run)

    reference_label = args.reference_label or reference_path.name
    implementation_label = args.implementation_label or implementation_path.name

    diff_lines = build_diff(
        read_text(reference_path),
        read_text(implementation_path),
        reference_label,
        implementation_label,
    )
    body = render_comment(
        title=args.title,
        repo=args.repo,
        pr_number=args.pr,
        reference_path=reference_path,
        implementation_path=implementation_path,
        reference_label=reference_label,
        implementation_label=implementation_label,
        diff_lines=diff_lines,
        max_diff_lines=args.max_diff_lines,
    )

    if args.dry_run:
        sys.stdout.write(body)
        return 0

    post_review_comment(
        args.repo,
        args.pr,
        body,
        args.comment_path,
        args.line,
        args.side,
    )
    print(
        f"Posted review comment to {args.repo} PR #{args.pr} at {args.comment_path}:{args.line} ({args.side})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
