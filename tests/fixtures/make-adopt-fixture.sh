#!/usr/bin/env bash
# tests/fixtures/make-adopt-fixture.sh — builds a throwaway, origin-shaped
# repository for SCAF-06's adoption-detection tests (D-13, D-14, D-17).
#
# CONFIDENTIALITY (D-13, T-01-26): only folder and file *names* are used,
# taken from 01-RESEARCH.md's already-redacted structural audit of the
# origin engagement repository. This script never opens, reads, copies or
# runs anything against that repository. Every file it creates is either
# empty or holds the single literal word `placeholder` — no real content,
# no person or organisation name, anywhere.
#
# Takes no arguments. Creates its own throwaway tree under `mktemp -d` and
# never writes anywhere else. Echoes the tree's path on success.
set -eu

d="$(mktemp -d)"

write_placeholder() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  printf 'placeholder\n' >"$path"
}

# --- Top level ---
write_placeholder "$d/.gitignore"
write_placeholder "$d/CLAUDE.md"
write_placeholder "$d/README.md"

# --- client/ — the seven living files + README (D-14's rename source) ---
write_placeholder "$d/client/ACTEURS.md"
write_placeholder "$d/client/APPRENTISSAGES.md"
write_placeholder "$d/client/CANAUX.md"
write_placeholder "$d/client/HISTORIQUE.md"
write_placeholder "$d/client/QUESTIONS-OUVERTES.md"
write_placeholder "$d/client/RELATION.md"
write_placeholder "$d/client/TON.md"
write_placeholder "$d/client/README.md"

# --- communication/ ---
write_placeholder "$d/communication/README.md"
write_placeholder "$d/communication/appels/PLACEHOLDER.md"
write_placeholder "$d/communication/livrables/PLACEHOLDER.md"
write_placeholder "$d/communication/mails/PLACEHOLDER.md"

# --- docs/ (docs/veille/ is added below, after the commit, deliberately
# left untracked — the git-mv failure mode of RESEARCH Pitfall 6) ---
write_placeholder "$d/docs/CONTEXTE.md"
write_placeholder "$d/docs/DOCTRINE.md"
write_placeholder "$d/docs/decisions/2026-01-15_example.md"

# --- pipeline/ — plays no dossier role; left alone and reported ignored
# (D-17) ---
write_placeholder "$d/pipeline/DESIGN.md"
write_placeholder "$d/pipeline/README.md"
write_placeholder "$d/pipeline/bin/PLACEHOLDER.md"
write_placeholder "$d/pipeline/templates/PLACEHOLDER.md"

# --- sources/ — internes/ and plaquette/ are unmapped (RESEARCH DISC-1/
# O-3, decided in 01-05-PLAN.md's Deviations: reported ignored, never
# renamed). transcripts/ and transcripts/raw/ already carry their fixed
# English names. ---
write_placeholder "$d/sources/internes/PLACEHOLDER.md"
write_placeholder "$d/sources/plaquette/PLACEHOLDER.md"
write_placeholder "$d/sources/transcripts/PLACEHOLDER.md"
write_placeholder "$d/sources/transcripts/raw/PLACEHOLDER.md"

git -C "$d" init -q
git -C "$d" config user.email "test@example.invalid"
git -C "$d" config user.name "Test Runner"
git -C "$d" add -A
git -C "$d" commit -q -m "fixture: origin-shaped tree"

# The untracked candidate that exercises the git-mv failure mode
# (RESEARCH Pitfall 6, O-2): created after the commit, left uncommitted.
write_placeholder "$d/docs/veille/README.md"

echo "$d"
