#!/bin/bash
set -e

rm -rf lib
mkdir -p lib

cp -r ../libmpv/src/main/jniLibs/* lib/

flutter create --org com.alexmercerind --template plugin_ffi --platforms=android .

# 🔥 SAME ABI FIX
python3 - <<'PY'
from pathlib import Path

files = [
    Path("android/build.gradle"),
    Path("example/android/app/build.gradle"),
]

snippet = """
    defaultConfig {
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }
"""

for f in files:
    if not f.exists():
        continue
    text = f.read_text()
    if "abiFilters" in text:
        continue
    if "android {" in text:
        text = text.replace("android {", "android {" + snippet, 1)
        f.write_text(text)
PY

if ! grep -q android "pubspec.yaml"; then
  printf "      android:\n        ffiPlugin: true\n" >> pubspec.yaml
fi

flutter pub get

cd example
flutter pub get

flutter build apk --release --target-platform android-arm,android-arm64,android-x64

cd ..

mkdir -p output

cd lib
zip -q -r "../output/full-arm64-v8a.jar" arm64-v8a
zip -q -r "../output/full-armeabi-v7a.jar" armeabi-v7a
zip -q -r "../output/full-x86_64.jar" x86_64
cd ..
