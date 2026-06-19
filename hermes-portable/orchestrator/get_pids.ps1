Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'node.exe' -or $_.Name -eq 'hermes.exe' } | Select-Object ProcessId,Name,CommandLine | Format-List
