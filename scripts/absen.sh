#!/system/bin/sh

DATE=$(date +%F)
HOUR=$(date +%H)
MIN=$(date +%M)
LOG_FILE="/sdcard/absenlog.txt"
SHIFT_FILE="/data/adb/modules/autoabsen/shift_jadwal.txt"
PIN_FILE="/data/adb/modules/autoabsen/pin.txt"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log "[INFO] absen.sh dieksekusi jam $HOUR:$MIN"

[ ! -f "$SHIFT_FILE" ] && log "[ERROR] Shift file tidak ditemukan" && exit 1
[ ! -f "$PIN_FILE" ] && log "[ERROR] PIN file tidak ditemukan" && exit 1

SHIFT=$(grep "^$DATE" "$SHIFT_FILE" | awk '{print $2}')
[ -z "$SHIFT" ] && log "[INFO] Tidak ada shift hari ini ($DATE)" && exit 0

PIN=$(cat "$PIN_FILE")

unlock_screen() {
  svc power stayon true

  is_screen_on() {
    dumpsys display | grep -q "mScreenState=ON"
  }

  if is_screen_on; then
    log "[INFO] Layar sudah menyala, lanjut swipe dan input PIN"
  else
    log "[INFO] Layar belum menyala, coba tap untuk wake"
    input tap 500 500 500 500
    sleep 2

    if is_screen_on; then
      log "[INFO] Berhasil menyala setelah tap"
    else
      log "[INFO] Tap gagal, coba tekan power pertama"
      input keyevent 26
      sleep 2

      if is_screen_on; then
        log "[INFO] Berhasil menyala setelah tekan power"
      else
        log "[INFO] Masih belum menyala, tekan power kedua kali"
        input keyevent 26
        sleep 2

        if ! is_screen_on; then
          log "[ERROR] Layar tetap tidak menyala meskipun sudah dicoba semua metode"
          return 1
        fi
      fi
    fi
  fi

  log "[INFO] Lanjut swipe dan input PIN"
  input swipe 300 1000 300 500
  sleep 1

  for i in $(echo "$PIN" | fold -w1); do
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
  input tab 915 1450
  sleep 2
  input tap 980 2280
  sleep 2
  am start -n com.pulsahandal.simpeg/.MainActivity
  sleep 10
  input tap 880 750
  sleep 4
  am force-stop com.blogspot.newapphorizons.fakegps
  am force-stop com.pulsahandal.simpeg
  sleep 1
  am force-stop com.pulsahandal.simpeg
  sleep 1
  input keyevent KEYCODE_APP_SWITCH
  sleep 2
  input tap 550 2250
  log "[INFO] Absen selesai dan aplikasi ditutup"
}

case "$SHIFT" in
  pagi)
    if [ "$HOUR" -eq 6 ]; then
      JENIS="pagi_datang"
    elif [ "$HOUR" -eq 14 ]; then
      JENIS="pagi_pulang"
    else
      log "[INFO] Bukan jam absen shift pagi (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;

  middle)
    if [ "$HOUR" -eq 9 ]; then
      JENIS="middle_datang"
    elif [ "$HOUR" -eq 17 ]; then
      JENIS="middle_pulang"
    else
      log "[INFO] Bukan jam absen shift middle (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;

  sore)
    if [ "$HOUR" -eq 13 ]; then
      JENIS="sore_datang"
    elif [ "$HOUR" -eq 21 ]; then
      JENIS="sore_pulang"
    else
      log "[INFO] Bukan jam absen shift sore (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;

  malam)
    if [ "$HOUR" -eq 20 ]; then
      JENIS="malam_datang"
    elif [ "$HOUR" -eq 7 ]; then
      JENIS="malam_pulang"
    else
      log "[INFO] Bukan jam absen shift malam (jam $HOUR:$MIN)"
      exit 0
    fi
    ;;

  *)
    log "[WARN] Shift tidak dikenali: $SHIFT"
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
