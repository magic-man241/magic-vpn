#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
# MAGIC-VPN 5.0 – by MAGIC-MAN (Le Dieu du Net)
# Gabon Flag Edition | Classic Menu (9 options) | Améliorations internes
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
mkdir -p "$MAGIC_DIR"

VERSION="5.1"
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
    for p in jq curl nmap; do
        command -v $p &>/dev/null || pkg install -y $p
    done
    if ! command -v speedtest-cli &>/dev/null; then
        pkg install -y python && pip install speedtest-cli 2>/dev/null
    fi
    log "Dépendances OK."
}

# ========== OPTION 1 : STABILISER & OPTIMISER (root) ==========
optimize_root() {
    log "Stabilisation (root si possible)..."
    if su -c "echo root" 2>/dev/null; then
        echo -e "${CYAN}[*] Root détecté, application des tweaks...${RESET}"
        su -c "sysctl -w net.ipv4.tcp_congestion_control=bbr" &>/dev/null
        su -c "sysctl -w net.ipv4.tcp_fastopen=3" &>/dev/null
        su -c "sysctl -w net.ipv4.tcp_rmem='4096 87380 33554432'" &>/dev/null
        su -c "sysctl -w net.ipv4.tcp_wmem='4096 65536 33554432'" &>/dev/null
        su -c "iptables -t mangle -F; iptables -t mangle -A OUTPUT -p tcp --dport 443 -j TOS --set-tos Maximize-Throughput" &>/dev/null
        echo -e "${GREEN}[✔] Optimisations root appliquées.${RESET}"
    else
        echo -e "${YELLOW}[!] Root non disponible. Application des optimisations de base...${RESET}"
        echo "nameserver 1.1.1.1" > /data/data/com.termux/files/usr/etc/resolv.conf 2>/dev/null
        echo -e "${CYAN} Keepalive : ping toutes les 5s (Ctrl+C pour arrêter).${RESET}"
        ping -i 5 8.8.8.8
    fi
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== OPTION 2 : SCANNER DES PORTS ==========
scan_ports() {
    if ! command -v nmap &>/dev/null; then
        pkg install -y nmap
    fi
    read -p "Cible (IP/Domaine) : " target
    [ -z "$target" ] && return
    echo -e "${CYAN}[*] Scan de $target...${RESET}"
    nmap -p 22,80,443,8080,1080 --open "$target"
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== OPTION 3 : GÉNÉRER UN PAYLOAD V2RAY ==========
gen_payload() {
    echo -e "${CYAN}[*] Génération d'un payload V2Ray...${RESET}"
    read -p "UUID (laisse vide pour aléatoire) : " uid
    [ -z "$uid" ] && uid=$(uuidgen 2>/dev/null || echo "ba7e9c5c-$(openssl rand -hex 4)-$(openssl rand -hex 2)-$(openssl rand -hex 2)-$(openssl rand -hex 6)")
    read -p "Host : " host
    read -p "Port (443) : " port
    port=${port:-443}
    read -p "Type (vmess/vless) : " vtype
    vtype=${vtype:-vmess}
    cat <<EOFP
${GREEN}===== PAYLOAD V2RAY =====${RESET}
{
  "outbounds": [{
    "protocol": "$vtype",
    "settings": {
      "vnext": [{
        "address": "$host",
        "port": $port,
        "users": [{"id": "$uid", "alterId": 0}]
      }]
    },
    "streamSettings": {"network": "tcp"}
  }]
}
${GREEN}========================${RESET}
EOFP
    log "Payload généré pour $host:$port"
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== OPTION 4 : MODIFIER UN HOST DANS UNE CONFIG V2RAY ==========
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
    # Détection simple du type
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

# ========== OPTION 5 : EMPOISONNER LES DNS ==========
dns_poison() {
    echo -e "${CYAN}[*] Changement des DNS...${RESET}"
    echo "1. Cloudflare (1.1.1.1)"
    echo "2. Google (8.8.8.8)"
    echo "3. Quad9 (9.9.9.9)"
    echo "4. Personnalisé"
    read -p "Choix : " dns
    case $dns in
        1) ns1="1.1.1.1"; ns2="1.0.0.1" ;;
        2) ns1="8.8.8.8"; ns2="8.8.4.4" ;;
        3) ns1="9.9.9.9"; ns2="149.112.112.112" ;;
        4) read -p "DNS1 : " ns1; read -p "DNS2 : " ns2 ;;
        *) return ;;
    esac
    echo -e "nameserver $ns1\nnameserver $ns2" > /data/data/com.termux/files/usr/etc/resolv.conf 2>/dev/null
    echo -e "${GREEN}[✔] DNS changés.${RESET}"
    log "DNS -> $ns1, $ns2"
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== FONCTIONS DE DÉTECTION (pour l'option 4) ==========
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

# ========== OPTION 6 : TEST DE VITESSE ==========
speed_test() {
    command -v speedtest-cli &>/dev/null && speedtest-cli || echo -e "${RED}Installe speedtest-cli.${RESET}"
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== OPTION 7 : VOIR LES LOGS ==========
show_logs() {
    if [ -f "$LOG" ]; then
        cat "$LOG"
    else
        echo "Aucun log pour le moment."
    fi
    echo -e "${CYAN}Appuyez sur Entrée pour revenir au menu...${RESET}"
    read
}

# ========== OPTION 8 : METTRE À JOUR LE SCRIPT ==========
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

# ========== MENU PRINCIPAL (9 OPTIONS) ==========
menu() {
    while true; do
        echo -e "\n${BOLD}${YELLOW}~~> MAGIC-VPN : MENU PRINCIPAL <~~${RESET}"
        echo "1. Stabiliser & optimiser (root)"
        echo "2. Scanner des ports (nmap)"
        echo "3. Générer un payload V2Ray"
        echo "4. Modifier un host dans une config V2Ray"
        echo "5. Empoisonner les DNS"
        echo "6. Test de vitesse Internet"
        echo "7. Voir les logs"
        echo "8. Mettre à jour le script"
        echo "9. Quitter"
        read -p "Votre choix [1-9] : " c
        case $c in
            1) optimize_root ;;
            2) scan_ports ;;
            3) gen_payload ;;
            4) mod_host ;;
            5) dns_poison ;;
            6) speed_test ;;
            7) show_logs ;;
            8) update_script ;;
            9)
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
