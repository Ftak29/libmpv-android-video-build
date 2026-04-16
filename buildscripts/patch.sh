#!/bin/bash -e

set -euo pipefail

. ./include/depinfo.sh

PATCHES=(patches/*)
ROOT=$(pwd)
TVEZ_LIB_VER="TVEZLibA-1.1"

for dep_path in "${PATCHES[@]}"; do
    if [ -d "$dep_path" ]; then
        patches=($dep_path/*)
        dep=$(echo $dep_path | cut -d/ -f 2)

        cd deps/$dep
        echo Patching $dep

        git reset --hard

        for patch in "${patches[@]}"; do
            echo Applying $patch
            git apply "$ROOT/$patch"
            echo Done $patch
        done

        git config user.email "ci@local"
        git config user.name "ci"

        if ! git diff --quiet; then
            git add -A
            git commit -m "Apply custom patches"
            echo "Created patch commit"
        else
            echo "No changes to commit for $dep"
        fi

        # Normalize version strings after patching
        if [ "$dep" = "mpv" ]; then
            printf '%s\n' "$TVEZ_LIB_VER $v_mpv" > MPV_VERSION
            rm -rf .git
        fi

        if [ "$dep" = "ffmpeg" ]; then
            printf '%s\n' "$v_ffmpeg" > VERSION
            rm -rf .git
        fi

        cd "$ROOT"
    fi
done

exit 0
