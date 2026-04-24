#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
# MAGIC-VPN 5.0 – by MAGIC-MAN (Le Dieu du Net)
# Gabon Flag Edition | Full Menu Loop | Host/SNI Changer | Auto-Update
#===============================================================================

GREEN='\e[42m\e[30m'
YELLOW='\e[43m\e[30m'
BLUE='\e[44m\e[30m'
RESET='\e[0m'
BOLD='\e[1m'
RED='\e[31m'
CYAN='\e[36m'
WHITE='\e[37m'
MAGENTA='\e[35m'

MAGIC_DIR="$HOME/.magicvpn"
LOG="$MAGIC_DIR/magic.log"
CONFIG_DIR="$MAGIC_DIR/configs"
mkdir -p "$MAGIC_DIR" "$CONFIG_DIR"

VERSION="5.0"
UPDATE_URL="https://raw.githubusercontent.com/magic-man241/magic-vpn/main/magic.sh"
VERSION_URL="https://raw.githubusercontent.com/magic-man241/magic-vpn/main/version"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

banner() {
    clear
    COLS=$(tput cols)
    [ -z "$COLS" ] && COLS=80
    printf "${GREEN}%*s${RESET}\n" "$COLS" ""
    TITLE="M A G I C - V P N"
    T_LEN=${#TITLE}
    PAD=$(( (COLS - T_LEN) / 2 ))
    printf "${YELLOW}%*s%s%*s${RESET}\n" "$PAD" "" "$TITLE" "$(( COLS - PAD - T_LEN ))" ""
    printf "${BLUE}%*s${RESET}\n" "$COLS" ""
    SUB="[ Created by MAGIC-MAN ]"
    S_LEN=${#SUB}
    PAD_S=$(( (COLS - S_LEN) / 2 ))
    printf "${WHITE}%*s${BOLD}${RED}${SUB}${RESET}\n\n" "$PAD_S" ""
}

auth() {
    while true; do
        echo -ne "${YELLOW}[>] Password: ${RESET}"
        read -s pass
        echo
        if [ "$pass" = "idiot" ]; then
            log "Authentifié."
            break
        else
            echo -e "${RED}[!] Mot de passe incorrect.${RESET}"
        fi
    done
}

install_deps() {
    log "Vérification dépendances..."
    pkg update -y -qq && pkg upgrade -y -qq
    for p in jq curl; do
        command -v $p &>/dev/null || pkg install -y $p
    done
    if ! command -v speedtest-cli &>/dev/null; then
        pkg install -y python && pip install speedtest-cli 2>/dev/null
    fi
    log "Dépendances OK."
}

optimize() {
    log "Stabilisation VPN (keepalive + DNS)"
    echo -e "${CYAN}[*] Optimisations non-root appliquées...${RESET}"
    echo "nameserver 1.1.1.1" > /data/data/com.termux/files/usr/etc/resolv.conf 2>/dev/null
    echo -e "${YELLOW}Keepalive : ping toutes les 5s (Ctrl+C pour arrêter).${RESET}"
    ping -i 5 8.8.8.8
    echo -e "${GREEN}[✔] Optimisations terminées. Retour au menu...${RESET}"
    sleep 1
}

detect_vpn() {
    local config="$1"
    if echo "$config" | grep -qiE '^(vmess|vless|trojan|ss|ssr)://'; then
        proto=$(echo "$config" | grep -oEi '^(vmess|vless|trojan|ss|ssr)' | tr '[:upper:]' '[:lower:]')
        echo "$proto"
        return
    fi
    if echo "$config" | jq -e .outbounds >/dev/null 2>&1; then
        proto=$(echo "$config" | jq -r '.outbounds[0].protocol // empty' 2>/dev/null)
        [ -n "$proto" ] && echo "v2ray-$proto" && return
    fi
    if echo "$config" | grep -qiE '^mode='; then
        echo "httpcustom"; return
    fi
    if echo "$config" | grep -qiE '^\[General\]'; then
        echo "npvtunnel"; return
    fi
    echo "inconnu"
}

compatible_apps() {
    local type="$1"
    case "$type" in
        vmess|vless|trojan|ss|ssr|v2ray-*)
            echo -e "${MAGENTA}[i] Protocole détecté : $type${RESET}"
            echo -e "${GREEN}Applications compatibles :${RESET}"
            echo "  - v2rayNG"
            echo "  - NapsternetV"
            echo "  - HTTPCustom (supporte VMess, VLESS, Trojan, SS)"
            echo "  - DarkTunnel"
            echo "  - NpvTunnel"
            echo "  - NetMod"
            ;;
        httpcustom)
            echo -e "${MAGENTA}[i] Configuration HTTPCustom détectée${RESET}"
            echo -e "${GREEN}Applications compatibles :${RESET}"
            echo "  - HTTPCustom"
            echo "  - NpvTunnel (conversion possible)"
            ;;
        npvtunnel)
            echo -e "${MAGENTA}[i] Configuration NpvTunnel détectée${RESET}"
            echo -e "${GREEN}Applications compatibles :${RESET}"
            echo "  - NpvTunnel"
            echo "  - HTTPCustom (conversion possible)"
            ;;
        inconnu|*)
            echo -e "${YELLOW}[!] Type de configuration non reconnu.${RESET}"
            ;;
    esac
}

mod_host() {
    echo -e "${CYAN}[*] Analyse et modification de configuration...${RESET}"
    echo "Colle ta configuration (lien ou JSON), puis tape FIN sur une nouvelle ligne :"
    tmpfile="$MAGIC_DIR/tmp_config"
    > "$tmpfile"
    while IFS= read -r line; do
        if [ "$line" = "FIN" ]; then break; fi
        if [ "$line" = "menu" ] || [ "$line" = "MENU" ]; then
            echo -e "${YELLOW}[i] Retour au menu.${RESET}"
            rm -f "$tmpfile"; return
        fi
        echo "$line" >> "$tmpfile"
    done
    if [ ! -s "$tmpfile" ]; then
        echo -e "${RED}[!] Aucune entrée.${RESET}"
        rm -f "$tmpfile"; return 1
    fi
    config=$(cat "$tmpfile")
    vpn_type=$(detect_vpn "$config")
    compatible_apps "$vpn_type"

    if echo "$vpn_type" | grep -qiE 'vmess|vless|trojan|ss|ssr|v2ray'; then
        echo ""
        echo -e "${CYAN}Que souhaites-tu modifier ? (h = Host, s = SNI, menu = annuler)${RESET}"
        read -p "Choix : " modchoice
        [ "$modchoice" = "menu" ] || [ "$modchoice" = "MENU" ] && { rm -f "$tmpfile"; return; }

        case "$modchoice" in
            h|H) read -p "Nouveau Host (ou 'menu' pour annuler) : " newhost ;;
            s|S) read -p "Nouveau SNI (ou 'menu' pour annuler) : " newhost ;;
            *) echo -e "${RED}[!] Choix invalide.${RESET}"; rm -f "$tmpfile"; return 1 ;;
        esac
        [ "$newhost" = "menu" ] || [ "$newhost" = "MENU" ] && { rm -f "$tmpfile"; return; }
        [ -z "$newhost" ] && { rm -f "$tmpfile"; return; }

        final_result=""; modified=0
        case "$vpn_type" in
            vmess) 
                if echo "$config" | grep -qi '^vmess://'; then
                    base64_part=$(echo "$config" | sed 's|^vmess://||')
                    padding=$(( (4 - ${#base64_part} % 4) % 4 ))
                    base64_part="${base64_part}$(printf '%*s' $padding '' | tr ' ' '=')"
                    decoded=$(echo "$base64_part" | base64 -d 2>/dev/null)
                    if [ -n "$decoded" ]; then
                        if [ "$modchoice" = "s" ] || [ "$modchoice" = "S" ]; then
                            newdecoded=$(echo "$decoded" | jq --arg sni "$newhost" '
                                if .sni then .sni = $sni else . end |
                                if .streamSettings.tlsSettings then .streamSettings.tlsSettings.serverName = $sni else . end')
                        else
                            newdecoded=$(echo "$decoded" | jq --arg h "$newhost" '.add = $h | .host = $h')
                        fi
                        if [ -n "$newdecoded" ]; then
                            newbase64=$(echo -n "$newdecoded" | base64 -w 0)
                            final_result="vmess://$newbase64"
                            modified=1
                        fi
                    fi
                fi
                ;;
            vless|trojan)
                proto=$(echo "$vpn_type" | tr '[:upper:]' '[:lower:]')
                if echo "$config" | grep -qi "^${proto}://"; then
                    if [ "$modchoice" = "h" ] || [ "$modchoice" = "H" ]; then
                        prefix=$(echo "$config" | sed -E "s|^${proto}://([^@]+).*|\1|")
                        rest=$(echo "$config" | sed -E "s|^${proto}://[^@]*@||")
                        if echo "$rest" | grep -q ':'; then
                            port_part=$(echo "$rest" | sed -E 's/^[^:]*:([0-9]*).*/\1/')
                            after_port=$(echo "$rest" | sed -E 's/^[^:]*:[0-9]*//')
                            final_result="${proto}://${prefix}@${newhost}:${port_part}${after_port}"
                        elif echo "$rest" | grep -q '/'; then
                            after_slash=$(echo "$rest" | sed -E 's/^[^/]*//')
                            final_result="${proto}://${prefix}@${newhost}${after_slash}"
                        elif echo "$rest" | grep -q '\?'; then
                            after_q=$(echo "$rest" | sed -E 's/^[^?]*//')
                            final_result="${proto}://${prefix}@${newhost}${after_q}"
                        elif echo "$rest" | grep -q '#'; then
                            after_hash=$(echo "$rest" | sed -E 's/^[^#]*//')
                            final_result="${proto}://${prefix}@${newhost}${after_hash}"
                        else
                            final_result="${proto}://${prefix}@${newhost}"
                        fi
                        modified=1
                    else
                        if echo "$config" | grep -qi '&sni=' || echo "$config" | grep -qi '?sni='; then
                            final_result=$(echo "$config" | sed -E "s/([?&]sni=)[^&]*(&?)/\1${newhost}\2/")
                            final_result=$(echo "$final_result" | sed 's/&$//')
                            modified=1
                        else
                            if echo "$config" | grep -q '#'; then
                                fragment=$(echo "$config" | sed -E 's/.*#/#/')
                                base=$(echo "$config" | sed -E 's/#.*//')
                                final_result="${base}&sni=${newhost}${fragment}"
                            else
                                final_result="${config}&sni=${newhost}"
                            fi
                            modified=1
                        fi
                    fi
                fi
                ;;
            ss|ssr)
                echo -e "${YELLOW}[i] Les liens SS/SSR ne sont pas modifiés automatiquement.${RESET}"
                final_result="$config"; modified=0
                ;;
            v2ray-*)
                if echo "$config" | jq empty &>/dev/null; then
                    if [ "$modchoice" = "s" ] || [ "$modchoice" = "S" ]; then
                        newconf=$(jq --arg sni "$newhost" '
                            (.outbounds[]? | select(.streamSettings.tlsSettings) | .streamSettings.tlsSettings.serverName) = $sni |
                            (.outbounds[]? | if .settings.vnext then .settings.vnext[].users[].sni = $sni else . end)' <<< "$config" 2>/dev/null)
                    else
                        newconf=$(jq --arg h "$newhost" '
                            (.outbounds[]? | select(.settings.vnext) | .settings.vnext[].address) = $h |
                            (.outbounds[]? | select(.settings.servers) | .settings.servers[].address) = $h' <<< "$config" 2>/dev/null)
                    fi
                    [ -n "$newconf" ] && { final_result="$newconf"; modified=1; }
                fi
                ;;
        esac

        if [ $modified -eq 1 ]; then
            echo -e "${GREEN}[✔] Configuration modifiée :${RESET}"
            echo "$final_result"
        elif [ "$vpn_type" = "ss" ] || [ "$vpn_type" = "ssr" ]; then
            echo -e "${YELLOW}[i] Le lien SS/SSR n'a pas été modifié. Lien original :${RESET}"
            echo "$final_result"
        else
            echo -e "${RED}[!] La modification a échoué.${RESET}"
        fi
        echo ""
        echo -e "${CYAN}👉 Pour copier, appuie longuement sur le lien puis « Copier ».${RESET}"
        echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
        read
    else
        echo -e "${YELLOW}[i] Modification impossible pour ce type de configuration.${RESET}"
    fi
    rm -f "$tmpfile"
}

save_config() {
    echo -e "${CYAN}Sauvegarde de configuration...${RESET}"
    read -p "Nom du fichier (ou 'menu' pour annuler) : " fname
    [ "$fname" = "menu" ] || [ "$fname" = "MENU" ] && return
    [ -z "$fname" ] && fname="backup_$(date +%s).json"
    echo "Colle la configuration, puis tape FIN sur une nouvelle ligne :"
    tmpfile="$CONFIG_DIR/$fname"
    > "$tmpfile"
    while IFS= read -r line; do
        [ "$line" = "FIN" ] && break
        [ "$line" = "menu" ] || [ "$line" = "MENU" ] && { rm -f "$tmpfile"; echo -e "${YELLOW}[i] Retour au menu.${RESET}"; return; }
        echo "$line" >> "$tmpfile"
    done
    if [ -s "$tmpfile" ]; then
        if jq empty "$tmpfile" &>/dev/null || [ -n "$(cat "$tmpfile")" ]; then
            echo -e "${GREEN}[✔] Config sauvegardée.${RESET}"
            log "Config sauvegardée : $fname"
        else
            echo -e "${RED}[!] Fichier vide.${RESET}"; rm -f "$tmpfile"
        fi
    else
        echo -e "${RED}[!] Annulé.${RESET}"
    fi
}

restore_config() {
    echo -e "${CYAN}Configurations disponibles :${RESET}"
    ls "$CONFIG_DIR"/* 2>/dev/null || { echo "Aucune."; return; }
    read -p "Fichier à afficher (ou 'menu' pour annuler) : " fname
    [ "$fname" = "menu" ] || [ "$fname" = "MENU" ] && return
    [ -f "$CONFIG_DIR/$fname" ] && cat "$CONFIG_DIR/$fname" || echo -e "${RED}Introuvable.${RESET}"
}

speed_test() {
    command -v speedtest-cli &>/dev/null && speedtest-cli || echo -e "${RED}Installe speedtest-cli.${RESET}"
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

show_logs() {
    if [ -f "$LOG" ]; then
        cat "$LOG"
    else
        echo "Aucun log pour le moment."
    fi
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

update_script() {
    echo -e "${CYAN}[*] Vérification de mise à jour...${RESET}"
    echo "Version actuelle : $VERSION"
    remote_version=$(curl -s "$VERSION_URL" 2>/dev/null)
    if [ -z "$remote_version" ]; then
        echo -e "${RED}[!] Impossible de vérifier la version (pas de connexion ?).${RESET}"
    elif [ "$remote_version" = "$VERSION" ]; then
        echo -e "${GREEN}[✔] Vous utilisez déjà la dernière version ($VERSION).${RESET}"
    else
        echo -e "${YELLOW}Une nouvelle version ($remote_version) est disponible !${RESET}"
        read -p "Voulez-vous mettre à jour ? (o/n) : " do_update
        if [ "$do_update" = "o" ] || [ "$do_update" = "O" ]; then
            echo "Téléchargement de la nouvelle version..."
            curl -sL "$UPDATE_URL" -o /tmp/magic_new.sh
            if bash -n /tmp/magic_new.sh &>/dev/null; then
                cp /tmp/magic_new.sh "$PREFIX/bin/magic"
                chmod +x "$PREFIX/bin/magic"
                echo -e "${GREEN}[✔] Mise à jour terminée. Relance 'magic'.${RESET}"
                log "Script mis à jour vers $remote_version"
            else
                echo -e "${RED}[!] Fichier téléchargé invalide.${RESET}"
            fi
            rm -f /tmp/magic_new.sh
        else
            echo -e "${YELLOW}[i] Mise à jour annulée.${RESET}"
        fi
    fi
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

menu() {
    while true; do
        echo -e "\n${BOLD}${YELLOW}====== MENU MAGIC-VPN ======${RESET}"
        echo "1. Stabiliser connexion VPN"
        echo "2. Analyser & Modifier une config (host/Sni)"
        echo "3. Sauvegarder config"
        echo "4. Restaurer config"
        echo "5. Test de vitesse"
        echo "6. Voir logs"
        echo "7. Mise à jour"
        echo "8. Quitter"
        read -p "Choix [1-8] : " c
        case $c in
            1) optimize ;;
            2) mod_host ;;
            3) save_config ;;
            4) restore_config ;;
            5) speed_test ;;
            6) show_logs ;;
            7) update_script ;;
            8)
                echo -e "${GREEN}========================================${RESET}"
                echo -e "${YELLOW}  Merci d'avoir utilisé MAGIC-VPN, le Dieu du Net !${RESET}"
                echo -e "${CYAN}  Rejoins mon groupe de formation Free Net :${RESET}"
                echo -e "${MAGENTA}  https://chat.whatsapp.com/Dfov4YFtEqe7eILe5ctEQd${RESET}"
                echo -e "${WHITE}  Contacte-moi sur WhatsApp : +24160141633${RESET}"
                echo -e "${GREEN}========================================${RESET}"
                echo -e "${BOLD}${RED}  N'oublie pas de me féliciter et de partager !${RESET}\n"
                exit 0
                ;;
            *) echo -e "${RED}[!] Invalide.${RESET}" ;;
        esac
    done
}

install_self() {
    [ -z "$PREFIX" ] && { echo "Termux uniquement."; exit 1; }
    install_deps
    cp "$0" "$PREFIX/bin/magic"
    chmod +x "$PREFIX/bin/magic"
    echo -e "${GREEN}[✔] MAGIC-VPN installé. Tape 'magic'.${RESET}"
    log "Installé."
}

BASE_NAME=$(basename "$0")
if [ "$BASE_NAME" != "magic" ]; then
    install_self
    exit 0
fi

banner
auth
menu
