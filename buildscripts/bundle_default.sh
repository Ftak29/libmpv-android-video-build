#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Build "default" flavor AAR + per-ABI jars
# -----------------------------

cd example || exit 1

flutter clean
flutter build apk --release

unzip -q -o build/app/outputs/apk/release/app-release.apk -d build/app/outputs/apk/release

cd build/app/outputs/apk/release/ || exit 1

# Remove Flutter & app libs; keep mpv + helper libs we want to ship
rm -r lib/*/libapp.so || true
rm -r lib/*/libflutter.so || true

# -----------------------------
# Create an AAR-like structure
# -----------------------------
rm -rf jni || true
mkdir -p jni

# Copy native libs from the APK into AAR "jni/<abi>/..."
# (AAR expects jni/<abi>/*.so)
for abi in arm64-v8a armeabi-v7a x86_64; do
  if [ -d "lib/${abi}" ]; then
    mkdir -p "jni/${abi}"
    cp -a "lib/${abi}/." "jni/${abi}/"
  fi
done

# IMPORTANT:
# "default" is a Java keyword and cannot be a package segment.
# Use a safe package name in the AAR manifest.
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
# If you still want the jars for legacy consumers:
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
# Export outputs to top-level /output
# -----------------------------
cd ../../../../../../.. || exit 1

mkdir -p output
cp -f example/build/app/outputs/apk/release/default.aar output/default.aar

# copy jars if they exist
[ -f example/build/app/outputs/apk/release/default-arm64-v8a.jar ] && cp -f example/build/app/outputs/apk/release/default-arm64-v8a.jar output/ || true
[ -f example/build/app/outputs/apk/release/default-armeabi-v7a.jar ] && cp -f example/build/app/outputs/apk/release/default-armeabi-v7a.jar output/ || true
[ -f example/build/app/outputs/apk/release/default-x86_64.jar ] && cp -f example/build/app/outputs/apk/release/default-x86_64.jar output/ || true

echo "Built:"
ls -la output || true
