#!/data/data/com.termux/files/usr/bin/bash

VERSION="v1.0"  # Ganti sesuai tag release kamu
BASE_URL="https://github.com/vay-leen/autoabsen/releases/download/$VERSION"
APK_NAME="mt.apk"
DEST_DIR="$HOME/storage/downloads/autoabsen"

# Pastikan storage tersedia
if [ ! -d "$HOME/storage/downloads" ]; then
    echo "📂 Mengatur akses penyimpanan Termux..."
    termux-setup-storage
    sleep 2
fi

mkdir -p "$DEST_DIR"

# Unduh APK
echo "⏳ Mengunduh $APK_NAME dari GitHub release..."
curl -# -L -o "$DEST_DIR/$APK_NAME" "$BASE_URL/$APK_NAME"

# Verifikasi file
if [ -f "$DEST_DIR/$APK_NAME" ] && [ "$(stat -c %s "$DEST_DIR/$APK_NAME")" -gt 10000 ]; then
    echo "✅ APK berhasil diunduh ke: $DEST_DIR/$APK_NAME"
else
    echo "❌ Gagal mengunduh APK atau file terlalu kecil. Pastikan sudah upload ke GitHub Releases."
    rm -f "$DEST_DIR/$APK_NAME"
fi
