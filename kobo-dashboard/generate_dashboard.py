#!/usr/bin/env python3
# ==============================================================================
# E-Ink Smart Desk Dashboard Generator for Kobo Aura 2 (758x1024 / 1024x758)
# - Screen size: 6.0" Carta E-Ink display (212 ppi)
# - Precision layout: Zero text overflow, automatic word-wrapping, high contrast
# - Typography: Space Grotesk Bold (large, chunky, legible from desk distance)
# - Icons: Phosphor Light (thin, elegant stroke; ONLY for weather & climate)
# - Live T3 Code Agent Quotas:
#     * Claude (Anthropic): Session 5h & Weekly with reset times
#     * Antigravity BHDH: Claude/GPT pool & Gemini pool
#     * Antigravity Dreamhunters: Claude/GPT pool & Gemini pool
#     * Antigravity Loi.TQ: Claude/GPT pool & Gemini pool
# ==============================================================================

import os
import json
import datetime
from datetime import timezone, timedelta
import urllib.request
from PIL import Image, ImageDraw, ImageFont

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FONTS_DIR = os.path.join(BASE_DIR, "fonts")
T3_CACHE_DIR = os.environ.get("T3_CACHE_DIR")
if not T3_CACHE_DIR or not os.path.exists(T3_CACHE_DIR):
    local_dir = os.path.expanduser(r"~/.t3/caches")
    if os.path.exists(local_dir):
        T3_CACHE_DIR = local_dir
    else:
        T3_CACHE_DIR = os.path.join(BASE_DIR, "caches")
TZ_VN = timezone(timedelta(hours=7))

# Kobo Aura Edition 2 Screen Dimensions
PORTRAIT_W, PORTRAIT_H = 758, 1024
LANDSCAPE_W, LANDSCAPE_H = 1024, 758

LATITUDE = 21.0285
LONGITUDE = 105.8542

DAILY_QUOTES = [
    "Hành động nhỏ lặp lại mỗi ngày tạo nên số phận vĩ đại.",
    "Tập trung vào điều bạn kiểm soát được; buông bỏ phần còn lại.",
    "Khó khăn hôm nay là bài học tôi luyện bản lĩnh ngày mai.",
    "Kỷ luật là cầu nối vững chắc giữa mục tiêu và thành tựu.",
    "Hạnh phúc là sự tĩnh lặng trong tâm trí, không phải tiếng ồn bên ngoài.",
    "Mỗi ngày mới là một cơ hội tuyệt vời để kiến tạo giá trị thực.",
    "Chậm lại một nhịp để nhìn thấu suốt hướng đi phía trước."
]

# ------------------------------------------------------------------------------
# FONT & ICON HELPERS
# ------------------------------------------------------------------------------
with open(os.path.join(FONTS_DIR, "phosphor_icons.json"), "r", encoding="utf-8") as f:
    PH_ICONS = json.load(f)

def get_icon(name):
    code = PH_ICONS.get(name)
    return chr(code) if code else ""

def load_fonts():
    font_bold = os.path.join(FONTS_DIR, "SpaceGrotesk-Bold.ttf")
    font_reg = os.path.join(FONTS_DIR, "SpaceGrotesk.ttf")
    font_ph = os.path.join(FONTS_DIR, "Phosphor-Light.ttf")

    if not os.path.exists(font_bold):
        font_bold = font_reg
    if not os.path.exists(font_ph):
        font_ph = os.path.join(FONTS_DIR, "Phosphor-Regular.ttf")

    return {
        "clock": ImageFont.truetype(font_bold, 92),
        "date": ImageFont.truetype(font_bold, 24),
        "badge": ImageFont.truetype(font_bold, 15),
        "h1": ImageFont.truetype(font_bold, 19),
        "h2": ImageFont.truetype(font_bold, 18),
        "temp": ImageFont.truetype(font_bold, 54),
        "temp_desc": ImageFont.truetype(font_bold, 19),
        "metric_bold": ImageFont.truetype(font_bold, 16),
        "quota_label": ImageFont.truetype(font_bold, 17),
        "quota_val": ImageFont.truetype(font_bold, 17),
        "quote": ImageFont.truetype(font_bold, 18),
        "sub": ImageFont.truetype(font_bold, 13),
        "tiny": ImageFont.truetype(font_bold, 12),
        "icon_weather": ImageFont.truetype(font_ph, 60),
        "icon_metric": ImageFont.truetype(font_ph, 18),
    }

# ------------------------------------------------------------------------------
# TEXT UTILITIES
# ------------------------------------------------------------------------------
def draw_wrapped_text(draw, text, x, y, max_width, font, fill=0, line_spacing=6):
    words = text.split()
    lines = []
    current_line = []
    for word in words:
        test_line = " ".join(current_line + [word])
        if font.getbbox(test_line)[2] <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(" ".join(current_line))
                current_line = [word]
            else:
                lines.append(word)
                current_line = []
    if current_line:
        lines.append(" ".join(current_line))

    curr_y = y
    for line in lines:
        draw.text((x, curr_y), line, fill=fill, font=font)
        bbox = font.getbbox(line)
        curr_y += (bbox[3] - bbox[1]) + line_spacing
    return curr_y

def draw_progress_bar(draw, x, y, w, h, remaining_pct):
    draw.rectangle([x, y, x + w, y + h], fill=255, outline=0, width=2)
    if remaining_pct > 0:
        fill_w = max(4, int((remaining_pct / 100.0) * w))
        draw.rectangle([x, y, x + fill_w, y + h], fill=0)

# ------------------------------------------------------------------------------
# DATA FETCHING
# ------------------------------------------------------------------------------
def fetch_weather():
    w_url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={LATITUDE}&longitude={LONGITUDE}"
        "&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"
        "&daily=temperature_2m_max,temperature_2m_min&timezone=Asia%2FBangkok"
    )
    aqi_url = (
        f"https://air-quality-api.open-meteo.com/v1/air-quality?latitude={LATITUDE}&longitude={LONGITUDE}"
        "&current=us_aqi,pm2_5&timezone=Asia%2FBangkok"
    )

    weather = {"temp": 22, "humidity": 75, "code": 1, "wind": 10, "t_min": 18, "t_max": 25}
    aqi = {"aqi": 50, "pm25": 15}

    try:
        req = urllib.request.Request(w_url, headers={"User-Agent": "KoboDashboard/2.0"})
        with urllib.request.urlopen(req, timeout=8) as r:
            d = json.load(r)
            curr = d.get("current", {})
            daily = d.get("daily", {})
            weather["temp"] = round(curr.get("temperature_2m", 22))
            weather["humidity"] = round(curr.get("relative_humidity_2m", 75))
            weather["code"] = curr.get("weather_code", 1)
            weather["wind"] = round(curr.get("wind_speed_10m", 10))
            if daily.get("temperature_2m_min"):
                weather["t_min"] = round(daily["temperature_2m_min"][0])
                weather["t_max"] = round(daily["temperature_2m_max"][0])
    except Exception as e:
        print(f"Weather error: {e}")

    try:
        req = urllib.request.Request(aqi_url, headers={"User-Agent": "KoboDashboard/2.0"})
        with urllib.request.urlopen(req, timeout=8) as r:
            d = json.load(r)
            curr = d.get("current", {})
            aqi["aqi"] = round(curr.get("us_aqi", 50))
            aqi["pm25"] = round(curr.get("pm2_5", 15))
    except Exception as e:
        print(f"AQI error: {e}")

    return weather, aqi

def get_weather_desc(code):
    mapping = {
        0: ("Trời quang đãng", "sun"),
        1: ("Ít mây, trời nắng", "cloud-sun"),
        2: ("Mây rải rác", "cloud-sun"),
        3: ("Trời nhiều mây", "cloud"),
        45: ("Có sương mù", "cloud"),
        48: ("Sương mù dày", "cloud"),
        51: ("Mưa phùn nhẹ", "cloud-rain"),
        53: ("Mưa phùn rải rác", "cloud-rain"),
        55: ("Mưa phùn hạt to", "cloud-rain"),
        61: ("Mưa rào nhẹ", "cloud-rain"),
        63: ("Mưa vừa", "cloud-rain"),
        65: ("Mưa to", "cloud-rain"),
        71: ("Tuyết rơi", "cloud-snow"),
        80: ("Mưa rào thoáng qua", "cloud-rain"),
        95: ("Có dông sét", "cloud-lightning"),
    }
    return mapping.get(code, ("Thời tiết mát mẻ", "cloud"))

def get_aqi_label(aqi):
    if aqi <= 50: return "Trong lành"
    if aqi <= 100: return "Trung bình"
    if aqi <= 150: return "Nhạy cảm"
    if aqi <= 200: return "Kém"
    return "Nguy hại"

def fetch_quotas():
    targets = [
        ("CLAUDE (ANTHROPIC)", "claudeAgent.json", "claude"),
        ("ANTIGRAVITY BHDH", "antigravity_bhdh.json", "antigravity"),
        ("ANTIGRAVITY DREAMHUNTERS", "antigravity_dreamhunters.json", "antigravity"),
        ("ANTIGRAVITY LOI.TQ", "antigravity.json", "antigravity")
    ]

    results = []
    for label, fname, kind in targets:
        fpath = os.path.join(T3_CACHE_DIR, fname)
        if not os.path.exists(fpath):
            continue

        try:
            with open(fpath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue

        limits = data.get("usageLimits") or {}
        windows = limits.get("windows", [])
        acc = {"name": label, "kind": kind, "bars": [], "status": None}

        if limits.get("unavailable"):
            continue

        if kind == "claude":
            for w in windows:
                wid = w.get("id", "")
                used = w.get("usedPercent", 0)
                rem = max(0, 100 - round(used))
                resets = w.get("resetsAt")
                r_str = ""
                if resets:
                    try:
                        dt = datetime.datetime.fromisoformat(resets.replace("Z", "+00:00")).astimezone(TZ_VN)
                        r_str = dt.strftime("%H:%M %d/%m")
                    except Exception:
                        pass

                if "five" in wid or "session" in w.get("kind", ""):
                    acc["bars"].append({
                        "label": "Session 5h",
                        "remaining": rem,
                        "used": round(used),
                        "reset": f"Reset {r_str}" if r_str else ""
                    })
                elif "seven" in wid or "weekly" in w.get("kind", ""):
                    acc["bars"].append({
                        "label": "Hạn mức Tuần",
                        "remaining": rem,
                        "used": round(used),
                        "reset": f"Reset {r_str}" if r_str else ""
                    })

        elif kind == "antigravity":
            p3 = next((w for w in windows if w.get("id") == "3p-5h"), None)
            gem = next((w for w in windows if w.get("id") == "gemini-5h"), None)

            if p3:
                u = p3.get("usedPercent", 0)
                acc["bars"].append({
                    "label": "Claude & GPT",
                    "remaining": max(0, 100 - round(u)),
                    "used": round(u),
                    "reset": ""
                })
            if gem:
                u = gem.get("usedPercent", 0)
                r_at = gem.get("resetsAt", "")
                r_str = ""
                if r_at:
                    try:
                        dt = datetime.datetime.fromisoformat(r_at.replace("Z", "+00:00")).astimezone(TZ_VN)
                        r_str = dt.strftime("%H:%M")
                    except Exception:
                        pass
                acc["bars"].append({
                    "label": "Gemini Flash",
                    "remaining": max(0, 100 - round(u)),
                    "used": round(u),
                    "reset": f"Reset {r_str}" if r_str else ""
                })

        results.append(acc)

    return results

# ------------------------------------------------------------------------------
# PORTRAIT LAYOUT RENDERER (758 x 1024) - NATIVE KOBO SCREEN
# ------------------------------------------------------------------------------
def render_portrait(output_path):
    fonts = load_fonts()
    weather, aqi = fetch_weather()
    quotas = fetch_quotas()
    now = datetime.datetime.now(TZ_VN)

    img = Image.new("L", (PORTRAIT_W, PORTRAIT_H), color=255)
    draw = ImageDraw.Draw(img)

    # 1. TOP HEADER: BADGE + CLOCK + DATE
    badge_text = "HÀ NỘI  •  T3 CODE DESK"
    badge_w = fonts["badge"].getbbox(badge_text)[2] + 24
    draw.rectangle([28, 20, 28 + badge_w, 46], fill=0)
    draw.text((40, 24), badge_text, fill=255, font=fonts["badge"])

    time_str = now.strftime("%H:%M")
    draw.text((24, 46), time_str, fill=0, font=fonts["clock"])

    days_vn = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
    day_name = days_vn[now.weekday()]
    date_str = f"{day_name}, {now.day} tháng {now.month}, {now.year}"
    draw.text((28, 144), date_str, fill=0, font=fonts["date"])

    draw.line([28, 180, PORTRAIT_W - 28, 180], fill=0, width=3)

    # 2. WEATHER CARD (y: 194 to 346, height: 152)
    w_card_y = 194
    w_card_h = 152
    draw.rectangle([28, w_card_y, PORTRAIT_W - 28, w_card_y + w_card_h], fill=255, outline=0, width=2)

    w_desc, icon_key = get_weather_desc(weather["code"])
    weather_icon = get_icon(icon_key)

    # Left: Icon + Temperature + Condition
    draw.text((44, w_card_y + 36), weather_icon, fill=0, font=fonts["icon_weather"])
    temp_str = f"{weather['temp']}°C"
    draw.text((122, w_card_y + 20), temp_str, fill=0, font=fonts["temp"])
    draw.text((124, w_card_y + 86), w_desc, fill=0, font=fonts["temp_desc"])

    # Right: Clean, spacious vertical metrics
    col_r_x = 410
    drop_ic = get_icon("drop")
    wind_ic = get_icon("wind")
    gauge_ic = get_icon("leaf")

    draw.text((col_r_x, w_card_y + 18), drop_ic, fill=0, font=fonts["icon_metric"])
    draw.text((col_r_x + 26, w_card_y + 18), f"Độ ẩm: {weather['humidity']}%", fill=0, font=fonts["metric_bold"])

    draw.text((col_r_x, w_card_y + 50), wind_ic, fill=0, font=fonts["icon_metric"])
    draw.text((col_r_x + 26, w_card_y + 50), f"Gió: {weather['wind']} km/h ({weather['t_min']}°- {weather['t_max']}°)", fill=0, font=fonts["metric_bold"])

    draw.text((col_r_x, w_card_y + 82), gauge_ic, fill=0, font=fonts["icon_metric"])
    aqi_lbl = get_aqi_label(aqi["aqi"])
    draw.text((col_r_x + 26, w_card_y + 82), f"AQI: {aqi['aqi']} • {aqi_lbl}", fill=0, font=fonts["metric_bold"])

    # 3. T3 CODE AGENT QUOTAS CARD (y: 360 to 868, height: 508)
    q_card_y = 360
    q_card_h = 508
    draw.rectangle([28, q_card_y, PORTRAIT_W - 28, q_card_y + q_card_h], fill=255, outline=0, width=2)
    # Header strip
    draw.rectangle([28, q_card_y, PORTRAIT_W - 28, q_card_y + 38], fill=0)
    draw.text((44, q_card_y + 8), "HẠN MỨC AGENT T3 CODE (CÒN LẠI)", fill=255, font=fonts["h1"])

    curr_y = q_card_y + 50
    card_w = PORTRAIT_W - 56
    inner_w = card_w - 36 # 666px

    for acc in quotas:
        name = acc["name"]
        bars = acc.get("bars", [])

        # Account Title
        draw.text((46, curr_y), name, fill=0, font=fonts["h2"])
        curr_y += 24

        for bar in bars:
            lbl = bar["label"]
            rem = bar["remaining"]
            used = bar["used"]
            reset_txt = bar.get("reset", "")

            # Line 1: Label left, Clear Status right
            val_str = "HẾT (0%)" if rem == 0 else f"Còn {rem}%"
            draw.text((46, curr_y), lbl, fill=0, font=fonts["quota_label"])
            val_w = fonts["quota_val"].getbbox(val_str)[2]
            draw.text((46 + inner_w - val_w, curr_y), val_str, fill=0, font=fonts["quota_val"])

            # Line 2: Prominent Progress Bar
            draw_progress_bar(draw, 46, curr_y + 22, inner_w, 10, rem)

            # Line 3: Subtext details (used % and reset time)
            sub_parts = []
            if used > 0 and rem > 0:
                sub_parts.append(f"Đã dùng {used}%")
            if reset_txt:
                sub_parts.append(reset_txt)
            if sub_parts:
                sub_str = "  •  ".join(sub_parts)
                draw.text((46, curr_y + 36), sub_str, fill=80, font=fonts["tiny"])
                curr_y += 54
            else:
                curr_y += 40

        curr_y += 8

    # 4. DAILY STOIC WISDOM CARD (y: 836 to 936, height: 100)
    w_y = 836
    w_h = 100
    draw.rectangle([28, w_y, PORTRAIT_W - 28, w_y + w_h], fill=255, outline=0, width=2)
    draw.rectangle([28, w_y, PORTRAIT_W - 28, w_y + 30], fill=0)
    draw.text((44, w_y + 5), "SUY NGẪM HÔM NAY", fill=255, font=fonts["h1"])

    q_idx = (now.day + now.month) % len(DAILY_QUOTES)
    quote = f"\"{DAILY_QUOTES[q_idx]}\""
    quote_max_w = (PORTRAIT_W - 56) - 36
    draw_wrapped_text(draw, quote, 46, w_y + 40, quote_max_w, fonts["quote"], line_spacing=4)

    # 5. DEDICATED EXIT BUTTON (y: 946 to 1006, height: 60)
    btn_y1 = 946
    btn_y2 = 1006
    btn_x1 = 40
    btn_x2 = PORTRAIT_W - 40
    draw.rounded_rectangle([btn_x1, btn_y1, btn_x2, btn_y2], radius=12, fill=0)
    
    btn_txt = "✕  CHẠM VÀO ĐÂY ĐỂ THOÁT RA HOME"
    btn_font = ImageFont.truetype(os.path.join(FONTS_DIR, "SpaceGrotesk-Bold.ttf"), 20)
    btn_bbox = btn_font.getbbox(btn_txt)
    btn_w = btn_bbox[2] - btn_bbox[0]
    btn_h = btn_bbox[3] - btn_bbox[1]
    txt_x = btn_x1 + (btn_x2 - btn_x1 - btn_w) // 2
    txt_y = btn_y1 + (btn_y2 - btn_y1 - btn_h) // 2 - 2
    draw.text((txt_x, txt_y), btn_txt, fill=255, font=btn_font)

    img.save(output_path, "PNG")
    print(f"[+] Saved Portrait Dashboard to {output_path}")

# ------------------------------------------------------------------------------
# LANDSCAPE LAYOUT RENDERER (1024 x 758)
# ------------------------------------------------------------------------------
def render_landscape(output_path):
    fonts = load_fonts()
    weather, aqi = fetch_weather()
    quotas = fetch_quotas()
    now = datetime.datetime.now(TZ_VN)

    img = Image.new("L", (LANDSCAPE_W, LANDSCAPE_H), color=255)
    draw = ImageDraw.Draw(img)

    # LEFT COLUMN (x: 24 to 470, w: 446)
    col1_x = 24
    col1_w = 446

    badge_text = "HÀ NỘI  •  T3 CODE DESK"
    badge_w = fonts["badge"].getbbox(badge_text)[2] + 24
    draw.rectangle([col1_x, 24, col1_x + badge_w, 48], fill=0)
    draw.text((col1_x + 12, 28), badge_text, fill=255, font=fonts["badge"])

    time_str = now.strftime("%H:%M")
    draw.text((col1_x, 52), time_str, fill=0, font=fonts["clock"])

    days_vn = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
    day_name = days_vn[now.weekday()]
    date_str = f"{day_name}, {now.day}/{now.month}/{now.year}"
    draw.text((col1_x + 4, 150), date_str, fill=0, font=fonts["date"])

    draw.line([col1_x, 186, col1_x + col1_w, 186], fill=0, width=3)

    # Weather Card Left
    w_card_y = 202
    w_card_h = 246
    draw.rectangle([col1_x, w_card_y, col1_x + col1_w, w_card_y + w_card_h], fill=255, outline=0, width=2)
    draw.rectangle([col1_x, w_card_y, col1_x + col1_w, w_card_y + 34], fill=0)
    draw.text((col1_x + 16, w_card_y + 7), "THỜI TIẾT & MÔI TRƯỜNG", fill=255, font=fonts["h1"])

    w_desc, icon_key = get_weather_desc(weather["code"])
    weather_icon = get_icon(icon_key)

    # Left sub-section: Icon + Temp + Condition
    draw.text((col1_x + 18, w_card_y + 54), weather_icon, fill=0, font=fonts["icon_weather"])
    temp_str = f"{weather['temp']}°C"
    draw.text((col1_x + 94, w_card_y + 44), temp_str, fill=0, font=fonts["temp"])
    draw.text((col1_x + 20, w_card_y + 124), w_desc, fill=0, font=fonts["temp_desc"])

    # Right sub-section: Clean stack with plenty of margin
    drop_ic = get_icon("drop")
    wind_ic = get_icon("wind")
    gauge_ic = get_icon("leaf")

    col_sub_x = col1_x + 230
    draw.text((col_sub_x, w_card_y + 54), drop_ic, fill=0, font=fonts["icon_metric"])
    draw.text((col_sub_x + 26, w_card_y + 54), f"Độ ẩm: {weather['humidity']}%", fill=0, font=fonts["metric_bold"])

    draw.text((col_sub_x, w_card_y + 88), wind_ic, fill=0, font=fonts["icon_metric"])
    draw.text((col_sub_x + 26, w_card_y + 88), f"Gió: {weather['wind']} km/h", fill=0, font=fonts["metric_bold"])

    draw.text((col_sub_x, w_card_y + 122), gauge_ic, fill=0, font=fonts["icon_metric"])
    aqi_lbl = get_aqi_label(aqi["aqi"])
    draw.text((col_sub_x + 26, w_card_y + 122), f"AQI: {aqi['aqi']} ({aqi_lbl})", fill=0, font=fonts["metric_bold"])

    # Daily Quote Left (Wrapped to guarantee NO overflow)
    q_y = 464
    q_h = 172
    draw.rectangle([col1_x, q_y, col1_x + col1_w, q_y + q_h], fill=255, outline=0, width=2)
    draw.rectangle([col1_x, q_y, col1_x + col1_w, q_y + 34], fill=0)
    draw.text((col1_x + 16, q_y + 7), "SUY NGẪM HÔM NAY", fill=255, font=fonts["h1"])

    q_idx = (now.day + now.month) % len(DAILY_QUOTES)
    quote = f"\"{DAILY_QUOTES[q_idx]}\""
    max_quote_w = col1_w - 40 # 406px
    draw_wrapped_text(draw, quote, col1_x + 20, q_y + 48, max_quote_w, fonts["quote"], line_spacing=4)

    draw.text((col1_x + 20, q_y + q_h - 26), f"Cập nhật: {now.strftime('%H:%M')} • Kobo Aura 2", fill=80, font=fonts["tiny"])

    # Dedicated Exit Button Left (y: 652 to 710, height: 58)
    l_btn_y1 = 652
    l_btn_y2 = 710
    draw.rounded_rectangle([col1_x, l_btn_y1, col1_x + col1_w, l_btn_y2], radius=10, fill=0)
    l_btn_txt = "✕  CHẠM ĐÂY ĐỂ THOÁT RA HOME"
    l_btn_font = ImageFont.truetype(os.path.join(FONTS_DIR, "SpaceGrotesk-Bold.ttf"), 18)
    l_btn_bbox = l_btn_font.getbbox(l_btn_txt)
    l_btn_w = l_btn_bbox[2] - l_btn_bbox[0]
    l_btn_h = l_btn_bbox[3] - l_btn_bbox[1]
    l_txt_x = col1_x + (col1_w - l_btn_w) // 2
    l_txt_y = l_btn_y1 + (l_btn_y2 - l_btn_y1 - l_btn_h) // 2 - 2
    draw.text((l_txt_x, l_txt_y), l_btn_txt, fill=255, font=l_btn_font)

    # RIGHT COLUMN: AGENT QUOTAS (x: 494 to 1000, w: 506)
    col2_x = 494
    col2_w = 506
    card_r_y = 24
    card_r_h = 708

    draw.rectangle([col2_x, card_r_y, col2_x + col2_w, card_r_y + card_r_h], fill=255, outline=0, width=2)
    draw.rectangle([col2_x, card_r_y, col2_x + col2_w, card_r_y + 38], fill=0)
    draw.text((col2_x + 18, card_r_y + 8), "HẠN MỨC AGENT T3 CODE (CÒN LẠI)", fill=255, font=fonts["h1"])

    curr_y = card_r_y + 52
    inner_w_l = col2_w - 44 # 462px

    for acc in quotas:
        name = acc["name"]
        bars = acc.get("bars", [])

        draw.text((col2_x + 22, curr_y), name, fill=0, font=fonts["h2"])
        curr_y += 24

        for bar in bars:
            lbl = bar["label"]
            rem = bar["remaining"]
            used = bar["used"]
            reset_txt = bar.get("reset", "")

            # Line 1: Label Left, Clean Value Right
            val_str = "HẾT (0%)" if rem == 0 else f"Còn {rem}%"
            draw.text((col2_x + 22, curr_y), lbl, fill=0, font=fonts["quota_label"])
            val_w = fonts["quota_val"].getbbox(val_str)[2]
            draw.text((col2_x + 22 + inner_w_l - val_w, curr_y), val_str, fill=0, font=fonts["quota_val"])

            # Line 2: Progress Bar
            draw_progress_bar(draw, col2_x + 22, curr_y + 22, inner_w_l, 10, rem)

            # Line 3: Subtext
            sub_parts = []
            if used > 0 and rem > 0:
                sub_parts.append(f"Dùng {used}%")
            if reset_txt:
                sub_parts.append(reset_txt)
            if sub_parts:
                sub_str = "  •  ".join(sub_parts)
                draw.text((col2_x + 22, curr_y + 36), sub_str, fill=80, font=fonts["tiny"])
                curr_y += 54
            else:
                curr_y += 40

        curr_y += 8

    img.save(output_path, "PNG")
    print(f"[+] Saved Landscape Dashboard to {output_path}")

    # Also save rotated version for horizontal Kobo placement
    rotated = img.rotate(90, expand=True)
    kobo_rot_path = os.path.join(os.path.dirname(output_path), "dashboard_landscape_kobo.png")
    rotated.save(kobo_rot_path, "PNG")
    print(f"[+] Saved 90° Rotated Landscape Dashboard to {kobo_rot_path}")

# ------------------------------------------------------------------------------
# MAIN ENTRY POINT
# ------------------------------------------------------------------------------
if __name__ == "__main__":
    out_dir = BASE_DIR
    portrait_target = os.path.join(out_dir, "dashboard.png")
    landscape_target = os.path.join(out_dir, "dashboard_landscape.png")

    render_portrait(portrait_target)
    render_landscape(landscape_target)
