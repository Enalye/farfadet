# Farfadet
Format déclaratif simple de configuration

# Format

Le format farfadet est organisé sous formes de simples commandes.

## Commentaire
Farfadet supporte deux types de commentaires:
* Les commentaires monolignes:
```
// Ceci est un commentaire
```
* Et les commentaires multilignes
```
/* Le texte
entre ces symboles /* sera */
ignoré */
```
Les commentaires imbriqués sont également supportés.

## Commande
Chaque commande est défini par une clé, qui peut s’accompagner d’un certain nombre d’arguments et d’un bloc de commandes optionnels.

Chaque commande est séparé d’une autre par un retour à la ligne ou un point‑virgule `;`.

Exemples:
```
maCommande
maCommande 3 12.5 "bonjour" [2 3 4] ; maCommande
maCommande {
    // Liste de commandes
}
maCommande false {}
```

## Argument
Un argument est une valeur associée à une commande et à un emplacement.

Un argument peut être de plusieurs types:
 * Entier (signé ou non-signé): `-12`, `0`, `+3_000`, `-0xFF`, `0b1100_0111`, `0o777`
 * Décimal: `3.14`, `-10.0`, `+0.1`
 * Lettre: `'a'`, `é`, `\n`, `🐕`, `\u{1F415}`
 * Booléen: `true`, `false`
 * Texte: `"Bonjour les gens"`
 * Liste: `[2 4 55 -13]`, `[true false false true]`

L’ordre des argument est fixe:
```
commande "zéro" [1 2] 3.0 '4' 5
// Ici "zéro" est le premier argument, [1 2] est le deuxième, 3.0 le troisième, etc.
```

## Bloc de commandes
Chaque commande peut définir d’autres commandes enfants à l’aide d’un bloc entre accolades `{` et `}`.

Exemple:
```
maCommande {
    commande1 ; commande2
    commande3
}
```

# API

## Lire un document farfadet
Ouvrir un document farfadet se fait comme suit:
```d
string text = "
commande1 1 [2 3]
commande2 {
    commande3
}";
Farfadet ffd = new Farfadet(text);
```
Accéder aux nœuds enfants se fait avec `Farfadet.nodes`:
```d
Farfadet ffd = new Farfadet(text);

foreach(node; ffd.nodes) {
    /// Traite chaque nœud enfant
}
```

Le nom de la commande associé à un nœud se récupère avec `Farfadet.name`:
```d
import std.stdio : writeln;

Farfadet ffd = new Farfadet(text);

foreach(node; ffd.nodes) {
    writeln("Nom du nœud: ", node.name);
}
```

Pour récupérer un argument d’une commande, on utilise `Farfadet.get()`:
```d
import std.stdio : writeln;

Farfadet ffd = new Farfadet(text);

foreach(node; ffd.nodes) {
    if(node.name == "commande1") {
        writeln("Arguments: ", node.get!int(0), ", ", node.get!(int[])(1));
    }
}
```

## Générer un document farfadet

Pour générer un document, on crée un nœud vide:
```d
Farfadet ffd = new Farfadet;
```

Ce nœud représente le document en lui-même et ne peut pas avoir d’argument ni de nom, seulement des nœuds enfants.

Ajouter un nœud enfant se fait avec `Farfadet.addNode()`:
```d
Farfadet command1 = ffd.addNode("command1");
```

Supprimer les nœuds se fait avec `Farfadet.clearNodes()`.

Ajouter un argument au nœud peut se faire avec `Farfadet.add()`:
```d
command1.add(1);
command1.add([2, 3]);
```
Supprimer les arguments se fait avec `Farfadet.clear()`.

Enfin, pour générer le code, on utilise `Farfader.generate()`:
```d
string result = ffd.generate();
```
