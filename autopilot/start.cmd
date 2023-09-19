@ECHO OFF

cmd.exe /c powershell.exe -NoLogo -Command "Invoke-WebRequest -Uri https://raw.githubusercontent.com/gemeentewestland-nl/intune-public/main/Autopilot/RunWindowsAutoPilotInfo.ps1 -OutFile C:\Windows\Temp\RunWindowsAutoPilotInfo.ps1"

cmd.exe /c powershell.exe -executionpolicy bypass -file C:\Windows\Temp\RunWindowsAutoPilotInfo.ps1