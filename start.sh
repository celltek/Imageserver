#!/bin/bash
#  ________      _______       ___           ___           _________    _______       ___  __       
#|\   ____\    |\  ___ \     |\  \         |\  \         |\___   ___\ |\  ___ \     |\  \|\  \     
#\ \  \___|    \ \   __/|    \ \  \        \ \  \        \|___ \  \_| \ \   __/|    \ \  \/  /|_   
# \ \  \        \ \  \_|/__   \ \  \        \ \  \            \ \  \   \ \  \_|/__   \ \   ___  \  
#  \ \  \____    \ \  \_|\ \   \ \  \____    \ \  \____        \ \  \   \ \  \_|\ \   \ \  \\ \  \ 
#   \ \_______\   \ \_______\   \ \_______\   \ \_______\       \ \__\   \ \_______\   \ \__\\ \__\
#    \|_______|    \|_______|    \|_______|    \|_______|        \|__|    \|_______|    \|__| \|__|  
#
# DONT COPY WITHOUT PERMISSIONS

DIR=$(pwd)
HOME=${DIR}
REPO="celltek/Imageserver"
CURRENT_VERSION="2.0.3"
SCRIPT_NAME="start.sh"
SCRIPT_URL="https://raw.githubusercontent.com/celltek/Imageserver/stable/start.sh"
LOG_FILE="script.log"
GAME=""
USERNAME=""
STEAM_PASS=""
STEAM_DIR="steam"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_latest_version() {
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    echo "$latest_version"
}

get_server_ip() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    echo "$server_ip"
}

check_ip_allowlist() {
    local server_ip auth_response auth_status auth_error
    server_ip=$(get_server_ip)

    auth_response=$(curl -s -H "Authorization: $server_ip" "https://api.celltek.de/allowlist/ip")

    if [ $? -eq 0 ]; then
        auth_status=$(echo "$auth_response" | grep -Po '"status":\s*\K\w+')
        auth_error=$(echo "$auth_response" | grep -Po '"error":\s*"\K[^"]+')

        if [[ "$auth_status" == "true" ]]; then
            log "IP-Adresse $server_ip ist in der Allowlist enthalten."
        else
            log "IP-Adresse $server_ip ist NICHT in der Allowlist enthalten. Fehler: $auth_error"
            exit 1
        fi
    else
        log "Fehler beim Überprüfen der IP-Allowlist für IP $server_ip."
        exit 1
    fi
}

check_game_details() {
    local game_details steam_login api_version installed_version
    game_details=$(curl -s "https://api.celltek.de/game/$GAME")

    if [ $? -ne 0 ]; then
        log "Fehler beim Abrufen der Spieldetails für das Spiel $GAME."
        exit 1
    fi

    steam_steamID=$(echo "$game_details" | jq -r '.response.steam.steamID')
    steam_login=$(echo "$game_details" | jq -r '.response.required.steamLOGIN')
    api_version=$(echo "$game_details" | jq -r '.response.version.full')

    installed_version=$(get_installed_version)

    if [ "$installed_version" != "$api_version" ]; then
        log "Version mismatch detected. Installed version: $installed_version, API version: $api_version. Updating..."
        update_game_files

        if [ "$steam_login" == "true" ]; then
            log "Steam-Anmeldung ist erforderlich. Überprüfe Benutzername und Passwort."
            if [ -z "$USERNAME" ] || [ -z "$STEAM_PASS" ]; then
                log "Fehler: Benutzername und Passwort müssen gesetzt sein, wenn Steam-Anmeldung erforderlich ist."
                exit 1
            fi
            run_steam_cmd "$steam_steamID" true
        else
            log "Steam-Anmeldung ist nicht erforderlich. Fallback auf anonymen Modus."
            run_steam_cmd "$steam_steamID" false
        fi
    else
        log "Installed version matches API version. No update required."
    fi
	
    save_installed_version "$api_version"
}

get_installed_version() {
    if [[ -f "version.txt" ]]; then
        cat version.txt
    else
        echo "0.0.0"
    fi
}

save_installed_version() {
    echo "$1" > version.txt
}

download_file() {
    local game_files file_id file_name file_path download_url
    game_files=$(curl -s "https://api.celltek.de/game/$GAME/files")

    if [ $? -ne 0 ]; then
        log "Fehler beim Abrufen der Dateien für das Spiel $GAME."
        exit 1
    fi

    FIRST_RUN=true
    if [ -f ".first_run" ]; then
        FIRST_RUN=false
    else
        touch ".first_run"
    fi

    echo "$game_files" | jq -c 'to_entries[]' | while read -r file_entry; do
        file_id=$(echo "$file_entry" | jq -r '.key')
        file_name=$(echo "$file_entry" | jq -r '.value.name')
        file_path=$(echo "$file_entry" | jq -r '.value.path')

        download_url="https://raw.githubusercontent.com/celltek/Imageserver/stable/$GAME/$file_name"

        if [ -z "$file_path" ]; then
            file_path="$DIR"
        fi
        
        target_path="$file_path/$file_name"

        mkdir -p "$file_path"

        if [[ "$file_name" == "server.cfg" && "$FIRST_RUN" == "false" ]]; then
            log "Erste Ausführung abgeschlossen. Datei $file_name wird nicht überschrieben."
            continue
        fi

        log "Lade $file_name herunter nach $target_path..."
        curl -s -o "$target_path" "$download_url"

        if [ $? -eq 0 ]; then
            log "Datei $file_name erfolgreich heruntergeladen und nach $target_path verschoben."
        else
            log "Fehler beim Herunterladen der Datei $file_name."
        fi
    done
}

download_steam_cmd() {
    log "Lade SteamCMD herunter..."
    mkdir -p "$STEAM_DIR"
    curl -s -L -o "$STEAM_DIR/steam.tar" "https://image.celltek.info/steam/steam.tar" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "Entpacke SteamCMD..."
        tar -xf "$STEAM_DIR/steam.tar" -C "$STEAM_DIR"
        log "SteamCMD erfolgreich entpackt."
    else
        log "Fehler beim Herunterladen der SteamCMD-Datei."
        exit 1
    fi
}

run_steam_cmd() {
    local steam_steamID="$1"
    local steam_login_required="$2"

    if [ "$steam_login_required" == "true" ]; then
        download_steam_cmd
        log "Führe SteamCMD aus für appID $steam_steamID mit Benutzer $USERNAME..."
        "$STEAM_DIR/steamcmd.sh" +force_install_dir ../ +login "$USERNAME" "$STEAM_PASS" +@ShutdownOnFailedCommand 0 +@NoPromptForPassword 1 +@sSteamCmdForcePlatformType linux +app_update ${steam_steamID} validate +quit
    else
        log "Führe SteamCMD aus für appID $steam_steamID im anonymen Modus..."
        "$STEAM_DIR/steamcmd.sh" +force_install_dir ../ +login anonymous +@ShutdownOnFailedCommand 0 +@NoPromptForPassword 1 +@sSteamCmdForcePlatformType linux +app_update ${steam_steamID} validate +quit
    fi
}

execute_import_script() {
    local import_details
    import_details=$(curl -s "https://api.celltek.de/game/$GAME/import/tekbase")

    if [ $? -ne 0 ]; then
        log "Fehler beim Abrufen der Importdetails für das Spiel $GAME."
        exit 1
    fi

    script_to_execute=$(echo "$import_details" | jq -r '.script')
    
    log "Starte das Spiel mit dem Skript: $script_to_execute"
    eval "$script_to_execute"
}

update_game_files() {
    log "Aktualisiere Spieldateien für $GAME..."
    download_file
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -game) GAME="$2"; shift ;;
            -steamuser) USERNAME="$2"; shift ;;
            -steampass) STEAM_PASS="$2"; shift ;;
            *) echo "Unbekannte Option: $1"; exit 1 ;;
        esac
        shift
    done

    if [ -z "$GAME" ]; then
        echo "Fehler: Das Spiel muss mit -game angegeben werden."
        exit 1
    fi
}

cleanup() {
    log "Bereinige temporäre Dateien und Ordner..."
    
    rm -rf "$STEAM_DIR"
    rm -rf "Steam"
    rm -rf "steamapps"
    find . -type f -name "*.pdf" -exec rm -f {} \;

    log "Bereinigung abgeschlossen."
}

main() {
    parse_args "$@"

    log "Starte das Skript in Version $CURRENT_VERSION..."

    log "Prüfe auf Updates..."
    LATEST_VERSION=$(get_latest_version)

    if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
        log "Neue Version $LATEST_VERSION verfügbar. Update wird durchgeführt..."
        ./update.sh
    else
        log "Skript ist auf dem neuesten Stand (Version $CURRENT_VERSION)."
    fi

    log "Prüfe, ob die aktuelle IP-Adresse in der Allowlist ist..."
    check_ip_allowlist || exit 1

    log "Prüfe die Spieldetails für $GAME..."
    check_game_details
	
	log "Bereinigen..."
	cleanup

    log "Rufe Dateien für das Spiel $GAME ab..."
    download_file	
	
	log "Führe das Import-Skript aus..."
    execute_import_script
	
}

main "$@"
