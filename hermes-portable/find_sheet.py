from google.oauth2 import service_account
from googleapiclient.discovery import build as drive_build

creds_path = r'C:\Users\USER\Downloads\spreadsheet-498408-84d5fca44c15.json'

drive_creds = service_account.Credentials.from_service_account_file(creds_path, scopes=['https://www.googleapis.com/auth/drive'])
drive = drive_build('drive', 'v3', credentials=drive_creds)

results = drive.files().list(q="name contains 'REPORT' or name contains 'ALL'", pageSize=20).execute()
for f in results.get('files', []):
    print(f"{f['name']} -> {f['id']}")