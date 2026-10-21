import json
import os
import subprocess
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
LINTO = str(ROOT / "bin" / "linto")
TOKEN = "memos_pat_test"


class FakeMemos(BaseHTTPRequestHandler):
    memos = {}
    requests = []

    def log_message(self, *args):
        pass

    def reply(self, status, payload=None):
        body = json.dumps(payload if payload is not None else {}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_any(self):
        url = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(url.query).items()}
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length)) if length else None
        type(self).requests.append((self.command, url.path, query, body))
        if self.headers.get("Authorization") != f"Bearer {TOKEN}":
            return self.reply(401, {"message": "unauthenticated"})
        parts = url.path.strip("/").split("/")
        if parts[:3] != ["api", "v1", "memos"]:
            return self.reply(404, {"message": "not found"})
        if len(parts) == 3:
            if self.command == "POST":
                name = f"memos/{len(self.memos) + 1}"
                self.memos[name] = {"name": name, "visibility": "PRIVATE", "createTime": "2026-01-01T10:00:00Z", **body}
                return self.reply(200, self.memos[name])
            ordered = list(self.memos.values())
            start = int(query.get("pageToken") or 0)
            size = int(query.get("pageSize") or 50)
            page = ordered[start:start + size]
            nxt = str(start + size) if start + size < len(ordered) else ""
            return self.reply(200, {"memos": page, "nextPageToken": nxt})
        name = "/".join(parts[2:4])
        memo = self.memos.get(name)
        if memo is None:
            return self.reply(404, {"message": "memo not found"})
        if self.command == "GET":
            return self.reply(200, memo)
        if self.command == "PATCH":
            memo.update(body)
            return self.reply(200, memo)
        if self.command == "DELETE":
            del self.memos[name]
            return self.reply(200, {})

    do_GET = do_POST = do_PATCH = do_DELETE = handle_any


class MemosTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), FakeMemos)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        FakeMemos.memos = {}
        FakeMemos.requests = []

    def memos(self, *args, token=TOKEN, stdin=None):
        env = dict(os.environ, LC_ALL="C", LINTO_MEMOS_URL=f"http://127.0.0.1:{self.server.server_port}",
                   NO_PROXY="127.0.0.1", no_proxy="127.0.0.1", TZ="UTC")
        env["LINTO_MEMOS_TOKEN"] = token
        return subprocess.run([LINTO, "web", "memos", *args], capture_output=True, text=True, env=env,
                              input=stdin if stdin is not None else "", timeout=30)

    def test_add_list_get_edit_delete(self):
        added = self.memos("add", "-v", "public", "First #idea", "line")
        self.assertEqual((added.returncode, added.stdout.strip()), (0, "memos/1"), added.stderr)
        self.assertEqual(FakeMemos.requests[-1][3], {"content": "First #idea line", "visibility": "PUBLIC"})
        self.memos("add", stdin="From stdin\nsecond line\n")
        listed = self.memos("list")
        self.assertIn("First #idea line", listed.stdout)
        self.assertIn("From stdin", listed.stdout)
        shown = self.memos("get", "memos/2")
        self.assertIn("second line", shown.stdout)
        edited = self.memos("edit", "2", "New text")
        self.assertEqual(edited.returncode, 0, edited.stderr)
        method, path, query, body = FakeMemos.requests[-1]
        self.assertEqual((method, path, query["updateMask"], body), ("PATCH", "/api/v1/memos/2", "content", {"content": "New text"}))
        self.assertEqual(self.memos("delete", "2", "--yes").returncode, 0)
        self.assertEqual(self.memos("get", "2").returncode, 1)

    def seed(self, stamps):
        for i, stamp in enumerate(stamps, 1):
            FakeMemos.memos[f"memos/{i * 100 + 7}"] = {
                "name": f"memos/{i * 100 + 7}", "content": f"memo {i}", "visibility": "PRIVATE", "createTime": stamp}

    def test_get_by_position_from_the_top(self):
        self.seed(["2026-03-02T10:00:00Z", "2026-03-01T10:00:00Z", "2026-02-28T10:00:00Z"])
        self.assertIn("memo 1", self.memos("get", "0").stdout)
        self.assertIn("memo 3", self.memos("get", "2").stdout)
        missing = self.memos("get", "3")
        self.assertEqual(missing.returncode, 1)
        self.assertIn("no memo at position 3", missing.stderr)

    def test_get_by_day_and_number(self):
        self.seed(["2026-03-02T09:00:00Z", "2026-03-01T18:00:00Z", "2026-03-01T08:00:00Z", "2026-02-28T10:00:00Z"])
        self.assertIn("memo 3", self.memos("get", "2026-03-01-00").stdout)
        self.assertIn("memo 2", self.memos("get", "2026-03-01-01").stdout)
        missing = self.memos("get", "2026-03-01-02")
        self.assertEqual(missing.returncode, 1)
        self.assertIn("2 that day", missing.stderr)
        self.assertIn("invalid date", self.memos("get", "2026-13-01-00").stderr)

    def test_get_renders_with_the_configured_markdown_viewer(self):
        import tempfile
        self.seed(["2026-03-02T10:00:00Z"])
        with tempfile.TemporaryDirectory() as home:
            viewer = Path(home) / "fakeview"
            viewer.write_text("#!/bin/sh\nprintf '<<'; cat; printf '>>\\n'\n")
            viewer.chmod(0o755)
            config = Path(home) / ".config" / "linto"
            config.mkdir(parents=True)
            (config / "config.yml").write_text(f'groups:\n  web:\n    configdata:\n      markdown:\n        - no-such-viewer-xyz\n        - "{viewer} --x"\n')
            env = dict(os.environ, LC_ALL="C", LINTO_MEMOS_URL=f"http://127.0.0.1:{self.server.server_port}",
                       LINTO_MEMOS_TOKEN=TOKEN, NO_PROXY="127.0.0.1", no_proxy="127.0.0.1", TZ="UTC",
                       HOME=home, XDG_CONFIG_HOME=str(Path(home) / ".config"))
            run = lambda *a: subprocess.run([LINTO, "web", "memos", "get", "0", *a], capture_output=True, text=True, env=env)
            self.assertIn("<<memo 1>>", run("--markdown").stdout)
            self.assertNotIn("<<", run().stdout)              # not a terminal: plain text
            self.assertNotIn("<<", run("--no-markdown").stdout)

    def test_markdown_command_picks_the_first_installed_viewer(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("memos_mod", ROOT / "groups" / "web" / "lib" / "memos.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.group_configdata = lambda group: {"markdown": ["no-such-viewer-xyz", "sh -c 'cat'", "cat"]}
        self.assertEqual(module.markdown_command(), ["sh", "-c", "cat"])
        module.group_configdata = lambda group: {"markdown": "no-such-viewer-xyz"}
        self.assertIsNone(module.markdown_command())

    def test_get_by_id_still_works(self):
        self.seed(["2026-03-02T10:00:00Z"])
        self.assertIn("memo 1", self.memos("get", "memos/107").stdout)
        self.assertIn("memo 1", self.memos("get", "107").stdout)

    def test_list_filters_and_pagination(self):
        for i in range(5):
            self.memos("add", f"memo {i}")
        listed = self.memos("list", "-n", "4", "-t", "idea", "-q", 'a"b', "--json")
        self.assertEqual(len(json.loads(listed.stdout)), 4)
        requests = [r for r in FakeMemos.requests if r[0] == "GET"]
        self.assertEqual(requests[0][2]["filter"], 'tag in ["idea"] && content.contains("a\\"b")')

    def test_authentication_error_is_reported(self):
        result = self.memos("list", token="wrong")
        self.assertEqual(result.returncode, 1)
        self.assertIn("HTTP 401: unauthenticated", result.stderr)

    def test_missing_configuration(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("LINTO_MEMOS")}
        result = subprocess.run([LINTO, "web", "memos", "list"], capture_output=True, text=True,
                                env=dict(env, LC_ALL="C", XDG_CONFIG_HOME="/nonexistent", LINTO_MEMOS_URL=""))
        self.assertEqual(result.returncode, 1)
        self.assertIn("no Memos server", result.stderr)

    def test_delete_needs_confirmation_without_a_terminal(self):
        self.memos("add", "x")
        self.assertEqual(self.memos("delete", "1").returncode, 2)


if __name__ == "__main__":
    unittest.main()
