---
description: Ambiguous "write to the client" must route to dossier-draft, never dossier-ingest
tags: [routing, draft, ambiguous]
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
---

Write to the client to say we can deliver the audit on 2026-11-02 instead of 2026-10-28.
