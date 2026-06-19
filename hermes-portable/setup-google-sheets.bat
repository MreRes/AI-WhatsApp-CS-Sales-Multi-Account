@echo off
REM Google Sheets Integration Setup untuk Hermes (Windows)

cls
echo.
echo ==================================================================
echo.     Google Sheets Integration Setup untuk Hermes
echo.
echo ==================================================================
echo.

REM Check if data\.env exists
if not exist "data\.env" (
    echo Error: data\.env tidak ditemukan
    echo Jalankan INSTALL.bat terlebih dahulu
    pause
    exit /b 1
)

echo Panduan Setup Google Sheets API Key:
echo.
echo 1. Buka: https://console.cloud.google.com
echo 2. Buat atau pilih project Anda
echo 3. Enable 'Google Sheets API':
echo    - Search 'Google Sheets API'
echo    - Click 'Enable'
echo 4. Buat API Key:
echo    - Go to 'Credentials'
echo    - Click 'Create Credentials' ^> 'API Key'
echo    - Copy API key yang di-generate
echo.
set /p api_key="Masukkan Google Sheets API Key Anda: "

if "%api_key%"=="" (
    echo Error: API key tidak boleh kosong
    pause
    exit /b 1
)

REM Check if API key already exists
findstr /M "GOOGLE_SHEETS_API_KEY" data\.env >nul 2>&1
if errorlevel 1 (
    REM Add new key
    echo.
    echo Adding Google Sheets API key to data\.env...
    echo. >> data\.env
    echo # Google Sheets Integration >> data\.env
    echo GOOGLE_SHEETS_API_KEY=%api_key% >> data\.env
) else (
    REM Update existing key using PowerShell (more reliable than batch)
    echo.
    echo Updating existing Google Sheets API key...
    powershell -Command "(Get-Content data\.env) -replace 'GOOGLE_SHEETS_API_KEY=.*', 'GOOGLE_SHEETS_API_KEY=%api_key%' | Set-Content data\.env"
)

echo.
echo ✓ API key saved to data\.env
echo.
echo Testing API key...
echo.

REM Test the API key using Python
python3 << 'PYTEST'
import os
import httpx
import asyncio

async def test_key():
    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("Error: API key tidak ditemukan dalam environment")
        return False

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            url = "https://sheets.googleapis.com/v4/spreadsheets/1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY"
            response = await client.get(url, params={"key": api_key})

            if response.status_code == 200:
                print("✓ API key valid!")
                data = response.json()
                print(f"  Spreadsheet: {data['properties']['title']}")
                return True
            elif response.status_code == 403:
                print("Warning: API key exists tapi Google Sheets API belum di-enable")
                print("Enable di: https://console.cloud.google.com/apis/library/sheets.googleapis.com")
                return False
            else:
                print(f"Error API: {response.status_code}")
                return False
    except Exception as e:
        print(f"Error testing key: {e}")
        return False

result = asyncio.run(test_key())
exit(0 if result else 1)
PYTEST

if errorlevel 1 (
    echo.
    echo Warning: API key test gagal. Cek API key dan pastikan Google Sheets API enabled
    echo.
) else (
    echo.
    echo ✓ Google Sheets integration siap!
    echo.
    echo Next steps:
    echo  1. Restart Hermes (jalankan STOP.bat kemudian START.bat)
    echo  2. Gunakan perintah Hermes untuk akses Google Sheets:
    echo     "Baca data dari Google Sheet [ID] range Sheet1!A1:D10"
    echo.
)

echo Dokumentasi lengkap: embedded-mcps\GOOGLE_SHEETS_SKILL.md
echo.
pause
