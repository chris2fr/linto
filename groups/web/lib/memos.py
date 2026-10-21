#!/usr/bin/env python3
"""Talk to a Memos server (usememos) through its REST API v1.

Usage: memos.py ACTION [OPTIONS]   (ACTION: list, get, add, edit, delete)
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail, group_configdata  # noqa: E402

PROG = "memos"
VISIBILITIES = ("PRIVATE", "PROTECTED", "PUBLIC")
ACTIONS = ("list", "get", "add", "edit", "delete")


class MemosError(Exception):
    pass


# ------------------------------------------------------------------ connection
def settings():
    """(base URL, token) from the environment, then groups.web.configdata.memos."""
    conf = group_configdata("web").get("memos") or {}
    url = os.environ["LINTO_MEMOS_URL"] if "LINTO_MEMOS_URL" in os.environ else conf.get("url") or ""
    token = os.environ.get("LINTO_MEMOS_TOKEN") or ""
    token_file = conf.get("token-file") or ""
    if not token and token_file:
        try:
            token = Path(token_file).expanduser().read_text(encoding="utf-8").strip()
        except OSError as exc:
            raise MemosError(_("cannot read the token file {}: {}").format(token_file, exc.strerror or exc))
    if not url:
        raise MemosError(_("no Memos server: set LINTO_MEMOS_URL or groups.web.configdata.memos.url"))
    if not token:
        raise MemosError(_("no access token: set LINTO_MEMOS_TOKEN or groups.web.configdata.memos.token-file"))
    return url.rstrip("/"), token


def request(method, path, body=None, query=None):
    """Call the API and return the decoded JSON (None for an empty reply)."""
    base, token = settings()
    url = f"{base}/api/v1/{path}"
    if query:
        url += "?" + urllib.parse.urlencode({k: v for k, v in query.items() if v not in (None, "")})
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}", "Accept": "application/json",
        **({"Content-Type": "application/json"} if data is not None else {})})
    try:
        with urllib.request.urlopen(req, timeout=20) as reply:
            raw = reply.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace").strip()
        try:
            detail = json.loads(detail).get("message", detail)
        except (ValueError, AttributeError):
            pass
        raise MemosError(_("the server answered HTTP {}: {}").format(exc.code, detail or exc.reason))
    except (urllib.error.URLError, OSError) as exc:
        raise MemosError(_("cannot reach {}: {}").format(base, getattr(exc, "reason", exc)))
    return json.loads(raw) if raw.strip() else None


def memo_id(text):
    """"123", "memos/123" -> "123"."""
    ident = text.strip().rstrip("/").split("/")[-1]
    if not ident:
        raise MemosError(_("invalid memo id: {}").format(text))
    return ident


# ------------------------------------------------------------------ helpers
def read_text(parser, words):
    if words:
        return " ".join(words)
    if sys.stdin.isatty():
        parser.error(_("no text: give TEXT or provide stdin"))
    return sys.stdin.read().rstrip("\n")


def cel_string(value):
    return json.dumps(value, ensure_ascii=False)


def build_filter(tags, search, visibility):
    parts = []
    for tag in tags or []:
        parts.append(f"tag in [{cel_string(tag)}]")
    if search:
        parts.append(f"content.contains({cel_string(search)})")
    if visibility:
        parts.append(f"visibility == {cel_string(visibility)}")
    return " && ".join(parts)


def first_line(content, width=70):
    line = next((l.strip() for l in content.splitlines() if l.strip()), "")
    return line if len(line) <= width else line[: width - 1] + "…"


def short_id(memo):
    return str(memo.get("name", "")).split("/")[-1]


def print_memo(memo):
    tags = " ".join("#" + t for t in memo.get("tags") or [])
    head = f"{memo.get('name', '')}  {memo.get('visibility', '')}  {str(memo.get('createTime', ''))[:19]}"
    print(head + (f"  {tags}" if tags else "") + ("  ★" if memo.get("pinned") else ""))
    print()
    print(memo.get("content", ""))


# ------------------------------------------------------------------ actions
def do_list(argv):
    p = Parser("web", "memos list", description=_("List memos, newest first."))
    p.add_argument("-t", "--tag", action="append", default=[], metavar="TAG", help=_("only memos with this tag (repeatable)"))
    p.add_argument("-q", "--search", metavar="TEXT", help=_("only memos whose content contains TEXT"))
    p.add_argument("--visibility", type=str.upper, choices=VISIBILITIES, metavar="LEVEL",
                   help=_("only PRIVATE, PROTECTED or PUBLIC memos"))
    p.add_argument("-n", "--limit", type=int, default=20, metavar="N", help=_("maximum number of memos (default: 20)"))
    p.add_argument("--json", action="store_true", help=_("print the memos as JSON"))
    args = p.parse_args(argv)
    if args.limit < 1:
        p.error(_("--limit must be at least 1"))
    memos, token = [], None
    while len(memos) < args.limit:
        reply = request("GET", "memos", query={
            "pageSize": min(args.limit - len(memos), 100), "pageToken": token,
            "filter": build_filter(args.tag, args.search, args.visibility)}) or {}
        memos += reply.get("memos") or reply.get("data") or []
        token = reply.get("nextPageToken")
        if not token:
            break
    memos = memos[: args.limit]
    if args.json:
        print(json.dumps(memos, ensure_ascii=False, indent=2))
    else:
        for memo in memos:
            print(f"{short_id(memo):>6}  {memo.get('visibility', '')[:4]:<4}  "
                  f"{str(memo.get('createTime', ''))[:10]}  {first_line(memo.get('content', ''))}")
    return 0


def do_get(argv):
    p = Parser("web", "memos get", description=_("Show one memo."))
    p.add_argument("id", metavar="ID")
    p.add_argument("--json", action="store_true", help=_("print the memo as JSON"))
    args = p.parse_args(argv)
    memo = request("GET", f"memos/{memo_id(args.id)}")
    if args.json:
        print(json.dumps(memo, ensure_ascii=False, indent=2))
    else:
        print_memo(memo)
    return 0


def do_add(argv):
    p = Parser("web", "memos add", description=_("Create a memo from TEXT or standard input."))
    p.add_argument("-v", "--visibility", type=str.upper, choices=VISIBILITIES, default="PRIVATE", metavar="LEVEL",
                   help=_("PRIVATE, PROTECTED or PUBLIC (default: PRIVATE)"))
    p.add_argument("text", nargs="*", metavar="TEXT", help=_("memo content (default: read standard input)"))
    args = p.parse_args(argv)
    content = read_text(p, args.text)
    if not content.strip():
        p.error(_("the memo is empty"))
    memo = request("POST", "memos", {"content": content, "visibility": args.visibility})
    print(memo.get("name", ""))
    return 0


def do_edit(argv):
    p = Parser("web", "memos edit", description=_("Replace the content of a memo with TEXT or standard input."))
    p.add_argument("-v", "--visibility", type=str.upper, choices=VISIBILITIES, metavar="LEVEL",
                   help=_("also change the visibility"))
    p.add_argument("id", metavar="ID")
    p.add_argument("text", nargs="*", metavar="TEXT", help=_("new content (default: read standard input)"))
    args = p.parse_args(argv)
    content = read_text(p, args.text)
    if not content.strip():
        p.error(_("the memo is empty"))
    body, mask = {"content": content}, ["content"]
    if args.visibility:
        body["visibility"] = args.visibility
        mask.append("visibility")
    memo = request("PATCH", f"memos/{memo_id(args.id)}", body, query={"updateMask": ",".join(mask)})
    print(memo.get("name", ""))
    return 0


def do_delete(argv):
    p = Parser("web", "memos delete", description=_("Delete a memo."))
    p.add_argument("-y", "--yes", action="store_true", help=_("do not ask for confirmation"))
    p.add_argument("id", metavar="ID")
    args = p.parse_args(argv)
    ident = memo_id(args.id)
    if not args.yes:
        if not sys.stdin.isatty():
            p.error(_("refusing to delete without confirmation: use --yes"))
        shown = first_line(request("GET", f"memos/{ident}").get("content", ""))
        if input(_("Delete memo {} ({})? [y/N] ").format(ident, shown)).strip().lower() not in ("y", "yes", "o", "oui"):
            return 1
    request("DELETE", f"memos/{ident}")
    print(_("deleted memos/{}").format(ident), file=sys.stderr)
    return 0


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        p = Parser("web", PROG, description=_("Work with a Memos server (usememos)."), raw=True,
                   epilog=_("""Actions:
  list     List memos, newest first.
  get      Show one memo.
  add      Create a memo from TEXT or standard input.
  edit     Replace the content of a memo.
  delete   Delete a memo.

Run linto web memos ACTION --help for an action's options.

Connection: set the server in groups.web.configdata.memos.url (or
LINTO_MEMOS_URL) and a personal access token in
groups.web.configdata.memos.token-file (or LINTO_MEMOS_TOKEN)."""))
        p.add_argument("action", choices=ACTIONS, help=_("what to do"))
        if argv:
            p.parse_args(argv)
        p.print_help(sys.stderr)
        return 2
    action, rest = argv[0], argv[1:]
    if action not in ACTIONS:
        Parser("web", PROG).error(_("unknown action: {}").format(action))
    try:
        return globals()[f"do_{action}"](rest)
    except MemosError as exc:
        return fail(PROG, str(exc))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
