#!/usr/bin/env bash

set -euf -o pipefail

mkdir -p "$EXPORT_DIRECTORY"
cd "$EXPORT_DIRECTORY"

git add -A .

if [ "`git status --porcelain`" = "" ]; then
    echo "Nothing to commit!"
else
    git commit -m "Automated resource export for `date`"
fi
