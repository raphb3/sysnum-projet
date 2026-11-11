# Simulateur de netlist

## Compilation

Depuis le dossier `tp1` :

```bash
ocamlbuild netlist_simulator.byte
```

## Exécution

```bash
./netlist_simulator.byte -n <nombre_de_cycles> <fichier.net>
```

### Tests effectués

J'ai exécuté tous les tests et, si je ne me trompe pas sur leur fonctionnement, mon programme semble fonctionner.

## Explication de mon simulateur

Avant toute chose, je vais décrire la structure de ma fonction `simulator` et les choix effectués.

Le cœur de la simulation utilise trois environnements :

- `env` (sous forme de `ref`)
- `env_prec` (idem)
- `env_mem`

`env` est l'environnement que l'on met à jour (via la référence) au cours d'un tour de boucle du programme.

`env_prec` sert à trois choses :

- initialiser toutes les variables à `false` avant le premier tour de boucle ;
- garder en mémoire les valeurs nécessaires au fonctionnement de `REG` ;
- servir de base à `env` au moment d'entrer les inputs : en effet, les valeurs qui ne sont pas des inputs seront de toute manière recalculées au cours du cycle.

`env_mem` est un environnement associant des `id` d'équations à des `bool array array`, qui sont mes cases mémoire. J'ai fait le choix de créer ce troisième environnement car les éléments de `env` et `env_prec` sont des `VBit` et des `VBitArray`, alors que j'ai représenté ma mémoire sous la forme de `bool array array`.

### Fonctionnement de `simulator`

1. On initialise `env_prec` (cf. la fonction correspondante plus bas).
2. On initialise `env_mem` (idem).
3. On boucle sur `i` de 1 à `number_steps` :
   - on affiche l'étape actuelle ;
   - on demande à l'utilisateur d'entrer la valeur de toutes les inputs ;
   - on évalue chacune des équations et on stocke le résultat dans la référence `env` ;
   - on écrit dans `env_mem` ce qui a été écrit dans la RAM ; l'écriture n'est donc effective qu'au cycle suivant ;
   - on affiche les outputs ;
   - on remplace le contenu de la référence `env_prec` par `env`.

J'ai essayé de garder `simulator` le plus court possible afin de me concentrer sur le fonctionnement global du programme et non sur la mise en pratique, qui est assurée par les fonctions annexes.

## Explication des fonctions annexes (dans l'ordre du fichier)

### `valeur_arg` (ligne 6)

Prend en argument un argument et un environnement, et renvoie la valeur de l'argument. Gère le cas où l'argument en question est une constante.

### `vbitarray_convert` (ligne 11)

Prend en argument une valeur de type `VBitArray` ou `VBit` et la transforme en array. Cela facilite grandement l'évaluation des `CONCAT`, etc.

### `convert_read_addr` (ligne 16)

Prend en argument une adresse de lecture ou d'écriture (sous forme de `VBit` ou de `VBitArray`).

Comme on le verra dans la fonction suivante, une ROM ou une RAM est modélisée par un `bool array array` (un array d'arrays de booléens). Pour accéder à un mot, je souhaite donc convertir l'adresse en un entier `i` afin de consulter le mot simplement avec `array.(i)`.

Cette fonction est peut-être écrite de manière non optimale :

- je commence par lire la valeur, que je stocke dans une string à l'aide d'une référence (la string est alors de la forme `"0010"`, par exemple) ;
- je considère que le bit de poids faible est à la fin de cette string ;
- je pose `n` tel que la valeur du bit de poids fort soit `2^n` ;
- j'initialise le résultat à 0 ;
- j'incrémente le résultat pour chaque `1` rencontré dans la string, tout en diminuant `n`.

Je me rends compte en écrivant cette explication que le passage par une string est inutile, mais cela m'a aidé lors de l'écriture de la fonction (je vais la laisser ainsi).

### `create_memory` (ligne 28)

Prend en argument les caractéristiques d'une ROM/RAM et renvoie le `bool array array` correspondant, entièrement initialisé à `false`.

Il existe peut-être un moyen plus simple d'exprimer les puissances de 2, mais cela fonctionne, donc je ne vais pas y toucher.

### `write_ram` (ligne 31)

Prend en argument `env`, `env_mem` et `program`, et met à jour `env_mem`.

- Je considère que `write_enable` est nécessairement un `VBit`.
- Les `bool array array` étant mutables, je peux modifier directement le contenu de ma RAM sans avoir besoin de passer par une référence pour `env_mem`.
- Il faut bien penser à convertir en array la valeur associée à l'argument `data` lors de l'écriture, car cette valeur est de type `VBitArray`.

### `env_mem_init` (ligne 39)

Prend en argument un programme.

Je parcours les équations et, pour chaque ROM/RAM rencontrée, je crée une mémoire dans `env_mem`. Ainsi, j'ai bien une mémoire à part entière pour chaque équation de la forme `x = ROM/RAM`, et chacune de ces mémoires est reliée à son `x` par la structure de l'environnement.

### `env_prec_init` (ligne 48)

Prend en argument un programme.

Pour chacune des variables, j'initialise sa valeur dans `env_prec` de sorte qu'elle soit du bon type (`VBit` ou `VBitArray`) et, pour les arrays, de la bonne taille. Tout est initialisé à `false`.

### `read_entries` (ligne 56)

Prend en argument un programme et `env_prec`.

Cette fonction sert à construire `env` au début du tour de boucle :

- on part de `env_prec` ;
- on veut ensuite entrer les nouvelles inputs : pour cela, on parcourt l'ensemble des variables d'entrée et, selon leur type, l'utilisateur est invité à les saisir sous forme de 0 et de 1. Pour les `VBitArray`, le programme affiche la longueur attendue.

### `print_outputs` (ligne 78)

Prend en argument un programme et un environnement.

On parcourt l'ensemble des outputs, que l'on distingue entre `VBit` et `VBitArray`, puis on les affiche sous forme de 0 et de 1 (les `VBitArray` sont d'abord transformés en simples arrays de 0 et de 1).

### `binop_eval` (ligne 93)

Prend en argument un `binop` et renvoie la fonction correspondante, qui dépend des deux entrées.

### `evaluer` (ligne 100)

Prend en argument une équation et les trois environnements. Pour chacun des cas, on renvoie la valeur attendue, sous forme de `VBit` ou de `VBitArray`.

- De `Enot` à `Ebinop`, je distingue les cas `VBit` et `VBitArray` ; dans le cas des bus, j'applique l'opération bit à bit.
- Pour `Emux`, je fais l'hypothèse que `c` est toujours un unique `VBit`. J'imagine que, si l'on avait voulu un `VBitArray` sélecteur de la même taille que les deux autres entrées, il aurait suffi d'utiliser la construction du MUX à partir de `OR`, `AND` et `NOT`.
- Pour `Ebinop`, j'utilise la structure du `match` qui me permet de « déballer » `b1` et `b2` directement (c'est-à-dire de les récupérer sous forme d'array / de booléen et non de `VBitArray` / `VBit`). Pour que le `match` fonctionne, je dois traiter tous les cas, y compris ceux censés être impossibles, d'où les branches renvoyant un `failwith` dans mon programme (je ne peux pas mettre `-> ()`, car les autres branches du `match` renvoient une `value`, alors que `()` est de type `unit`).
- Le reste est assez direct : je ne fais que lire la RAM/ROM. Je ne gère pas les cas où des `VBitArray` seraient de tailles différentes lorsque cela est censé être impossible : je suppose les netlists bien construites.

## Utilisation de l'IA

Par souci de transparence, voici les usages que j'ai faits de l'IA pour m'aider dans ce travail.

### Aide à la syntaxe

Je suis un conscrit du département de physique venant de PC : j'ai donc commencé à apprendre OCaml il y a trois semaines, pour le TP1, et je n'avais pas toutes les cartes en main pour la première partie du projet.

Exemples précis d'usages :

- la syntaxe des `Printf` et des `read_line` ;
- la manipulation des différents objets (prompts du type « comment faire telle opération sur tel objet ») ;
- savoir quand il faut utiliser `;` ou non (idem pour `begin … end`).
- l'usage de la syntaxe `| _ -> ...` dans les match

### Subtilités d'OCaml découvertes

Dans le cadre de cette aide à la syntaxe, je me suis rendu compte de certaines subtilités d'OCaml. Exemples précis :

- Lorsqu'on crée un array d'arrays, il faut veiller à ce que tous les « sous-arrays » ne soient pas en réalité le même (par exemple avec `Array.make size l_array_en_question`) : modifier un sous-array modifierait alors tous les autres, puisqu'ils partagent la même adresse mémoire.
- `2 ** int` ne fonctionne pas pour calculer une puissance de deux : `**` ne marche que sur les flottants (`2. ** float`). J'utilise donc `int_of_float` et `float_of_int`.
- La différence entre `=` et `==`.

### Ce que l'IA n'a pas fait

- Écrire du code.
- Concevoir l'architecture de mon programme.

## Difficultés rencontrées

J'ai assez vite eu l'idée du fonctionnement général de ma fonction `simulator`, y compris la gestion des registres. Discuter avec certains de mes camarades m’a permis d’avoir assez clairement l'implémentation de cette partie-là en tête. En revanche, la mémoire a été un point très compliqué pour moi. Je m'y suis pris (trop) tard pour réaliser tout cela, et je ne comprenais pas bien la structure générale de la mémoire, donc je n'arrivais pas à l'implémenter. J'en ai discuté le mardi 10/11 avec M. Miquel en TD, et il m'a clarifié la structure de la mémoire en me faisant comprendre que je pouvais utiliser des `bool array array`. Je savais donc comment créer mes cellules mémoire, mais j'ai mis du temps à trouver une méthode correcte pour les implémenter. L'idée de `env_mem` m'est venue après plusieurs constats :

- Ma mémoire n'est pas un `VBitArray` et elle est mutable, ce qui pousse à ne pas la mettre dans `env`.
- De toute façon, même sans ce problème de type, je ne vois pas comment inclure une `RAM` dans `env` sans rencontrer, par exemple, un problème d'`ident`.
- Un `Env` est immuable, mais ce qui est immuable, c'est l'association entre une clé et sa valeur : ici, la valeur étant mutable, on peut la modifier sans problème.

Enfin, j'ai aussi rencontré des difficultés plus techniques, liées au fait que j'apprends encore OCaml, notamment pour des fonctions relativement « simples » comme `convert_read_addr`. La gestion des types est également compliquée pour quelqu'un comme moi qui n'avait fait que du Python auparavant.


