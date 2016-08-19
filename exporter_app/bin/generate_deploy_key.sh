#!/bin/bash

name="$1"

if [ "$name" = "" ] || [ "$name" = "-h" ] || [ "$name" = "--help" ]; then
    echo "Generate a deploy key for use with Github and friends"
    echo
    echo "Usage: $0 <name of RepositoryMergeTask job>"
    echo
    echo "NOTE: If you will be setting up multiple git repositories"
    echo "within a single GitHub account (with different deploy keys for"
    echo "each), you should set the deploy key's short name to match the"
    echo "identifier of your RepositoryMergeTask job in jobs.rb.  When we"
    echo "run the 'git push', we will give priority to any SSH key with the"
    echo "same name as the job itself, and this ensures we get the right key"
    echo "for the right repository."
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

ssh-keygen -t rsa -b 4096 -f "${keysdir}/${name}" -N ''

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
