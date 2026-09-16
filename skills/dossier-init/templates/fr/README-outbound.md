# Sortant

Chaque fichier de ce dossier s'ouvre sur un en-tête de statut, verbatim :

```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```

Les fichiers sont nommés `YYYY-MM-DD_slug` (plus leur extension).

- `deliverables/` — un fichier rendu garde son fichier source à côté, même radical.
- `mails/` — un fichier par message.
- `calls/` — préparation, puis compte-rendu.

Deux règles permanentes : aucun nom confidentiel n'apparaît jamais dans un fichier de ce dossier,
et rien ne quitte ce dépôt sans qu'un humain l'envoie.
