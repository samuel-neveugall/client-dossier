# tests/fixtures/lint/fr -- the committed French lint fixture

A French-content dossier (`language: fr`) that `scripts/lint.py` must pass with exit 0 while
raising both prose warnings, `[W1]` and `[W2]`, and no error at all. It is ROADMAP Phase 2
criterion 3, asserted by `tests/test-lint.sh` on paths and line numbers, not on a count.

**Why it is committed.** It is the only committed lint fixture (D-28 as amended): it carries
content the producer can never generate -- deliberate relative-date words, deliberately
unsourced bullets, a typographic apostrophe, a genuine multi-line HTML comment block and a
word-boundary bait line. Everything else was scaffolded by `init.py --language fr` and kept
as is, including the English `Last updated:` labels inside French prose: that label is a
protocol keyword and is never translated, which is what `[E7]` staying silent here proves.

**The clean fixture is not here.** It is generated at test time by a real `init.py` run in
`tests/test-lint.sh`, and the error fixtures are built from it by
`tests/fixtures/make-lint-fixtures.sh`, so "a fresh scaffold lints clean" stays a statement
about the scaffolder rather than about a hand-maintained copy.

**Not a faithful copy of the producer's output.** git tracks no empty directory, so this tree
may lack `sources/transcripts/` itself (only `sources/transcripts/raw/.gitkeep` is tracked).
No Phase 2 check reads that folder, so the loss is harmless here; the sync guarantee belongs
to the generated clean fixture.

**What each overlay line is for** (`dossier/HISTORY.md` unless stated):

| Line | Expected |
|------|----------|
| `rappelle demain pour valider le périmètre.` | `[W1]` and `[W2]` on the same line |
| `attendu la semaine prochaine (appel @12:34).` | `[W1]` only -- sourced |
| `Probablement un budget revu à la hausse.` | nothing -- opinion marker |
| `Leur priorité est reconstruite ...` | `[W2]` -- an inflected near-marker is not a marker |
| `confirmé le cadrage aujourd’hui (mail ...)` | `[W1]` -- typographic apostrophe (U+2019) |
| the bullet inside the `<!--` ... `-->` block | nothing -- the comment tracker |
| `Acme attend une proposition chiffrée.` | `[W2]` -- the tracker closed |
| `dossier/CHANNELS.md`: `Les fichiers de la hiérarchie ...` | nothing -- `hier` is inside words |
| `knowledge/CONTEXT.md`: `Le marché a bougé récemment.` | `[W1]` -- `knowledge/` is in scope |

Every name in this tree (Acme, Jane Doe, Paul Martin) is invented. Edit this tree only
together with the assertions in `tests/test-lint.sh` that pin it.
