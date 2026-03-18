#!/bin/bash -e

set -euo pipefail

PATCHES=(patches/*)
ROOT=$(pwd)

for dep_path in "${PATCHES[@]}"; do
    if [ -d "$dep_path" ]; then
        patches=($dep_path/*)
        dep=$(echo $dep_path |cut -d/ -f 2)
        
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

        cd $ROOT
    fi
done

exit 0
