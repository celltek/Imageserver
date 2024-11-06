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
SCRIPT_NAME="start.sh"
SCRIPT_PATH=$(dirname "$0")/$SCRIPT_NAME 
SCRIPT_URL="https://github.com/celltek/Imageserver/raw/refs/heads/stable/SCRIPT_NAME"
LOG_FILE="script.log" 

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Lade die neueste Version von $SCRIPT_NAME herunter..."
curl -s -L -o "$SCRIPT_PATH.tmp" "$SCRIPT_URL"

if [ $? -eq 0 ] && [ -s "$SCRIPT_PATH.tmp" ]; then
	mv "$SCRIPT_PATH.tmp" "$SCRIPT_PATH"
	chmod +x "$SCRIPT_PATH"
	log "Update erfolgreich. Starte $SCRIPT_NAME neu..."
	(sleep 2 && exec "$SCRIPT_PATH") &
else
	log "Fehler beim Herunterladen von $SCRIPT_NAME."
	rm -f "$SCRIPT_PATH.tmp"
	exit 1
fi