#!/system/bin/sh

MODDIR=${0%/*}

(
  while true; do
    MIN=$(date +%M | sed 's/^0*//')  # hilangkan leading zero
    REM=$((MIN % 5))

    if [ "$REM" -eq 0 ]; then
      logfile="/sdcard/service_log.txt"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Menit ke-$MIN. Menjalankan absen.sh" >> "$logfile"
      
      sh "$MODDIR/scripts/absen.sh" --force

      sleep 60  # cegah multiple run dalam 1 menit
    else
      sleep 20
    fi
  done
) &