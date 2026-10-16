# linto

Linux Tools (mainly command-line)

Scripts de gestion de la bibliographie (`fr.bib`, `transcriptions.json`, fichiers `_pieces-*.yml`) et de rendu des documents Quarto du projet.

La plupart des scripts supposent d'être lancés **depuis la racine du projet** (le dossier parent de `scripts/`), là où se trouvent `fr.bib`, `transcriptions.json` et les fichiers `.qmd`.

## Vue d'ensemble du flux

```
transcriptions.json ⇄ fr.bib ──► _pieces-XXX.yml ──► pieces-XXX.bib ──► quarto render
   (json2bib.sh / bib2json.sh)     (lib/generer-bib.py via build-bib.sh, lancé par render.sh)
```

### bib2json.sh

### json2bib.sh

## Rendu et génération de la bibliographie

| Script | Rôle | Usage |
|---|---|---|

### render.sh

### scripts/render.sh

Lance `build-bib.sh` puis `quarto render` sur chaque `*.qmd` du dossier courant. 

### build-bib.sh

./scripts/build-bib.sh  
Pour chaque `_pieces-*.yml`, appelle `lib/generer-bib.py` et produit `pieces-*.bib` (le préfixe `_` est retiré). 

### lib/generer-bib.py

python3 lib/generer-bib.py _pieces-ref-08.yml pieces-ref-08.bib  
Génère un `.bib` contextuel : reprend les entrées de `fr.bib` listées dans un YAML clé → numéro et leur injecte un champ `number`. Signale les clés absentes de `fr.bib`. Nécessite PyYAML. Appelé par `build-bib.sh`. 

### firefox-open-version.sh
 
Ouvre dans Firefox la dernière version `draft-*` de `_output/versions/`. 


## Conversion et manipulation de la bibliographie

### bib2json.sh

./bib2json.sh <fichier.bib> <entrée.json> <sortie.json>  
Injecte les entrées de `fr.bib` dans le champ `bibtex` de chaque clé de `transcriptions.json` (via `bibtexparser`, installé avec pip) et liste les clés absentes de `fr.bib`. Les trois fichiers sont obligatoires. 

### json2bib.sh

./json2bib.sh <entrée.json> <sortie.bib>  
Opération inverse : reconstruit `fr.bib` à partir du champ `bibtex` de `transcriptions.json` (via `jq`). Les deux fichiers sont obligatoires. 

### mkbib.sh

./mkbib.sh fr.bib  
Éclate un fichier `.bib` en un fichier par entrée dans `./bib/<clé>.bib`. `mkbib.sh` vérifie l'argument et appelle `lib/mkbib.awk` (résolu par rapport au dossier du script).  (utilise  ./lib/mkbib.awk )

### formatsiglebib.sh

./formatsiglebib.sh fichier.bib  
Remet en forme un `.bib` de `@misc` : en-tête, champs triés, virgules finales corrigées. Réécrit le fichier. 

### bib2csv.awk

gawk -f bib2csv.awk fr.bib > fr.csv  
Extrait la clé et un ensemble fixe de champs d'un `.bib` en CSV séparé par `;`. Filtre optionnel par thème (`-v theme="acp,far"`). Nécessite gawk. 

### annexes.awk

gawk -f annexes.awk fr.csv  
Lit le CSV produit par `bib2csv.awk` et génère les listes d'annexes en Markdown, regroupées par année et mois. Trois formats de sortie (variable `output_format`, 1 par défaut). Nécessite gawk. 


## Numérotation et texte

### renumberyml.py

python3 renumberyml.py in.yml [out.yml]  
Renumérote un YAML de lignes `"clé": N` pour que chaque valeur soit égale à son numéro de ligne. Sortie standard si aucun fichier de sortie n'est donné. 

### renumberyml.awk

awk -f renumberyml.awk in.yml  
Version minimale : affiche `premier-champ: numéro-de-ligne`. 

### endquotes.sh

./endquotes.sh fichier.md  
Remplace les guillemets français `«` et `»` par `"` dans un fichier (sauvegarde `.bak`). 

### md2json.py

python3 md2json.py fichier.md --format sections --pretty  
Convertit du Markdown en JSON (formats texte brut, structuré, sections ; options `-o`, `--format`, `--pretty`, `--outdir`). 

### cetcst.py

python3 cetcst.py  
Exemple/utilitaire : transforme une date et une heure locales (Europe/Paris) en horodatage ISO 8601 avec décalage UTC, pour le champ `date` de biblatex. Nécessite `pytz`. Les valeurs sont codées en dur dans le script. 


## `loops/` – scripts de migration ponctuels

Scripts utilisés pour des migrations en masse de `fr.bib`. Les `loop_*.sh` lisent un CSV séparé par `;` sans en-tête et appliquent un `sed -i` sur `fr.bib` pour chaque ligne. Ils ont été écrits pour des opérations ponctuelles : **ils modifient `fr.bib` sur place, faites une copie avant de les relancer**.

| Script | Rôle |
|---|---|

### loop_authors.sh

CSV `auteur;acronyme-organisation` : ajoute un champ `x-orgacronyme` après chaque champ `author` correspondant.

### loop_types.sh

CSV `ancien;nouveau` : renomme le préfixe des clés `@misc`, et ajoute `x-key-orig`, `x-type-orig`, `x-type`.

### loop_calckey_key.sh

CSV `calckey;clé` : modèle de boucle de correspondance entre clés calculées et clés.

### loop_compteurs.sh

Idem, pour les compteurs.

### loop_keys.sh

Idem, pour les clés.

### loop_neweditions.sh

Idem, pour les nouvelles éditions.

### old2newkeys.awk

À partir d'un CSV de la bibliographie, affiche des commandes `sed` qui remplacent les anciennes clés (`x-key-orig`, `x-key-orig2`) par les nouvelles dans les citations `@clé`.

### modifrefs.sh

Série de `sed` qui renomment les anciennes clés de citation (`@email211209acparisorg1838`) vers le nouveau format (`@2021-12-09-acparisorg-1838`) dans le fichier passé en argument.

### modifpublishers.sh

Série de `sed` qui convertissent `howpublished` en `publisher` pour des adresses e-mail dans les `.bib` d'un dossier passé en argument.

> Les en-têtes de commentaires de plusieurs `loop_*.sh` sont des copies de `loop_calckey_key.sh` et ne décrivent pas toujours fidèlement le script ; le rôle indiqué ci-dessus est déduit de la commande `sed` de chaque boucle.
