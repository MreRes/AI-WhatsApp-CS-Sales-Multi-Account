# Google Sheets Integration Skill untuk Hermes

Skill ini memungkinkan Hermes Agent untuk membaca dan mengakses data dari Google Sheets menggunakan API key Anda.

## Setup

### 1. Dapatkan Google Sheets API Key

1. Buka [Google Cloud Console](https://console.cloud.google.com)
2. Buat project baru atau gunakan existing project
3. Enable **Google Sheets API**:
   - Search "Google Sheets API"
   - Click "Enable"
4. Buat API Key:
   - Go to **Credentials**
   - Click **Create Credentials** → **API Key**
   - Copy API key yang di-generate

### 2. Setup di Hermes

Simpan API key ke environment variable atau config:

```bash
# Di data/.env atau config.yaml
GOOGLE_SHEETS_API_KEY=YOUR_API_KEY_HERE
```

## Penggunaan

### Baca Data dari Sheet

```
"Baca data dari Google Sheet dengan ID 1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY 
dan range Sheet1!A1:D10"
```

Agent akan:
1. Parse spreadsheet ID dan range
2. Call MCP tool `read_sheet`
3. Return data dalam format readable

### Query/Search Data

```
"Cari semua rows yang mengandung 'Jakarta' di spreadsheet 
1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY"
```

### Convert ke JSON

```
"Ambil data dari Sheet1 range A1:E100 dan convert menjadi JSON objects 
dengan headers dari row pertama"
```

Agent akan return data sebagai array of objects yang bisa diparsing lebih lanjut.

### Ambil Metadata

```
"Berapa banyak sheets di spreadsheet 1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY?"
```

## Operasi yang Tersedia

| Operasi | Deskripsi | Batasan |
|---------|-----------|---------|
| **read_sheet** | Baca data dari range tertentu | API key support |
| **get_metadata** | Ambil info spreadsheet & sheets | API key support |
| **query_sheet** | Search data dalam sheet | API key support |
| **get_json** | Convert sheet data ke JSON objects | API key support |
| **write_sheet** | Tulis/update data | ⚠️ Butuh Service Account atau OAuth2 |

## Limitasi API Key Biasa

API key Google Sheets yang biasa **HANYA** bisa:
- ✅ Read data (GET operations)
- ✅ Query/search data

API key **TIDAK** bisa:
- ❌ Write/update data
- ❌ Delete data
- ❌ Create new sheets

### Upgrade ke Service Account

Jika Anda perlu write operations:

1. Buat Service Account:
   - Google Cloud Console → Service Accounts
   - Create service account
   - Generate JSON key
   - Download file `.json`

2. Share spreadsheet dengan email service account:
   - Get service account email dari file JSON
   - Share spreadsheet dengan email tersebut

3. Update Hermes config:
   ```bash
   GOOGLE_SHEETS_AUTH_TYPE=service_account
   GOOGLE_SHEETS_SERVICE_ACCOUNT_JSON=/path/to/key.json
   ```

## Contoh Penggunaan

### Example 1: Baca Customer Data

```
Hermes: Baca semua customer data dari Google Sheet 
        https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY

Output:
✅ Berhasil baca 25 rows
- Row 1: [Name, Email, Phone, City]
- Row 2: [John Doe, john@example.com, 0812xxx, Jakarta]
- Row 3: [Jane Smith, jane@example.com, 0813xxx, Bandung]
...
```

### Example 2: Search & Convert to JSON

```
Hermes: Cari semua data customer dari Jakarta di spreadsheet tadi 
        dan berikan dalam format JSON

Output:
✅ Ditemukan 8 hasil
[
  {
    "Name": "John Doe",
    "Email": "john@example.com",
    "Phone": "0812xxx",
    "City": "Jakarta"
  },
  {
    "Name": "Ahmad Rizki",
    "Email": "ahmad@example.com",
    "Phone": "0815xxx",
    "City": "Jakarta"
  },
  ...
]
```

### Example 3: Get Spreadsheet Info

```
Hermes: Berapa sheet apa saja yang ada di spreadsheet 
        1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY?

Output:
✅ Metadata berhasil diambil (3 sheets)
- Title: Company Database
- Sheets: [Customers, Products, Transactions]
```

## Troubleshooting

| Error | Solusi |
|-------|--------|
| "API key not found" | Set `GOOGLE_SHEETS_API_KEY` di `.env` atau config |
| "Invalid spreadsheet ID" | Copy ID dari URL: `docs.google.com/spreadsheets/d/{ID}/edit` |
| "Permission denied" | Pastikan spreadsheet bukan private atau share dengan akun tertentu |
| "Range not found" | Check format: `Sheet1!A1:D10` atau `"Sheet Name"!A1:D10` |
| "Write operation failed" | Upgrade ke Service Account authentication |

## Advanced: Custom Range Queries

Anda bisa query dengan format range yang berbeda:

- `Sheet1!A1:D10` — Specific range
- `Sheet1!A:D` — Entire columns A to D
- `Sheet1!A1:Z1000` — Large range (default)
- `"Custom Name"!A1:B50` — Named sheet dengan spasi

## Next Steps

1. ✅ Setup API key
2. ✅ Test read operations
3. 🔄 Untuk write operations: Upgrade ke Service Account
4. 🔗 Integrate dengan Hermes workflows/automations

Enjoy! 🚀
