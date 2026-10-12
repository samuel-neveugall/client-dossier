#!/bin/bash
# evals/routing/init-new-client/scaffold.sh -- a bare repository, no dossier yet:
# the skill under test is the one that creates it. Runs in an empty workspace
# (claude plugin eval --scaffold); no network, nothing written outside it.
set -eu
git init -q .
