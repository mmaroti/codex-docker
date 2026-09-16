#!/usr/bin/env bash

set -euo pipefail

if (($# == 0)); then
    echo "Usage: $0 FILE.lean [...]" >&2
    exit 2
fi

for source_file in "$@"; do
    source_file=$(realpath -- "$source_file")

    if [[ ! -f $source_file ]]; then
        echo "Lean source file not found: $source_file" >&2
        exit 2
    fi

    (
        cd /opt/mathlib
        lake env lean "$source_file"
    )
done
