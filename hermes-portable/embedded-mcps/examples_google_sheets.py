#!/usr/bin/env python3
"""
Contoh Penggunaan Google Sheets Integration dengan Hermes
Run: python3 examples_google_sheets.py
"""

import asyncio
import os
from pathlib import Path
from embedded_mcps.google_sheets_mcp import GoogleSheetsMCP

# Test Spreadsheet ID (Google's public test spreadsheet)
TEST_SPREADSHEET_ID = "1BxiMVs0XRA5nFMoon9TTL2FwMSK_x3ILn50Fh7MvGY"

async def example_1_read_data():
    """Example 1: Baca data dari sheet"""
    print("\n" + "="*60)
    print("EXAMPLE 1: Membaca Data dari Google Sheet")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Baca data
    result = await mcp.read_sheet(
        TEST_SPREADSHEET_ID,
        "Sheet1!A1:D10"
    )

    print(f"Status: {result['message']}")
    print(f"Range: {result['range']}")
    print(f"Data preview:")
    for i, row in enumerate(result.get('data', [])[:5]):
        print(f"  Row {i+1}: {row}")

    await mcp.close()


async def example_2_get_metadata():
    """Example 2: Ambil informasi spreadsheet"""
    print("\n" + "="*60)
    print("EXAMPLE 2: Mengambil Metadata Spreadsheet")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Ambil metadata
    result = await mcp.get_spreadsheet_metadata(TEST_SPREADSHEET_ID)

    print(f"Status: {result['message']}")
    print(f"Title: {result['title']}")
    print(f"Sheets: {result['sheets']}")
    print(f"Spreadsheet ID: {result['spreadsheet_id']}")

    await mcp.close()


async def example_3_query_data():
    """Example 3: Search/query data dalam sheet"""
    print("\n" + "="*60)
    print("EXAMPLE 3: Query/Search Data dalam Sheet")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Query data
    result = await mcp.query_sheet(
        TEST_SPREADSHEET_ID,
        "US",  # Search untuk "US"
        "Sheet1!A1:Z1000"
    )

    print(f"Status: {result['message']}")
    print(f"Query: '{result['query']}'")
    print(f"Matched: {result['matched_count']} rows")
    print(f"Results preview:")
    for i, match in enumerate(result.get('results', [])[:3]):
        print(f"  Row {match['row_number']}: {match['data'][:3]}...")

    await mcp.close()


async def example_4_convert_to_json():
    """Example 4: Convert sheet data ke JSON objects"""
    print("\n" + "="*60)
    print("EXAMPLE 4: Convert Sheet ke JSON Objects")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Convert ke JSON
    result = await mcp.get_sheet_values_as_json(
        TEST_SPREADSHEET_ID,
        "Sheet1!A1:D20",
        has_header=True
    )

    print(f"Status: {result['message']}")
    print(f"Headers: {result.get('headers', [])}")
    print(f"Total rows: {result['row_count']}")
    print(f"Data (first 2 objects):")

    for i, obj in enumerate(result.get('data', [])[:2]):
        print(f"\n  Object {i+1}:")
        for key, value in obj.items():
            print(f"    {key}: {value}")

    await mcp.close()


async def example_5_custom_processing():
    """Example 5: Custom processing - statistik dari data"""
    print("\n" + "="*60)
    print("EXAMPLE 5: Custom Processing - Analisis Data")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')
    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Ambil data
    result = await mcp.read_sheet(
        TEST_SPREADSHEET_ID,
        "Sheet1!A1:Z100"
    )

    if result['success'] and result['data']:
        data = result['data']

        # Custom analysis
        total_rows = len(data)
        total_cols = max(len(row) for row in data) if data else 0
        non_empty_rows = sum(1 for row in data if any(row))

        print(f"📊 Statistik Data:")
        print(f"  Total rows: {total_rows}")
        print(f"  Max columns: {total_cols}")
        print(f"  Non-empty rows: {non_empty_rows}")
        print(f"  Density: {(non_empty_rows/total_rows*100):.1f}%")

    await mcp.close()


async def example_6_error_handling():
    """Example 6: Error handling - bagaimana menangani error"""
    print("\n" + "="*60)
    print("EXAMPLE 6: Error Handling")
    print("="*60 + "\n")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')

    if not api_key:
        print("❌ GOOGLE_SHEETS_API_KEY tidak di-set")
        return

    mcp = GoogleSheetsMCP(api_key)

    # Test dengan spreadsheet ID yang invalid
    print("Testing dengan invalid spreadsheet ID...")
    result = await mcp.read_sheet(
        "INVALID_ID",
        "Sheet1!A1:D10"
    )

    print(f"Success: {result['success']}")
    print(f"Message: {result['message']}")
    if not result['success']:
        print(f"Error: {result.get('error', 'Unknown error')}")

    await mcp.close()


async def main():
    """Run all examples"""

    print("""
╔════════════════════════════════════════════════════════════════╗
║     Contoh Penggunaan Google Sheets Integration untuk Hermes   ║
╚════════════════════════════════════════════════════════════════╝
""")

    print("\n⚠️  Setup required:")
    print("   Pastikan GOOGLE_SHEETS_API_KEY di-set:")
    print("   - Linux/macOS: export GOOGLE_SHEETS_API_KEY='YOUR_KEY'")
    print("   - Windows: set GOOGLE_SHEETS_API_KEY=YOUR_KEY")
    print("   - Atau: tambahkan ke data/.env")

    api_key = os.getenv('GOOGLE_SHEETS_API_KEY')

    if not api_key:
        print("\n❌ API key tidak ditemukan!")
        print("   Jalankan: ./setup-google-sheets.sh (Linux/macOS)")
        print("   Atau:     setup-google-sheets.bat (Windows)")
        return

    print(f"\n✅ API key found: {api_key[:20]}...")

    # Run examples
    try:
        await example_1_read_data()
        await example_2_get_metadata()
        await example_3_query_data()
        await example_4_convert_to_json()
        await example_5_custom_processing()
        await example_6_error_handling()

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "="*60)
    print("✅ Contoh selesai!")
    print("="*60)


if __name__ == "__main__":
    asyncio.run(main())
