#!/bin/bash

# ============================================
# CLIENT PACKAGE DELIVERY SCRIPT
# Packages all necessary files for client delivery
# ============================================

if [ -z "$1" ]; then
    echo "Usage: ./package_client.sh <client_identifier>"
    echo "Example: ./package_client.sh cafeabc"
    exit 1
fi

CLIENT_ID=$1
PACKAGE_DIR="client_packages/${CLIENT_ID}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "╔════════════════════════════════════════════════════════╗"
echo "║     CLIENT PACKAGE CREATOR                             ║"
echo "║     Creating delivery package for: $CLIENT_ID"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Create package directory
echo "📁 Creating package directory..."
mkdir -p "$PACKAGE_DIR"

# Copy APK
echo "📱 Copying APK..."
if [ -f "${CLIENT_ID}_pos.apk" ]; then
    cp "${CLIENT_ID}_pos.apk" "$PACKAGE_DIR/"
else
    echo "⚠️  Warning: APK not found. Please build first."
fi

# Copy SQL setup
echo "💾 Copying SQL setup..."
if [ -f "setup_${CLIENT_ID}.sql" ]; then
    cp "setup_${CLIENT_ID}.sql" "$PACKAGE_DIR/"
else
    echo "⚠️  Warning: SQL setup not found."
fi

# Copy credentials
echo "🔑 Copying credentials..."
if [ -f "credentials_${CLIENT_ID}.txt" ]; then
    cp "credentials_${CLIENT_ID}.txt" "$PACKAGE_DIR/"
else
    echo "⚠️  Warning: Credentials not found."
fi

# Copy README
echo "📄 Copying README..."
if [ -f "README_${CLIENT_ID}.md" ]; then
    cp "README_${CLIENT_ID}.md" "$PACKAGE_DIR/"
else
    echo "⚠️  Warning: README not found."
fi

# Copy user guides
echo "📚 Copying user guides..."
cp USER_QUICK_REFERENCE.md "$PACKAGE_DIR/" 2>/dev/null || true
cp CARA_MEMBUAT_USER.md "$PACKAGE_DIR/" 2>/dev/null || true
cp CARA_TAMBAH_LOGO_STRUK.md "$PACKAGE_DIR/" 2>/dev/null || true

# Create installation guide
echo "📝 Creating installation guide..."
cat > "$PACKAGE_DIR/INSTALLATION_GUIDE.txt" << EOF
═══════════════════════════════════════════════════════
  PANDUAN INSTALASI - POS KASIR
═══════════════════════════════════════════════════════

LANGKAH 1: INSTALL APK
───────────────────────────────────────────────────────
1. Transfer file ${CLIENT_ID}_pos.apk ke HP Android
2. Buka file APK di HP
3. Izinkan instalasi dari sumber tidak dikenal (jika diminta)
4. Klik Install
5. Tunggu hingga selesai

LANGKAH 2: BUKA APLIKASI
───────────────────────────────────────────────────────
1. Buka aplikasi POS Kasir
2. Login dengan kredensial dari file credentials_${CLIENT_ID}.txt
3. Aplikasi siap digunakan!

LANGKAH 3: TRAINING (OPSIONAL)
───────────────────────────────────────────────────────
Hubungi support untuk jadwal training:
- WhatsApp: [lihat credentials]
- Email: [lihat credentials]

TROUBLESHOOTING
───────────────────────────────────────────────────────
Q: Tidak bisa install APK?
A: Pastikan "Install from Unknown Sources" diaktifkan

Q: Lupa password?
A: Hubungi support untuk reset password

Q: Data tidak tersimpan?
A: Pastikan koneksi internet aktif untuk sync

SUPPORT
───────────────────────────────────────────────────────
Lihat file credentials_${CLIENT_ID}.txt untuk info support

═══════════════════════════════════════════════════════
Package created: $TIMESTAMP
═══════════════════════════════════════════════════════
EOF

# Create ZIP archive
echo "📦 Creating ZIP archive..."
cd client_packages
zip -r "${CLIENT_ID}_delivery_${TIMESTAMP}.zip" "${CLIENT_ID}/"
cd ..

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                 ✅ PACKAGE COMPLETE!                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Package Location:"
echo "   $PACKAGE_DIR/"
echo ""
echo "📦 ZIP Archive:"
echo "   client_packages/${CLIENT_ID}_delivery_${TIMESTAMP}.zip"
echo ""
echo "📋 Package Contents:"
ls -lh "$PACKAGE_DIR/"
echo ""
echo "🚀 Ready for delivery!"
echo ""
echo "Next Steps:"
echo "1. Send ZIP file to client"
echo "2. Schedule training session"
echo "3. Follow up after 1 week"
