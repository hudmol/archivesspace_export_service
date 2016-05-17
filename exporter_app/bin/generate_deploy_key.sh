#!/bin/bash

name="$1"

if [ "$name" = "" ] || [ "$name" = "-h" ] || [ "$name" = "--help" ]; then
    echo "Generate a deploy key for use with Github and friends"
    echo
    echo "Usage: $0 <short name for deploy key>"
    echo

    exit
fi

if [ "`echo "$name" | grep '[^a-zA-Z0-9_-]'`" != "" ]; then
    echo "Error: name must consist only of letters, numbers, hyphens and underscores"
    exit
fi

set -euf -o pipefail

keysdir="$(dirname "$0")/../.keys"
mkdir -p "$keysdir"

ssh-keygen -t dsa -f "${keysdir}/${name}" -N ''

echo
echo "========================================================================"
echo "Git deploy key generated!"
echo
echo "To use this key with GitHub, browse to your GitHub repository, then:"
echo
echo "  - Click 'Settings'"
echo "  - Click 'Deploy keys'"
echo "  - Click 'Add deploy key'"
echo "  - Give the key the title '$name'"
echo "  - Check 'Allow write access'"
echo "  - Paste the following text into the 'Key' field:"
echo
cat "${keysdir}/${name}.pub"
echo
