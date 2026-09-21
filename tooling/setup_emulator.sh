#!/bin/bash
# Create the AVD, boot it, and install the mitmproxy CA into the SYSTEM store.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
AVD="volga"
IMG="system-images;android-33;google_apis;arm64-v8a"

if ! avdmanager list avd 2>/dev/null | grep -q "Name: $AVD"; then
  echo "no" | avdmanager create avd -n "$AVD" -k "$IMG" -d "pixel_5"
  echo "created AVD $AVD"
else
  echo "AVD $AVD already exists"
fi

# Boot with writable system so we can add a system CA (needed on API24+).
echo "booting emulator (writable system, no snapshot)..."
nohup emulator -avd "$AVD" -writable-system -no-snapshot -no-boot-anim -gpu swiftshader_indirect >/tmp/emulator.log 2>&1 &
echo $! > /tmp/emulator.pid

echo "waiting for device..."
adb wait-for-device
# wait for full boot
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
echo "boot complete"

echo "gaining root + remounting /system..."
adb root
sleep 2
adb wait-for-device
adb remount || { adb shell avbctl disable-verification 2>/dev/null; adb reboot; adb wait-for-device; until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; adb root; sleep 2; adb remount; }

HASH=$(cat "$DIR/.ca_hash")
echo "pushing CA $HASH.0 into /system/etc/security/cacerts/ ..."
adb push "$DIR/$HASH.0" "/sdcard/$HASH.0"
adb shell su 0 cp "/sdcard/$HASH.0" "/system/etc/security/cacerts/$HASH.0" 2>/dev/null || adb shell cp "/sdcard/$HASH.0" "/system/etc/security/cacerts/$HASH.0"
adb shell chmod 644 "/system/etc/security/cacerts/$HASH.0"
adb shell ls -l "/system/etc/security/cacerts/$HASH.0"
echo "DONE. CA installed as system cert."
