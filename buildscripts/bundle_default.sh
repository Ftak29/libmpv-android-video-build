#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Robust paths: this script lives in <repo>/buildscripts/
# We always resolve repo root and work from there.
# -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLE_DIR="${REPO_ROOT}/example"
OUTPUT_DIR="${REPO_ROOT}/output"

if [ ! -d "${EXAMPLE_DIR}" ]; then
  echo "ERROR: example/ folder not found at: ${EXAMPLE_DIR}"
  echo "Repo root resolved as: ${REPO_ROOT}"
  echo "Contents of repo root:"
  ls -la "${REPO_ROOT}" || true
  exit 1
fi

cd "${EXAMPLE_DIR}"

flutter clean
flutter build apk --release

APK_PATH="build/app/outputs/apk/release/app-release.apk"
if [ ! -f "${APK_PATH}" ]; then
  echo "ERROR: APK not found at: ${EXAMPLE_DIR}/${APK_PATH}"
  find build -maxdepth 6 -type f -name "*.apk" -print || true
  exit 1
fi

# Extract APK
rm -rf build/app/outputs/apk/release/unpacked || true
mkdir -p build/app/outputs/apk/release/unpacked
unzip -q -o "${APK_PATH}" -d build/app/outputs/apk/release/unpacked

cd build/app/outputs/apk/release/unpacked

# Remove Flutter/app libs; keep mpv + helper libs we want to ship
rm -f lib/*/libapp.so || true
rm -f lib/*/libflutter.so || true

# -----------------------------
# Create an AAR structure
# -----------------------------
rm -rf jni || true
mkdir -p jni

# Copy native libs from the APK into AAR "jni/<abi>/..."
for abi in arm64-v8a armeabi-v7a x86_64; do
  if [ -d "lib/${abi}" ]; then
    mkdir -p "jni/${abi}"
    cp -a "lib/${abi}/." "jni/${abi}/"
  fi
done

# IMPORTANT:
# "default" is a Java keyword and cannot be a package segment.
cat > AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="dev.jdtech.mpv.libmpv_default">
  <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="36" />
</manifest>
EOF

# Package the AAR
rm -f default.aar || true
zip -q -r default.aar jni AndroidManifest.xml

# -----------------------------
# Also produce per-ABI jars (legacy)
# -----------------------------
rm -f default-arm64-v8a.jar default-armeabi-v7a.jar default-x86_64.jar || true

if [ -d "lib/arm64-v8a" ]; then
  (mkdir -p libtmp/arm64-v8a && cp -a lib/arm64-v8a libtmp/ && cd libtmp && zip -q -r ../default-arm64-v8a.jar arm64-v8a)
  rm -rf libtmp
fi

if [ -d "lib/armeabi-v7a" ]; then
  (mkdir -p libtmp/armeabi-v7a && cp -a lib/armeabi-v7a libtmp/ && cd libtmp && zip -q -r ../default-armeabi-v7a.jar armeabi-v7a)
  rm -rf libtmp
fi

if [ -d "lib/x86_64" ]; then
  (mkdir -p libtmp/x86_64 && cp -a lib/x86_64 libtmp/ && cd libtmp && zip -q -r ../default-x86_64.jar x86_64)
  rm -rf libtmp
fi

# -----------------------------
# Export outputs to repo /output
# -----------------------------
mkdir -p "${OUTPUT_DIR}"
cp -f default.aar "${OUTPUT_DIR}/default.aar"

[ -f default-arm64-v8a.jar ] && cp -f default-arm64-v8a.jar "${OUTPUT_DIR}/" || true
[ -f default-armeabi-v7a.jar ] && cp -f default-armeabi-v7a.jar "${OUTPUT_DIR}/" || true
[ -f default-x86_64.jar ] && cp -f default-x86_64.jar "${OUTPUT_DIR}/" || true

echo "Built outputs:"
ls -la "${OUTPUT_DIR}" || true
