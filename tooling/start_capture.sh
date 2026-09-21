#!/bin/bash
# Start mitmproxy capture and point the emulator's proxy at it.
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/env.sh"
CAP="${1:-$DIR/flows.jsonl}"
: > "$CAP"
# emulator reaches host loopback via 10.0.2.2; mitmproxy listens on 8080
adb shell settings put global http_proxy 10.0.2.2:8080
echo "emulator proxy -> 10.0.2.2:8080 ; capturing to $CAP"
echo "(Ctrl-C to stop; to clear proxy: adb shell settings put global http_proxy :0)"
mitmdump -s "$DIR/capture.py" --set capfile="$CAP" --listen-port 8080
