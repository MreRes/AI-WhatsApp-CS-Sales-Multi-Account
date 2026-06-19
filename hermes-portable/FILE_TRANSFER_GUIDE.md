# Hermes Portable — File Transfer, Screenshot, Camera & Mic

Ternyata Hermes **sudah punya** semua tool ini built-in (toolset `portable`).
Fase 2 hanya perlu MENGAKTIFKAN-nya di config — sudah dilakukan.

## Yang sekarang aktif

| Kemampuan | Tool | Catatan |
|-----------|------|---------|
| Kirim **file apa pun** dari laptop ke messenger | `send_file` | Auto-route: video→video, gambar→photo, lainnya→document |
| Screenshot layar | Windows-MCP `Screenshot` | Capture → kirim via `send_file` |
| Rekam **kamera** | `capture_webcam` | Foto/klip webcam → kirim |
| Rekam **mikrofon** | `record_audio` | Audio → kirim |
| Clipboard | `clipboard_get/set` | Baca/tulis clipboard |

Batas ukuran file: **50MB** (limit Telegram).
Jenis file yang auto jadi video: `.mp4 .mov .avi .mkv .3gp` — sisanya dikirim sebagai dokumen (PDF, ZIP, docx, dll).

## Cara pakai (lewat chat Telegram)

Setelah Telegram dikonfigurasi, cukup perintah natural ke bot:
- "Kirim file C:\Users\USER\Documents\laporan.pdf ke sini"
- "Screenshot layar sekarang dan kirim"
- "Ambil foto dari webcam"
- "Rekam audio 10 detik lalu kirim"
- "Ambil video terbaru di folder Videos dan kirim"

Agent akan memanggil `send_file` / Screenshot / capture_webcam otomatis.

## Keamanan file (allow-dirs)

Agent boleh mengambil file dari folder di `gateway.media_delivery_allow_dirs`
(default: folder user `C:\Users\USER`). Plus `trust_recent_files: true` →
file yang baru dibuat (≤5 menit: screenshot, export, download) langsung bisa dikirim.

**Tetap diblokir** (keamanan): `~/.ssh`, `~/.aws`, `C:\Windows`, path sistem.

Tambah drive/folder lain di `data/config.yaml`:
```yaml
gateway:
  media_delivery_allow_dirs:
    - 'C:\Users\USER'
    - 'D:\'
    - 'E:\Projects'
```

## Live stream saat eksekusi MCP — Screen Monitor (SUDAH DIBANGUN ✅)

Tool baru **`screen_monitor`** (toolset `portable`) memberi efek "live-ish":
menangkap layar tiap N detik dan mengirim tiap frame sebagai foto ke chat,
**sambil agent tetap menjalankan aksi Windows-MCP** (jalan di background thread).

### Cara pakai (via chat)
- "Pantau layar saya sambil kamu kerjakan ini" → agent panggil `screen_monitor(action=start)`
- Agent lakukan aksi MCP (klik/ketik/buka app) — frame layar streaming ke chat
- Selesai → agent panggil `screen_monitor(action=stop)`

### Parameter
| Param | Default | Maks | Fungsi |
|-------|---------|------|--------|
| `action` | start | — | start / stop / status |
| `interval_seconds` | 3 | min 1 | jeda antar frame |
| `duration_seconds` | 60 | 600 | auto-stop setelah sekian detik |
| `max_frames` | 40 | — | auto-stop setelah sekian frame |

Frame: JPEG quality 70 (kecil, upload cepat), disimpan sementara di
`HERMES_HOME/cache/screenshots` lalu dihapus setelah terkirim.
Capture: Pillow `ImageGrab` (utama) → `dxcam` (fallback). Keduanya sudah
terpasang lewat extra `portable-windows`.

> Catatan: Telegram bot tidak punya video live murni, jadi ini stream-frame.
> Untuk pengalaman streaming penuh di browser (feed real-time via tunnel),
> bisa dibangun di Fase 2b sebagai opsi lanjutan.
