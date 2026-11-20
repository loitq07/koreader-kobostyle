#!/bin/sh
# Stop E-Ink Dashboard and restore Kobo normal interface

BASE_DIR="/mnt/onboard/.adds/kobo-dashboard"
FBINK_BIN="$BASE_DIR/fbink"

touch /tmp/stop_dashboard
killall dd 2>/dev/null
killall -9 start_dashboard.sh 2>/dev/null

if [ -x "$FBINK_BIN" ]; then
    $FBINK_BIN -q -c -m "Da dung Dashboard. Dang quay lai Kobo..."
    sleep 1
    $FBINK_BIN -q -c
fi
