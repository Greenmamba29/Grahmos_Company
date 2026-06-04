#!/usr/bin/env python3

import argparse
import json
import os
import sys
from pathlib import Path


def build_comment_body(args: argparse.Namespace) -> str:
    lines = [
        "Blocked.",
        "",
        f"Unblock owner: {args.owner}",
        f"Unblock action: {args.action}",
    ]

    if args.reason:
        lines.extend(["", f"Reason: {args.reason}"])

    if args.evidence:
        lines.extend(["", "Evidence:"])
        for item in args.evidence:
            lines.append(f"- {item}")

    return "\n".join(lines).rstrip() + "\n"


def build_comment_payload(args: argparse.Namespace) -> dict:
    payload = {"body": build_comment_body(args)}
    if args.resume:
        payload["resume"] = True
    return payload


def build_status_payload(args: argparse.Namespace) -> dict:
    payload = {"status": "blocked"}
    if args.resume:
        payload["resume"] = True
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Generate Paperclip issue comment/update payloads for a blocked "
            "disposition. This is intended for use once an authenticated "
            "browser session, MCP tool, or another supported API auth path is "
            "available."
        )
    )
    parser.add_argument("issue_id", help="Paperclip issue UUID or identifier")
    parser.add_argument(
        "--owner",
        default="Paperclip board admin/operator",
        help="Named unblock owner to record in the task comment",
    )
    parser.add_argument(
        "--action",
        default=(
            "Provide a supported authenticated automation path for cloud agents "
            "(browser session, MCP, or documented API auth)."
        ),
        help="Named unblock action to record in the task comment",
    )
    parser.add_argument(
        "--reason",
        default=(
            "Cloud-agent shell requests cannot update Paperclip issues because "
            "the instance requires board-authenticated session access."
        ),
        help="Short blocker reason to include in the generated comment",
    )
    parser.add_argument(
        "--evidence",
        action="append",
        default=[],
        help="Extra evidence bullet to include in the generated comment",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Include resume=true in generated payloads",
    )
    parser.add_argument(
        "--write-dir",
        default="",
        help="Optional directory to write JSON payload files into",
    )
    parser.add_argument(
        "--print-curl",
        action="store_true",
        help="Print example curl commands using PAPERCLIP_API_URL after payload generation",
    )
    args = parser.parse_args()

    comment_payload = build_comment_payload(args)
    status_payload = build_status_payload(args)

    print("Paperclip blocked update helper")
    print(f"  issue_id: {args.issue_id}")
    print()
    print("Comment payload:")
    print(json.dumps(comment_payload, indent=2))
    print()
    print("Status payload:")
    print(json.dumps(status_payload, indent=2))

    if args.write_dir:
        out_dir = Path(args.write_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        comment_path = out_dir / "paperclip-comment-payload.json"
        status_path = out_dir / "paperclip-status-payload.json"
        comment_path.write_text(json.dumps(comment_payload, indent=2) + "\n")
        status_path.write_text(json.dumps(status_payload, indent=2) + "\n")
        print()
        print(f"Wrote: {comment_path}")
        print(f"Wrote: {status_path}")

    if args.print_curl:
        api_url = os.getenv("PAPERCLIP_API_URL", "<PAPERCLIP_API_URL>")
        print()
        print("Example authenticated curl commands:")
        print(
            f"  curl -sS -X POST '{api_url}/api/issues/{args.issue_id}/comments' "
            "-H 'Content-Type: application/json' "
            "-b <cookie-jar> -c <cookie-jar> "
            f"--data @<(cat <<'JSON'\n{json.dumps(comment_payload, indent=2)}\nJSON\n)"
        )
        print(
            f"  curl -sS -X PATCH '{api_url}/api/issues/{args.issue_id}' "
            "-H 'Content-Type: application/json' "
            "-b <cookie-jar> -c <cookie-jar> "
            f"--data @<(cat <<'JSON'\n{json.dumps(status_payload, indent=2)}\nJSON\n)"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
