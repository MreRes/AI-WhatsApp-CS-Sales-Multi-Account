# Hermes Portable — 9router Auto-Update, Model Selection & Always-On Gateway

This covers the three things you asked for.

---

## 1. 9router selalu versi terbaru (auto-update)

9router sekarang dipasang sebagai **paket npm resmi** (`9router`), bukan build dari
source. Keuntungan:

- **Prebuilt** — install ~15 detik (bukan build bermenit-menit + error tailwind).
- **Auto-update** — `START.bat` menjalankan `npm install 9router@latest` setiap boot
  (best-effort, non-blocking). Kalau offline, pakai versi yang sudah ada.
- 9router juga punya self-update check internal (kita tidak pakai `--skip-update`).

Lokasi: `runtime/9router-app/node_modules/9router/`
Update manual kapan saja:
```
runtime\node\npm.cmd install 9router@latest --prefix runtime\9router-app
```

---

## 2. Cara pilih model Hermes

Ada **2 cara**:

### A. Lewat Dashboard (paling mudah)
1. Jalankan `START.bat`
2. Buka **http://localhost:9119** (Hermes dashboard)
3. Buka tab **Config / Model**
4. Pilih model dari provider **9router**

### B. Lewat config.yaml (manual)
Edit `data/config.yaml`, ubah baris `model:`:
```yaml
# Format: "<provider-key>:<model-id>"
model: "9router:gpt-4o-mini"      # ganti gpt-4o-mini ke model apa pun

providers:
  9router:
    base_url: "http://localhost:20128/v1"   # LLM gateway lokal
    api_key: "sk-..."                         # API key dari 9router
    default_model: "gpt-4o-mini"
```

> Model yang tersedia tergantung provider yang kamu aktifkan **di dashboard 9router**
> (http://localhost:20128 → Providers → tambah OpenRouter/Anthropic/Google + API key).
> Lalu pakai id model itu di `model:` (mis. `9router:anthropic/claude-3.5-sonnet`).

Cek model aktif kapan saja:
```
data\.venv\Scripts\hermes.exe status
```

---

## 3. Hermes selalu menjalankan gateway messenger

`START.bat` sekarang menjalankan **3 proses**:

| Proses | Port | Fungsi |
|--------|------|--------|
| 9router | 20128 | LLM API gateway |
| Hermes **dashboard** | 9119 | Frontend + API + pilih model |
| Hermes **gateway** | — | Bot messenger (Telegram/Discord/dll) — **selalu jalan** |

Gateway (`hermes gateway run`) hidup selama bundle nyala. Kalau Telegram belum
dikonfigurasi, ia idle (tidak error). Begitu token Telegram diisi, bot langsung aktif.

### Konfigurasi Telegram
Isi di `data/.env`:
```
HERMES_TELEGRAM_TOKEN=123456:ABC...     # dari @BotFather
HERMES_TELEGRAM_CHAT_ID=123456789       # dari @userinfobot
```
Atau lewat dashboard 9119 → Gateway. Lalu restart (`STOP.bat` → `START.bat`).

Log gateway: `data/logs/gateway.log`

---

## Menerapkan perubahan

Karena bundle kamu sudah ter-update:
```
STOP.bat
START.bat
```

Untuk mesin baru / install ulang bersih: `INSTALL.bat` (sekarang pasang 9router npm
otomatis, tanpa build).

---

## Ringkasan port & URL
```
9router  (LLM gateway) : http://localhost:20128   → setup providers + API key
Hermes   (dashboard)   : http://localhost:9119    → pilih model, lihat status
Gateway  (messenger)   : background                → Telegram/Discord bot
+ Cloudflare tunnel     : 2 public URL otomatis saat START
```
