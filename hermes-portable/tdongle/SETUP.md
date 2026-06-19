# T-Dongle-S3 Auto-Trigger — Setup Guide

Buat Hermes Portable **start otomatis saat T-Dongle dicolok** ke laptop — tanpa
klik START manual. T-Dongle = *injector* (pemicu), bukan tempat Hermes berjalan.
Hermes tetap jalan di laptop.

> Hardware: **LilyGO T-Dongle-S3** (ESP32-S3, USB-A, ada LCD 0.96" + slot TF).
> Belum punya? Siapkan dulu file di folder ini, flash saat dongle datang.

---

## Dua mode pemicu — pilih salah satu

| Mode | Cara kerja | Setup PC | Keamanan |
|------|-----------|----------|----------|
| **A. HID Keyboard** (firmware) | Dongle "mengetik" perintah buka START.bat | Tidak perlu apa-apa | Sedang — mengetik ke PC mana pun yang dicolok |
| **B. Presence Watcher** | Watcher di PC deteksi VID/PID dongle → jalankan START | Install watcher 1x | Lebih aman — tak ada keystroke; hanya PC ber-watcher yang bereaksi |

**Rekomendasi:** Mode A untuk laptop pribadi (paling simpel). Mode B untuk
mesin yang dipakai bersama / lebih sensitif.

---

## Mode A — HID Keyboard Firmware

### 1. Flash firmware
**Arduino IDE:**
1. Install board "esp32" (Espressif) ≥ 2.0.14 via Boards Manager
2. Buka `firmware/tdongle_hermes/tdongle_hermes.ino`
3. Tools → Board: **ESP32S3 Dev Module**
4. Tools → **USB CDC On Boot: Disabled**, **USB Mode: USB-OTG (TinyUSB)**
5. Colok T-Dongle (mode download: tahan tombol BOOT saat colok bila perlu)
6. Upload

**PlatformIO** (alternatif):
```
cd firmware/tdongle_hermes
pio run -t upload
```

### 2. Konfigurasi (opsional, di dalam .ino)
- `TRIGGER_MODE` = `MODE_LAUNCH_CMD` (default) — ketik perintah penuh
- `BOOT_DELAY_MS` (default 4000) — naikkan bila trigger terlalu cepat (desktop belum siap)
- Folder bundle default `hermes-portable`. Kalau kamu rename, edit `LAUNCH_PS`.

### 3. Pakai
Colok dongle → tunggu ~4 detik → muncul Run dialog → perintah PowerShell
men-scan semua drive untuk `hermes-portable\START.bat` → jalan. Selesai.

> Catatan: perintah pakai **layout keyboard US**. Kalau layout PC kamu beda dan
> ada karakter salah ketik, pakai Mode B (watcher) yang tidak bergantung ketik.

---

## Mode B — Presence Watcher (lebih aman)

Watcher PowerShell memantau USB. Saat VID/PID T-Dongle muncul → jalankan START.bat.
Dongle cukup hadir secara fisik (firmware HID boleh ada/tidak).

### 1. Cari VID/PID dongle (sekali, saat dongle tercolok)
```powershell
Get-CimInstance Win32_PnPEntity | Where-Object PNPDeviceID -like 'USB*' |
  Select-Object Name, PNPDeviceID | Format-List
```
Cari baris ESP32-S3 — formatnya `USB\VID_303A&PID_xxxx`. Default ESP32-S3
VID = **303A** (Espressif). Catat PID-nya untuk lebih spesifik.

### 2. Install watcher (jalan otomatis tiap logon)
```powershell
cd tdongle\watcher
powershell -NoProfile -ExecutionPolicy Bypass -File install_watcher.ps1
# jalankan sekarang tanpa logout:
schtasks /Run /TN HermesTDongleWatcher
```

Uji manual dulu (opsional):
```powershell
powershell -File tdongle_watcher.ps1 -Vid 303A -Pid <PID-kamu>
```

### 3. Hapus watcher
```powershell
powershell -File install_watcher.ps1 -Uninstall
```

### Parameter watcher
| Param | Default | |
|-------|---------|--|
| `-Vid` | 303A | Vendor ID hex |
| `-Pid` | (kosong) | Product ID hex; kosong = cocokkan semua PID di VID itu |
| `-PollSeconds` | 3 | interval polling |
| `-StartBat` | auto | path START.bat (auto: relatif ke bundle / scan drive) |

Watcher **debounce**: hanya jalan sekali per colok (tidak re-launch selama tetap tertancap).

---

## Keamanan
- USB auto-trigger itu kuat. **Jaga dongle secara fisik.**
- Mode A mengetik perintah ke PC mana pun → jangan colok ke mesin asing.
- Mode B hanya bereaksi di PC yang menjalankan watcher → lebih aman untuk shared PC.
- Watcher pakai hak terbatas (RL LIMITED), bukan admin.

---

## Troubleshooting
| Gejala | Solusi |
|--------|--------|
| Trigger terlalu cepat (Run dialog kosong) | Naikkan `BOOT_DELAY_MS` (mis. 6000) |
| Karakter salah ketik (Mode A) | Layout non-US → pakai Mode B |
| Upload gagal | Tahan tombol BOOT saat colok untuk masuk mode download |
| Watcher tak jalan | Cek `schtasks /Query /TN HermesTDongleWatcher`; jalankan manual untuk lihat error |
| START.bat tak ketemu | Pastikan bundle bernama `hermes-portable`, atau pakai `-StartBat <path>` |

---

## File di folder ini
```
tdongle/
├── SETUP.md                              # panduan ini
├── firmware/tdongle_hermes/
│   ├── tdongle_hermes.ino                # firmware HID keyboard (Mode A)
│   └── platformio.ini                    # build PlatformIO (alternatif Arduino IDE)
└── watcher/
    ├── tdongle_watcher.ps1               # watcher VID/PID (Mode B)
    └── install_watcher.ps1               # daftarkan watcher sbg scheduled task
```
