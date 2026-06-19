"""
Google Sheets MCP Server — FastMCP stdio server for Hermes Portable.

Wraps google_sheets_mcp.GoogleSheetsMCP as MCP tools so Hermes can
call them via its standard MCP tool-dispatch pipeline.

Launched by launcher.py as: python -m gsheets_mcp
Requires env var: GOOGLE_SHEETS_API_KEY
"""

import json
import logging
import os
import sys
from pathlib import Path

# Allow importing google_sheets_mcp from the embedded-mcps parent directory
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastmcp import FastMCP
from google_sheets_mcp import GoogleSheetsMCP  # noqa: E402

logger = logging.getLogger(__name__)

mcp = FastMCP(
    "Google Sheets",
    instructions=(
        "Read and query data from Google Sheets via the Sheets API (read-only). "
        "Use spreadsheet_id from the URL: docs.google.com/spreadsheets/d/{ID}/. "
        "Range uses A1 notation, e.g. Sheet1!A1:D100."
    ),
)


def _client() -> GoogleSheetsMCP:
    api_key = os.environ.get("GOOGLE_SHEETS_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError(
            "GOOGLE_SHEETS_API_KEY tidak di-set. "
            "Tambahkan ke data/.env lalu restart Hermes."
        )
    return GoogleSheetsMCP(api_key)


@mcp.tool()
async def read_sheet(
    spreadsheet_id: str,
    range_name: str = "Sheet1!A1:Z1000",
) -> str:
    """Baca data dari Google Sheet dalam range tertentu.

    Args:
        spreadsheet_id: ID spreadsheet dari URL Google Sheets.
        range_name: Range A1 notation, contoh: Sheet1!A1:D10.
    """
    gs = _client()
    result = await gs.read_sheet(spreadsheet_id, range_name)
    await gs.close()
    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
async def get_metadata(spreadsheet_id: str) -> str:
    """Ambil metadata spreadsheet: judul, daftar sheet, dll.

    Args:
        spreadsheet_id: ID spreadsheet dari URL Google Sheets.
    """
    gs = _client()
    result = await gs.get_spreadsheet_metadata(spreadsheet_id)
    await gs.close()
    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
async def query_sheet(
    spreadsheet_id: str,
    query: str,
    range_name: str = "Sheet1!A1:Z1000",
) -> str:
    """Search/filter data di Google Sheet berdasarkan teks (case-insensitive).

    Args:
        spreadsheet_id: ID spreadsheet dari URL Google Sheets.
        query: Teks yang dicari.
        range_name: Range yang dicari.
    """
    gs = _client()
    result = await gs.query_sheet(spreadsheet_id, query, range_name)
    await gs.close()
    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
async def get_json(
    spreadsheet_id: str,
    range_name: str = "Sheet1!A1:Z1000",
    has_header: bool = True,
) -> str:
    """Ambil data sheet dan convert ke JSON objects (row pertama jadi key nama kolom).

    Args:
        spreadsheet_id: ID spreadsheet dari URL Google Sheets.
        range_name: Range yang dibaca.
        has_header: True jika row pertama adalah header/nama kolom.
    """
    gs = _client()
    result = await gs.get_sheet_values_as_json(spreadsheet_id, range_name, has_header)
    await gs.close()
    return json.dumps(result, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    mcp.run()
