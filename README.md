# cleanram

Petit script pour soulager la RAM sur Ubuntu (l'équivalent d'un `.bat` sous Windows).

## Installation

```bash
chmod +x cleanram.sh
```

## Utilisation

```bash
./cleanram.sh      # mode interactif : demande avant chaque étape
./cleanram.sh -y   # mode auto : fait tout sans demander
```

## Ce qu'il fait

1. **Ferme les processus de fond pas indispensables** : indexation de fichiers (tracker),
   calendrier/contacts Evolution, Logiciels/Snap Store en fond, notifications de mises à jour,
   Zeitgeist, Déjà Dup, comptes en ligne… Ils se relancent tout seuls si tu en as besoin.
2. **Affiche le top 10 des programmes gourmands** et te laisse choisir lesquels fermer
   (les processus vitaux comme `gnome-shell` ou `Xorg` sont protégés).
3. **Vide le cache disque du noyau** (`drop_caches`, demande `sudo`).
4. **Rapatrie le swap en RAM** si il reste assez de place.

Il affiche la mémoire avant/après et la quantité de RAM libérée.

## Astuce : le lancer en double-clic

Crée `~/.local/share/applications/cleanram.desktop` :

```ini
[Desktop Entry]
Name=Nettoyer la RAM
Exec=gnome-terminal -- bash -c "/chemin/vers/cleanram.sh; read -p 'Entree pour fermer'"
Icon=utilities-system-monitor
Terminal=false
Type=Application
```
