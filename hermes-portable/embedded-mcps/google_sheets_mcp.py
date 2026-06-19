"""
Google Sheets MCP Tool untuk Hermes Agent
Menggunakan Google Sheets API dengan simple API key untuk read/write operations
"""

import os
import json
import httpx
from typing import Any, Optional
from dataclasses import dataclass

@dataclass
class GoogleSheetsConfig:
    """Konfigurasi Google Sheets"""
    api_key: str
    spreadsheet_id: str

class GoogleSheetsMCP:
    """MCP Tool untuk Google Sheets integration"""

    BASE_URL = "https://sheets.googleapis.com/v4/spreadsheets"

    def __init__(self, api_key: str):
        """
        Initialize Google Sheets MCP

        Args:
            api_key: Google API key
        """
        self.api_key = api_key
        self.client = httpx.AsyncClient(timeout=30.0)

    async def read_sheet(
        self,
        spreadsheet_id: str,
        range_name: str = "Sheet1!A1:Z1000"
    ) -> dict[str, Any]:
        """
        Baca data dari Google Sheet

        Args:
            spreadsheet_id: ID spreadsheet
            range_name: Range untuk dibaca (contoh: "Sheet1!A1:D10")

        Returns:
            dict berisi values, headers, dan metadata
        """
        try:
            url = f"{self.BASE_URL}/{spreadsheet_id}/values/{range_name}"
            params = {"key": self.api_key}

            response = await self.client.get(url, params=params)
            response.raise_for_status()

            data = response.json()

            return {
                "success": True,
                "data": data.get("values", []),
                "range": data.get("range", range_name),
                "message": f"✅ Berhasil baca {len(data.get('values', []))} rows"
            }

        except httpx.HTTPStatusError as e:
            return {
                "success": False,
                "error": f"HTTP Error {e.response.status_code}: {e.response.text}",
                "message": "❌ Gagal membaca sheet"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "❌ Error membaca sheet"
            }

    async def write_sheet(
        self,
        spreadsheet_id: str,
        range_name: str,
        values: list[list[Any]],
        value_input_option: str = "RAW"
    ) -> dict[str, Any]:
        """
        Tulis/update data ke Google Sheet

        Catatan: Butuh OAuth2 atau Service Account (tidak bisa dengan API key biasa)
        Untuk API key biasa, gunakan Google Forms atau integrasi lain

        Args:
            spreadsheet_id: ID spreadsheet
            range_name: Range untuk ditulis (contoh: "Sheet1!A1")
            values: Data yang akan ditulis [[row1_col1, row1_col2], [row2_col1, ...]]
            value_input_option: RAW atau USER_ENTERED

        Returns:
            dict berisi hasil update
        """
        return {
            "success": False,
            "error": "API key biasa tidak support write operations",
            "message": "⚠️ Untuk write/update, gunakan Service Account (JSON) atau OAuth2",
            "recommendation": "Upgrade ke Service Account authentication"
        }

    async def get_spreadsheet_metadata(
        self,
        spreadsheet_id: str
    ) -> dict[str, Any]:
        """
        Ambil metadata spreadsheet (judul, sheets, dll)

        Args:
            spreadsheet_id: ID spreadsheet

        Returns:
            dict berisi metadata spreadsheet
        """
        try:
            url = f"{self.BASE_URL}/{spreadsheet_id}"
            params = {"key": self.api_key}

            response = await self.client.get(url, params=params)
            response.raise_for_status()

            data = response.json()

            sheets = [sheet["properties"]["title"] for sheet in data.get("sheets", [])]

            return {
                "success": True,
                "title": data.get("properties", {}).get("title", "Unknown"),
                "sheets": sheets,
                "spreadsheet_id": spreadsheet_id,
                "message": f"✅ Metadata berhasil diambil ({len(sheets)} sheets)"
            }

        except httpx.HTTPStatusError as e:
            return {
                "success": False,
                "error": f"HTTP Error {e.response.status_code}",
                "message": "❌ Gagal ambil metadata"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "❌ Error ambil metadata"
            }

    async def query_sheet(
        self,
        spreadsheet_id: str,
        query: str,
        range_name: str = "Sheet1!A1:Z1000"
    ) -> dict[str, Any]:
        """
        Query/search data di sheet dengan filter sederhana

        Args:
            spreadsheet_id: ID spreadsheet
            query: Query string (search dalam values)
            range_name: Range untuk dicari

        Returns:
            dict berisi matched rows
        """
        try:
            result = await self.read_sheet(spreadsheet_id, range_name)

            if not result["success"]:
                return result

            all_values = result["data"]
            matched_rows = []

            for idx, row in enumerate(all_values):
                row_str = " ".join(str(cell) for cell in row)
                if query.lower() in row_str.lower():
                    matched_rows.append({"row_number": idx + 1, "data": row})

            return {
                "success": True,
                "query": query,
                "matched_count": len(matched_rows),
                "results": matched_rows,
                "message": f"✅ Ditemukan {len(matched_rows)} hasil"
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "❌ Error query sheet"
            }

    async def get_sheet_values_as_json(
        self,
        spreadsheet_id: str,
        range_name: str = "Sheet1!A1:Z1000",
        has_header: bool = True
    ) -> dict[str, Any]:
        """
        Ambil data sheet dan convert ke JSON (setiap row jadi object)

        Args:
            spreadsheet_id: ID spreadsheet
            range_name: Range untuk dibaca
            has_header: Apakah row pertama adalah header

        Returns:
            dict berisi array of objects
        """
        try:
            result = await self.read_sheet(spreadsheet_id, range_name)

            if not result["success"]:
                return result

            all_values = result["data"]

            if not all_values:
                return {
                    "success": True,
                    "data": [],
                    "message": "✅ Sheet kosong"
                }

            if has_header and len(all_values) > 0:
                headers = all_values[0]
                rows = all_values[1:]

                json_data = []
                for row in rows:
                    obj = {}
                    for idx, header in enumerate(headers):
                        obj[header] = row[idx] if idx < len(row) else None
                    json_data.append(obj)

                return {
                    "success": True,
                    "headers": headers,
                    "data": json_data,
                    "row_count": len(json_data),
                    "message": f"✅ Convert to JSON: {len(json_data)} objects"
                }
            else:
                return {
                    "success": True,
                    "data": all_values,
                    "row_count": len(all_values),
                    "message": f"✅ Raw data: {len(all_values)} rows"
                }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "❌ Error convert to JSON"
            }

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()


# Standalone functions untuk MCP registration
async def read_sheet(api_key: str, spreadsheet_id: str, range_name: str = "Sheet1!A1:Z1000") -> str:
    """MCP wrapper: read_sheet"""
    mcp = GoogleSheetsMCP(api_key)
    result = await mcp.read_sheet(spreadsheet_id, range_name)
    await mcp.close()
    return json.dumps(result, indent=2, ensure_ascii=False)

async def get_metadata(api_key: str, spreadsheet_id: str) -> str:
    """MCP wrapper: get_metadata"""
    mcp = GoogleSheetsMCP(api_key)
    result = await mcp.get_spreadsheet_metadata(spreadsheet_id)
    await mcp.close()
    return json.dumps(result, indent=2, ensure_ascii=False)

async def query_sheet(api_key: str, spreadsheet_id: str, query: str, range_name: str = "Sheet1!A1:Z1000") -> str:
    """MCP wrapper: query_sheet"""
    mcp = GoogleSheetsMCP(api_key)
    result = await mcp.query_sheet(spreadsheet_id, query, range_name)
    await mcp.close()
    return json.dumps(result, indent=2, ensure_ascii=False)

async def get_json(api_key: str, spreadsheet_id: str, range_name: str = "Sheet1!A1:Z1000", has_header: bool = True) -> str:
    """MCP wrapper: get_json"""
    mcp = GoogleSheetsMCP(api_key)
    result = await mcp.get_sheet_values_as_json(spreadsheet_id, range_name, has_header)
    await mcp.close()
    return json.dumps(result, indent=2, ensure_ascii=False)
