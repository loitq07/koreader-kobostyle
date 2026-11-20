#!/bin/sh
# ==============================================================================
# Standalone Kobo E-Ink Desk Dashboard Runner (NO KOREADER NEEDED)
# ==============================================================================

BASE_DIR="/mnt/onboard/.adds/kobo-dashboard"
LOG_FILE="$BASE_DIR/dashboard.log"
CONF_FILE="$BASE_DIR/dashboard.conf"
LOCAL_IMG="$BASE_DIR/dashboard.png"
IMG_PATH="/tmp/dashboard.png"
STOP_FLAG="/tmp/stop_dashboard"

# Redirect all output to dashboard.log
exec > "$LOG_FILE" 2>&1
echo "=== Kobo Dashboard Start: $(date) ==="

# Defaults
DASHBOARD_URL=""
INTERVAL_SECONDS=1800
ORIENTATION="portrait" # "portrait" (758x1024) or "landscape" (1024x758 rotated)
FBINK_BIN="$BASE_DIR/fbink"

if [ -f "$CONF_FILE" ]; then
    echo "[+] Loading config: $CONF_FILE"
    . "$CONF_FILE"
fi

rm -f "$STOP_FLAG"

# Ensure FBInk binary is executable
if [ -f "$FBINK_BIN" ]; then
    chmod +x "$FBINK_BIN"
    echo "[+] Found FBInk: $FBINK_BIN"
else
    echo "[!] ERROR: Khong tim thay binary fbink tai $FBINK_BIN"
    exit 1
fi

# Pick image and remote URL based on orientation setting
if [ "$ORIENTATION" = "landscape" ]; then
    if [ -f "$BASE_DIR/dashboard_landscape_kobo.png" ]; then
        LOCAL_IMG="$BASE_DIR/dashboard_landscape_kobo.png"
    fi
    if echo "$DASHBOARD_URL" | grep -q "dashboard.png"; then
        DASHBOARD_URL=$(echo "$DASHBOARD_URL" | sed 's/dashboard\.png/dashboard_landscape_kobo\.png/')
    fi
fi
echo "[+] Target image: $LOCAL_IMG"
echo "[+] Remote URL: $DASHBOARD_URL"

if [ ! -f "$LOCAL_IMG" ]; then
    echo "[!] ERROR: Khong tim thay file anh tai $LOCAL_IMG"
    exit 1
fi

# 1. BƯỚC 1: Hiển thị ngay ảnh Dashboard sắc nét (clear + flash)
echo "[*] Rendering dashboard with FBInk..."
$FBINK_BIN -q -c -f -g file="$LOCAL_IMG"
res=$?
echo "[+] FBInk render status code: $res"

# 2. BƯỚC 2: Xác định thiết bị cảm ứng Touchscreen
TOUCH_DEV="/dev/input/event1"
if [ -f /proc/bus/input/devices ]; then
    t_ev=$(awk '
        /touch|zforce|cyttsp|elan/ { is_touch=1 }
        is_touch && /Handlers=/ {
            for(i=1; i<=NF; i++) if ($i ~ /^event[0-9]+$/) { print $i; exit }
        }
    ' /proc/bus/input/devices)
    if [ -n "$t_ev" ] && [ -e "/dev/input/$t_ev" ]; then
        TOUCH_DEV="/dev/input/$t_ev"
    fi
fi
echo "[+] Touch input device: $TOUCH_DEV"

# 3. BƯỚC 3: Lắng nghe nút Nguồn (Power button) ngầm để thoát nhanh nếu cần
POWER_PID=""
if [ -e /dev/input/event0 ]; then
    (
        dd if=/dev/input/event0 bs=16 count=1 >/dev/null 2>&1
        touch "$STOP_FLAG"
        killall dd 2>/dev/null
    ) &
    POWER_PID=$!
    echo "[+] Power button listener started (PID: $POWER_PID)"
fi

# 4. BƯỚC 4: Tự động cập nhật qua Wi-Fi ngầm (nếu có cấu hình DASHBOARD_URL)
REFRESH_PID=""
if [ -n "$DASHBOARD_URL" ] && ! echo "$DASHBOARD_URL" | grep -q "username/repository"; then
    echo "[+] Bat dau tien trinh Auto-Refresh ngam (Chu ky: ${INTERVAL_SECONDS}s)"
    (
        while [ ! -f "$STOP_FLAG" ]; do
            sleep "$INTERVAL_SECONDS"
            if [ -f "$STOP_FLAG" ]; then break; fi

            echo "[*] Auto-refresh: Kiem tra anh moi tu $DASHBOARD_URL..."
            /sbin/ifconfig wlan0 up 2>/dev/null
            connected=0
            for i in $(seq 1 12); do
                if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
                    connected=1
                    break
                fi
                sleep 1
            done

            if [ $connected -eq 1 ]; then
                rm -f "$IMG_PATH"
                if which curl >/dev/null 2>&1; then
                    curl -s -k -L -m 20 -o "$IMG_PATH" "$DASHBOARD_URL"
                else
                    wget -q -T 20 -O "$IMG_PATH" "$DASHBOARD_URL"
                fi

                if [ -f "$IMG_PATH" ] && [ $(wc -c < "$IMG_PATH") -gt 1024 ]; then
                    cp "$IMG_PATH" "$LOCAL_IMG"
                    $FBINK_BIN -q -c -f -g file="$LOCAL_IMG"
                    echo "[+] Da tai va cap nhat anh Dashboard moi thanh cong: $(date)"
                fi
            else
                echo "[!] Khong the ket noi Wi-Fi, bo qua lan cap nhat nay."
            fi

            /sbin/ifconfig wlan0 down 2>/dev/null
        done
    ) &
    REFRESH_PID=$!
fi

# 5. BƯỚC 5: Vòng lặp giám sát cảm ứng (CHỈ THOÁT KHI CHẠM NÚT THOÁT)
# KHÔNG dừng Nickel (để tránh watchdog sickel/hindenburg khởi động lại máy).
# Nếu người dùng chạm vào nội dung phía trên, tự động vẽ lại Dashboard để ảnh không bị mất.
# Nếu chạm vào nút Thoát ở đáy (Y >= 930), thoát vòng lặp và trả lại giao diện Kobo Home.
echo "[+] Dang giu Dashboard tren man hinh. Cho cham nut Thoat (Y >= 930)..."

while [ ! -f "$STOP_FLAG" ]; do
    # Chặn đọc cảm ứng (0% CPU, kernel sleep cho den khi co thao tac cham)
    out=$(dd if="$TOUCH_DEV" bs=64 count=1 2>/dev/null | busybox hexdump -v -e '8/2 "%u " "\n"')

    if [ -f "$STOP_FLAG" ]; then
        echo "[+] Stop flag phat hien! Dang thoat..."
        break
    fi

    # Kiem tra toa do Y cua nut Thoat:
    hit=""
    if [ "$ORIENTATION" = "landscape" ]; then
        hit=$(echo "$out" | awk '
            $5 == 3 && ($6 == 53 || $6 == 0) { x = $7 }
            $5 == 3 && ($6 == 54 || $6 == 1) { y = $7 }
            END { if (x >= 620 && y >= 500) print "EXIT" }
        ')
    else
        hit=$(echo "$out" | awk '
            $5 == 3 && ($6 == 54 || $6 == 1) {
                if ($7 >= 930) { print "EXIT"; exit }
            }
        ')
    fi

    if [ "$hit" = "EXIT" ]; then
        echo "[+] Da cham vao nut Thoat! Dang tro ve Kobo Home..."
        break
    else
        # Chạm vào phần nội dung phía trên: phục hồi lại ảnh nếu Nickel có vẽ đè
        sleep 0.2
        $FBINK_BIN -q -g file="$LOCAL_IMG" 2>/dev/null
    fi
done

# 6. BƯỚC 6: Dọn dẹp và trả lại màn hình cho Kobo Home
if [ -n "$REFRESH_PID" ]; then
    kill "$REFRESH_PID" 2>/dev/null
fi
if [ -n "$POWER_PID" ]; then
    kill "$POWER_PID" 2>/dev/null
fi
rm -f "$STOP_FLAG"
/sbin/ifconfig wlan0 down 2>/dev/null

# Clear màn hình để giao diện Kobo Home hiển thị sắc nét
echo "[+] Lam sach man hinh de ve Home..."
$FBINK_BIN -q -c 2>/dev/null

echo "=== Dashboard Stopped: $(date) ==="
exit 0
