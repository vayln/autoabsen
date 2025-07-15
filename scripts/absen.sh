#!/system/bin/sh

DATE=$(date +%F)
HOUR=$(date +%H)
MIN=$(date +%M)
TIME=$(date +%H:%M)

LOG_FILE="/sdcard/absenlog.txt"
SHIFT_FILE="/data/adb/modules/autoabsen/shift_jadwal.txt"
PIN_FILE="/data/adb/modules/autoabsen/pin.txt"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

unlock_screen() {
  svc power stayon true

  is_screen_on() {
    dumpsys display | grep -q "mScreenState=ON"
  }

  if is_screen_on; then
    log "[INFO] Layar sudah menyala, lanjut swipe dan input PIN"
  else
    log "[INFO] Layar belum menyala, coba tap untuk wake"
    input tap 500 500
    sleep 2
    if ! is_screen_on; then
      log "[INFO] Tap gagal, coba tekan power pertama"
      input keyevent 26
      sleep 2
      if ! is_screen_on; then
        log "[INFO] Masih belum menyala, tekan power kedua kali"
        input keyevent 26
        sleep 2
        if ! is_screen_on; then
          log "[ERROR] Layar tetap tidak menyala"
          return 1
        fi
      fi
    fi
  fi

  log "[INFO] Lanjut swipe dan input PIN"
  input swipe 300 1000 300 500
  sleep 1
  for i in $(cat "$PIN_FILE" | fold -w1); do
    input text "$i"
    sleep 0.2
  done
  input keyevent 66
  sleep 2
}


do_absen() {
  log "[INFO] Menjalankan absen shift $SHIFT - $JENIS"
  unlock_screen
  am start -n com.blogspot.newapphorizons.fakegps/.MainActivity
  sleep 5
  input tap 915 1450
  sleep 2
  input tap 980 2280
  sleep 2
  am start -n com.pulsahandal.simpeg/.MainActivity
  sleep 5
  input tap 880 750
  sleep 4
  am force-stop com.blogspot.newapphorizons.fakegps
  am force-stop com.pulsahandal.simpeg
  sleep 1
  input keyevent KEYCODE_APP_SWITCH
  sleep 2
  input tap 550 2250
  log "[INFO] Absen selesai dan aplikasi ditutup"
}

log "[INFO] absen.sh dieksekusi jam $TIME"

[ ! -f "$SHIFT_FILE" ] && log "[ERROR] Shift file tidak ditemukan" && exit 1
[ ! -f "$PIN_FILE" ] && log "[ERROR] PIN file tidak ditemukan" && exit 1

if [ "$HOUR" -eq 7 ]; then
  YESTERDAY_EPOCH=$(( $(date +%s) - 86400 ))
  YESTERDAY=$(date -u -d "@$YESTERDAY_EPOCH" +%F 2>/dev/null)
  [ -z "$YESTERDAY" ] && YESTERDAY=$(date -r "$YESTERDAY_EPOCH" +%F 2>/dev/null)
  [ -z "$YESTERDAY" ] && YESTERDAY=$(busybox date -D %s -d "$YESTERDAY_EPOCH" +%F)

  log "[DEBUG] YESTERDAY terdeteksi: $YESTERDAY"

  LINE=$(grep "^$YESTERDAY" "$SHIFT_FILE" | head -n1)
  SHIFT_YEST=$(echo "$LINE" | awk '{print $2}')

  log "[DEBUG] Line kemarin: '$LINE'"
  log "[DEBUG] Shift kemarin: '$SHIFT_YEST'"

  if [ "$SHIFT_YEST" = "malam" ]; then
    SHIFT="malam"
    JENIS="malam_pulang"
    log "[INFO] Deteksi shift malam untuk pulang (data $YESTERDAY)"

    LAST_FILE="/data/adb/modules/autoabsen/last_absen_${JENIS}.txt"
    if [ -f "$LAST_FILE" ]; then
      LAST_EPOCH=$(cat "$LAST_FILE")
      NOW_EPOCH=$(date +%s)
      DIFF=$((NOW_EPOCH - LAST_EPOCH))
      if [ "$DIFF" -lt 3600 ]; then
        log "[INFO] Sudah absen $JENIS kurang dari 1 jam lalu"
        exit 0
      fi
    fi

    do_absen
    date +%s > "$LAST_FILE"
    input keyevent 26
    exit 0
  fi
fi

LINE=$(grep "^$DATE" "$SHIFT_FILE" | head -n1)
SHIFT=$(echo "$LINE" | awk '{print $2}')
log "[DEBUG] Line hari ini: '$LINE'"
log "[DEBUG] Shift hari ini: '$SHIFT'"

if [ -z "$SHIFT" ]; then
  log "[INFO] Tidak ada shift hari ini (libur atau kosong)"
  exit 0
fi

case "$SHIFT" in
  pagi)
    if [ "$HOUR" -eq 6 ] && [ "$MIN" -le 10 ]; then
      JENIS="pagi_datang"
    elif [ "$HOUR" -eq 14 ] && [ "$MIN" -le 10 ]; then
      JENIS="pagi_pulang"
    else
      log "[INFO] Bukan waktu absen shift pagi (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;
  middle)
    if [ "$HOUR" -eq 9 ] && [ "$MIN" -le 10 ]; then
      JENIS="middle_datang"
    elif [ "$HOUR" -eq 17 ] && [ "$MIN" -le 10 ]; then
      JENIS="middle_pulang"
    else
      log "[INFO] Bukan waktu absen shift middle (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;
  sore)
    if [ "$HOUR" -eq 13 ] && [ "$MIN" -le 10 ]; then
      JENIS="sore_datang"
    elif [ "$HOUR" -eq 21 ] && [ "$MIN" -le 10 ]; then
      JENIS="sore_pulang"
    else
      log "[INFO] Bukan waktu absen shift sore (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;
  malam)
    if [ "$HOUR" -eq 20 ] && [ "$MIN" -le 10 ]; then
      JENIS="malam_datang"
    elif [ "$HOUR" -eq 7 ] && [ "$MIN" -le 10 ]; then
      JENIS="malam_pulang"
    else
      log "[INFO] Bukan waktu absen shift malam (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;
  *)
    log "[WARN] Shift tidak dikenali atau kosong: '$SHIFT'"
    exit 0
    ;;
esac

LAST_FILE="/data/adb/modules/autoabsen/last_absen_${JENIS}.txt"
if [ -f "$LAST_FILE" ]; then
  LAST_EPOCH=$(cat "$LAST_FILE")
  NOW_EPOCH=$(date +%s)
  DIFF=$((NOW_EPOCH - LAST_EPOCH))
  if [ "$DIFF" -lt 3600 ]; then
    log "[INFO] Sudah absen $JENIS kurang dari 1 jam lalu"
    exit 0
  fi
fi

do_absen
date +%s > "$LAST_FILE"

case "$JENIS" in
  *_datang)
    log "[INFO] Menjadwalkan ulang absen $JENIS dalam 30 menit"
    if command -v at >/dev/null 2>&1; then
      echo "$(realpath $0)" | at now + 30 minutes
      log "[INFO] Dischedule ulang pakai 'at'"
    else
      (
        sleep 1800
        log "[INFO] Menjalankan ulang absen $JENIS setelah 30 menit"
        do_absen
      ) &
      log "[INFO] Dischedule ulang pakai background subshell + sleep"
    fi
    ;;
esac

sleep 1
input keyevent 26