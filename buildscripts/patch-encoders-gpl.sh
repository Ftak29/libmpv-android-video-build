#!/bin/bash -e

PATCHES=(patches-encoders-gpl/*)
ROOT=$(pwd)

for dep_path in "${PATCHES[@]}"; do
    dep="$(basename "$dep_path")"

    [ -d "$ROOT/deps/$dep" ] || continue
    cd "$ROOT/deps/$dep"

    for patch in "$ROOT/$dep_path"/*.patch; do
        [ -f "$patch" ] || continue

        if [ "$dep" = "mpv" ] && [ "$(basename "$patch")" = "depend_on_fftools_ffi.patch" ]; then
            echo "Applying $patch via scripted edit"

            python3 - <<'PY'
from pathlib import Path
import sys

meson = Path("meson.build")
if not meson.exists():
    print("meson.build not found", file=sys.stderr)
    sys.exit(1)

text = meson.read_text()

dep_anchor = "libswscale = dependency('libswscale', version: '>= 7.5.100')\n"
dep_insert = "\n# fftools-ffi\nlibfftools_ffi = dependency('fftools-ffi')\n"
if "libfftools_ffi = dependency('fftools-ffi')" not in text:
    if dep_anchor not in text:
        print("dep anchor not found", file=sys.stderr)
        sys.exit(1)
    text = text.replace(dep_anchor, dep_anchor + dep_insert, 1)

deps_old = "                libswresample,\n                libswscale]"
deps_new = "                libswresample,\n                libswscale,\n                libfftools_ffi]"
if "libfftools_ffi]" not in text:
    if deps_old not in text:
        print("deps anchor not found", file=sys.stderr)
        sys.exit(1)
    text = text.replace(deps_old, deps_new, 1)

src_old = "    'ta/ta_talloc.c',\n    'ta/ta_utils.c'\n)"
src_new = "    'ta/ta_talloc.c',\n    'ta/ta_utils.c',\n\n    ## fftools-ffi hack\n    'fftools-ffi.c'\n)"
if "'fftools-ffi.c'" not in text:
    if src_old not in text:
        print("source anchor not found", file=sys.stderr)
        sys.exit(1)
    text = text.replace(src_old, src_new, 1)

meson.write_text(text)

Path("fftools-ffi.c").write_text(
    '#include "fftools-ffi/dart_api.h"\n\n'
    'void* a = FFToolsFFIInitialize;\n'
    'void* b = FFToolsFFIExecuteFFmpeg;\n'
    'void* c = FFToolsFFIExecuteFFprobe;\n'
    'void* d = FFToolsCancel;\n'
)
PY
            continue
        fi

        echo "Applying $patch"
        git apply "$patch"
    done

    cd "$ROOT"
done

exit 0
