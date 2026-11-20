#!/bin/sh
LOG="/mnt/onboard/.adds/kobo-dashboard/dashboard.log"
if [ -f "$LOG" ]; then
    tail -n 14 "$LOG"
else
    echo "Chua co file log. Hay bam 'E-Ink Dashboard' truoc de khoi dong."
fi
