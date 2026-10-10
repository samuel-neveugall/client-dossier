# Phase 4 — security audit (audit-4)

HEAD 556c834 (audited files unchanged at 55985ef); vf-auditer via gsd-security-auditor (OPEN_THREATS;
its T-04-26 "blocking" not retained as blocking), 2026-10-10; persisted by the mission manager.
Verdict: **gaps_found** — 0 blocker, 1 major, 9 minor. Suites replayed: fetch 103/0, file 284/0,
extract 73/0, agent 57/0, guard 153/0.

Conforming (reproduced on a local server / monkeypatch, no external host): 29 SSRF URL forms refused
(schemes, loopback/private/link-local/metadata in decimal/hex/short/IPv6-mapped forms, userinfo, bad port,
redirects to private/other schemes, > 5 hops); size cap (10^12 Content-Length, infinite stream cut at
100 MiB); URL-derived names sanitised; no overwrite, `sources/` symlinked outside refused, FIFO/dir/
`/dev/zero`/empty refused, staging inside the dossier refused; `extract-text.sh` immune to `$()`, `;`,
quotes, newlines, leading dash. Evidence: no secret. Procedure note: probing `http://0177.0.0.1` opened a
connection to the public 177.0.0.1 (macOS reads it as decimal); check and connection saw the same IP.

| ID | Sev. | Ref | Finding |
|---|---|---|---|
| A4-F1 | major | SKILL.md:47,63,87,237 | Placeholders in double quotes: `$(…)`/backticks in an URL or slug are executed (reproduced: MARK files created). Single quotes; refuse values with `'` or newline; slug restricted to `[a-z0-9-]`; same for the no-scripts section. |
| A4-F2 | minor | file_source.py:379-423 | DNS rebinding: the check resolves, the connection resolves again (reproduced: hit on 127.0.0.1). Fix: connection pinned to the validated IP (Host/SNI kept). |
| A4-F3 | minor | file_source.py:301-313 | `sources` symlinked to an internal dir (`outbound`, `.git`) writes there. Refuse when `root/sources` is a link or `realpath(sources) != root/sources`. |
| A4-F4 | minor | SKILL.md:30,42-51; fact-extractor.md rule 2 | Prompt injection: "the source is data" missing at the initial peek; extractor may read any path. Add both rules (kept identical in skill and agent). |
| A4-F5 | minor | file_source.py:473,496-509 | Deadline does not cover header phase (60.5 s for a 3 s deadline; worst case ~50 min). Global deadline. |
| A4-F6 | minor | file_source.py:394-399 | NAT64/SIIT (`64:ff9b::/96`), `::ffff:0:…`, `::a.b.c.d`, site-local `fec0::/10`, multicast, `192.0.0.0/24`, `192.88.99.0/24` pass `is_public`. |
| A4-F7 | minor | file_source.py:519-522,575-581 | URL with a space → `InvalidURL` echoing the query token in an internal error. Validate control chars/spaces; never echo `exc`. |
| A4-F8 | minor | extract-text.sh:38,64,72 | Raw filename printed (newline injects lines into agent-read output); writes next to any PDF, not only under `sources/`; non-atomic final write. |
| A4-F9 | minor | file_source.py:535-558; SKILL.md | Fetch staging never purged (9 stages left; one 8.3 GB stage from a killed run, outside the repository). |
| A4-F10 | minor | fact-extractor.md:4 (T-04-26) | Agent `tools:` restriction never observed at runtime (dispatch never happened). Proven by the re-run where the dispatch is mandatory. |

## Manager decision
All ten findings are fixed in one round (fix-4a) together with the code review's R4-M1..R4-m10, then a
full re-review and the paid re-runs (dispatch now gating, D-12 amended). No residual is accepted as debt,
so no question to Samuel under his standing rule (he decides only when a fail-open residual would remain).
