from google.oauth2 import service_account
from googleapiclient.discovery import build
import json

creds_path = r'C:\Users\USER\Downloads\spreadsheet-498408-84d5fca44c15.json'
credentials = service_account.Credentials.from_service_account_file(creds_path, scopes=['https://www.googleapis.com/auth/spreadsheets'])
service = build('sheets', 'v4', credentials=credentials)

spreadsheet_id = '1JZ6Nlz46Pu3OutsYHeNHJnVJnH5iP7iAZuHzmQMWTXE'

# Get spreadsheet metadata
spreadsheet = service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
print("Sheets:")
for sheet in spreadsheet.get('sheets', []):
    print(f"  - {sheet['properties']['title']}")

# Get first sheet data (first 10 rows)
sheet_title = spreadsheet['sheets'][0]['properties']['title']
result = service.spreadsheets().values().get(spreadsheetId=spreadsheet_id, range=f"{sheet_title}!A1:J10").execute()
print(f"\nData dari {sheet_title}:")
for row in result.get('values', []):
    print(row)