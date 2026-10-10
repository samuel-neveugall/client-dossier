#!/usr/bin/env python3
# vibeflow:allow-large-file -- one file on purpose: a bare-skills copy runs it
# by path, so a second importable module would turn sys.path into a
# distribution concern (DIST-03). Filing, dedup, containment and the safe URL
# fetch are one cohesive pass. Tracked in 04-01-SUMMARY.md.
"""File one source into a client-dossier repository's sources/ folder.

Mechanics tier only (spec principle: "skills carry the judgement, scripts
carry the mechanics"). Every input arrives as a command-line argument: this
script never prompts, never reads a TTY and starts no other process. Judgement
(which kind a source is, which content date and slug it gets, whether a
downloaded page is a login page) lives in skills/dossier-ingest/SKILL.md.

It is the only route a source takes into sources/: the Write and Edit tools
are denied there by hooks/guard-sources.py, so filing is this script's job.

Usage:
    file_source.py --kind received|transcript|raw [--date YYYY-MM-DD]
                   [--slug TEXT] PATH
    file_source.py fetch URL

The filing form copies a local file into sources/. The fetch form (D-02)
downloads a URL as-is (no cookies, no authentication, no proxy) into a
staging folder OUTSIDE the dossier and prints where; the skill reads the
staged file, then files it with the filing form, because the content date and
the kind are only known once the bytes have been read. The address validated
for a host is the address the connection is made to (pinned, A4-F2): the Host
header and the TLS server name stay those of the URL, so DNS cannot change
between the check and the connection.

Every path prints exactly one ASCII-only JSON object on stdout and exits
0 (filed), 1 (refused or failed), 2 (no dossier.yaml upward, as lint.py) or
3 (internal error).

Python 3 standard library only, targeting Python >= 3.8.
"""

import argparse
import datetime
import hashlib
import http.client
import ipaddress
import json
import os
import shutil
import signal
import socket
import stat
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONFIG_NAME = "dossier.yaml"
GITKEEP = ".gitkeep"

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_NO_DOSSIER = 2
EXIT_INTERNAL = 3

# D-07: the folder follows the kind the skill decided.
KIND_DIRS = {
    "received": "sources/received",
    "transcript": "sources/transcripts",
    "raw": "sources/transcripts/raw",
}

CHUNK = 1 << 16

# D-02 / T-04-06: bounds on a download.
MAX_REDIRECTS = 5
FETCH_TIMEOUT_SECONDS = 30
FETCH_DEADLINE_SECONDS = 120
FETCH_MAX_BYTES = 100 * 1024 * 1024
FETCH_STAGE_PREFIX = "client-dossier-fetch-"
USER_AGENT = "client-dossier"
DOWNLOAD_HINT = "Download it manually and re-run on the local file."
PURGE_NOTE = "after filing, remove the staging folder: rm -r '{stage}'"

# A fixed table, never `mimetypes`: the extension must not depend on the
# machine, and the Content-Disposition header is not read at all.
EXT_BY_TYPE = {
    "application/pdf": ".pdf",
    "text/plain": ".txt",
    "text/html": ".html",
    "application/json": ".json",
    "text/vtt": ".vtt",
    "application/x-subrip": ".srt",
    "message/rfc822": ".eml",
    "text/markdown": ".md",
    "text/csv": ".csv",
}

# GitHub refuses a file above 100 MiB; the result carries a warning above this.
LARGE_FILE_WARNING_BYTES = 100 * 1024 * 1024
SLUG_MAX = 60
EXT_MAX = 10
_DIGITS = "0123456789"
_SLUG_CHARS = "abcdefghijklmnopqrstuvwxyz" + _DIGITS


def find_root(start):
    """The nearest directory at or above `start` holding dossier.yaml.

    No stop condition (D-01, Q-4): a dossier legitimately lives inside a
    larger repository, so the walk does not stop at `.git`. Returns None
    when no dossier.yaml exists anywhere up to the filesystem root.
    """
    here = Path(os.path.realpath(start))
    if not here.is_dir():
        here = here.parent
    for candidate in (here,) + tuple(here.parents):
        if os.path.isfile(os.path.join(str(candidate), CONFIG_NAME)):
            return str(candidate)
    return None


class Refusal(Exception):
    """A refused or failed run, reported as a JSON error and an exit code."""

    def __init__(self, code, message, hint=None, status=EXIT_REFUSED):
        Exception.__init__(self, message)
        self.code = code
        self.message = message
        self.hint = hint
        self.status = status

    def result(self):
        out = {"status": "error", "error": self.code, "message": self.message}
        if self.hint:
            out["hint"] = self.hint
        return out


class _Parser(argparse.ArgumentParser):
    """A parser whose usage errors are JSON, not a stderr dump and exit 2."""

    def error(self, message):
        raise Refusal("usage", message)


def build_parser():
    parser = _Parser(
        description="File one source into sources/ (mechanics tier; never interactive).",
        add_help=False,
        allow_abbrev=False,
    )
    parser.add_argument("--kind", required=True, choices=sorted(KIND_DIRS))
    parser.add_argument("--date", default=None)
    parser.add_argument("--slug", default=None)
    parser.add_argument("path")
    return parser


def slugify(text):
    """Fold TEXT to the [a-z0-9]+(-[a-z0-9]+)* shape lint requires of names."""
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    out = []
    dash = False
    for ch in folded.lower():
        if ch in _SLUG_CHARS:
            out.append(ch)
            dash = False
        elif not dash and out:
            out.append("-")
            dash = True
    return "".join(out).strip("-")[:SLUG_MAX].strip("-") or "source"


def extension_of(name):
    """The lowercased extension when it is a dot and 1 to 10 of a-z0-9."""
    ext = os.path.splitext(name)[1].lower()
    body = ext[1:]
    if body and len(body) <= EXT_MAX and all(ch in _SLUG_CHARS for ch in body):
        return ext
    return ""


def resolve_date(text):
    """D-01: --date, else the local filing date. Exactly YYYY-MM-DD, a real day."""
    if text is None:
        return datetime.date.today().isoformat()
    shaped = (
        len(text) == 10
        and text[4] == "-"
        and text[7] == "-"
        and all(ch in _DIGITS for ch in text[:4] + text[5:7] + text[8:])
    )
    if shaped:
        try:
            datetime.date(int(text[:4]), int(text[5:7]), int(text[8:]))
            return text
        except ValueError:
            pass
    raise Refusal(
        "bad_date",
        "--date must be a real calendar date written YYYY-MM-DD",
    )


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            chunk = handle.read(CHUNK)
            if not chunk:
                return digest.hexdigest()
            digest.update(chunk)


def inside(child, parent):
    """True when the real path CHILD is PARENT or lies below it."""
    return child == parent or child.startswith(parent.rstrip(os.sep) + os.sep)


def require_root():
    root = find_root(os.getcwd())
    if root is None:
        raise Refusal(
            "no_dossier",
            "no dossier.yaml in the current directory or above it",
            status=EXIT_NO_DOSSIER,
        )
    return root


def make_stage(root, prefix="client-dossier-file-"):
    """A fresh staging directory that must resolve outside the dossier."""
    stage = tempfile.mkdtemp(prefix=prefix)
    if inside(os.path.realpath(stage), os.path.realpath(root)):
        shutil.rmtree(stage, ignore_errors=True)
        raise Refusal(
            "staging_inside_dossier",
            "the temporary directory resolves inside the dossier; "
            "point TMPDIR outside it and re-run",
        )
    return stage


def find_duplicate(sources, digest, size):
    """The root-relative path of a regular file under SOURCES with these bytes.

    D-06: stateless. Symlinks, non-regular files and .gitkeep are skipped;
    only files of the same size are hashed.
    """
    for dirpath, dirnames, filenames in os.walk(sources, followlinks=False):
        dirnames.sort()
        for fname in sorted(filenames):
            if fname == GITKEEP:
                continue
            path = os.path.join(dirpath, fname)
            try:
                info = os.lstat(path)
            except OSError:
                continue
            if not stat.S_ISREG(info.st_mode) or info.st_size != size:
                continue
            if sha256_of(path) == digest:
                rel = os.path.relpath(path, sources).replace(os.sep, "/")
                return "sources/" + rel
    return None


def transcript_exists(folder, stem):
    """True when FOLDER holds a regular file named STEM.<ext>."""
    try:
        names = os.listdir(folder)
    except OSError:
        return False
    for entry in names:
        if entry.startswith(stem + ".") and os.path.isfile(os.path.join(folder, entry)):
            return True
    return False


def check_plain_folder(real_root, rel):
    """The absolute path of REL under REAL_ROOT, refused unless it is plain.

    Plain: the folder, and every folder above it inside the dossier, is a real
    directory, so its real path is its own path. A file there is refused too.
    """
    expected = os.path.join(real_root, rel)
    actual = os.path.realpath(expected)
    if actual == expected:
        if os.path.lexists(expected) and not os.path.isdir(expected):
            raise Refusal(
                "not_a_directory",
                "{}/ is not a folder; refusing to file there".format(rel),
            )
        return expected
    if not inside(actual, real_root):
        raise Refusal(
            "sources_outside_dossier",
            "{}/ resolves outside the dossier; refusing to file there".format(rel),
        )
    raise Refusal(
        "sources_redirected",
        "{}/ is a link to another place in the dossier; refusing to file there".format(rel),
    )


def staging_warnings(incoming):
    """A note to purge the fetch staging folder the filed file came from."""
    stage = os.path.dirname(incoming)
    if os.path.basename(stage).startswith(FETCH_STAGE_PREFIX):
        return [PURGE_NOTE.format(stage=stage)]
    return []


def run_file(argv):
    args = build_parser().parse_args(argv)
    date = resolve_date(args.date)
    if "://" in args.path:
        raise Refusal(
            "url_argument",
            "the filing form takes a local file, not a URL; "
            "run file_source.py fetch URL first, then file the staged path it prints",
        )
    root = require_root()
    real_root = os.path.realpath(root)

    incoming = os.path.realpath(args.path)
    if not os.path.exists(incoming):
        raise Refusal("missing", "no such file: {}".format(args.path))
    if not os.path.isfile(incoming):
        raise Refusal("not_a_regular_file", "not a regular file: {}".format(args.path))
    if os.path.getsize(incoming) == 0:
        raise Refusal("empty", "the file is empty: {}".format(args.path))

    given = os.path.basename(args.path.rstrip("/")) or args.path
    slug = slugify(args.slug if args.slug is not None else os.path.splitext(given)[0])
    stem = "{}_{}".format(date, slug)
    name = stem + extension_of(given)

    # A4-F3: sources/ and the kind folder must be the plain directories they
    # appear to be. A link that stays inside the dossier (sources -> outbound,
    # .git) would write there as surely as one that leaves it.
    sources = check_plain_folder(real_root, "sources")
    kind_dir = KIND_DIRS[args.kind]
    folder = real_root
    for part_name in kind_dir.split("/"):
        folder = os.path.join(folder, part_name)
        if part_name != "sources" and os.path.lexists(folder):
            check_plain_folder(real_root, os.path.relpath(folder, real_root))
    folder = os.path.join(real_root, kind_dir)

    stage = make_stage(real_root)
    try:
        staged = os.path.join(stage, "incoming")
        with open(incoming, "rb") as fin, open(staged, "xb") as fout:
            shutil.copyfileobj(fin, fout, CHUNK)
        size = os.path.getsize(staged)
        if size == 0:
            raise Refusal("empty", "the file is empty: {}".format(args.path))
        digest = sha256_of(staged)

        existing = find_duplicate(sources, digest, size)
        if existing is not None:
            return (
                {
                    "status": "already_filed",
                    "path": existing,
                    "root": real_root,
                    "abs_path": os.path.join(real_root, existing),
                    "sha256": digest,
                    "warnings": staging_warnings(incoming),
                },
                EXIT_OK,
            )

        rel = kind_dir + "/" + name
        try:
            os.makedirs(folder, exist_ok=True)
        except OSError:
            raise Refusal(
                "not_a_directory",
                "{}/ cannot be created or is not a folder; refusing to file there".format(kind_dir),
            )
        target = os.path.join(folder, name)
        try:
            fout = open(target, "xb")
        except FileExistsError:
            raise Refusal(
                "name_taken",
                "{} already exists; choose another --slug".format(rel),
            )
        try:
            with fout, open(staged, "rb") as fin:
                shutil.copyfileobj(fin, fout, CHUNK)
        except BaseException:
            try:
                os.remove(target)
            except OSError:
                pass
            raise
    finally:
        shutil.rmtree(stage, ignore_errors=True)

    warnings = []
    warnings.extend(staging_warnings(incoming))
    if args.kind == "raw" and not transcript_exists(os.path.join(sources, "transcripts"), stem):
        warnings.append(
            "no transcript named {}.* under sources/transcripts/ yet; "
            "file the transcript with the same --date and --slug".format(stem)
        )
    if size > LARGE_FILE_WARNING_BYTES:
        warnings.append(
            "the file is larger than 100 MB; GitHub refuses files over that "
            "size, so track it with Git LFS before pushing"
        )
    return (
        {
            "status": "filed",
            "path": rel,
            "root": real_root,
            "abs_path": os.path.join(real_root, rel),
            "sha256": digest,
            "bytes": size,
            "warnings": warnings,
        },
        EXIT_OK,
    )


class Unresolvable(Exception):
    """The host name does not resolve to any address."""


def download_refusal(code, message):
    return Refusal(code, message, hint=DOWNLOAD_HINT)


class NotPublic(Exception):
    """The host resolves to an address that is not globally routable."""


# Networks refused whatever the running Python's `is_global` says (its answer
# differs between versions): IANA special-purpose blocks, multicast, site-local
# IPv6, the NAT64 local-use prefix and discard-only space.
_BLOCKED_NETWORKS = tuple(
    ipaddress.ip_network(text)
    for text in (
        "0.0.0.0/8",
        "100.64.0.0/10",
        "192.0.0.0/24",
        "192.88.99.0/24",
        "198.18.0.0/15",
        "224.0.0.0/4",
        "240.0.0.0/4",
        "100::/64",
        "2001::/23",
        "64:ff9b:1::/48",
        "fec0::/10",
        "ff00::/8",
    )
)
_NAT64 = ipaddress.ip_network("64:ff9b::/96")
_SIIT = ipaddress.ip_network("::ffff:0:0:0/96")
_V4_COMPATIBLE = ipaddress.ip_network("::/96")


def embedded_ipv4(addr):
    """The IPv4 address carried inside the IPv6 ADDR, else None.

    IPv4-mapped (::ffff:a.b.c.d), 6to4 (2002::/16), NAT64 (64:ff9b::/96), SIIT
    (::ffff:0:a.b.c.d) and IPv4-compatible (::a.b.c.d) forms all reach an IPv4
    host: the carried address is what must be public (A4-F6).
    """
    if addr.version != 4:
        mapped = addr.ipv4_mapped
        if mapped is not None:
            return mapped
        six = addr.sixtofour
        if six is not None:
            return six
        if addr in _NAT64 or addr in _SIIT or addr in _V4_COMPATIBLE:
            return ipaddress.IPv4Address(int(addr) & 0xFFFFFFFF)
    return None


def address_is_public(addr):
    """True when the ipaddress object ADDR is globally routable."""
    embedded = embedded_ipv4(addr)
    if embedded is not None:
        return address_is_public(embedded)
    if not addr.is_global or addr.is_multicast:
        return False
    return not any(addr in net for net in _BLOCKED_NETWORKS if net.version == addr.version)


def public_addresses(host):
    """The addresses HOST resolves to, all of them globally routable.

    Loopback, link-local (169.254.169.254 included), RFC 1918, CGNAT, multicast
    and the IPv6 forms that carry a private IPv4 address are refused (T-04-01,
    A4-F6). Raises Unresolvable or NotPublic. The caller connects to one of
    the returned addresses and to no other (pinning, A4-F2).
    """
    try:
        infos = socket.getaddrinfo(host, None)
    except (socket.gaierror, UnicodeError):
        raise Unresolvable(host)
    addrs = sorted(set(info[4][0].split("%")[0] for info in infos))
    if not addrs:
        raise Unresolvable(host)
    for text in addrs:
        if not address_is_public(ipaddress.ip_address(text)):
            raise NotPublic(host)
    return addrs


# host (lowercase) -> the addresses check_url validated for it. The pinned
# connection below reads this table, so the connection goes where the check
# looked and DNS is not asked a second, different question.
_PINS = {}


def _has_control(text):
    return any(ord(ch) <= 32 or ord(ch) == 127 for ch in text)


def check_url(url):
    """Raise a download Refusal unless URL is a safe http(s) target."""
    if _has_control(url):
        raise download_refusal("bad_url", "the URL holds a space or a control character")
    try:
        parts = urllib.parse.urlsplit(url)
        host = parts.hostname
        parts.port  # validates the port
    except ValueError:
        raise download_refusal("bad_url", "the URL is malformed")
    if parts.scheme not in ("http", "https"):
        raise download_refusal("bad_url", "only http and https URLs are downloaded")
    if "@" in parts.netloc:
        raise download_refusal(
            "bad_url", "a URL carrying credentials is refused (no authentication, D-02)"
        )
    if not host:
        raise download_refusal("bad_url", "the URL has no host")
    try:
        _PINS[host.lower()] = public_addresses(host)
    except Unresolvable:
        raise download_refusal("unresolvable", "the host name does not resolve")
    except NotPublic:
        raise download_refusal("not_public", "the host is not a public internet address")


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    """Re-checks every hop with check_url and bounds the chain (T-04-03)."""

    max_redirections = MAX_REDIRECTS

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        try:
            check_url(newurl)
        except Refusal as refusal:
            raise urllib.error.HTTPError(
                newurl, code, "redirect refused: " + refusal.message, headers, fp
            )
        return urllib.request.HTTPRedirectHandler.redirect_request(
            self, req, fp, code, msg, headers, newurl
        )


def pinned_connection(address, timeout=socket._GLOBAL_DEFAULT_TIMEOUT, source_address=None):
    """socket.create_connection, but only to an address that was validated."""
    host, port = address
    addrs = _PINS.get(str(host).lower())
    if addrs is None:
        try:
            addrs = public_addresses(host)
        except Unresolvable:
            raise download_refusal("unresolvable", "the host name does not resolve")
        except NotPublic:
            raise download_refusal("not_public", "the host is not a public internet address")
    last = OSError("no address to connect to")
    for addr in addrs:
        try:
            return socket.create_connection((addr, port), timeout, source_address)
        except OSError as exc:
            last = exc
    raise last


class PinnedHTTPConnection(http.client.HTTPConnection):
    """Connects to the validated address; Host stays the URL's host."""

    def __init__(self, *args, **kwargs):
        http.client.HTTPConnection.__init__(self, *args, **kwargs)
        self._create_connection = pinned_connection


class PinnedHTTPSConnection(http.client.HTTPSConnection):
    """As above; the TLS server name and the certificate check stay the URL's host."""

    def __init__(self, *args, **kwargs):
        http.client.HTTPSConnection.__init__(self, *args, **kwargs)
        self._create_connection = pinned_connection


class PinnedHTTPHandler(urllib.request.HTTPHandler):
    def http_open(self, req):
        return self.do_open(PinnedHTTPConnection, req)


class PinnedHTTPSHandler(urllib.request.HTTPSHandler):
    def https_open(self, req):
        return self.do_open(PinnedHTTPSConnection, req, context=self._context)


def make_opener():
    """An explicit opener: no proxy, file, ftp, data or unknown-scheme handler."""
    opener = urllib.request.OpenerDirector()
    for handler in (
        PinnedHTTPHandler(),
        PinnedHTTPSHandler(),
        urllib.request.HTTPDefaultErrorHandler(),
        SafeRedirect(),
        urllib.request.HTTPErrorProcessor(),
    ):
        opener.add_handler(handler)
    return opener


def build_fetch_parser():
    parser = _Parser(
        description="Download a URL as-is into a staging folder (mechanics tier).",
        add_help=False,
        allow_abbrev=False,
    )
    parser.add_argument("url")
    return parser


class _DeadlineHit(Exception):
    """Raised by the SIGALRM handler when the global deadline passes."""


def _on_alarm(signum, frame):
    raise _DeadlineHit()


def _arm_deadline(seconds):
    """Arm a global deadline (A4-F5); the header phase counts, not only the body.

    SIGALRM exists on POSIX main threads only; elsewhere the per-chunk check in
    the body loop is the only bound. Returns what _disarm_deadline needs.
    """
    if not hasattr(signal, "setitimer"):
        return None
    try:
        previous = signal.signal(signal.SIGALRM, _on_alarm)
    except ValueError:  # not the main thread
        return None
    signal.setitimer(signal.ITIMER_REAL, seconds)
    return previous


def _disarm_deadline(armed):
    if armed is None:
        return
    signal.setitimer(signal.ITIMER_REAL, 0)
    signal.signal(signal.SIGALRM, armed)


def download(url, stage):
    """Stream URL into STAGE; return (path, ext, size, digest, final_host, slug)."""
    armed = _arm_deadline(FETCH_DEADLINE_SECONDS)
    try:
        return _download(url, stage)
    except _DeadlineHit:
        raise download_refusal("timeout", "the download took too long")
    finally:
        _disarm_deadline(armed)


def _download(url, stage):
    request = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept-Encoding": "identity"}
    )
    deadline = time.monotonic() + FETCH_DEADLINE_SECONDS
    try:
        response = make_opener().open(request, timeout=FETCH_TIMEOUT_SECONDS)
    except Refusal:
        raise
    except urllib.error.HTTPError as exc:
        exc.close()
        if 300 <= exc.code < 400:
            raise download_refusal(
                "redirect_refused",
                "a redirect was refused (non-public target, unsupported scheme "
                "or more than {} hops)".format(MAX_REDIRECTS),
            )
        raise download_refusal("http_{}".format(exc.code), "the server answered HTTP {}".format(exc.code))
    except urllib.error.URLError as exc:
        if isinstance(exc.reason, socket.timeout):
            raise download_refusal("timeout", "the server did not answer in time")
        raise download_refusal("network", "could not reach the server")
    except socket.timeout:
        raise download_refusal("timeout", "the server did not answer in time")
    except (OSError, http.client.HTTPException):
        # RemoteDisconnected, BadStatusLine, a reset before the headers (R4-M2)
        raise download_refusal("network", "the connection failed before the answer")

    part = os.path.join(stage, "download.part")
    digest = hashlib.sha256()
    total = 0
    try:
        encoding = (response.headers.get("Content-Encoding") or "").strip().lower()
        if encoding and encoding != "identity":
            raise download_refusal(
                "content_encoding",
                "the server compressed the answer ({}); it would be filed unreadable".format(
                    "".join(ch for ch in encoding if ch.isalnum() or ch in "-,") [:20]
                ),
            )
        declared = response.headers.get("Content-Length")
        declared_size = int(declared) if declared and declared.strip().isdigit() else None
        if declared_size is not None and declared_size > FETCH_MAX_BYTES:
            raise download_refusal("too_large", "the download exceeds {} bytes".format(FETCH_MAX_BYTES))
        read = getattr(response, "read1", response.read)
        with open(part, "xb") as out:
            while True:
                chunk = read(CHUNK)
                if not chunk:
                    break
                total += len(chunk)
                if total > FETCH_MAX_BYTES:
                    raise download_refusal(
                        "too_large", "the download exceeds {} bytes".format(FETCH_MAX_BYTES)
                    )
                if time.monotonic() > deadline:
                    raise download_refusal("timeout", "the download took too long")
                out.write(chunk)
                digest.update(chunk)
        if declared_size is not None and total != declared_size:
            raise download_refusal(
                "truncated",
                "the server declared {} bytes and sent {}; a partial source is never filed".format(
                    declared_size, total
                ),
            )
        final_url = response.geturl()
        ctype = (response.headers.get("Content-Type") or "").split(";")[0].strip().lower()
    except (Refusal, _DeadlineHit):
        raise
    except socket.timeout:
        raise download_refusal("timeout", "the server stopped answering")
    except (OSError, http.client.HTTPException):
        raise download_refusal("network", "the connection failed during the download")
    finally:
        response.close()

    final = urllib.parse.urlsplit(final_url)
    segment = urllib.parse.unquote(final.path.rstrip("/").rsplit("/", 1)[-1])
    ext = EXT_BY_TYPE.get(ctype) or extension_of(segment) or ".bin"
    slug = slugify(os.path.splitext(segment)[0])
    path = os.path.join(stage, slug + ext)
    os.rename(part, path)
    return path, ext, total, digest.hexdigest(), final.hostname or "", slug


def run_fetch(argv):
    args = build_fetch_parser().parse_args(argv)
    root = require_root()
    stage = make_stage(os.path.realpath(root), FETCH_STAGE_PREFIX)
    kept = False
    try:
        check_url(args.url)
        path, ext, size, digest, host, slug = download(args.url, stage)
        kept = True
    finally:
        if not kept:
            shutil.rmtree(stage, ignore_errors=True)
    return (
        {
            "status": "fetched",
            "path": path,
            "ext": ext,
            "bytes": size,
            "sha256": digest,
            "final_url_host": host,
            "suggested_slug": slug,
            "stage": os.path.dirname(path),
            "purge": PURGE_NOTE.format(stage=os.path.dirname(path)),
        },
        EXIT_OK,
    )


def emit(result):
    sys.stdout.write(json.dumps(result, ensure_ascii=True) + "\n")
    sys.stdout.flush()


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        if argv[:1] == ["fetch"]:
            result, code = run_fetch(argv[1:])
        else:
            result, code = run_file(argv)
    except Refusal as refusal:
        result, code = refusal.result(), refusal.status
    except Exception as exc:  # never a traceback: the agent reads one JSON object
        result = {
            "status": "error",
            "error": "internal",
            "message": "internal error ({})".format(type(exc).__name__),
        }
        code = EXIT_INTERNAL
    emit(result)
    return code


if __name__ == "__main__":
    sys.exit(main())
