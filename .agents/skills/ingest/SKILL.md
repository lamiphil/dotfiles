---
name: ingest
description: Rapatrie une source de connaissance externe (compte-rendu Fellow, doc Google Drive, thread Gmail) dans une note Obsidian propre du bon projet, avec frontmatter, wikilinks et résumé. Use when the user invokes /ingest, or wants to import/consolidate meeting notes, shared docs, or emails into the vault.
---

# Ingest Skill

Transforme une source externe (Fellow, Google Drive, Gmail) en note Obsidian propre,
rangée dans le bon dossier projet, avec le frontmatter standard et des wikilinks vers
les notes existantes reliées.

## Vault et langue

- Vault: `/Users/philippe.lamy/workspaces/vooban/notes`
- Écrire en **français** (Québec), notes concises à la première personne.
  Garder les termes techniques en anglais quand c'est plus clair (`Docker`, `k8s`, `VPN`, etc.).

## Conventions du système (contrat de metadata)

Chaque note du vault déclare son projet, son type et son statut dans le frontmatter.
C'est ce qui permet aux `_MOC.md` (voir skill `project-digest`) de s'assembler seuls.

```yaml
---
customer: maheu-maheu        # slug stable du projet (voir table ci-dessous)
type: meeting | ref | decision | issue | contact | info
status: ongoing | completed | blocked | archived
date: YYYY-MM-DD             # date de la source, pas d'aujourd'hui
source: fellow | gdrive | gmail | gitlab
link: <URL de la source>     # lien vers l'original
tags: [<slug-projet>, <type>]
---
```

### Table des projets (slugs)

| Projet | Slug | Dossier |
|--------|------|---------|
| SOM | `som` | `Customers/SOM/` |
| Maheu-Maheu | `maheu-maheu` | `Customers/Maheu-Maheu/` |

Si le projet n'est pas dans la table, **demander** le nom et le slug, puis créer le dossier
`Customers/<Nom>/` avec les sous-dossiers `Issues/`, `Meetings/`, `Refs/`.

### Emplacement de la note produite

- `type: meeting` -> `Customers/<Projet>/Meetings/YYYY-MM-DD - <titre>.md`
- `type: ref` ou `decision` -> `Customers/<Projet>/Refs/<titre>.md`
- Créer les sous-dossiers manquants.

## Récupérer la source

Les outils MCP sont différés: les charger via ToolSearch avant de les appeler.

### Fellow (comptes-rendus de rencontre)

Fellow n'est **pas authentifié par défaut**. D'abord `ToolSearch` avec
`query: "fellow"`. Si seuls `authenticate` / `complete_authentication` apparaissent,
appeler `mcp__claude_ai_Fellow_ai__authenticate` et suivre le flot OAuth avec l'utilisateur,
puis re-chercher les outils de lecture. Récupérer la rencontre visée (par titre, date, ou
participants) et son contenu complet (notes, action items, décisions).

### Google Drive (docs partagés)

`ToolSearch` avec `query: "google drive read search"`. Utiliser
`mcp__claude_ai_Google_Drive__search_files` pour trouver le doc, puis
`read_file_content` / `download_file_content` pour le contenu.

### Gmail (courriels avec info projet)

`ToolSearch` avec `query: "gmail thread search"`. Utiliser `search_threads` puis
`get_thread` pour le fil complet.

### GitLab (docs/architecture dans un repo)

Pas de MCP: utiliser la CLI `glab`. Récupérer un fichier brut via l'API:
`glab api "projects/<path%2Furl-encodé>/repository/files/<chemin%2Fencodé>/raw?ref=<branche>"`.
Ex.: `projects/vooban%2Fcustomers%2Fsom%2Fsom-docs/repository/files/architecture%2Fplan-adressage-ip.md/raw?ref=dev`.
Ces docs sont en général `type: ref` ou `decision`.

## Composer la note

Ne pas copier-coller brut. Produire une note structurée:

1. **Frontmatter** conforme au contrat ci-dessus.
2. Titre `# <titre>`.
3. `## Résumé` — 2 à 4 phrases sur l'essentiel.
4. `## Points clés` — bullets des faits/infos importants.
5. `## Décisions` — décisions prises (si applicable).
6. `## Actions` — action items avec responsable si connu (`- [ ] @qui: quoi`).
7. `## Détails` — le contenu détaillé nettoyé (pas le bruit).

### Wikilinks

Avant d'écrire, `Grep` le vault pour les entités mentionnées (numéros de tickets `MAH-*`,
`CR-*`, noms de clusters, de personnes, de composants). Pour chaque correspondance avec
une note existante, insérer un wikilink `[[nom-de-note]]`. Un wikilink vers une note
inexistante est acceptable s'il désigne clairement une note à créer plus tard.

## Process

1. Identifier la source (Fellow/GDrive/Gmail) et le projet. Si l'un des deux est ambigu, demander.
2. Charger les outils MCP requis via ToolSearch (authentifier Fellow si besoin).
3. Récupérer le contenu de la source.
4. Déterminer `type`, `date` (celle de la source), slug projet et emplacement.
5. Grep le vault pour les entités reliées -> wikilinks.
6. Écrire la note (créer les dossiers manquants).
7. Confirmer à l'utilisateur: quoi a été importé, où, et quels liens ont été créés.
   Suggérer de lancer `/project-digest <projet>` pour rafraîchir la vue d'ensemble.
