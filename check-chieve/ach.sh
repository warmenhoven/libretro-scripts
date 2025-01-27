#!/bin/bash

function usage() {
    echo "Usage:"
    echo "  $0 [rom_directory]"
    echo "Environment variables:"
    echo "  RA_API_KEY must be set."
    echo "  ROM_DIR can be set, or specified as an argument, otherwise defaults to \$PWD."
    exit 1
}

# List of required commands
required_commands=( "curl" "jq" "RAHasher" )

# Check each required command
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is required but not found in PATH."
        exit 1
    fi
done

# Determine ROM directory
ROM_DIR="${1:-$ROM_DIR}"
if [ -z "$ROM_DIR" ]; then
    ROM_DIR="$PWD"
fi

if [ -z "$RA_API_KEY" ]; then
    echo "Error: RA_API_KEY environment variable is not set."
    usage
fi

function rebuild_cache() {
    curl -s -o consoleids.json "https://retroachievements.org/API/API_GetConsoleIDs.php?y=$RA_API_KEY"
    for i in `jq '.[].ID' consoleids.json` ; do
        curl -o $i.json "https://retroachievements.org/API/API_GetGameList.php?y=$RA_API_KEY&i=$i&h=1"
    done
}

if [ ! -f "consoleids.json" ] ; then rebuild_cache ; fi

for dir in "$ROM_DIR"/* ; do
    if [ ! -d "$dir" ] ; then continue ; fi
    bn=$(basename "$dir")
    sys=$(jq -r --arg system "$bn" '.[] | select(.[0] == $system) | .[1]' ratora.json)
    if [ -z "$sys" ] ; then continue ; fi
    sysid=$(jq -r --arg system "$sys" '.[] | select(.Name == $system) | .ID' consoleids.json)
    if [ -z "$sysid" ] ; then continue ; fi

    for file in "$dir"/* ; do
        if [ ! -f "$file" ] ; then continue ; fi
        filehash=$(RAHasher "$sysid" "$file" 2>/dev/null)
        if [ -z "$filehash" ] ; then
            echo Could not properly hash "$file"
            continue
        fi
        title=$(jq -r --arg searchHash "$filehash" '.[] | select(.Hashes[]? | ascii_downcase == ($searchHash | ascii_downcase)) | .Title' $sysid.json)
        if [ -z "$title" ] ; then
            echo "Could not match $bn/"$(basename $file)" (system $sys, $sysid, $filehash)"
        fi
    done
done
