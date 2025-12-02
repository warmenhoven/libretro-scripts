#!/bin/bash

function usage() {
    echo "Usage:"
    echo "  $0 [rom_directory] [system_name]"
    echo "Environment variables:"
    echo "  RA_API_KEY must be set."
    echo "  ROM_DIR can be set, or specified as an argument, otherwise defaults to \$PWD."
    echo "If system_name is provided, only that system directory will be checked."
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

# Determine ROM directory and optional system filter
ROM_DIR="${1:-$ROM_DIR}"
if [ -z "$ROM_DIR" ]; then
    ROM_DIR="$PWD"
fi
SYSTEM_NAME="$2"

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

function check_dir() {
    dir="$1"
    if [ ! -d "$dir" ] ; then continue ; fi
    bn=$(basename "$dir")
    sys=$(jq -r --arg system "$bn" '.[] | select(.[0] == $system) | .[1]' ratora.json)
    if [ -z "$sys" ] ; then
        echo " !!!!! Ignoring $bn !!!!!"
        continue
    fi
    sysid=$(jq -r --arg system "$sys" '.[] | select(.Name == $system) | .ID' consoleids.json)
    if [ -z "$sysid" ] ; then continue ; fi
    echo "===== $sys ($sysid) ====="

    count=0
    badhash=0
    nomatch=0
    for file in "$dir"/* ; do
        count=$(($count + 1))
        if [ ! -f "$file" ] ; then continue ; fi
        if [[ "$file" == *.rvz ]]; then
            filehash=$(test_rvz_reader "$file" 2>/dev/null | awk '{print $4}')
        else
            filehash=$(RAHasher "$sysid" "$file" 2>/dev/null)
        fi
        if [ -z "$filehash" ] ; then
            echo "  Could not properly hash $file"
            badhash=$(($badhash + 1))
            continue
        fi
        title=$(jq -r --arg searchHash "$filehash" '.[] | select(.Hashes[]? | ascii_downcase == ($searchHash | ascii_downcase)) | .Title' $sysid.json)
        if [ -z "$title" ] ; then
            echo "  Could not match $bn/"$(basename $file)" (system $sys, $sysid, $filehash)"
            nomatch=$(($nomatch + 1))
        fi
    done
    echo " --> $count files, $(($count - $badhash - $nomatch)) matches"
    if [ $badhash -gt 0 ] ; then
        echo "  --> $badhash bad hashes"
    fi
    if [ $nomatch -gt 0 ] ; then
        echo "  --> $nomatch did not match"
    fi
}

if [ -n "$SYSTEM_NAME" ]; then
    check_dir "$ROM_DIR/$SYSTEM_NAME"
else
    for dir in "$ROM_DIR"/* ; do
        check_dir "$dir"
    done
fi
