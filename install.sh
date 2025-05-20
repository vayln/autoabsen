#!/data/data/com.termux/files/usr/bin/bash

VERSION="V1.0"
BASE_URL="https://github.com/vayln/autoabsen/releases/download/$VERSION"
APK_NAME="mt.apk"
DEST_DIR="$HOME/storage/downloads/autoabsen"


if [ ! -d "$HOME/storage/downloads" ]; then
    echo "📂 Mengatur akses penyimpanan Termux..."
    termux-setup-storage
    sleep 2
fi

mkdir -p "$DEST_DIR"


echo "⏳ Mengunduh $APK_NAME dari GitHub release..."
curl -# -L -o "$DEST_DIR/$APK_NAME" "$BASE_URL/$APK_NAME"


if [ -f "$DEST_DIR/$APK_NAME" ] && [ "$(stat -c %s "$DEST_DIR/$APK_NAME")" -gt 10000 ]; then
    echo "✅ APK berhasil diunduh ke: $DEST_DIR/$APK_NAME"
else
    echo "❌ Gagal mengunduh APK atau file terlalu kecil. Pastikan sudah upload ke GitHub Releases."
    rm -f "$DEST_DIR/$APK_NAME"
fi
