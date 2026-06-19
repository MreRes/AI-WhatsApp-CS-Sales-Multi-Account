# Hermes Portable — Phase 2 Plan

**Status Fase 1 (MVP): ✅ SELESAI**
- 9router npm (auto-update), Hermes dashboard + gateway, Cloudflare tunnel,
  3 MCP (Windows/macOS/Android), config + pilih model, .env tiga-tier.

Fase 2 = membuat bundle **benar-benar plug-and-play & lebih kaya fitur**.
Diurutkan berdasarkan dampak vs usaha.

---

## 🥇 Prioritas 1 — T-Dongle S3 Auto-Trigger (fitur utama yang kamu minta)

**Tujuan:** colok T-Dongle → bundle START otomatis, tanpa klik manual.
T-Dongle = *injector* (USB keyboard emulator), bukan executor.

### Tahap
1. **Firmware T-Dongle (ESP32-S3)**
   - Emulasi USB HID keyboard
   - Saat colok: ketik perintah buka `START.bat` (mis. `Win+R` → path → Enter)
   - Atau ketik token rahasia yang dipantau script di PC
2. **Sisi PC (Windows)**
   - Opsi A: AutoRun/Scheduled Task mendeteksi VID/PID T-Dongle → jalankan START
   - Opsi B: watcher kecil yang nyala saat login, mendeteksi device USB
3. **Linux/macOS**
   - udev rule (Linux) / `IOKit` watcher (macOS) deteksi VID/PID → START

**Deliverable:** `tdongle/firmware.ino`, `tdongle/SETUP.md`, watcher script.
**Estimasi:** sedang–besar (perlu hardware T-Dongle untuk uji).
**Risiko:** butuh device fisik; keamanan auto-run (mitigasi: token + konfirmasi).

---

## 🥈 Prioritas 2 — File Transfer ke Messaging

**Tujuan:** kirim/terima file lewat Telegram/Discord/WhatsApp/Slack dari agent.

### Tahap
- Tool baru di Hermes: `send_file(platform, chat_id, path)`
- Terima file masuk → simpan ke `data/inbox/`
- Integrasi dengan gateway yang sudah jalan (Fase 1)

**Deliverable:** plugin/tool `file_transfer`.
**Estimasi:** sedang. **Manfaat:** tinggi (remote file ops).

---

## 🥉 Prioritas 3 — Screenshot Capture & Upload

**Tujuan:** "screenshot layar dan kirim ke Telegram".

### Tahap
- Windows-MCP sudah punya `dxcam`/capture → expose sebagai tool
- Pipeline: capture → simpan `data/screenshots/` → upload via file-transfer (P2)
- Trigger lewat chat: "screenshot sekarang"

**Estimasi:** kecil–sedang (capture sudah ada, tinggal wiring).
**Dependensi:** Prioritas 2 (upload).

---

## 🏅 Prioritas 4 — Multi-Platform Validasi Nyata

Fase 1 OS-aware tapi baru diuji di Windows. Fase 2:
- Uji `install.sh` + `start.sh` nyata di **Linux** (Ubuntu)
- Uji di **macOS** (arm64) + macOS-MCP (pyobjc)
- Uji **Android-MCP** dengan device terhubung (ADB)

**Estimasi:** sedang (butuh akses tiap OS). **Manfaat:** klaim "cross-platform" jadi nyata.

---

## 🎖️ Prioritas 5 — Setup Messaging Multi-Platform

Saat ini Telegram saja yang mulus. Lengkapi wizard:
- WhatsApp (Twilio), Discord, Slack — sudah ada di `.env` tier-2, tinggal uji & dokumen
- `config-setup.ps1`/`.sh` sudah ada menu-nya → validasi end-to-end

**Estimasi:** kecil–sedang.

---

## 🔮 Prioritas 6 — Fitur Lanjutan (low priority)

| Fitur | Catatan |
|-------|---------|
| Camera stream | webcam → snapshot/stream ke chat |
| Microphone record | rekam audio → kirim |
| Docker variant | container untuk server deployment |
| ngrok alternatif | selain Cloudflare |
| Single .exe (Nuitka) | launcher satu file |
| Auto-cleanup vendored | hapus `services/9router` lama (sudah tak terpakai) |

---

## Urutan Eksekusi yang Disarankan

```
1. (cepat) Auto-cleanup services/9router lama + smoke test START.bat penuh
2. P2 File transfer  ──┐
3. P3 Screenshot    ───┴─→ paket "remote control" (saling tergantung)
4. P1 T-Dongle (saat hardware siap)
5. P4 Validasi Linux/macOS/Android
6. P5 Messaging multi-platform
7. P6 sesuai kebutuhan
```

---

## Pertanyaan untuk kamu (biar saya fokus)
1. **T-Dongle**: hardware-nya sudah ada di tangan? (menentukan kapan P1 bisa diuji)
2. **Target OS utama**: Windows saja dulu, atau perlu Linux/macOS juga sekarang?
3. **Fitur mana yang paling kamu butuhkan duluan**: file-transfer, screenshot, atau T-Dongle?
