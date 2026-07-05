#!/system/bin/sh


DATE=$(date +%F)
HOUR=$(date +%H)
MIN=$(date +%M)
TIME=$(date +%H:%M)

LOG_FILE="/sdcard/simpeg/absenlog.txt"
SHIFT_FILE="/data/adb/modules/autoabsen/shift_jadwal.txt"
PIN_FILE="/data/adb/modules/autoabsen/pin.txt"
IMG_PATH="/sdcard/simpeg/screenshot_absen.png"


TELE_CONF="/data/adb/modules/autoabsen/conf/telegram.conf"
DISCORD_CONF="/data/adb/modules/autoabsen/conf/discord.conf"
[ -f "$TELE_CONF" ] && source "$TELE_CONF"
[ -f "$DISCORD_CONF" ] && source "$DISCORD_CONF"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}


send_notif() {
  MESSAGE="$1"

  # Telegram
  if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="$MESSAGE" \
      -d parse_mode="Markdown" >/dev/null
  fi

  # Discord
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"content\": \"$MESSAGE\"}" \
      "$WEBHOOK_URL" >/dev/null
  fi
}

send_photo_notif() {
  FILE="$1"
  CAPTION="$2"

  if [ ! -s "$FILE" ]; then
    log "[ERROR] File screenshot kosong atau tidak ada: $FILE"
    return
  fi

  # Telegram
  if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
      -F chat_id="$CHAT_ID" \
      -F photo=@"$FILE" \
      -F caption="$CAPTION" \
      -F parse_mode="Markdown" >/dev/null
  fi

  # Discord
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST -H "Content-Type: multipart/form-data" \
      -F "file=@$FILE" \
      -F "content=$CAPTION" \
      "$WEBHOOK_URL" >/dev/null
  fi
}

unlock_screen() {
  svc power stayon true

  is_screen_on() {
    dumpsys display | grep -q "mScreenState=ON"
  }

  if ! is_screen_on; then
    log "[INFO] Layar belum menyala, coba tap untuk wake"
    sleep 0.5
    input tap 500 500
    sleep 2

    if ! is_screen_on; then
      log "[INFO] Tap gagal, tekan power"
      sleep 0.5
      input keyevent 26
      sleep 2
    fi
  fi

  log "[INFO] Swipe dan input PIN"
  sleep 0.5
  input swipe 300 1000 300 500
  sleep 1

  for i in $(cat "$PIN_FILE" | fold -w1); do
    sleep 0.2
    input text "$i"
  done

  sleep 0.5
  input keyevent 66
  sleep 2
}


do_absen() {
  while true; do
    log "[INFO] Menjalankan sesi absen shift $SHIFT - $JENIS"
    unlock_screen

    mkdir -p /sdcard/simpeg/

    am start -S -n io.github.jqssun.gpssetter/.ui.MapActivity
    sleep 5
    input tap 45 115
    sleep 1
    input tap 300 315
    sleep 1
    input tap 565 1278 
    sleep 1
    input tap 930 1750
    sleep 2

    MAX_RETRIES=3
    RETRY_COUNT=0
    APP_LOADED=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      log "[INFO] Membuka aplikasi simpeg (Percobaan $((RETRY_COUNT+1))/$MAX_RETRIES)"
      
      # Pastikan bersih sebelum start
      input keyevent 3
      sleep 1
      
      am start -n com.pulsahandal.simpeg/.MainActivity
      sleep 12
      rm -f /sdcard/window_dump.xml
      uiautomator dump /sdcard/window_dump.xml > /dev/null 2>&1
      
      if grep -iq "FIQHQY ALFAUZI" /sdcard/window_dump.xml; then
        log "[INFO] Profil ditemukan! Aplikasi sukses dimuat."
        APP_LOADED=true
        break
      else
        log "[WARNING] Layar blank atau nama tidak ditemukan. Menutup via App Switcher..."
        
        # Pengganti am force-stop sesuai request
        input keyevent 3
        sleep 1
        input keyevent KEYCODE_APP_SWITCH
        sleep 2
        input tap 550 2250
        sleep 2
        
        RETRY_COUNT=$((RETRY_COUNT+1))
      fi
    done

    if [ "$APP_LOADED" = true ]; then
      input tap 880 750
      sleep 1
      input tap 777 1372
      sleep 8
      
      screencap -p "$IMG_PATH"
      for i in $(seq 1 5); do
        if [ -s "$IMG_PATH" ]; then break; fi
        sleep 1
      done

      log "[INFO] Absen berhasil dieksekusi"
      send_notif "*Absen berhasil* pada $(date +%H:%M) untuk shift *$SHIFT - $JENIS*"
      send_photo_notif "$IMG_PATH" "📸 Screenshot absen: *$SHIFT - $JENIS*"
      
      am start -S -n io.github.jqssun.gpssetter/.ui.MapActivity
      sleep 2
      input tap 930 1750
      sleep 2

      # Cleanup Akhir menggunakan App Switcher
      log "[INFO] Selesai, membersihkan task..."
      input keyevent 3
      sleep 1
      input keyevent KEYCODE_APP_SWITCH
      sleep 2
      input tap 550 2250
      sleep 1
      
      rm -f "$IMG_PATH"
      rm -f /sdcard/window_dump.xml
      input keyevent 26 
      return 0
    else
      log "[ERROR] Gagal memuat aplikasi setelah $MAX_RETRIES kali. Menunggu retry besar..."
      sleep 600
    fi
  done
}



log "[INFO] absen.sh dieksekusi jam $TIME"

[ ! -f "$SHIFT_FILE" ] && log "[ERROR] Shift file tidak ditemukan" && exit 1
[ ! -f "$PIN_FILE" ] && log "[ERROR] PIN file tidak ditemukan" && exit 1


for arg in "$@"; do
  case "$arg" in
    --force|-f|-force)
      log "[INFO] Mode FORCE Aktif: Melewati semua pengecekan jadwal dan durasi."
      SHIFT="manual"
      JENIS="manual_force"
      do_absen
      date +%s > "/data/adb/modules/autoabsen/last_absen_${JENIS}.txt"
      exit 0
      ;;
  esac
done


if [ "$HOUR" -eq 7 ] && [ "$MIN" -le 10 ]; then
  YESTERDAY_EPOCH=$(( $(date +%s) - 86400 ))
  YESTERDAY=$(date -u -d "@$YESTERDAY_EPOCH" +%F 2>/dev/null || busybox date -D %s -d "$YESTERDAY_EPOCH" +%F)
  SHIFT_YEST=$(grep "^$YESTERDAY" "$SHIFT_FILE" | awk '{print $2}')

  log "[DEBUG] Shift kemarin ($YESTERDAY): $SHIFT_YEST"

  if [ "$SHIFT_YEST" = "malam" ]; then
    SHIFT="malam"
    JENIS="malam_pulang"
  else
    log "[INFO] Bukan shift malam kemarin"
    exit 0
  fi
else
  SHIFT=$(grep "^$DATE" "$SHIFT_FILE" | awk '{print $2}')
  log "[DEBUG] Shift hari ini ($DATE): $SHIFT"

  case "$SHIFT" in
  pagi)
    [ "$HOUR" -eq 6 ] && [ "$MIN" -le 10 ] && JENIS="pagi_datang"
    [ "$HOUR" -eq 14 ] && JENIS="pagi_pulang"
    ;;
  pagi-extend)
    [ "$HOUR" -eq 6 ] && [ "$MIN" -le 10 ] && JENIS="pagi_datang"
    [ "$HOUR" -eq 15 ] && JENIS="pagi_pulang"
    ;;
  middle|siang)
    [ "$HOUR" -eq 9 ] && [ "$MIN" -le 10 ] && JENIS="middle_datang"
    [ "$HOUR" -eq 17 ] && JENIS="middle_pulang"
    ;;
  middle-extend|siang-extend)
    [ "$HOUR" -eq 9 ] && [ "$MIN" -le 10 ] && JENIS="middle_datang"
    [ "$HOUR" -eq 17 ] && [ "$MIN" -ge 30 ] && [ "$MIN" -le 40 ] && JENIS="middle_pulang"
    ;;
  sore)
    [ "$HOUR" -eq 13 ] && [ "$MIN" -le 10 ] && JENIS="sore_datang"
    [ "$HOUR" -eq 21 ] && JENIS="sore_pulang"
    ;;
  sore-extend)
    [ "$HOUR" -eq 12 ] && [ "$MIN" -le 10 ] && JENIS="sore_datang"
    [ "$HOUR" -eq 21 ] && JENIS="sore_pulang"
    ;;
  malam)
    [ "$HOUR" -eq 20 ] && [ "$MIN" -le 10 ] && JENIS="malam_datang"
    [ "$HOUR" -eq 7 ] && [ "$MIN" -le 10 ] && JENIS="malam_pulang"
    ;;
  malam-extend)
    [ "$HOUR" -eq 20 ] && [ "$MIN" -le 10 ] && JENIS="malam_datang"
    [ "$HOUR" -eq 7 ] && [ "$MIN" -le 10 ] && JENIS="malam_pulang"
    ;;
  *)
    ;;
esac
fi

[ -z "$SHIFT" ] || [ -z "$JENIS" ] && log "[ERROR] SHIFT/JENIS kosong" && exit 1


LAST_FILE="/data/adb/modules/autoabsen/last_absen_${JENIS}.txt"
NOW_EPOCH=$(date +%s)
if [ -f "$LAST_FILE" ]; then
  LAST_EPOCH=$(cat "$LAST_FILE")
  DIFF=$((NOW_EPOCH - LAST_EPOCH))
  if [ "$DIFF" -lt 3600 ]; then
    log "[INFO] Sudah absen $JENIS kurang dari 1 jam lalu"
    exit 0
  fi
fi


do_absen
date +%s > "$LAST_FILE"