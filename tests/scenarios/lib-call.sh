#!/usr/bin/env bash
# tests/scenarios/lib-call.sh — fixtures and verdict helpers of the CALL-04
# ("prepare tomorrow's call") and CALL-05 ("where are we with this deal")
# scenarios (Phase 6: D-08, D-10, D-11, D-16). Shared by
# tests/scenarios/call-prepare.sh and tests/scenarios/deal-status.sh, and read
# by plans 06-03 and 06-05, which source it and never edit it.
#
# Sourced after tests/scenarios/lib-scenario.sh and lib-draft.sh. It is NOT run
# by tests/run.sh (a scenario costs model calls); tests/scenarios/selftest-call.sh
# proves every helper for free.
#
# Source-safe: defines functions only, runs nothing. Bash 3.2 (macOS), no
# arrays, python3 standard library only. Every python snippet runs with
# `python3 -I` (no cwd, no user site on the path). A helper prints `no`,
# `none`, `missing` or `0` for a missing file, never a traceback.
#
# Dates: D(n) is the run's today plus n days. Every fixture date is computed
# from the run date, never hard-coded (06-RESEARCH Pitfall 12).

: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# rel_date N [TODAY] — TODAY (default: today) plus N days, YYYY-MM-DD.
rel_date() {
  python3 -I -c '
import datetime, sys
n = int(sys.argv[1])
base = datetime.date.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else datetime.date.today()
print((base + datetime.timedelta(days=n)).isoformat())
' "$1" "${2:-}"
}

# _call_pyhelp — the python prelude shared by the two fixture writers. Reads
# argv[1] = the dossier directory and argv[2] = the run date. A broken
# precondition exits 1 with a message on stderr.
_call_pyhelp() {
  cat <<'PYHELP'
import datetime, os, re, sys
DIR = sys.argv[1]
TODAY = datetime.date.fromisoformat(sys.argv[2])
def d(n):
    return (TODAY + datetime.timedelta(days=n)).isoformat()
def die(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(1)
def rd(rel):
    try:
        with open(os.path.join(DIR, rel), encoding="utf-8", newline="") as fh:
            return fh.read()
    except OSError:
        return None
def touch(path, iso):
    t = datetime.datetime.strptime(iso + " 10:00", "%Y-%m-%d %H:%M").timestamp()
    os.utime(path, (t, t))
def wr(rel, text, day=None):
    path = os.path.join(DIR, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    if day:
        touch(path, day)
def edit(rel, fn):
    text = rd(rel)
    if text is None:
        die("missing file " + rel)
    lines = text.split("\n")
    fn(lines)
    wr(rel, "\n".join(lines))
def insert_block(rel, heading, new):
    def fn(lines):
        if heading not in lines:
            die("heading %r missing from %s" % (heading, rel))
        j = lines.index(heading) + 1
        while j < len(lines) and (lines[j].strip() == "" or lines[j].lstrip().startswith("<!--")):
            j += 1
        lines[j:j] = list(new) + [""]
    edit(rel, fn)
def table_rows(rel, heading, rows):
    def fn(lines):
        if heading not in lines:
            die("heading %r missing from %s" % (heading, rel))
        j = lines.index(heading) + 1
        while j < len(lines) and not lines[j].startswith("| ---"):
            if lines[j].startswith("## "):
                die("no table under %r in %s" % (heading, rel))
            j += 1
        if j >= len(lines):
            die("no table under %r in %s" % (heading, rel))
        lines[j + 1:j + 1] = list(rows)
    edit(rel, fn)
def set_last_updated(rel, iso):
    def fn(lines):
        for i, line in enumerate(lines):
            if re.match(r"^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}", line):
                lines[i] = "Last updated: " + iso
                return
        die("no Last updated: line in " + rel)
    edit(rel, fn)
def section(text, start, stop):
    """Lines of text strictly between the line start and the next line starting with stop."""
    out = []
    on = False
    for line in text.split("\n"):
        if on and line.startswith(stop):
            break
        if on:
            out.append(line)
        if line == start:
            on = True
    return out
PYHELP
}

# _call_py CODE ARG... — runs the prelude plus CODE with the arguments.
_call_py() {
  local code="$1"
  shift
  python3 -I -c "$(_call_pyhelp)
$code" "$@"
}

# ---------------------------------------------------------------------------
# CALL-04 fixture
# ---------------------------------------------------------------------------

_call_prep_py() {
  cat <<'PYPREP'
mode = sys.argv[3]
ROWS = [
    "| Do the Northwind Telecom field teams join the pilot? | Changes the training effort we quote. | after the pilot site list arrives |",
    "| Who signs the order on the ordering party's side? | Decides who we commit to in writing. | next call, first thing |",
    "| Is the go-live date of the pilot firm? | Sets the final week of the pilot. | before the quote is sent |",
]
CHRON = [
    "- On %s Jane Doe (Acme Consulting) asked for an offer on a pilot (mail %s from Jane Doe)." % (d(-30), d(-30)),
    "- On %s we sent the first presentation to Jane Doe (Acme Consulting) (mail %s from Sam)." % (d(-27), d(-27)),
    "- On %s Jane Doe (Acme Consulting) shared the list of pilot goals (mail %s from Jane Doe)." % (d(-24), d(-24)),
    "- On %s we agreed internally on the boundaries of the pilot scope (decision %s by Sam)." % (d(-20), d(-20)),
    "- On %s Jane Doe (Acme Consulting) confirmed the people who attend the kickoff (mail %s from Jane Doe)." % (d(-14), d(-14)),
    "- On %s we held the kickoff call with Jane Doe (Acme Consulting) (call %s @21:40)." % (d(-10), d(-10)),
]
OURS = "- We send the quote for the pilot to Jane Doe (Acme Consulting) by %s (call %s @21:40)." % (d(5), d(-10))
NEVER = "- A price before the pilot scope is signed (decision %s by Sam)." % d(-20)
CHAN = "- Calls with Jane Doe (Acme Consulting) last 30 minutes and take place on video (call %s @21:40)." % d(-10)
CALLREL = "outbound/calls/%s_kickoff.md" % d(-10)
CALLTXT = "\n".join([
    "<!--",
    "Status: draft",
    "To: the ordering party's project lead",
    "Written by: agent session, %s" % d(-11),
    "Rules: no confidential names; see knowledge/DOCTRINE.md",
    "-->",
    "",
    "# Kickoff call with the ordering party, %s" % d(-10),
    "",
    "## Context",
    "",
    "Kickoff of the pilot with Jane Doe (Acme Consulting).",
    "",
    "## Agenda",
    "",
    "- 0:00-0:10 Introductions",
    "- 0:10-0:30 Goals of the pilot",
    "",
    "## Open questions",
    "",
    "- Who signs the order on the ordering party's side?",
    "",
    "## Minutes",
    "",
    "- Jane Doe (Acme Consulting) wants the pilot to start with one site (call %s @21:40)." % d(-10),
    "- We promise a quote for the pilot (call %s @25:10)." % d(-10),
    "",
])
if mode == "seed":
    oq = "dossier/OPEN-QUESTIONS.md"
    text = rd(oq)
    if text is None:
        die("missing file " + oq)
    heads = [l for l in text.split("\n") if l.startswith("## ")]
    if len(heads) < 2:
        die("OPEN-QUESTIONS.md has fewer than two ## headings")
    table_rows(oq, heads[1], ROWS)
    insert_block("dossier/HISTORY.md", "## Chronology", CHRON)
    insert_block("dossier/HISTORY.md", "### Ours", [OURS])
    insert_block("knowledge/DOCTRINE.md", "## What we never say", [NEVER])
    insert_block("dossier/CHANNELS.md", "## Calls", [CHAN])
    wr(CALLREL, CALLTXT)
elif mode == "check":
    text = rd("dossier/OPEN-QUESTIONS.md") or ""
    lines = text.split("\n")
    pos = []
    for k, row in enumerate(ROWS):
        if row not in lines:
            die("the prepare-call fixture is not seeded: open question %d is missing from dossier/OPEN-QUESTIONS.md" % (k + 1))
        pos.append(lines.index(row))
    if not (pos[0] < pos[1] < pos[2]):
        die("the prepare-call fixture is not seeded: the open questions are not in the scrambled order")
    hist = rd("dossier/HISTORY.md") or ""
    if OURS not in section(hist, "### Ours", "###"):
        die("the prepare-call fixture is not seeded: the Ours commitment is missing from dossier/HISTORY.md")
    n = sum(1 for b in CHRON if b in hist.split("\n"))
    if n != len(CHRON):
        die("the prepare-call fixture is not seeded: a Chronology bullet is missing from dossier/HISTORY.md")
    if [l for l in section(hist, "## Upcoming", "## ") if l.strip()]:
        die("the prepare-call fixture is wrong: dossier/HISTORY.md holds an Upcoming line")
    if NEVER not in (rd("knowledge/DOCTRINE.md") or "").split("\n"):
        die("the prepare-call fixture is not seeded: the doctrine line is missing from knowledge/DOCTRINE.md")
    if CHAN not in (rd("dossier/CHANNELS.md") or "").split("\n"):
        die("the prepare-call fixture is not seeded: the calls line is missing from dossier/CHANNELS.md")
    if rd(CALLREL) is None:
        die("the prepare-call fixture is not seeded: " + CALLREL + " is missing")
PYPREP
}

# prep_fixture DIR TODAY — seeds the CALL-04 fixture into a dossier built by
# build_dossier, backdates every living file's `Last updated:` to D(-10) and
# commits nothing.
prep_fixture() {
  local dir="$1" today="$2" msg
  msg="$(_call_py "$(_call_prep_py)" "$dir" "$today" seed 2>&1)" \
    || scenario_die "prep_fixture failed: $msg"
  backdate_last_updated "$dir" "$(rel_date -10 "$today")"
}

# check_prep_fixture DIR TODAY — scenario_die naming the missing seed, else
# nothing.
check_prep_fixture() {
  local dir="$1" today="$2" msg
  msg="$(_call_py "$(_call_prep_py)" "$dir" "$today" check 2>&1)" \
    || scenario_die "$msg"
  return 0
}

# ---------------------------------------------------------------------------
# CALL-05 fixture (hardened, D-16)
# ---------------------------------------------------------------------------

_call_status_py() {
  cat <<'PYSTATUS'
mode = sys.argv[3]
ME = "Jane Doe (Acme Consulting)"
RULES = "Rules: no confidential names; see knowledge/DOCTRINE.md"
SEED_COMMIT = "- We send the security questionnaire answers to %s by %s (call %s @14:05)." % (ME, d(-3), d(-12))
TRAP_SENT_LINE = "- %s: draft mail 'revised-quote' written, to be sent by Sam, deadline %s (outbound/mails/%s_revised-quote.md)." % (d(-9), d(-7), d(-9))
TRAP_FUTURE_LINE = "- %s: draft mail 'pilot-plan' written, to be sent by Sam, deadline %s (outbound/mails/%s_pilot-plan.md)." % (d(-5), d(4), d(-5))
TRAP_DONE_LINE = "- %s sends the signed NDA by %s, done %s (mail %s from Jane Doe)." % (ME, d(-20), d(-21), d(-21))
TRAP_DONE_CHRON = "- On %s %s sent the signed NDA (mail %s from Jane Doe)." % (d(-21), ME, d(-21))
THEIRS_FILLER = "- %s sends the pilot site list by %s (mail %s from Jane Doe)." % (ME, d(12), d(-6))
UPCOMING = "- Pilot kick-off workshop with %s on %s (mail %s from Jane Doe)." % (ME, d(20), d(-6))
STATUS_LINE = "On track for the pilot, scope agreed, quote under review (call %s @25:10)." % d(-12)
TOPICS = [
    "the access rules for the shared folder", "the reporting format of the pilot",
    "the contact list of the operations team", "the calendar of the pilot workshops",
    "the data export format", "the review rhythm of the pilot",
    "the glossary of the sector terms", "the layout of the weekly status page",
    "the scope boundaries of the first phase", "the staffing plan on the ordering party's side",
    "the travel rules for on-site days", "the invoicing contact",
    "the test environment", "the sign-off steps for deliverables",
    "the training outline", "the escalation path",
]
CHRON_DAYS = [-40, -39, -38, -37, -35, -34, -33, -32, -31, -30, -29, -28, -26, -25, -24, -23,
              -22, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10, -9, -8, -7, -6, -5]
CHRON = []
for k, n in enumerate(CHRON_DAYS):
    CHRON.append("- On %s %s clarified %s (mail %s from Jane Doe)." % (d(n), ME, TOPICS[k % len(TOPICS)], d(n)))
CHRON.append(TRAP_DONE_CHRON)
CHRON.sort(key=lambda b: b[5:15])

def header(status, subject, deadline, written):
    out = ["<!--", "Status: " + status, "To: " + ME, "Subject: " + subject]
    if deadline:
        out.append("Deadline: " + deadline)
    out += ["Written by: agent session, " + written, RULES, "-->", ""]
    return out
def mail(day, slug, status, subject, deadline, body):
    return ("outbound/mails/%s_%s.md" % (d(day), slug),
            "\n".join(header(status, subject, deadline, d(day)) + body + [""]))
SEED_DRAFT_REL = "outbound/mails/%s_steering-agenda.md" % d(-6)
MAILS = [
    mail(-30, "intro-offer", "sent %s by Sam" % d(-30), "Pilot offer", None, ["Hello Jane,", "", "Here is our offer for a pilot.", "", "With thanks,", "Sam"]),
    mail(-22, "scope-recap", "sent %s by Sam" % d(-22), "Scope recap", None, ["Hello Jane,", "", "Here is the recap of the scope we discussed.", "", "With thanks,", "Sam"]),
    mail(-14, "nda-reminder", "sent %s by Sam" % d(-14), "Reminder on the NDA", None, ["Hello Jane,", "", "A short reminder about the signed NDA.", "", "With thanks,", "Sam"]),
    mail(-9, "revised-quote", "sent %s by Sam" % d(-8), "Revised quote", d(-7), ["Hello Jane,", "", "Please find the revised quote for the pilot.", "", "With thanks,", "Sam"]),
    mail(-6, "steering-agenda", "draft", "Steering committee agenda", d(-2), ["Hello Jane,", "", "Here is the proposed agenda for the steering committee.", "", "With thanks,", "Sam"]),
    mail(-5, "pilot-plan", "draft", "Pilot plan", d(4), ["Hello Jane,", "", "Here is the plan for the pilot.", "", "With thanks,", "Sam"]),
]
CALLS = [("outbound/calls/%s_scoping-call.md" % d(-12), "\n".join([
    "<!--", "Status: draft", "To: the ordering party's project lead",
    "Written by: agent session, %s" % d(-13), RULES, "-->", "",
    "# Scoping call with the ordering party, %s" % d(-12), "",
    "## Context", "", "Scoping of the pilot with %s." % ME, "",
    "## Agenda", "", "- 0:00-0:10 Introductions", "- 0:10-0:30 Scope", "",
    "## Minutes", "",
    "- %s agrees on the scope of the pilot (call %s @05:12)." % (ME, d(-12)),
    "- We promise answers on the security review (call %s @14:05)." % d(-12), ""]))]
SOURCES = [
    (-40, "received", "kickoff-brief", "Kickoff brief\n\nThe ordering party describes the goals of the pilot.\nThe pilot runs on one site first.\n"),
    (-38, "transcripts", "intro-call", "Transcript of the intro call\n\nJane: We would like a short pilot.\nSam: We can prepare an offer.\n"),
    (-35, "received", "org-chart", "Organisation chart of the ordering party\n\nProject lead: Jane Doe.\nSponsor: the operations director.\n"),
    (-33, "received", "pilot-goals", "Goals of the pilot\n\nReduce the time spent on reporting.\nKeep the data on the ordering party's side.\n"),
    (-30, "transcripts", "discovery-call", "Transcript of the discovery call\n\nJane: The sponsor wants a weekly view.\nSam: We will propose a format.\n"),
    (-27, "received", "access-rules", "Access rules\n\nThe shared folder is read-only for external people.\n"),
    (-24, "received", "reporting-format", "Reporting format\n\nOne page per week, three figures, one comment.\n"),
    (-20, "transcripts", "workshop-call", "Transcript of the workshop call\n\nJane: The operations team can join on Tuesdays.\nSam: We plan the workshops around that.\n"),
    (-17, "received", "site-list-draft", "Draft site list\n\nSite A, site B and site C are candidates for the pilot.\n"),
    (-14, "received", "nda-draft", "Draft of the NDA\n\nThe parties keep each other's information confidential.\n"),
    (-12, "transcripts", "scoping-call", "Transcript of the scoping call\n\nJane: The scope is agreed.\nSam: We send the answers on the security review.\n"),
    (-10, "transcripts", "kickoff-call", "Transcript of the kickoff call\n\nJane: The pilot starts with one site.\nSam: We send the quote.\n"),
    (-9, "received", "quote-feedback", "Feedback on the quote\n\nThe ordering party asks for a revised quote.\n"),
    (-8, "received", "staffing-plan", "Staffing plan\n\nTwo people from the ordering party join the pilot.\n"),
    (-7, "received", "test-environment", "Test environment\n\nA test environment is available on request.\n"),
    (-6, "received", "invoicing-contact", "Invoicing contact\n\nInvoices go to the finance team of the ordering party.\n"),
    (-2, "received", "pilot-brochure", "Pilot brochure\n\nA short presentation of the pilot offer of the ordering party.\nThree pages, one price table.\n"),
]
def stage_of(n):
    if n <= -31: return -40
    if n <= -21: return -30
    if n <= -11: return -20
    if n <= -8: return -10
    if n <= -6: return -5
    return n
def src_rel(n, folder, slug):
    return "sources/%s/%s_%s.txt" % (folder, d(n), slug)
MARKET_REL = "knowledge/watch/%s_market-note.md" % d(-1)
MARKET_TXT = "# Market note\n\nA competitor announced a new support offer (web %s).\n" % d(-1)

if mode.lstrip("-").isdigit():
    stage = int(mode)
    if stage == -40:
        for base, dirs, files in os.walk(DIR):
            dirs[:] = [x for x in dirs if x != ".git"]
            for f in files:
                touch(os.path.join(base, f), d(-40))
    if stage == -5:
        for rel, iso in (("dossier/HISTORY.md", -5), ("dossier/OPEN-QUESTIONS.md", -5),
                         ("dossier/ACTORS.md", -5), ("dossier/CHANNELS.md", -5),
                         ("dossier/LEARNINGS.md", -5), ("dossier/TONE.md", -5),
                         ("dossier/RELATIONSHIP.md", -13)):
            set_last_updated(rel, d(iso))
        insert_block("dossier/HISTORY.md", "## Chronology", CHRON)
        insert_block("dossier/HISTORY.md", "### Ours", [SEED_COMMIT, TRAP_SENT_LINE, TRAP_FUTURE_LINE])
        insert_block("dossier/HISTORY.md", "### Theirs", [TRAP_DONE_LINE, THEIRS_FILLER])
        insert_block("dossier/HISTORY.md", "## Upcoming", [UPCOMING])
        insert_block("dossier/RELATIONSHIP.md", "## Status in one line", [STATUS_LINE])
        insert_block("dossier/ACTORS.md", "### Name (Organisation)", ["- %s is the project lead on the ordering party's side (mail %s from Jane Doe)." % (ME, d(-40))])
        insert_block("dossier/LEARNINGS.md", "## How they speak and think", ["- %s prefers short mails with a single question (mail %s from Jane Doe)." % (ME, d(-30))])
        insert_block("dossier/TONE.md", "## The voice in one sentence", ["- Direct and factual, no hedging (review by Sam on %s)." % d(-20)])
        insert_block("dossier/CHANNELS.md", "## Calls", ["- Calls with %s take place on video (call %s @05:12)." % (ME, d(-12))])
        table_rows("dossier/OPEN-QUESTIONS.md", [l for l in rd("dossier/OPEN-QUESTIONS.md").split("\n") if l.startswith("## ")][1],
                   ["| Which site hosts the pilot? | Sets the travel budget. | next call |"])
        insert_block("knowledge/DOCTRINE.md", "## What we never say", ["- A price before the pilot scope is signed (decision %s by Sam)." % d(-20)])
        for rel, txt in MAILS + CALLS:
            wr(rel, txt, d(-5))
        for base, dirs, files in os.walk(os.path.join(DIR, "dossier")):
            for f in files:
                touch(os.path.join(base, f), d(-5))
        touch(os.path.join(DIR, "knowledge/DOCTRINE.md"), d(-5))
    if stage == -2:
        wr(src_rel(-2, "received", "pilot-brochure"), SOURCES[-1][3], d(-2))
    elif stage == -1:
        wr(MARKET_REL, MARKET_TXT, d(-1))
    else:
        for n, folder, slug, txt in SOURCES:
            if n != -2 and stage_of(n) == stage:
                wr(src_rel(n, folder, slug), txt, d(n))
elif mode == "check":
    def all_files(sub):
        out = []
        for base, dirs, files in os.walk(os.path.join(DIR, sub)):
            for f in files:
                out.append(os.path.relpath(os.path.join(base, f), DIR))
        return sorted(out)
    hist = rd("dossier/HISTORY.md") or ""
    ours = section(hist, "### Ours", "###")
    theirs = section(hist, "### Theirs", "##")
    for name, line, where in (("the overdue commitment", SEED_COMMIT, ours),
                              ("the sent-mail trap", TRAP_SENT_LINE, ours),
                              ("the future-draft trap", TRAP_FUTURE_LINE, ours),
                              ("the closed-commitment trap", TRAP_DONE_LINE, theirs),
                              ("the Theirs filler", THEIRS_FILLER, theirs)):
        if line not in where:
            die("the deal-status fixture is broken: %s is not under its heading in dossier/HISTORY.md" % name)
    if UPCOMING not in section(hist, "## Upcoming", "## "):
        die("the deal-status fixture is broken: the Upcoming line is missing")
    chron = [l for l in section(hist, "## Chronology", "## ") if l.startswith("- ")]
    if len(chron) < 30:
        die("the deal-status fixture is broken: the Chronology holds %d bullets, fewer than 30" % len(chron))
    if TRAP_DONE_CHRON not in chron:
        die("the deal-status fixture is broken: the closed commitment is not in the Chronology")
    draft = rd(SEED_DRAFT_REL)
    if draft is None:
        die("the deal-status fixture is broken: " + SEED_DRAFT_REL + " is missing")
    if ("Deadline: " + d(-2)) not in draft.split("\n") or "Status: draft" not in draft.split("\n"):
        die("the deal-status fixture is broken: the steering draft lacks its status or its deadline field")
    sent = rd("outbound/mails/%s_revised-quote.md" % d(-9)) or ""
    if ("Status: sent %s by Sam" % d(-8)) not in sent.split("\n") or ("Deadline: " + d(-7)) not in sent.split("\n"):
        die("the deal-status fixture is broken: the sent-mail trap lost its status or deadline")
    future = rd("outbound/mails/%s_pilot-plan.md" % d(-5)) or ""
    if ("Deadline: " + d(4)) not in future.split("\n") or "Status: draft" not in future.split("\n"):
        die("the deal-status fixture is broken: the future-draft trap lost its status or deadline")
    if len([f for f in all_files("outbound/mails") if not f.endswith(".gitkeep")]) < 6:
        die("the deal-status fixture is broken: fewer than 6 mails under outbound/mails")
    if rd("outbound/calls/%s_scoping-call.md" % d(-12)) is None:
        die("the deal-status fixture is broken: the past call file is missing")
    for rel in ("dossier/HISTORY.md", "dossier/OPEN-QUESTIONS.md", "dossier/ACTORS.md",
                "dossier/CHANNELS.md", "dossier/LEARNINGS.md", "dossier/TONE.md", "dossier/RELATIONSHIP.md"):
        m = re.search(r"^Last updated: ([0-9]{4}-[0-9]{2}-[0-9]{2})", rd(rel) or "", re.M)
        want = d(-13) if rel.endswith("RELATIONSHIP.md") else d(-5)
        if not m or m.group(1) != want:
            die("the deal-status fixture is broken: %s has Last updated %s, expected %s" % (rel, m.group(1) if m else "none", want))
    srcs = [f for f in all_files("sources") if os.path.basename(f) not in (".gitkeep", "README.md")]
    if len(srcs) < 15:
        die("the deal-status fixture is broken: only %d files under sources/, expected at least 15" % len(srcs))
    brochure_rel = src_rel(-2, "received", "pilot-brochure")
    if brochure_rel not in srcs:
        die("the deal-status fixture is broken: " + brochure_rel + " is missing")
    # token uniqueness: each seed token lives in exactly its seed
    hits = {"questionnaire": [], "steering": [], "brochure": []}
    for sub in ("dossier", "outbound", "sources", "knowledge"):
        for rel in all_files(sub):
            if rel == "sources/README.md":
                continue
            raw = rd(rel)
            hay = (rel + "\n" + (raw or "")).lower()
            for tok in hits:
                if tok in hay:
                    hits[tok].append(rel)
    if hits["questionnaire"] != ["dossier/HISTORY.md"] or not any("questionnaire" in l.lower() for l in section(hist, "### Ours", "###")) \
            or sum(1 for l in hist.split("\n") if "questionnaire" in l.lower()) != 1:
        die("the deal-status fixture is broken: 'questionnaire' is not unique to the overdue commitment (%s)" % hits["questionnaire"])
    if hits["steering"] != [SEED_DRAFT_REL]:
        die("the deal-status fixture is broken: 'steering' is not unique to its draft (%s)" % hits["steering"])
    if hits["brochure"] != [brochure_rel]:
        die("the deal-status fixture is broken: 'brochure' is not unique to its source (%s)" % hits["brochure"])
    for rel in all_files("outbound"):
        hay = (rel + "\n" + (rd(rel) or "")).lower()
        if "northwind" in hay:
            die("the deal-status fixture is broken: a confidential name appears under outbound/ (%s)" % rel)
PYSTATUS
}

# status_fixture DIR TODAY — writes the CALL-05 fixture AND commits it in dated
# stages (mtimes set before each add, so the index stat matches and
# `git status` has nothing to refresh); echoes the final HEAD.
status_fixture() {
  local dir="$1" today="$2" st msg code
  code="$(_call_status_py)"
  for st in -40 -30 -20 -10 -5 -2 -1; do
    msg="$(_call_py "$code" "$dir" "$today" "$st" 2>&1)" \
      || scenario_die "status_fixture stage D($st) failed: $msg"
    commit_at "$dir" "$(rel_date "$st" "$today")" "fixture stage D($st)" >/dev/null \
      || scenario_die "status_fixture: commit of stage D($st) failed"
  done
  git -C "$dir" rev-parse HEAD
}

# check_status_fixture DIR TODAY — scenario_die naming the broken seed, trap,
# count, date or token uniqueness, else nothing.
check_status_fixture() {
  local dir="$1" today="$2" msg brochure d2 d1 head_date
  msg="$(_call_py "$(_call_status_py)" "$dir" "$today" check 2>&1)" \
    || scenario_die "$msg"
  brochure="sources/received/$(rel_date -2 "$today")_pilot-brochure.txt"
  d2="$(git -C "$dir" log --diff-filter=A --format=%ad --date=short -- "$brochure" 2>/dev/null | tail -1)"
  [ "$d2" = "$(rel_date -2 "$today")" ] \
    || scenario_die "the deal-status fixture is broken: the brochure was added on '$d2', expected $(rel_date -2 "$today")"
  head_date="$(git -C "$dir" log -1 --format=%ad --date=short 2>/dev/null)"
  d1="$(rel_date -1 "$today")"
  [ "$head_date" = "$d1" ] \
    || scenario_die "the deal-status fixture is broken: HEAD is dated '$head_date', expected $d1"
  if git -C "$dir" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | grep -q '^sources/'; then
    scenario_die "the deal-status fixture is broken: HEAD touches a file under sources/"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Verdict helpers
# ---------------------------------------------------------------------------

# call_question_order FILE TOK1 TOK2 TOK3 — yes when each token occurs
# (case-insensitively) on a line of FILE that also holds a `?` and the first
# such lines number strictly ascend in argument order; no when all occur but not
# in that order; missing when one does not occur or FILE is missing.
call_question_order() {
  python3 -I -c '
import sys
path, toks = sys.argv[1], sys.argv[2:5]
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print("missing")
    sys.exit(0)
first = []
for tok in toks:
    hit = None
    for i, line in enumerate(lines):
        if "?" in line and tok.casefold() in line.casefold():
            hit = i
            break
    if hit is None:
        print("missing")
        sys.exit(0)
    first.append(hit)
print("yes" if first[0] < first[1] < first[2] else "no")
' "$1" "$2" "$3" "$4"
}

# call_heading_present FILE ERE — yes when a heading line of FILE (^#{1,6} )
# matches ERE case-insensitively (applied to the whole line), else no.
call_heading_present() {
  python3 -I -c '
import re, sys
path, ere = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print("no")
    sys.exit(0)
pat = re.compile(ere, re.I)
print("yes" if any(re.match(r"#{1,6} ", l) and pat.search(l) for l in lines) else "no")
' "$1" "$2"
}

# call_minutes_empty FILE ERE — for the last heading line matching ERE
# (case-insensitive, whole line): yes when every line after it, up to the next
# heading or the end, is blank or inside an HTML comment, no when one is not;
# none when no heading matches or FILE is missing.
call_minutes_empty() {
  python3 -I -c '
import re, sys
path, ere = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print("none")
    sys.exit(0)
pat = re.compile(ere, re.I)
idx = None
for i, l in enumerate(lines):
    if re.match(r"#{1,6} ", l) and pat.search(l):
        idx = i
if idx is None:
    print("none")
    sys.exit(0)
body = []
for l in lines[idx + 1:]:
    if re.match(r"#{1,6} ", l):
        break
    body.append(l)
text = "\n".join(body)
text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
text = re.sub(r"<!--.*\Z", "", text, flags=re.S)
print("yes" if text.strip() == "" else "no")
' "$1" "$2"
}

# call_timed_lines FILE — the number of timed lines: a line counts when it holds
# no `@` and matches (re.I) either (?:^|[^0-9:@])[0-9]{1,2}:[0-9]{2}(?![0-9]) or
# [0-9]+ ?min. The `@` exclusion keeps transcript locators out.
call_timed_lines() {
  python3 -I -c '
import re, sys
try:
    with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print(0)
    sys.exit(0)
a = re.compile(r"(?:^|[^0-9:@])[0-9]{1,2}:[0-9]{2}(?![0-9])", re.I)
b = re.compile(r"[0-9]+ ?min", re.I)
print(sum(1 for l in lines if "@" not in l and (a.search(l) or b.search(l))))
' "$1"
}

# call_line_present FILE ERE — yes when any line matches ERE, no otherwise,
# none without FILE.
call_line_present() {
  python3 -I -c '
import re, sys
try:
    with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print("none")
    sys.exit(0)
pat = re.compile(sys.argv[2])
print("yes" if any(pat.search(l) for l in lines) else "no")
' "$1" "$2"
}

# text_has_ci JSONL NEEDLE — yes when the LAST result event's result text holds
# NEEDLE case-insensitively, after folding `-` and `_` to a space in both.
text_has_ci() {
  python3 -I -c '
import json, sys
path, needle = sys.argv[1], sys.argv[2]
last = None
try:
    fh = open(path, encoding="utf-8", errors="replace")
except OSError:
    print("no")
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if isinstance(ev, dict) and ev.get("type") == "result":
            last = ev.get("result")
def fold(s):
    return str(s).casefold().replace("-", " ").replace("_", " ")
print("yes" if isinstance(last, str) and needle and fold(needle) in fold(last) else "no")
' "$1" "$2"
}

# call_reads JSONL — the number of assistant Read tool_uses plus Bash tool_uses
# whose command contains `cat `, `head ` or `sed -n`.
call_reads() {
  python3 -I -c '
import json, sys
n = 0
try:
    fh = open(sys.argv[1], encoding="utf-8", errors="replace")
except OSError:
    print(0)
    sys.exit(0)
with fh:
    for line in fh:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict) or ev.get("type") != "assistant":
            continue
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if block.get("name") == "Read":
                n += 1
            elif block.get("name") == "Bash" and isinstance(block.get("input"), dict):
                cmd = str(block["input"].get("command", ""))
                if "cat " in cmd or "head " in cmd or "sed -n" in cmd:
                    n += 1
print(n)
' "$1"
}

# stop_blocked JSONL — yes when the stream holds the Stop hook's text
# `but nothing under dossier/ did`, else no.
stop_blocked() {
  if [ -f "$1" ] && grep -qF -- 'but nothing under dossier/ did' "$1"; then
    echo yes
  else
    echo no
  fi
}

# porcelain_empty DIR — yes when `git status --porcelain` prints nothing.
porcelain_empty() {
  local out
  out="$(git --no-optional-locks -C "$1" status --porcelain 2>/dev/null)" || {
    echo no
    return 0
  }
  if [ -z "$out" ]; then echo yes; else echo no; fi
}

# tree_manifest DIR — one line `<sha256>  <relative path>` per regular file
# under DIR, .git included, sorted.
tree_manifest() {
  python3 -I -c '
import hashlib, os, sys
root = sys.argv[1]
rows = []
for base, dirs, files in os.walk(root):
    dirs.sort()
    for name in files:
        path = os.path.join(base, name)
        if os.path.islink(path) or not os.path.isfile(path):
            continue
        try:
            with open(path, "rb") as fh:
                sha = hashlib.sha256(fh.read()).hexdigest()
        except OSError:
            sha = "UNREADABLE"
        rows.append((os.path.relpath(path, root), sha))
rows.sort()
for rel, sha in rows:
    print("%s  %s" % (sha, rel))
' "$1"
}
