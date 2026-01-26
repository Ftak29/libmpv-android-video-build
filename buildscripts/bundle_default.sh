# --------------------------------------------------

[ -d deps ] && sudo rm -rf deps
[ -d prefix ] && sudo rm -rf prefix

./download.sh || exit 1
./patch.sh || exit 1

# --------------------------------------------------

if [ ! -f "scripts/ffmpeg" ]; then
  rm scripts/ffmpeg.sh
fi
cp flavors/default.sh scripts/ffmpeg.sh

# --------------------------------------------------

./build.sh || exit 1

# --------------------------------------------------

echo "chdir media-kit-android-helpe"
cd deps/media-kit-android-helper || exit 1

sudo chmod +x gradlew
./gradlew assembleRelease

unzip -q -o app/build/outputs/apk/release/app-release.apk -d app/build/outputs/apk/release

ln -sf "$(pwd)/app/build/outputs/apk/release/lib/arm64-v8a/libmediakitandroidhelper.so"   "../../../libmpv/src/main/jniLibs/arm64-v8a"
ln -sf "$(pwd)/app/build/outputs/apk/release/lib/armeabi-v7a/libmediakitandroidhelper.so" "../../../libmpv/src/main/jniLibs/armeabi-v7a"
ln -sf "$(pwd)/app/build/outputs/apk/release/lib/x86/libmediakitandroidhelper.so"         "../../../libmpv/src/main/jniLibs/x86"
ln -sf "$(pwd)/app/build/outputs/apk/release/lib/x86_64/libmediakitandroidhelper.so"      "../../../libmpv/src/main/jniLibs/x86_64"

cd ../..

# --------------------------------------------------

cd deps/media_kit/media_kit_native_event_loop || exit 1

flutter create --org com.alexmercerind --template plugin_ffi --platforms=android .

if ! grep -q android "pubspec.yaml"; then
  printf "      android:\n        ffiPlugin: true\n" >> pubspec.yaml
fi

flutter pub get

cp -a ../../mpv/include/mpv/. src/include/

cd example || exit 1

flutter clean
flutter build apk --release

unzip -q -o build/app/outputs/apk/release/app-release.apk -d build/app/outputs/apk/release

cd build/app/outputs/apk/release/ || exit 1

# --------------------------------------------------

rm -f lib/*/libapp.so
rm -f lib/*/libflutter.so

# --------------------------------------------------
# OLD BEHAVIOR (kept): zip lib folders into per-ABI JARs
# --------------------------------------------------

zip -q -r "default-arm64-v8a.jar"                lib/arm64-v8a
zip -q -r "default-armeabi-v7a.jar"              lib/armeabi-v7a
zip -q -r "default-x86.jar"                      lib/x86
zip -q -r "default-x86_64.jar"                   lib/x86_64

# --------------------------------------------------
# NEW BEHAVIOR: create ONE AAR that contains all ABIs
# This is what Android/Gradle expects for native libs.
# --------------------------------------------------

AAR_NAME="default.aar"
AAR_TMP="$(pwd)/.aar_tmp"

rm -rf "${AAR_TMP}"
mkdir -p "${AAR_TMP}/jni"

# Copy all native libs from the unzipped APK into AAR jni/<abi>/
for ABI in arm64-v8a armeabi-v7a x86 x86_64; do
  if [ -d "lib/${ABI}" ]; then
    mkdir -p "${AAR_TMP}/jni/${ABI}"
    cp -a "lib/${ABI}/." "${AAR_TMP}/jni/${ABI}/"
  fi
done

# Minimal AndroidManifest.xml required by AAR
cat > "${AAR_TMP}/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="dev.jdtech.mpv.default">
  <uses-sdk android:minSdkVersion="21" />
</manifest>
EOF

# AAR requires classes.jar. Make a tiny placeholder.
# (Does not contain code; you can add real classes later if needed.)
mkdir -p "${AAR_TMP}/.classes_tmp"
echo "placeholder" > "${AAR_TMP}/.classes_tmp/placeholder.txt"
( cd "${AAR_TMP}/.classes_tmp" && zip -q -r "../classes.jar" . )
rm -rf "${AAR_TMP}/.classes_tmp"

# Build the AAR (AAR is just a ZIP)
rm -f "${AAR_NAME}"
( cd "${AAR_TMP}" && zip -q -r "../${AAR_NAME}" . )

# --------------------------------------------------

mkdir -p ../../../../../../../../../../output

# Copy both JARs and AAR to output
cp *.jar ../../../../../../../../../../output
cp "${AAR_NAME}" ../../../../../../../../../../output

echo "==== Output checksums ===="
md5sum *.jar "${AAR_NAME}" || true

cd ../../../../../../../../..

# --------------------------------------------------

# zip -q -r debug-symbols-default.zip prefix/*/lib
