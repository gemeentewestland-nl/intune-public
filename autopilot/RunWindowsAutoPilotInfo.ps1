<# 
.SYNOPSIS 
   Register Device in Autopilot.
 
.DESCRIPTION 
   This script install the WindowsAutoPilotInfo script and registers the device in autopilot
        
.NOTES 
    Author: Benno Rummens from Login Consultants 
    Website: http://www.loginconsultants.com 
    Last Updated: 24/03/2022 
    Version 1.0 

    #DISCLAIMER
    The script is provided AS IS without warranty of any kind.

#>

#region Create Directory

    $DirectoryPath = "C:\HWID"
    New-Item -Path $DirectoryPath -ItemType Directory -Force

#endregion

Start-Transcript -Path $DirectoryPath\Transscript.log

#region Input form Grouptag

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Select Device Type'
    $form.Size = New-Object System.Drawing.Size(300,200)
    $form.ControlBox = $false
    $form.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(110,115)
    $okButton.Size = New-Object System.Drawing.Size(70,25)
    $okButton.Text = 'OK'
    $okButton.Enabled = $false
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = 'Please select an Autopilotprofile:'
    $form.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10,40)
    $listBox.Size = New-Object System.Drawing.Size(260,20)
    $listBox.Height = 80

    [void] $listBox.Items.Add('Kiosk')
    [void] $listBox.Items.Add('Persoonlijk')
    [void] $listBox.Items.Add('Shared')

    $form.Controls.Add($listBox)

    $form.Topmost = $true

    $listBox.add_SelectedIndexChanged({    
        $okButton.Enabled = $true
    })

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $Grouptag = $listBox.SelectedItem
        Write-Output "The Grouptag is set to: $Grouptag"
    }

#endregion

#region Install Autopilot Script

    Set-Location $DirectoryPath
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Script -Name Get-WindowsAutoPilotInfo -Force

#endregion

#region Register Device in Autopilot

    Get-WindowsAutoPilotInfo.ps1 -GroupTag $Grouptag -OutputFile AutoPilotHWID.csv
    Get-WindowsAutoPilotInfo.ps1 -GroupTag $Grouptag -Online -Assign

#endregion     

Stop-Transcript


If ((Get-ItemProperty -Path "HKLM:\SYSTEM\Setup\Status" -ErrorAction SilentlyContinue).AuditBoot -eq 1) {

        Write-Output "This computer is running in Audit mode. Automatic reboot will not be triggered by this script."
        
        }
        else{

        Write-Output "Script is finished: Rebooting computer."
        Start-Sleep -Seconds 10 ; Restart-Computer -Force

        }