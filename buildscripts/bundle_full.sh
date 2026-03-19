#!/bin/bash
set -e

# Create Flutter plugin skeleton
flutter create --org com.alexmercerind --template plugin_ffi --platforms=android .

# Force supported ABIs only
python3 - <<'PY'
from pathlib import Path

files = [
    Path("android/build.gradle"),
    Path("android/build.gradle.kts"),
    Path("example/android/app/build.gradle"),
    Path("example/android/app/build.gradle.kts"),
]

for f in files:
    if not f.exists():
        continue

    text = f.read_text()

    if "abiFilters" in text:
        continue

    if f.suffix == ".kts":
        if "android {" in text:
            text = text.replace(
                "android {",
                """android {
    defaultConfig {
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }""",
                1,
            )
    else:
        if "android {" in text:
            text = text.replace(
                "android {",
                """android {
    defaultConfig {
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }""",
                1,
            )

    f.write_text(text)
PY

# Ensure Android FFI plugin section exists
if ! grep -q "android:" pubspec.yaml; then
  cat >> pubspec.yaml <<'EOF'
    android:
      ffiPlugin: true
EOF
fi

flutter pub get

cd example
flutter pub get
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
cd ..

# Package built native libraries
mkdir -p output

cd ../libmpv/src/main/jniLibs
zip -q -r "../../../buildscripts/output/full-arm64-v8a.jar" arm64-v8a
zip -q -r "../../../buildscripts/output/full-armeabi-v7a.jar" armeabi-v7a
zip -q -r "../../../buildscripts/output/full-x86_64.jar" x86_64
cd -
