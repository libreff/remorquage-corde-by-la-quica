# Remorquage Corde by La Quica

Ressource FiveM/ESX permettant de relier physiquement deux véhicules avec l’item `CORDE`.

## Dépendances

- `es_extended`
- `ox_lib`
- `ox_target`
- `acn_inventory`
- OneSync activé

## Installation

1. Placez `remorquage_corde_by_la_quica` dans les ressources du serveur.
2. Vérifiez que l’item unique `CORDE` existe dans `acn_inventory`.
3. Ajoutez `ensure remorquage_corde_by_la_quica` après les dépendances dans `server.cfg`.

L’export suivant reste disponible si votre configuration d’items exige une action client. Il affiche un rappel expliquant d’utiliser `Alt` :

```lua
client = {
    export = 'remorquage_corde_by_la_quica.UseRope'
}
```

## Utilisation

1. Possédez l’item `CORDE` dans votre inventaire.
2. Maintenez `Alt` en regardant le véhicule tracteur.
3. Sélectionnez **Attacher la corde à l’arrière**.
4. Transportez la corde jusqu’au second véhicule.
5. Maintenez `Alt` sur celui-ci et sélectionnez **Attacher la corde à l’avant**.
6. Montez dans le véhicule tracteur et roulez progressivement.

Pour retirer la corde, maintenez `Alt` sur l’un des deux véhicules et sélectionnez **Détacher la corde**. Retour arrière annule la pose avant la seconde fixation.

## Sécurité et synchronisation

- L’inventaire `CORDE`, les distances, les Net IDs et l’unicité des véhicules sont vérifiés côté serveur.
- Une seule corde active est autorisée par joueur et par véhicule.
- La corde est recréée localement pour chaque joueur lorsque les deux véhicules sont streamés.
- Elle casse automatiquement au-delà de la distance définie dans `Config.BreakDistance`.
- La corde utilise le matériau tressé natif de GTA et une bobine tenue en main pendant le déplacement.

Toutes les distances, durées, couleurs, animations et propriétés physiques sont configurables dans `config.lua`.
