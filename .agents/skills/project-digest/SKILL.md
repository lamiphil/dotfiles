---
name: project-digest
description: Régénère la vue d'ensemble (_MOC.md) d'un projet à partir de toutes ses notes. Crée le tableau de bord Dataview s'il manque, puis synthétise l'état courant, les décisions, les questions ouvertes et les prochaines étapes. Use when the user invokes /project-digest, or wants a project overview / status refresh / dashboard.
---

# Project Digest Skill

Produit ou rafraîchit le fichier `_MOC.md` (Map of Content) d'un projet: le tableau de bord
qui donne la vue d'ensemble. La partie automatique (listes Dataview) et la partie synthétisée
(état écrit) sont séparées par des marqueurs, pour ne jamais écraser le mauvais bout.

## Vault et langue

- Vault: `/Users/philippe.lamy/workspaces/vooban/notes`
- Écrire en **français** (Québec), concis, première personne.

## Résoudre le projet

Argument = nom ou slug du projet.

| Projet | Slug | Dossier |
|--------|------|---------|
| SOM | `som` | `Customers/SOM/` |
| Maheu-Maheu | `maheu-maheu` | `Customers/Maheu-Maheu/` |

Si absent de la table, chercher un dossier correspondant sous `Customers/`. Si rien, demander.

## Scaffold du _MOC.md (créer s'il manque)

Créer `Customers/<Projet>/_MOC.md` avec cette structure. Le slug dans les requêtes Dataview
doit être le slug du projet.

````markdown
---
customer: <slug>
type: moc
---
# <Projet> — Vue d'ensemble

<!-- DIGEST:START -->
_(synthèse régénérée par /project-digest)_
<!-- DIGEST:END -->

## En cours
```dataview
TABLE status, date, link
FROM #<slug>
WHERE type = "issue" AND status = "ongoing"
SORT date DESC
```

## Tous les tickets
```dataview
TABLE status, date, link
FROM #<slug>
WHERE type = "issue"
SORT date DESC
```

## Décisions
```dataview
TABLE date, file.link
FROM #<slug>
WHERE type = "decision"
SORT date DESC
```

## Rencontres récentes
```dataview
TABLE date, file.link
FROM #<slug>
WHERE type = "meeting"
SORT date DESC
LIMIT 10
```

## Références
```dataview
LIST FROM #<slug> WHERE type = "ref"
```
````

## Régénérer la synthèse

1. Lire **toutes** les notes du dossier projet (`Issues/`, `Meetings/`, `Refs/`, `_info.md`).
2. Synthétiser, et remplacer **uniquement** le contenu entre `<!-- DIGEST:START -->` et
   `<!-- DIGEST:END -->` par:

```markdown
> [!info] État au YYYY-MM-DD
> <1 à 3 phrases sur où en est le projet globalement.>

**En cours:** <ce qui bouge activement, avec [[wikilinks]] vers les notes.>

**Décisions récentes:** <décisions clés prises, avec liens.>

**Questions ouvertes / risques:** <ce qui est incertain ou à surveiller.>

**Prochaines étapes:** <les prochains gestes concrets.>
```

3. Ne pas toucher aux blocs Dataview ni au reste du fichier.

## Process

1. Résoudre le projet -> dossier.
2. Si `_MOC.md` n'existe pas, le créer avec le scaffold (slug correct dans les requêtes).
3. Lire toutes les notes du projet.
4. Synthétiser et remplacer le bloc entre les marqueurs DIGEST.
5. Confirmer à l'utilisateur ce qui a été rafraîchi, et signaler les notes au frontmatter
   incomplet (type/status/customer manquants) qui n'apparaîtront pas dans les Dataview.
