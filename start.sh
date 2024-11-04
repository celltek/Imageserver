#!/bin/bash

REPO="celltek/Imageserver"
CURRENT_VERSION="2.0.3"
SCRIPT_NAME="start.sh"
SCRIPT_URL="https://raw.githubusercontent.com/celltek/Imageserver/master/start.sh"
LOG_FILE="script.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_latest_version() {
	local latest_version
	latest_version=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
	echo "$latest_version"
}

main() {
	log "Starte das Skript in Version $CURRENT_VERSION..."

	log "Prüfe auf Updates..."
	LATEST_VERSION=$(get_latest_version)
	
	if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
		log "Neue Version $LATEST_VERSION verfügbar. Update wird durchgeführt..."
		./update.sh
	else
		log "Skript ist auf dem neuesten Stand (Version $CURRENT_VERSION)."
	fi

}

main "$@"