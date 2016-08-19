#!/bin/bash

set -x

keysdir="$(dirname "$0")/../.keys"
mkdir -p "$keysdir"


# If a key is named after this job, prioritize it.
#
# We need to do this because if you have a single GitHub account with
# multiple repositories, and each repository has a deploy key, GitHub
# will actually accept any of the keys for authentication, but then
# *fails* moments later if the deploy key you used wasn't the one that
# corresponded to the repository you're trying to access.
#
# In practice that means that SSH sends the first key along, which
# gets accepted, but then git fails with a "permission denied" error
# (even though SSH could have sent a different key and all would have
# been well).
#

if [ "$JOB_IDENTIFIER" != "" ] && [ -e "${keysdir}/${JOB_IDENTIFIER}" ]; then
    keyfile_args="-i ${keysdir}/${JOB_IDENTIFIER}"
else
    # Look for keys we've generated
    local_keyfiles=$(find "$keysdir" -type f | grep -v '\.pub$' | sed 's/^/-i /' | tr "\n" " ")

    # Plus any in the user's home directory
    home_keyfiles=$(find "$HOME/.ssh" -type f 2>/dev/null | grep '\.pub$' | sed 's/^/-i /' | sed 's/\.pub//' | tr "\n" " ")

    keyfile_args="${local_keyfiles} ${home_keyfiles}"
fi

# Invoke SSH with our generated keys explicitly requested
exec ssh -v -o "StrictHostKeyChecking=no" $keyfile_args ${1+"$@"}
