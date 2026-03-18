#!/bin/bash -e

set -euo pipefail

PATCHES=(patches/*)
ROOT=$(pwd)

for dep_path in "${PATCHES[@]}"; do
    if [ -d "$dep_path" ]; then
        mapfile -t patches < <(find "$dep_path" -maxdepth 1 -type f | sort)
        dep=$(echo "$dep_path" | cut -d/ -f 2)

        cd "deps/$dep"
        echo "Patching $dep"

        git reset --hard

        for patch in "${patches[@]}"; do
            echo "Checking patch: $patch"
            git apply --check "$patch"
            echo "Applying patch: $patch"
            git apply "$patch"
            echo "Applied patch successfully: $patch"
        done

        echo "Git status after patching $dep:"
        git status --short

        echo "Changed files after patching $dep:"
        git diff --name-only HEAD

        git config user.email "ci@local"
        git config user.name "ci"

        if ! git diff --quiet; then
            git add -A
            git commit -m "Apply custom patches"
            echo "Created patch commit:"
            git log -1 --oneline
        else
            echo "No changes to commit for $dep"
        fi

        cd "$ROOT"
    fi
done

exit 0
