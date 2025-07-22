#!/system/bin/sh

MODDIR=${0%/*}
LOGFILE="/sdcard/service_log.txt"


dumpsys deviceidle disable

export PATH=/system/bin:/system/xbin:/sbin:/vendor/bin:/vendor/xbin:/system/sbin:$PATH

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] service.sh dijalankan sebagai: $(id)" >> "$LOGFILE"


exec 200>/sys/power/wake_lock
echo "autoabsen_wakelock" >&200


svc power stayon true


(
while true; do
  MIN=$(date +%M | sed 's/^0*//') 
  REM=$((MIN % 5))
  logfile="/sdcard/service_log.txt"

  if [ "$REM" -eq 0 ]; then  
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Menit ke-$MIN. Menjalankan absen.sh" >> "$logfile"  
    sh "$MODDIR/scripts/absen.sh" --force  
    sleep 60  
  else  
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEARTBEAT] service.sh aktif, menit ke-$MIN" >> "$logfile"  
    sleep 20  
  fi
done
) &
