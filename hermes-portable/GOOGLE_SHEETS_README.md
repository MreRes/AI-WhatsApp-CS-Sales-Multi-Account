# Google Sheets Integration untuk Hermes Agent

Dokumentasi lengkap untuk mengintegrasikan Google Sheets dengan Hermes AI Agent menggunakan API key.

## 📋 Ringkasan Implementasi

Saya sudah membuat:

### 1. **MCP Tool** (`google_sheets_mcp.py`)
   - Pure Python implementation menggunakan `httpx` library
   - Support untuk read-only operations (API key biasa)
   - 4 operasi utama:
     - `read_sheet` — Baca data dari range tertentu
     - `get_metadata` — Ambil info spreadsheet
     - `query_sheet` — Search data dalam sheet
     - `get_json` — Convert sheet data ke JSON objects

### 2. **Skill Documentation** (`GOOGLE_SHEETS_SKILL.md`)
   - Panduan lengkap untuk user
   - Setup instructions
   - Contoh penggunaan
   - Troubleshooting guide

### 3. **Configuration Files**
   - `google_sheets_mcp.json` — MCP tool registry
   - `google_sheets_integration.py` — Integration hook

### 4. **Setup Scripts**
   - `setup-google-sheets.bat` — Setup untuk Windows
   - `setup-google-sheets.sh` — Setup untuk Linux/macOS

## 🚀 Quick Start

### Step 1: Dapatkan API Key

1. Buka [Google Cloud Console](https://console.cloud.google.com)
2. Buat project baru atau pilih existing
3. Enable "Google Sheets API"
4. Buat "API Key" di Credentials
5. Copy API key

### Step 2: Setup di Hermes

**Windows:**
```bash
setup-google-sheets.bat
```

**Linux/macOS:**
```bash
chmod +x setup-google-sheets.sh
./setup-google-sheets.sh
```

Atau manual:
```bash
# Edit data/.env
echo "GOOGLE_SHEETS_API_KEY=YOUR_KEY_HERE" >> data/.env
```

### Step 3: Restart Hermes

```bash
# Stop
STOP.bat  (atau stop.sh)

# Start
START.bat (atau start.sh)
```

### Step 4: Use Hermes

```
User: "Baca data dari Google Sheet 1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY range Sheet1!A1:D10"

Hermes: ✅ Berhasil baca 25 rows
        - Row 1: [Name, Email, Phone]
        - Row 2: [John Doe, john@example.com, 0812xxx]
        ...
```

## 📊 Operasi yang Tersedia

### read_sheet
Membaca data dari range tertentu di sheet

```python
await read_sheet(
    api_key="YOUR_KEY",
    spreadsheet_id="1BxiMV...",
    range_name="Sheet1!A1:D10"  # optional, default Sheet1!A1:Z1000
)

# Return:
{
    "success": true,
    "data": [["Name", "Email"], ["John", "john@example.com"], ...],
    "range": "Sheet1!A1:D10",
    "message": "✅ Berhasil baca 25 rows"
}
```

### get_metadata
Mengambil informasi tentang spreadsheet

```python
await get_metadata(
    api_key="YOUR_KEY",
    spreadsheet_id="1BxiMV..."
)

# Return:
{
    "success": true,
    "title": "My Spreadsheet",
    "sheets": ["Sheet1", "Sheet2", "Sheet3"],
    "spreadsheet_id": "1BxiMV...",
    "message": "✅ Metadata berhasil diambil (3 sheets)"
}
```

### query_sheet
Search/filter data berdasarkan text

```python
await query_sheet(
    api_key="YOUR_KEY",
    spreadsheet_id="1BxiMV...",
    query="Jakarta",
    range_name="Sheet1!A1:Z1000"  # optional
)

# Return:
{
    "success": true,
    "query": "Jakarta",
    "matched_count": 8,
    "results": [
        {"row_number": 5, "data": ["John", "john@example.com", "Jakarta"]},
        {"row_number": 12, "data": ["Jane", "jane@example.com", "Jakarta"]},
        ...
    ],
    "message": "✅ Ditemukan 8 hasil"
}
```

### get_json
Convert sheet data menjadi JSON objects (dengan headers)

```python
await get_json(
    api_key="YOUR_KEY",
    spreadsheet_id="1BxiMV...",
    range_name="Sheet1!A1:D100",
    has_header=true  # optional
)

# Return:
{
    "success": true,
    "headers": ["Name", "Email", "Phone", "City"],
    "data": [
        {"Name": "John", "Email": "john@example.com", "Phone": "0812xxx", "City": "Jakarta"},
        {"Name": "Jane", "Email": "jane@example.com", "Phone": "0813xxx", "City": "Bandung"},
        ...
    ],
    "row_count": 50,
    "message": "✅ Convert to JSON: 50 objects"
}
```

## 🔐 Authentication

### API Key (Read-Only)

```env
GOOGLE_SHEETS_API_KEY=AIzaSyC...
```

✅ **Support:**
- Read data
- Query data
- Get metadata

❌ **Tidak support:**
- Write/update data
- Delete data
- Create sheets

### Service Account (Read-Write)

Untuk write/update operations, upgrade ke Service Account:

1. Buat Service Account di Google Cloud Console
2. Generate JSON key
3. Share spreadsheet dengan service account email
4. Update Hermes config:

```env
GOOGLE_SHEETS_AUTH_TYPE=service_account
GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON=/path/to/key.json
```

(Implementasi Service Account akan ditambahkan di future release)

## 💡 Contoh Use Cases

### 1. Monitoring Database

```
User: "Baca data customer terbaru dari Google Sheet dan berikan statistik"

Hermes akan:
1. Ambil data dari sheet
2. Parse dan analyze
3. Berikan summary (total customer, kota terbanyak, dll)
```

### 2. Data Validation

```
User: "Cek apakah ada duplicate email di sheet customers"

Hermes akan:
1. Read semua data
2. Check untuk duplicates
3. Report hasil
```

### 3. Data Export

```
User: "Ambil semua order dari Jakarta dan convert ke JSON format"

Hermes akan:
1. Query data dengan filter "Jakarta"
2. Convert ke JSON
3. Return structured data untuk processing lebih lanjut
```

### 4. Integration dengan Tools Lain

```
User: "Baca contact list dari Google Sheet dan import ke Telegram contacts"

Hermes akan:
1. Read data dari sheet
2. Convert ke JSON
3. Integrate dengan Telegram MCP tool
4. Auto-import contacts
```

## 📁 File Structure

```
hermes-portable/
├── embedded-mcps/
│   ├── google_sheets_mcp.py              ← Core MCP implementation
│   ├── google_sheets_mcp.json            ← MCP configuration
│   ├── google_sheets_integration.py      ← Integration hook
│   └── GOOGLE_SHEETS_SKILL.md            ← User documentation
├── setup-google-sheets.bat               ← Windows setup
├── setup-google-sheets.sh                ← Linux/macOS setup
├── data/
│   └── .env                              ← API key storage
└── README.md                             ← This file
```

## 🧪 Testing

### Test Read Operation

```bash
python3 << 'EOF'
import asyncio
from embedded_mcps.google_sheets_mcp import GoogleSheetsMCP

async def test():
    mcp = GoogleSheetsMCP("YOUR_API_KEY")
    
    # Test metadata
    result = await mcp.get_spreadsheet_metadata("1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY")
    print(result)
    
    await mcp.close()

asyncio.run(test())
EOF
```

### Test Query

```bash
python3 << 'EOF'
import asyncio
import os
from embedded_mcps.google_sheets_mcp import GoogleSheetsMCP

async def test():
    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    mcp = GoogleSheetsMCP(api_key)
    
    # Test query
    result = await mcp.query_sheet(
        "YOUR_SPREADSHEET_ID",
        "search_term",
        "Sheet1!A1:Z100"
    )
    print(result)
    
    await mcp.close()

asyncio.run(test())
EOF
```

## 🔧 Advanced: Custom Integration

### Add Custom Tool

Buat file baru `my_sheets_tool.py`:

```python
from embedded_mcps.google_sheets_mcp import GoogleSheetsMCP

async def my_custom_operation(api_key, spreadsheet_id):
    mcp = GoogleSheetsMCP(api_key)
    
    # Ambil data
    data = await mcp.read_sheet(spreadsheet_id, "Sheet1!A1:D100")
    
    # Custom processing
    processed = process_data(data["data"])
    
    await mcp.close()
    return processed

def process_data(data):
    # Your custom logic here
    pass
```

Kemudian register ke Hermes dalam `config.yaml`:

```yaml
tools:
  custom_sheets:
    module: my_sheets_tool
    function: my_custom_operation
    description: Custom Google Sheets operation
```

## ⚠️ Limitations

### API Key Biasa
- ✅ Read data
- ✅ Query data
- ✅ Get metadata
- ❌ Write data
- ❌ Delete data
- ❌ Create sheets
- ❌ Modify formatting

### Rate Limits
- Google Sheets API memiliki rate limits
- Free tier: ~100 requests per user per 100 seconds
- Untuk production: Consider upgrade ke billing

### Sheet Size
- Default range: `Sheet1!A1:Z1000` (1000 rows, 26 columns)
- Bisa customize range sesuai kebutuhan
- Large sheets (~100k rows) mungkin lambat

## 🐛 Troubleshooting

| Masalah | Solusi |
|---------|--------|
| "API key not found" | Pastikan `GOOGLE_SHEETS_API_KEY` di `.env` |
| "Invalid spreadsheet ID" | Copy ID dari URL: `docs.google.com/spreadsheets/d/{ID}` |
| "Permission denied" | Pastikan spreadsheet tidak private (atau share dengan akun) |
| "Invalid range" | Format: `Sheet1!A1:D10` atau `"Sheet Name"!A1:D10` |
| "Timeout" | Check internet connection atau range terlalu besar |

## 📚 Dokumentasi Terkait

- `GOOGLE_SHEETS_SKILL.md` — User-facing documentation
- [Google Sheets API Docs](https://developers.google.com/sheets/api)
- [Google Cloud Console](https://console.cloud.google.com)

## 🎯 Next Steps

- [ ] Setup API key
- [ ] Jalankan `setup-google-sheets.bat/sh`
- [ ] Test dengan `read_sheet` operation
- [ ] Integrate ke Hermes workflows
- [ ] (Optional) Upgrade ke Service Account untuk write operations

## 📞 Support

Jika ada masalah:
1. Cek `data/logs/` untuk error messages
2. Baca troubleshooting section di atas
3. Check Google Sheets API documentation
4. Cek forum/issue tracker Hermes

---

**Created:** June 2026
**Version:** 1.0.0
**Status:** Ready for Production (read-only)
