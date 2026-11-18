#!/usr/bin/env bash
set -euo pipefail

adb shell settings put secure location_mode 3
flutter build apk --debug

# Wait for Package Manager after the slow emulator boot.
timeout 30s adb shell cmd package list packages >/dev/null 2>&1 || sleep 10
timeout 30s adb shell cmd package list packages >/dev/null 2>&1

apk=build/app/outputs/flutter-apk/app-debug.apk
install_ok=false
for attempt in 1 2; do
  # Non-streaming install avoids the ADB streaming path that timed out
  # twice on the previous API 35 emulator run.
  if timeout 240s adb install --no-streaming -r "$apk"; then
    install_ok=true
    break
  fi
  echo "APK install attempt $attempt failed; checking Package Manager"
  timeout 30s adb shell cmd package list packages >/dev/null 2>&1 || true
  sleep 10
done

if [ "$install_ok" != true ]; then
  echo "::error::APK install failed after two bounded non-streaming attempts"
  adb logcat -d -t 1000 | tail -n 200 || true
  exit 1
fi

adb shell pm grant jp.neoenox.michiake android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant jp.neoenox.michiake android.permission.ACCESS_FINE_LOCATION
adb shell pm grant jp.neoenox.michiake android.permission.POST_NOTIFICATIONS
timeout 300s flutter test integration_test/location_foreground_permission_test.dart
