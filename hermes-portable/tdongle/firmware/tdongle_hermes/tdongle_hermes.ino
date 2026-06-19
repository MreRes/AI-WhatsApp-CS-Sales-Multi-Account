/*
 * Hermes Portable — T-Dongle-S3 Auto-Trigger Firmware
 * ====================================================
 * Target board : LilyGO T-Dongle-S3 (ESP32-S3, native USB OTG)
 * Role         : USB HID keyboard "injector". When the dongle is plugged into
 *                the PC it auto-types a command that launches START.bat, so the
 *                Hermes Portable bundle starts WITHOUT a manual click.
 *
 * It does NOT run Hermes itself — Hermes runs on the laptop. The dongle is only
 * the trigger (an auto-typing keyboard), exactly as requested.
 *
 * TWO TRIGGER MODES (pick with TRIGGER_MODE below):
 *   MODE_LAUNCH_CMD  — types a full PowerShell one-liner that scans every drive
 *                      for hermes-portable\START.bat and runs the first hit.
 *                      Self-contained: no PC-side setup needed.
 *   MODE_SECRET_PHRASE — types only a short secret token. A tiny watcher running
 *                      on the PC (see tdongle/watcher/) detects it and launches
 *                      START. Safer: no command injection if plugged into the
 *                      wrong machine (the watcher must be installed to react).
 *
 * SECURITY: an auto-typing USB keyboard is powerful. Keep this dongle physically
 * controlled. Prefer MODE_SECRET_PHRASE on shared machines.
 *
 * BUILD (Arduino IDE):
 *   - Boards Manager: "esp32" by Espressif (>= 2.0.14)
 *   - Board: "ESP32S3 Dev Module"
 *   - USB CDC On Boot: "Disabled"  (we own the USB as HID)
 *   - USB Mode: "USB-OTG (TinyUSB)"
 *   - Upload, then unplug/replug into the target PC.
 *
 * BUILD (PlatformIO): see platformio.ini in this folder.
 */

#include "USB.h"
#include "USBHIDKeyboard.h"

// ───────────────────────── Configuration ─────────────────────────

// 1 = type full launch command, 2 = type only the secret phrase
#define MODE_LAUNCH_CMD     1
#define MODE_SECRET_PHRASE  2
#define TRIGGER_MODE        MODE_LAUNCH_CMD

// Seconds to wait after plug-in before typing, so the OS finishes enumerating
// the HID device and the desktop has focus. Increase if triggering too early.
#define BOOT_DELAY_MS       4000

// Keystroke pacing (ms). Too fast can drop characters on some hosts.
#define KEY_DELAY_MS        12

// Only fire ONCE per power-up (plug-in). Set false to re-fire every RETRIGGER_MS.
#define FIRE_ONCE           true
#define RETRIGGER_MS        60000

// Secret phrase (MODE_SECRET_PHRASE). MUST match SECRET in tdongle_watcher.ps1.
const char* SECRET_PHRASE = "HERMES-START-7F3A9C";

// Full launch command (MODE_LAUNCH_CMD). Scans all filesystem drives for the
// bundle's START.bat and runs the first match. Edit the folder name if you
// renamed the bundle directory (default: hermes-portable).
const char* LAUNCH_PS =
  "powershell -NoProfile -WindowStyle Hidden -Command "
  "\"$ErrorActionPreference='SilentlyContinue';"
  "Get-PSDrive -PSProvider FileSystem | ForEach-Object {"
  "$p=Join-Path $_.Root 'hermes-portable\\START.bat';"
  "if(Test-Path $p){Start-Process -FilePath $p -WorkingDirectory (Split-Path $p);break}}\"";

// ──────────────────────────────────────────────────────────────────

USBHIDKeyboard Keyboard;

static void typeString(const char* s) {
  for (const char* p = s; *p; ++p) {
    Keyboard.write((uint8_t)*p);
    delay(KEY_DELAY_MS);
  }
}

// Open the Windows Run dialog (Win+R), type a line, press Enter.
static void runViaWinR(const char* line) {
  // Win down, R, Win up
  Keyboard.press(KEY_LEFT_GUI);
  delay(60);
  Keyboard.press('r');
  delay(60);
  Keyboard.releaseAll();
  delay(700);                 // wait for Run dialog to appear
  typeString(line);
  delay(150);
  Keyboard.write(KEY_RETURN);
}

static void fireTrigger() {
#if TRIGGER_MODE == MODE_LAUNCH_CMD
  runViaWinR(LAUNCH_PS);
#else
  // MODE_SECRET_PHRASE: just type the token + Enter into whatever has focus.
  // The PC-side watcher listens globally for this string.
  typeString(SECRET_PHRASE);
  Keyboard.write(KEY_RETURN);
#endif
}

void setup() {
  Keyboard.begin();
  USB.begin();
  delay(BOOT_DELAY_MS);       // let the host enumerate the HID device
  fireTrigger();
}

void loop() {
#if FIRE_ONCE
  // Idle forever; trigger already fired once on power-up.
  delay(1000);
#else
  delay(RETRIGGER_MS);
  fireTrigger();
#endif
}
