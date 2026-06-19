#!/bin/bash

# Google Sheets Integration Setup untuk Hermes
# Script untuk setup Google Sheets API key di Hermes

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Google Sheets Integration Setup untuk Hermes               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if data/.env exists
if [ ! -f "data/.env" ]; then
    echo "❌ Error: data/.env tidak ditemukan"
    echo "   Jalankan INSTALL.bat atau install.sh terlebih dahulu"
    exit 1
fi

echo "📝 Setup Google Sheets API Key"
echo ""
echo "Anda perlu Google Sheets API key. Jika belum punya:"
echo "  1. Buka: https://console.cloud.google.com"
echo "  2. Buat/pilih project"
echo "  3. Enable 'Google Sheets API'"
echo "  4. Buat 'API Key' di Credentials section"
echo "  5. Copy API key"
echo ""

read -p "🔑 Masukkan Google Sheets API Key Anda: " api_key

if [ -z "$api_key" ]; then
    echo "❌ API key tidak boleh kosong"
    exit 1
fi

# Remove existing key if any
if grep -q "GOOGLE_SHEETS_API_KEY" data/.env; then
    echo "🔄 Updating existing API key..."
    sed -i "s/GOOGLE_SHEETS_API_KEY=.*/GOOGLE_SHEETS_API_KEY=$api_key/" data/.env
else
    echo "➕ Adding API key to data/.env..."
    echo "" >> data/.env
    echo "# Google Sheets Integration" >> data/.env
    echo "GOOGLE_SHEETS_API_KEY=$api_key" >> data/.env
fi

echo "✅ API key saved to data/.env"
echo ""

# Test the API key
echo "🧪 Testing API key..."
python3 << 'PYTEST'
import os
import httpx
import asyncio

async def test_key():
    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ API key not found in environment")
        return False

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Try to get a public spreadsheet (Google's own test spreadsheet)
            url = "https://sheets.googleapis.com/v4/spreadsheets/1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY"
            response = await client.get(url, params={"key": api_key})

            if response.status_code == 200:
                print("✅ API key is valid!")
                data = response.json()
                print(f"   Spreadsheet: {data['properties']['title']}")
                return True
            elif response.status_code == 403:
                print("⚠️  API key exists but Google Sheets API might not be enabled")
                print("   Enable it at: https://console.cloud.google.com/apis/library/sheets.googleapis.com")
                return False
            else:
                print(f"❌ API Error: {response.status_code}")
                print(f"   Response: {response.text}")
                return False
    except Exception as e:
        print(f"❌ Error testing API key: {e}")
        return False

result = asyncio.run(test_key())
exit(0 if result else 1)
PYTEST

if [ $? -eq 0 ]; then
    echo "✅ Google Sheets integration is ready!"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Restart Hermes (STOP.bat/sh then START.bat/sh)"
    echo "  2. Ask Hermes to access Google Sheets:"
    echo "     'Baca data dari Google Sheet [ID] range Sheet1!A1:D10'"
    echo ""
else
    echo "⚠️  API key test failed. Check your key and Google Sheets API settings"
    echo ""
fi

echo "📚 Dokumentasi lengkap: embedded-mcps/GOOGLE_SHEETS_SKILL.md"
