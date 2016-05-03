#!/usr/bin/env bash

set -euf -o pipefail

mkdir -p "$EXPORT_DIRECTORY"
cd "$EXPORT_DIRECTORY"

if [ ! -d .git ]; then
   # Create the git directory for the first time if needed
   git init

   cat <<EOF > .gitignore
*.tmp
EOF

   git add .gitignore
   git commit -m "Initial import"
fi

# Remove any temp files
git clean -fdx

# Roll back any uncommitted work
git reset --hard
