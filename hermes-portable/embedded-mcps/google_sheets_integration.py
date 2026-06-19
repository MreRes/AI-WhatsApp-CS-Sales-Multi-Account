"""
Hermes Google Sheets Integration Hook
Memungkinkan Hermes agent untuk mengakses Google Sheets melalui MCP tools
"""

import os
import sys
import json
from pathlib import Path

def register_google_sheets_tools():
    """
    Register Google Sheets MCP tools ke Hermes agent
    Dipanggil saat Hermes startup
    """

    # Get API key dari environment
    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')

    if not api_key:
        print("⚠️  Warning: GOOGLE_SHEETS_API_KEY tidak di-set. Google Sheets tools tidak tersedia.")
        print("   Set environment variable atau tambahkan ke data/.env")
        return False

    # Import MCP module
    try:
        from embedded_mcps.google_sheets_mcp import GoogleSheetsMCP
        print("✅ Google Sheets MCP tools loaded successfully")
        return True
    except ImportError as e:
        print(f"❌ Failed to import Google Sheets MCP: {e}")
        return False

def setup_google_sheets_config():
    """
    Setup configuration untuk Google Sheets integration
    """

    config_path = Path(__file__).parent / "data" / "config.yaml"

    # Read existing config
    try:
        import yaml
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f) or {}
    except Exception as e:
        print(f"Warning: Could not read config: {e}")
        config = {}

    # Add Google Sheets config if not exists
    if 'integrations' not in config:
        config['integrations'] = {}

    if 'google_sheets' not in config['integrations']:
        config['integrations']['google_sheets'] = {
            'enabled': True,
            'api_key_env': 'GOOGLE_SHEETS_API_KEY',
            'description': 'Google Sheets API integration'
        }

        # Write back config
        try:
            import yaml
            with open(config_path, 'w') as f:
                yaml.dump(config, f)
            print("✅ Google Sheets config added to config.yaml")
        except Exception as e:
            print(f"Warning: Could not write config: {e}")

    return config

def print_setup_instructions():
    """
    Print setup instructions untuk user
    """

    instructions = """
╔════════════════════════════════════════════════════════════════╗
║          Google Sheets Integration untuk Hermes               ║
╚════════════════════════════════════════════════════════════════╝

✅ TERSEDIA TOOLS:
   • read_sheet      - Baca data dari Google Sheet
   • get_metadata    - Ambil info spreadsheet
   • query_sheet     - Search data dalam sheet
   • get_json        - Convert sheet ke JSON objects

🔑 SETUP:

   1. Dapatkan Google Sheets API Key:
      → https://console.cloud.google.com
      → Enable "Google Sheets API"
      → Create "API Key" di Credentials

   2. Set environment variable:
      → Edit data/.env
      → Tambahkan: GOOGLE_SHEETS_API_KEY=YOUR_KEY_HERE

   3. Restart Hermes
      → STOP.bat (atau stop.sh)
      → START.bat (atau start.sh)

📝 CONTOH PENGGUNAAN:

   Baca data dari Google Sheet:
   "Baca data dari spreadsheet 1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY
    range Sheet1!A1:D10"

   Search data:
   "Cari semua yang mengandung 'Jakarta' di spreadsheet tersebut"

   Convert ke JSON:
   "Ambil data Sheet1!A1:E100 dan berikan sebagai JSON objects"

⚠️  LIMITASI:
   • API key biasa hanya bisa READ
   • Untuk WRITE/UPDATE: Upgrade ke Service Account
   • Lihat GOOGLE_SHEETS_SKILL.md untuk detail lengkap

📚 DOKUMENTASI:
   → Baca: embedded-mcps/GOOGLE_SHEETS_SKILL.md
   → Config: embedded-mcps/google_sheets_mcp.json

═══════════════════════════════════════════════════════════════════
"""

    print(instructions)

if __name__ == "__main__":
    print("Initializing Google Sheets Integration...\n")

    # Setup config
    setup_google_sheets_config()

    # Register tools
    register_google_sheets_tools()

    # Print instructions
    print_setup_instructions()

    print("\n✅ Google Sheets integration ready!")
    print("   Mulai Hermes untuk menggunakan Google Sheets tools")
