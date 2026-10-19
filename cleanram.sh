#!/usr/bin/env bash
# cleanram.sh - Soulage la RAM sur Ubuntu (l'equivalent d'un petit .bat Windows)
#
# Ce que fait le script :
#   1. Ferme les processus de fond "pas indispensables" de ta session
#      (indexation de fichiers, calendrier Evolution, Logiciels/Snap Store en fond...)
#      -> ils se relancent tout seuls si tu en as besoin plus tard.
#   2. Te montre les 10 programmes qui mangent le plus de RAM et te propose d'en fermer.
#   3. Vide le cache disque du noyau (page cache) avec sudo.
#   4. Vide le swap dans la RAM si il reste assez de place.
#
# Utilisation :
#   ./cleanram.sh        -> mode interactif (demande avant chaque etape)
#   ./cleanram.sh -y     -> mode auto (fait tout sans poser de question, sauf le top 10)

set -u

AUTO=0
[[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]] && AUTO=1

# Couleurs
G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; B='\033[1;34m'; N='\033[0m'

# Processus de fond qu'on peut fermer sans risque (ils sont relances a la demande)
OPTIONAL_PROCS=(
    tracker-miner-fs-3 tracker-extract-3 tracker-miner-rss-3   # indexation des fichiers
    evolution-alarm-notify evolution-calendar-factory           # calendrier / contacts Evolution
    evolution-addressbook-factory evolution-source-registry
    gnome-software snap-store                                   # magasin d'applis en fond
    update-notifier                                             # notif de mises a jour
    zeitgeist-daemon zeitgeist-datahub zeitgeist-fts            # historique d'activite
    deja-dup-monitor                                            # sauvegardes auto
    goa-daemon goa-identity-service                             # comptes en ligne
    gnome-calendar gnome-contacts                               # si laisses ouverts en fond
)

ask() {
    # ask "question" -> 0 si oui
    (( AUTO )) && return 0
    local rep
    read -r -p "$(echo -e "${Y}?${N} $1 [O/n] ")" rep
    [[ -z "$rep" || "$rep" =~ ^[oOyY] ]]
}

# Les noms de process sont tronques a 15 caracteres, donc on cherche dans la ligne de commande
proc_pids() { pgrep -u "$USER" -f "^([^ ]*/)?$1( |\$)" 2>/dev/null; }

mem_available_kb() { awk '/^MemAvailable:/ {print $2}' /proc/meminfo; }

show_mem() {
    echo -e "${B}--- Memoire ---${N}"
    free -h | sed 's/^/  /'
}

echo -e "${G}=== Nettoyage de la RAM ===${N}"
show_mem
BEFORE=$(mem_available_kb)
echo

# 1. Processus de fond optionnels -----------------------------------------
found=()
for p in "${OPTIONAL_PROCS[@]}"; do
    [[ -n "$(proc_pids "$p")" ]] && found+=("$p")
done

if (( ${#found[@]} )); then
    echo -e "${B}[1/4]${N} Processus de fond pas indispensables trouves :"
    for p in "${found[@]}"; do
        kb=$(ps -o rss= -p "$(proc_pids "$p" | paste -sd,)" 2>/dev/null | awk '{s+=$1} END {print s+0}')
        printf "  - %-32s %6d Mo\n" "$p" $((kb / 1024))
    done
    if ask "Les fermer ?"; then
        for p in "${found[@]}"; do proc_pids "$p" | xargs -r kill 2>/dev/null; done
        echo -e "  ${G}OK${N}"
    fi
else
    echo -e "${B}[1/4]${N} Aucun processus de fond inutile trouve."
fi
echo

# 2. Top 10 des gros consommateurs ----------------------------------------
echo -e "${B}[2/4]${N} Les 10 programmes qui utilisent le plus de RAM (a toi) :"
mapfile -t TOP < <(ps -u "$USER" -o pid=,rss=,comm= --sort=-rss | head -n 10)
i=1
for line in "${TOP[@]}"; do
    read -r pid rss comm <<<"$line"
    printf "  %2d) %-25s PID %-7s %6d Mo\n" "$i" "$comm" "$pid" $((rss / 1024))
    ((i++))
done
if [[ -t 0 ]]; then
    echo "  Tape les numeros a fermer separes par des espaces (ex: 2 5), ou Entree pour passer."
    echo -e "  ${R}Attention${N} : evite gnome-shell, Xorg/Xwayland, systemd... sinon ta session plante."
    read -r -p "  > " choix
    for n in $choix; do
        [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#TOP[@]} )) || continue
        read -r pid _ comm <<<"${TOP[n-1]}"
        case "$comm" in
            gnome-shell|Xorg|Xwayland|systemd|gnome-session*|dbus-daemon|pipewire*|wireplumber)
                echo -e "  ${R}Refuse${N} : $comm est vital pour ta session." ;;
            *)
                kill "$pid" 2>/dev/null && echo -e "  ${G}Ferme${N} : $comm ($pid)" ;;
        esac
    done
fi
echo

# 3. Cache disque ---------------------------------------------------------
echo -e "${B}[3/4]${N} Vider le cache disque du noyau (demande ton mot de passe sudo)."
if ask "Vider le cache ?"; then
    sync
    if echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null; then
        echo -e "  ${G}OK${N}"
    else
        echo -e "  ${R}Impossible${N} (pas de sudo ?)"
    fi
fi
echo

# 4. Swap -----------------------------------------------------------------
swap_used_kb=$(awk '/^SwapTotal:/ {t=$2} /^SwapFree:/ {f=$2} END {print t-f}' /proc/meminfo)
if (( swap_used_kb > 0 )); then
    echo -e "${B}[4/4]${N} Swap utilise : $((swap_used_kb / 1024)) Mo"
    # On ne vide le swap que s'il reste au moins 500 Mo de marge en RAM
    if (( $(mem_available_kb) > swap_used_kb + 512000 )); then
        if ask "Rapatrier le swap en RAM (peut prendre un peu de temps) ?"; then
            sudo swapoff -a && sudo swapon -a && echo -e "  ${G}OK${N}"
        fi
    else
        echo -e "  ${Y}Pas assez de RAM libre pour vider le swap sans risque, on laisse.${N}"
    fi
else
    echo -e "${B}[4/4]${N} Swap vide, rien a faire."
fi
echo

AFTER=$(mem_available_kb)
show_mem
gain=$(( (AFTER - BEFORE) / 1024 ))
echo
if (( gain > 0 )); then
    echo -e "${G}=== Termine : environ $gain Mo de RAM liberes ===${N}"
else
    echo -e "${G}=== Termine ===${N} (pas de gain visible, ta RAM etait deja propre)"
fi
