<!-- client-dossier:start -->
Ce dépôt est un **dossier client** : un dépôt git qui garde la mémoire d'une relation avec un
tiers, géré par le plugin d'agent de code `client-dossier`.

- `sources/` — immuable. Jamais modifié une fois versé ; les corrections vont dans les
  fichiers vivants.
- `dossier/` — les sept fichiers vivants : ce qui est vrai aujourd'hui de cette relation,
  chaque fait sur sa propre ligne datée et sourcée.
- `knowledge/` — le contexte interne et la doctrine à laquelle cette relation est confrontée.
- `outbound/` — tout ce qui est adressé au tiers. Chaque fichier commence par un statut, et
  c'est toujours un humain qui envoie — un agent n'envoie jamais un brouillon depuis ce
  dossier.

Lire avant d'agir : `dossier/` et `knowledge/CONTEXT.md`. Mettre à jour avant de rendre la
main : les fichiers vivants que le travail a touchés.

Chaque fait tient en une phrase, porte une date absolue et une source entre parenthèses (un
horodatage d'appel, une date et un expéditeur de mail, une page de document). Une ligne
contredite se corrige sur place, elle ne se duplique pas.

Ne jamais : modifier quoi que ce soit sous `sources/`, envoyer quoi que ce soit, ou nommer
une partie confidentielle dans `outbound/`.

La configuration vit dans `dossier.yaml`. Le protocole complet vit dans la compétence
`dossier` du plugin `client-dossier`.
<!-- client-dossier:end -->
