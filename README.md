# Remorquage Corde by La Quica

Ressource FiveM/ESX permettant de relier physiquement deux véhicules avec l’item `CORDE`.

## Dépendances

- `es_extended`
- `ox_lib`
- `acn_inventory`
- OneSync activé

## Installation

1. Placez `remorquage_corde_by_la_quica` dans les ressources du serveur.
2. Vérifiez que l’item unique `CORDE` existe dans `acn_inventory`.
3. Ajoutez `ensure remorquage_corde_by_la_quica` après les dépendances dans `server.cfg`.

`ESX.RegisterUsableItem` permet normalement le clic droit **Utiliser** depuis `acn_inventory`. Si votre configuration d’items exige un export client, associez l’item à :

```lua
client = {
    export = 'remorquage_corde_by_la_quica.UseRope'
}
```

## Utilisation

1. Utilisez l’item `CORDE` hors d’un véhicule.
2. Approchez-vous de l’arrière du véhicule tracteur et appuyez sur `E`.
3. Transportez la corde jusqu’à l’avant du véhicule à tracter.
4. Appuyez de nouveau sur `E` après l’animation de fixation.
5. Montez dans le véhicule tracteur et roulez progressivement.

Pour retirer la corde, approchez-vous de son point d’attache à l’arrière du véhicule tracteur ou à l’avant du véhicule tracté, puis appuyez sur `E`. Retour arrière annule la pose avant la seconde fixation.

## Sécurité et synchronisation

- L’inventaire `CORDE`, les distances, les Net IDs et l’unicité des véhicules sont vérifiés côté serveur.
- Une seule corde active est autorisée par joueur et par véhicule.
- La corde est recréée localement pour chaque joueur lorsque les deux véhicules sont streamés.
- Elle casse automatiquement au-delà de la distance définie dans `Config.BreakDistance`.
- La corde utilise le matériau tressé natif de GTA et une bobine tenue en main pendant le déplacement.

Toutes les distances, durées, couleurs, animations et propriétés physiques sont configurables dans `config.lua`.
