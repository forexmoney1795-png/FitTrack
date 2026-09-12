#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

echo "========================================"
echo " FitTrack - APK Builder"
echo "========================================"

if ! command -v java >/dev/null 2>&1; then
  echo "Java not found. Installing OpenJDK 17..."
  sudo apt update
  sudo apt install -y openjdk-17-jdk unzip wget
fi

JAVA_HOME_CANDIDATE="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
if [ -d "$JAVA_HOME_CANDIDATE" ]; then export JAVA_HOME="$JAVA_HOME_CANDIDATE"; fi

# Find an Android SDK installed by Android Studio or common Linux locations.
if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  for d in "$HOME/Android/Sdk" "$HOME/Android/sdk" "/opt/android-sdk" "/usr/lib/android-sdk"; do
    if [ -d "$d" ]; then export ANDROID_SDK_ROOT="$d"; break; fi
  done
fi
if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  echo "Android SDK was not found."
  echo "Install/open Android Studio once, install Android SDK Platform 35 + Build Tools, then run this script again."
  echo "If Android Studio is already installed, set ANDROID_SDK_ROOT to its SDK folder."
  exit 1
fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"

SDKMANAGER=""
for x in "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" "$ANDROID_SDK_ROOT/cmdline-tools/bin/sdkmanager" "$(command -v sdkmanager 2>/dev/null || true)"; do
  if [ -n "$x" ] && [ -x "$x" ]; then SDKMANAGER="$x"; break; fi
done

if [ -n "$SDKMANAGER" ]; then
  echo "Accepting Android SDK licenses..."
  yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
  echo "Installing required SDK packages..."
  "$SDKMANAGER" "platform-tools" "platforms;android-35" "build-tools;35.0.0" >/dev/null
else
  echo "sdkmanager not found. Continuing with the SDK already installed."
fi

# Use a local Gradle distribution so no Gradle installation is required.
GRADLE_VERSION="8.7"
GRADLE_DIR="$APP_DIR/.gradle-local/gradle-$GRADLE_VERSION"
GRADLE_BIN="$GRADLE_DIR/bin/gradle"
if [ ! -x "$GRADLE_BIN" ]; then
  mkdir -p "$APP_DIR/.gradle-local"
  TMP="$APP_DIR/.gradle-local/gradle.zip"
  echo "Downloading Gradle $GRADLE_VERSION..."
  wget -q --show-progress -O "$TMP" "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  unzip -q -o "$TMP" -d "$APP_DIR/.gradle-local"
  rm -f "$TMP"
fi

echo "Building debug APK..."
"$GRADLE_BIN" --no-daemon assembleDebug

APK="$APP_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK" ]; then
  cp "$APK" "$APP_DIR/FitTrack.apk"
  echo
  echo "========================================"
  echo " APK READY!"
  echo " $APP_DIR/FitTrack.apk"
  echo "========================================"
else
  echo "Build finished but APK was not found."
  exit 2
fi
