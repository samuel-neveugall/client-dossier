#!/usr/bin/env bash
# tests/test-ingest-fetch.sh — INGEST-01 (URL accepted) and decision D-02:
# `file_source.py fetch URL` downloads a URL as-is (standard library, no
# cookies, no authentication, no proxy) into a staging folder OUTSIDE the
# dossier; the filing form then files the staged file. Plan 04-01.
#
# Security guard-rails asserted (RESEARCH Security Domain, threats T-04-01 to
# T-04-06, T-04-12): only http and https, no userinfo, every resolved address
# of the host and of every redirect hop globally routable BEFORE any
# connection, at most 5 redirects, an explicit opener without proxy, file,
# ftp or data handlers, a byte cap, a total deadline, no query string in the
# JSON, partial downloads removed.
#
# No case reaches the real network: the URL cases run in one python3 program
# against a local http.server on 127.0.0.1 (the program patches is_public to
# accept only that literal, and getaddrinfo to fail for the unresolvable
# case). Every assertion is one `label<TAB>expected<TAB>actual` line printed
# by the program and turned into one assert_eq here. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fs_script() {
  echo "$REPO_ROOT/skills/dossier-ingest/scripts/file_source.py"
}

FS_OUT=""
FS_ERR=""
FS_STATUS=0

ERRDIR="$(mktemp -d)"
trap 'rm -rf "$ERRDIR"' EXIT

# run_fs DIR ARG... — the script run as a subprocess from DIR (for the cases
# that need a real process environment: TMPDIR, no dossier upward). stderr
# goes through a file under ERRDIR, outside every dossier.
run_fs() {
  local dir="$1" err_file="$ERRDIR/err"
  shift
  FS_STATUS=0
  FS_OUT="$(cd "$dir" && python3 "$(fs_script)" "$@" 2>"$err_file")" || FS_STATUS=$?
  FS_ERR="$(cat "$err_file")"
}

fs_field() {
  printf '%s' "$FS_OUT" | python3 -c 'import json, sys
text = sys.stdin.read()
try:
    value = json.loads(text)
    if not isinstance(value, dict):
        raise ValueError("not an object")
except Exception:
    print("invalid")
    sys.exit(0)
v = value.get(sys.argv[1], "none")
print(json.dumps(v) if isinstance(v, (list, dict)) else v)' "$1"
}

d="$(scratch_repo)"
python3 "$(init_py)" --target "$d" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1

# ---------------------------------------------------------------------------
echo '--- Process-level cases: no dossier, TMPDIR inside the dossier ---'

nodossier="$(mktemp -d)"
run_fs "$nodossier" fetch 'https://example.com/a.pdf'
assert_eq 2 "$FS_STATUS" 'fetch outside any dossier: exit 2'
assert_eq no_dossier "$(fs_field error)" 'fetch outside any dossier: no_dossier'
assert_eq '' "$FS_ERR" 'fetch outside any dossier: empty stderr'
rm -rf "$nodossier"

mkdir -p "$d/tmp"
TMPDIR="$d/tmp" run_fs "$d" fetch 'https://example.com/a.pdf'
assert_eq 1 "$FS_STATUS" 'fetch with TMPDIR inside the dossier: exit 1'
assert_eq staging_inside_dossier "$(fs_field error)" 'fetch with TMPDIR inside the dossier: staging_inside_dossier'
assert_eq 0 "$(ls -A "$d/tmp" | wc -l | tr -d ' ')" 'fetch with TMPDIR inside the dossier: nothing left behind'

run_fs "$d" fetch
assert_eq 1 "$FS_STATUS" 'fetch without a URL: exit 1'
assert_eq usage "$(fs_field error)" 'fetch without a URL: usage'

# ---------------------------------------------------------------------------
echo '--- URL cases against a local server, the network patched out ---'

PROG_OUT="$(python3 -B - "$(fs_script)" "$d" <<'PY'
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import shutil
import socket
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

script, dossier = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("file_source", script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
os.chdir(dossier)
real_dossier = os.path.realpath(dossier)
tmpbase = os.path.realpath(tempfile.mkdtemp())
tempfile.tempdir = tmpbase  # staging area, outside the dossier

HINT = "Download it manually and re-run on the local file."
PDF = b"%PDF-1.4\n" + b"fake pdf bytes\n" * 20
VTT = b"WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhello\n"
SRT = b"1\n00:00:01,000 --> 00:00:02,000\nhello\n"
HTML = b"<html><body><form>Please log in</form></body></html>"
SEEN = []
PDF_ROUTE = "/files/Brochure%202026.pdf"
rows = []


def check(label, expected, actual):
    rows.append((label, expected, actual))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):
        pass

    def reply(self, code, ctype, body, extra=()):
        self.send_response(code)
        if ctype:
            self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for key, value in extra:
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        SEEN.append(dict(self.headers))
        path = self.path.split("?")[0]
        port = self.server.server_address[1]
        try:
            if path == PDF_ROUTE:
                self.reply(200, "application/pdf; qs=1", PDF)
            elif path == "/call":
                self.reply(200, "text/vtt", VTT)
            elif path == "/sub.srt":
                self.reply(200, "application/octet-stream", SRT)
            elif path == "/blob":
                self.reply(200, "application/octet-stream", b"\x00\x01\x02binary")
            elif path == "/login":
                self.reply(200, "text/html; charset=utf-8", HTML)
            elif path == "/redir-localhost":
                self.reply(302, None, b"", [("Location", "http://localhost:%d%s" % (port, PDF_ROUTE))])
            elif path == "/redir-file":
                self.reply(302, None, b"", [("Location", "file:///etc/passwd")])
            elif path == "/redir-ok":
                self.reply(302, None, b"", [("Location", PDF_ROUTE)])
            elif path.startswith("/chain/"):
                n = int(path.rsplit("/", 1)[1])
                if n >= 6:
                    self.reply(200, "application/pdf", PDF)
                else:
                    self.reply(302, None, b"", [("Location", "/chain/%d" % (n + 1))])
            elif path == "/forbidden":
                self.reply(403, "text/plain", b"no")
            elif path == "/big":
                self.reply(200, "application/pdf", b"x" * 10000)
            elif path == "/big-nolength":
                self.send_response(200)
                self.send_header("Content-Type", "application/pdf")
                self.end_headers()
                self.wfile.write(b"x" * 10000)
            elif path == "/slow":
                self.send_response(200)
                self.send_header("Content-Type", "application/pdf")
                self.send_header("Content-Length", "200")
                self.end_headers()
                for _ in range(200):
                    self.wfile.write(b"x")
                    self.wfile.flush()
                    time.sleep(0.1)
            else:
                self.reply(404, "text/plain", b"missing")
        except (BrokenPipeError, ConnectionResetError):
            pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
server.daemon_threads = True
PORT = server.server_address[1]
threading.Thread(target=server.serve_forever, daemon=True).start()


def run(argv):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = mod.main(argv)
    text = buf.getvalue()
    try:
        obj = json.loads(text)
    except ValueError:
        obj = {"_invalid": text}
    return code, obj, text


def url(route):
    return "http://127.0.0.1:%d%s" % (PORT, route)


def staged_dirs():
    return sorted(os.listdir(tmpbase))


# --- refusals before any connection --------------------------------------
orig_make_opener = mod.make_opener
calls = []


def forbidden_opener():
    calls.append(1)
    raise AssertionError("an opener was built for a refused URL")


mod.make_opener = forbidden_opener

refused = [
    ("file scheme", "file:///etc/passwd", "bad_url"),
    ("ftp scheme", "ftp://example.com/a.pdf", "bad_url"),
    ("data scheme", "data:text/plain,hi", "bad_url"),
    ("userinfo", "https://user:pw@example.com/a.pdf", "bad_url"),
    ("loopback", "http://127.0.0.1:9/a.pdf", "not_public"),
    ("link-local metadata", "http://169.254.169.254/latest/meta-data/", "not_public"),
    ("RFC 1918", "http://10.0.0.1/a.pdf", "not_public"),
    ("CGNAT", "http://100.64.0.1/a.pdf", "not_public"),
    ("IPv6 loopback", "http://[::1]/a.pdf", "not_public"),
    ("IPv4-mapped loopback", "http://[::ffff:127.0.0.1]/a.pdf", "not_public"),
    ("localhost", "http://localhost/a.pdf", "not_public"),
]
before = staged_dirs()
for label, target, code_wanted in refused:
    code, obj, text = run(["fetch", target])
    check("refused " + label + ": exit", 1, code)
    check("refused " + label + ": error", code_wanted, obj.get("error"))
    check("refused " + label + ": hint", HINT, obj.get("hint"))

real_gai = socket.getaddrinfo


def no_dns(*args, **kwargs):
    raise socket.gaierror(8, "nodename nor servname provided")


socket.getaddrinfo = no_dns
try:
    code, obj, text = run(["fetch", "http://no-such-host.invalid/a.pdf"])
finally:
    socket.getaddrinfo = real_gai
check("refused unresolvable: exit", 1, code)
check("refused unresolvable: error", "unresolvable", obj.get("error"))
check("refused unresolvable: hint", HINT, obj.get("hint"))
check("refusals: the opener was never built", 0, len(calls))
check("refusals: nothing staged", before, staged_dirs())

# --- the opener ------------------------------------------------------------
mod.make_opener = orig_make_opener
mod.is_public = lambda host: host == "127.0.0.1"

handlers = sorted(type(h).__name__ for h in mod.make_opener().handlers)
check(
    "opener handlers are exactly the five",
    sorted([
        "HTTPHandler",
        "HTTPSHandler",
        "HTTPDefaultErrorHandler",
        mod.SafeRedirect.__name__,
        "HTTPErrorProcessor",
    ]),
    handlers,
)
check("SafeRedirect is an HTTPRedirectHandler", True,
      issubclass(mod.SafeRedirect, mod.urllib.request.HTTPRedirectHandler))
check("redirect bound is 5", 5, mod.SafeRedirect.max_redirections)

# --- successful downloads --------------------------------------------------
code, obj, text = run(["fetch", url(PDF_ROUTE + "?token=SECRET")])
check("pdf: exit", 0, code)
check("pdf: status", "fetched", obj.get("status"))
check("pdf: ext from the content type (parameters ignored)", ".pdf", obj.get("ext"))
check("pdf: bytes", len(PDF), obj.get("bytes"))
check("pdf: sha256", hashlib.sha256(PDF).hexdigest(), obj.get("sha256"))
check("pdf: final_url_host", "127.0.0.1", obj.get("final_url_host"))
check("pdf: suggested_slug from the last path segment", "brochure-2026", obj.get("suggested_slug"))
check("pdf: the query string is never echoed", False, "SECRET" in text)
check("pdf: ASCII only", True, all(ord(c) < 128 for c in text))
staged = obj.get("path", "")
real_staged = os.path.realpath(staged)
check("pdf: staged path is absolute", True, os.path.isabs(staged))
check("pdf: staged file exists", True, os.path.isfile(staged))
check("pdf: staged bytes", PDF, open(staged, "rb").read() if os.path.isfile(staged) else None)
check("pdf: staged outside the dossier", False,
      real_staged == real_dossier or real_staged.startswith(real_dossier + os.sep))
check("pdf: staged in a fresh fetch directory", True,
      os.path.basename(os.path.dirname(real_staged)).startswith("client-dossier-fetch-")
      and os.path.dirname(os.path.dirname(real_staged)) == tmpbase)
req = SEEN[-1]
check("request: User-Agent", True, req.get("User-Agent", "").startswith("client-dossier"))
check("request: Accept-Encoding", "identity", req.get("Accept-Encoding"))
check("request: no cookie", False, "Cookie" in req)
check("request: no authorization", False, "Authorization" in req)

code, obj, text = run(["fetch", url("/call")])
check("vtt: ext from text/vtt", ".vtt", obj.get("ext"))
code, obj, text = run(["fetch", url("/sub.srt")])
check("srt: ext from the URL path when the type is unknown", ".srt", obj.get("ext"))
code, obj, text = run(["fetch", url("/blob")])
check("blob: neither gives .bin", ".bin", obj.get("ext"))
code, obj, text = run(["fetch", url("/login")])
check("login-like html: staged, the skill decides", "fetched", obj.get("status"))
check("login-like html: ext", ".html", obj.get("ext"))

# --- redirects ---------------------------------------------------------------
before = staged_dirs()
for label, route in (("to localhost", "/redir-localhost"), ("to file://", "/redir-file"), ("6 hops", "/chain/0")):
    code, obj, text = run(["fetch", url(route)])
    check("redirect " + label + ": exit", 1, code)
    check("redirect " + label + ": error", "redirect_refused", obj.get("error"))
    check("redirect " + label + ": hint", HINT, obj.get("hint"))
check("refused redirects: nothing staged", before, staged_dirs())
code, obj, text = run(["fetch", url("/redir-ok")])
check("single redirect to an allowed URL: followed", "fetched", obj.get("status"))
check("single redirect: bytes", len(PDF), obj.get("bytes"))

# --- errors, caps, deadline ---------------------------------------------------
before = staged_dirs()
code, obj, text = run(["fetch", url("/forbidden?token=SECRET")])
check("403: exit", 1, code)
check("403: error", "http_403", obj.get("error"))
check("403: hint", HINT, obj.get("hint"))
check("403: the query string is never echoed", False, "SECRET" in text)
code, obj, text = run(["fetch", url("/missing")])
check("404: error", "http_404", obj.get("error"))

mod.FETCH_MAX_BYTES = 1000
code, obj, text = run(["fetch", url("/big")])
check("too large (Content-Length): error", "too_large", obj.get("error"))
check("too large (Content-Length): hint", HINT, obj.get("hint"))
code, obj, text = run(["fetch", url("/big-nolength")])
check("too large (streamed): error", "too_large", obj.get("error"))
mod.FETCH_MAX_BYTES = 100 * 1024 * 1024

mod.FETCH_DEADLINE_SECONDS = 0.3
started = time.monotonic()
code, obj, text = run(["fetch", url("/slow")])
elapsed = time.monotonic() - started
mod.FETCH_DEADLINE_SECONDS = 120
check("slow: error", "timeout", obj.get("error"))
check("slow: hint", HINT, obj.get("hint"))
check("slow: stopped well before the body ended", True, elapsed < 5)
check("errors: no staged file or directory left", before, staged_dirs())

# --- the filing form takes the staged file --------------------------------------
code, obj, text = run(["fetch", url(PDF_ROUTE)])
staged = obj.get("path", "")
code, filed, text = run(["--kind", "received", "--date", "2026-10-01", "--slug", "brochure", staged])
check("filing the staged file: exit", 0, code)
check("filing the staged file: status", "filed", filed.get("status"))
check("filing the staged file: path", "sources/received/2026-10-01_brochure.pdf", filed.get("path"))
check("filing the staged file: bytes on disk", PDF,
      open("sources/received/2026-10-01_brochure.pdf", "rb").read())
code, obj, text = run(["fetch", url(PDF_ROUTE)])
code, again, text = run(["--kind", "received", "--date", "2026-10-02", "--slug", "again", obj.get("path", "")])
check("second fetch + file of the same bytes: status", "already_filed", again.get("status"))
check("second fetch + file: names the first file", "sources/received/2026-10-01_brochure.pdf", again.get("path"))

shutil.rmtree(tmpbase, ignore_errors=True)
server.shutdown()
for label, expected, actual in rows:
    print("%s\t%s\t%s" % (label, expected, actual))
PY
)"

if [ -z "$PROG_OUT" ]; then
  echo 'FAIL: the python program printed nothing (it crashed before its assertions)' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

while IFS="$(printf '\t')" read -r label expected actual; do
  [ -n "$label" ] || continue
  assert_eq "$expected" "$actual" "$label"
done <<EOF
$PROG_OUT
EOF

# ---------------------------------------------------------------------------
echo '--- Everything stayed outside sources/ except the one filed brochure ---'

COUNT="$(find "$d/sources" -type f ! -name .gitkeep ! -path "$d/sources/README.md" | wc -l | tr -d ' ')"
assert_eq 1 "$COUNT" 'only the brochure was filed under sources/'

finish
