<div align="center">

# DuoBar

### Un indicateur compact pour la barre de menus macOS : batterie, réseau et volume.

**Trois états en direct. Un seul glyphe. Moins d'encombrement dans la barre de menus.**

[English](README.md) | [Français](README.fr.md) | [简体中文](README.zh-CN.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [ไทย](README.th.md)

[**Télécharger DuoBar 1.4.2**](https://github.com/Mikeli7666/DuoBar/releases/download/v1.4.2/DuoBar-1.4.2.dmg) · [**Toutes les versions**](https://github.com/Mikeli7666/DuoBar/releases) · [**Signaler un bug**](https://github.com/Mikeli7666/DuoBar/issues)

DuoBar 1.4.2 (Build 11) · macOS 13+ · Apple Silicon ou Intel · Universal 2 · Gratuit et open source

> **Remarque :** Ceci est le DuoBar gratuit et open source de Mikeli7666, disponible uniquement sur GitHub. Une autre application du même nom est vendue sur le Mac App Store — c'est une application distincte, à code source fermé, d'un autre développeur, sans affiliation avec ce projet.

<a href="https://ko-fi.com/duobar"><img src="https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Soutenir DuoBar sur Ko-fi"></a>

<br>

<img src="marketing/1.4.2/readme/duobar-1.4.2-menubar.jpg" alt="DuoBar dans la barre de menus macOS" width="1340">

</div>

## Un glyphe, trois états en direct

DuoBar adapte le concept de statut trois-en-un inspiré de l'iPhone Duo pour la barre de menus du Mac. Un seul glyphe compact présente les informations système normalement réparties sur plusieurs indicateurs :

- **Arc extérieur** → un anneau de batterie en direct sur les MacBook, ou un anneau adaptatif sur les Mac de bureau
- **Centre** → le réseau actif : Wi-Fi, Ethernet ou un état hors ligne / de secours
- **Quatre points inférieurs** → le volume de sortie en direct

L'état persistant reste monochrome et d'aspect natif. Quand des AirPods ou une autre sortie audio Bluetooth prise en charge devient active, le centre passe brièvement de Réseau → AirPods / écouteurs → Réseau. La déconnexion ne déclenche pas d'animation.

<p align="center">
  <img src="marketing/1.4.2/readme/duobar-1.4.2-popover-classic.png" alt="Fenêtre DuoBar 1.4.2, style classique" width="360">
  <img src="marketing/1.4.2/readme/duobar-1.4.2-popover-glass.png" alt="Fenêtre DuoBar 1.4.2, style Liquid Glass" width="360">
</p>

## Anneau adaptatif et anneau de batterie

Sur les MacBook, l'anneau de batterie extérieur affiche le niveau de batterie en direct, un éclair de charge dynamique et un code couleur de batterie optionnel pour la charge, le mode économie d'énergie et les états de batterie faible. Sur les Mac de bureau, l'anneau adaptatif reste neutre en l'absence d'activité de performance significative et fait apparaître automatiquement une pression soutenue sur le CPU, la mémoire ou la température le cas échéant. Il reste automatique : il n'y a pas de sélecteur de métrique manuel.

## DuoBar sur macOS

La version 1.4.2 actuelle ajoute le français et un interrupteur Liquid Glass marche/arrêt, en plus du widget de bureau, du changement de langue dans l'application et de la fenêtre de réglages redimensionnable.

<p align="center">
## Fonctionnalités

- Anneau de batterie avec niveau en direct, éclair de charge dynamique, état de batterie faible et code couleur de batterie optionnel
- Détails de la batterie dans la fenêtre : charge, charge en pause ou fonctionnement sur adaptateur, avec le temps restant jusqu'à charge complète ou décharge
- Anneau adaptatif pour les Mac de bureau : neutre par défaut, avec détection automatique de la pression CPU, mémoire et thermique
- Langage visuel Duo natif raffiné, indicateur Wi-Fi arrondi, anneau de batterie, indicateurs de volume et présentation de la charge
- États automatiques Wi-Fi, Ethernet et hors ligne
- Affichage du nom du réseau Wi-Fi et contrôle public de l'alimentation Wi-Fi
- Vitesse de téléchargement et d'envoi en direct dans la ligne Réseau de la fenêtre
- Comportement optionnel d'ouverture au survol
- Indicateur de volume en direct à quatre points
- Widget de bureau : le même glyphe 3-en-1 sur votre bureau, déplaçable partout, en 3 tailles (à activer dans Réglages)
- Curseur de volume compact, coupure du son Core Audio publique et changement de périphérique de sortie quand c'est pris en charge
- Présentation temporaire de la connexion AirPods / écouteurs
- Taille d'icône de la barre de menus réglable
- Anglais, français, russe, ukrainien, chinois simplifié, chinois traditionnel et thaï
- Fenêtre personnalisée compacte : Réseau et Batterie ouvrent les Réglages Système, alimentation Wi-Fi, volume, sélection de sortie audio, Réglages et Quitter
- Fenêtre Liquid Glass sur macOS 26 et versions ultérieures, avec un interrupteur dans Réglages pour revenir à l'aspect classique d'avant la 1.4.0
- Modes clair et sombre
- Lancement à l'ouverture de session
- Universal 2 : prise en charge Apple Silicon et Intel sur macOS 13+
- Swift, SwiftUI et AppKit natifs
- Icône Dock optionnelle (désactivée par défaut) ; un clic ouvre les Réglages

## Configuration requise

**macOS 13.0+**<br>
**Apple Silicon ou Intel**

## Installation

1. Ouvrez la [version DuoBar 1.4.2](https://github.com/Mikeli7666/DuoBar/releases/tag/v1.4.2) et trouvez **Assets**.
2. Téléchargez **DuoBar-1.4.2.dmg**. Ne téléchargez pas `Source code (zip)` ou `Source code (tar.gz)`.
3. Double-cliquez sur le DMG et glissez **DuoBar.app** vers **Applications**.
4. Ouvrez Applications et lancez DuoBar. C'est un utilitaire de barre de menus et il n'apparaît normalement pas dans le Dock.

DuoBar 1.4.2 utilise la signature Developer ID, le Hardened Runtime et la notarisation Apple. L'installation normale ne nécessite pas de désactiver Gatekeeper / SIP, Terminal, `sudo` ou `xattr`.

SHA-256 : `97c1e565f07944ca94884ebefc30a93afaa6b6a6e1fb28d70e2d01081a7cbfef`

Les travaux de build et de compatibilité / fiabilité ont été vérifiés avec Xcode 27 et le SDK macOS 27 tout en continuant à prendre en charge macOS 13+. Cela ne prétend pas à une validation matérielle de macOS 27.

## Autorisations

- **Localisation :** macOS peut exiger une autorisation avant que CoreWLAN puisse exposer le nom du réseau Wi-Fi actuel. Refuser l'accès ne casse ni la connexion de base, ni l'interface, ni l'état du signal ; le SSID peut simplement rester indisponible. DuoBar ne demande l'accès au SSID que quand c'est utile pour l'interface.
- **Bluetooth :** DuoBar conserve l'observation publique du contrôleur Bluetooth tandis que Core Audio fournit la source principale pour les points de terminaison audio Bluetooth. L'application ne gère ni n'apparie les périphériques.

## Comportement de la sortie audio

Le contrôle du volume n'est disponible que lorsque la sortie Core Audio active expose des propriétés de volume public réglables par logiciel. Les sorties externes HDMI, AirPlay, USB et autres peuvent afficher **Contrôlé par l'appareil** à la place.

La classification audio AirPods et Bluetooth est une approximation basée sur les métadonnées publiques du système. DuoBar ne prétend pas détecter la génération exacte des AirPods.

## Confidentialité

- Le traitement de l'état du système se fait localement.
- Aucune analyse ni suivi.
- Aucun backend ni télémétrie.
- Aucun envoi de l'état du système.
- Aucune requête réseau sans rapport.

## Limites connues

- Le nom du réseau Wi-Fi peut être indisponible sans l'autorisation de localisation ou quand macOS le retient.
- La puissance Wi-Fi utilise des données RSSI documentées et de larges plages de signal ; elle ne reproduit pas l'algorithme d'icône privé d'Apple.
- Certains périphériques audio exposent un volume fixe ou contrôlé de l'extérieur.
- DuoBar ne rejoint pas les réseaux Wi-Fi et n'apparie pas les périphériques Bluetooth.
- La détection audio Bluetooth et de la famille AirPods est une approximation via les API publiques.

## Compiler depuis les sources

Ouvrez `DuoBar.xcodeproj` dans Xcode, sélectionnez le schéma **DuoBar** et lancez. Les builds de débogage incluent la simulation d'état et des outils de capture marketing ; ces outils sont exclus du comportement Release.

## Avertissement

DuoBar est un projet indépendant et n'est ni affilié à Apple Inc. ni approuvé par Apple Inc.

## Licence

DuoBar est disponible sous la [licence MIT](LICENSE).
