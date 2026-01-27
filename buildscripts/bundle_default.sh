#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# Clean previous build artifacts
# --------------------------------------------------
[ -d deps ] && sudo rm -rf deps
[ -d prefix ] && sudo rm -rf prefix

./download.sh || exit 1
./patch.sh || exit 1

# --------------------------------------------------
# Select FFmpeg flavor script (default)
# --------------------------------------------------
if [ ! -f "scripts/ffmpeg" ]; then
  rm -f scripts/ffmpeg.sh
fi
cp -f flavors/default.sh scripts/ffmpeg.sh

# --------------------------------------------------
# Build libmpv (native)
# --------------------------------------------------
./build.sh || exit 1

# --------------------------------------------------
# Build media-kit-android-helper (produces libmediakitandroidhelper.so)
# --------------------------------------------------
echo "chdir media-kit-android-helper"
cd deps/media-kit-android-helper || exit 1

sudo chmod +x gradlew
./gradlew assembleRelease

unzip -q -o app/build/outputs/apk/release/app-release.apk -d app/build/outputs/apk/release

ln -sf "$(pwd)/app/build/outputs/apk/release/lib/arm64-v8a/libmediakitandroidhelper.so"   "../../../libmpv/src/main/jniLibs/arm64-v8a"
ln -sf "$(pwd)/app/build/outputs/apk/release/lib/armeabi-v7a/libmediakitandroidhelper.so" "../../../libmpv/src/main/jniLibs/armeabi-v7a"
ln -sf "$(pwd)/app/build/outputs/apk/release/lib/x86_64/libmediakitandroidhelper.so"      "../../../libmpv/src/main/jniLibs/x86_64"

cd ../..

# --------------------------------------------------
# Build media_kit_native_event_loop example APK (to collect all .so's)
# --------------------------------------------------
cd deps/media_kit/media_kit_native_event_loop || exit 1

# Ensure this is a Flutter package with Android enabled
flutter create --org com.alexmercerind --template plugin_ffi --platforms=android . || true

# Ensure pubspec has android ffiPlugin section
if ! grep -q "android:" "pubspec.yaml"; then
  printf "\nflutter:\n  plugin:\n    platforms:\n      android:\n        ffiPlugin: true\n" >> pubspec.yaml
fi

flutter pub get

# Copy mpv headers (kept from your original script)
mkdir -p src/include
cp -a ../../mpv/include/mpv/. src/include/ || true

# --------------------------------------------------
# FIX 1: Some Flutter versions/templates may NOT create example/
# Create it if missing.
# --------------------------------------------------
if [ ! -d "example" ]; then
  echo "example/ folder not found. Creating a minimal Android example app..."
  flutter create --platforms=android example

  # Make example depend on this package (path dependency)
  if ! grep -q "media_kit_native_event_loop:" "example/pubspec.yaml"; then
    cat >> example/pubspec.yaml <<'EOF'

dependencies:
  media_kit_native_event_loop:
    path: ..
EOF
  fi

  (cd example && flutter pub get)
fi

cd example || { echo "ERROR: example/ still missing"; exit 1; }

flutter clean
flutter build apk --release

unzip -q -o build/app/outputs/apk/release/app-release.apk -d build/app/outputs/apk/release
cd build/app/outputs/apk/release/ || exit 1

# --------------------------------------------------
# Cleanup: remove unrelated libs from the unzipped APK
# --------------------------------------------------
rm -f lib/*/libapp.so || true
rm -f lib/*/libflutter.so || true

# --------------------------------------------------
# OLD BEHAVIOR: per-ABI JARs (optional; kept)
# --------------------------------------------------
zip -q -r "default-arm64-v8a.jar"   lib/arm64-v8a || true
zip -q -r "default-armeabi-v7a.jar" lib/armeabi-v7a || true
zip -q -r "default-x86_64.jar"      lib/x86_64 || true

# --------------------------------------------------
# NEW BEHAVIOR: ONE AAR containing all ABIs
# --------------------------------------------------
AAR_NAME="default.aar"
AAR_TMP="$(pwd)/.aar_tmp"

rm -rf "${AAR_TMP}"
mkdir -p "${AAR_TMP}/jni"

for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
  if [ -d "lib/${ABI}" ]; then
    mkdir -p "${AAR_TMP}/jni/${ABI}"
    cp -a "lib/${ABI}/." "${AAR_TMP}/jni/${ABI}/"
  fi
done

# --------------------------------------------------
# FIX 2: AndroidManifest package must NOT contain ".default"
# Use a safe package name.
# --------------------------------------------------
cat > "${AAR_TMP}/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="dev.jdtech.mpv.libmpv_default">
  <uses-sdk android:minSdkVersion="21" />
</manifest>
EOF

# AAR requires classes.jar (placeholder is fine)
mkdir -p "${AAR_TMP}/.classes_tmp"
echo "placeholder" > "${AAR_TMP}/.classes_tmp/placeholder.txt"
( cd "${AAR_TMP}/.classes_tmp" && zip -q -r "../classes.jar" . )
rm -rf "${AAR_TMP}/.classes_tmp"

rm -f "${AAR_NAME}"
( cd "${AAR_TMP}" && zip -q -r "../${AAR_NAME}" . )

# --------------------------------------------------
# Copy outputs to repo-level output/
# --------------------------------------------------
mkdir -p ../../../../../../../../../../output

cp -f *.jar ../../../../../../../../../../output || true
cp -f "${AAR_NAME}" ../../../../../../../../../../output

echo "==== Output checksums ===="
md5sum *.jar "${AAR_NAME}" || true

# Return to repo root
cd ../../../../../../../../..
