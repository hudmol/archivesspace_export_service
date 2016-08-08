#!/bin/bash

keysdir="$(dirname "$0")/../.keys"
mkdir -p "$keysdir"

keyfile_args=$(find "$keysdir" -type f | grep -v '\.pub$' | sed 's/^/-i /' | tr "\n" " ")

# Invoke SSH with our generated keys explicitly requested
exec ssh -v -o "StrictHostKeyChecking=no" $keyfile_args ${1+"$@"}
