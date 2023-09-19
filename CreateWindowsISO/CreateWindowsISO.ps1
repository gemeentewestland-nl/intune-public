<# 
.SYNOPSIS 
   Creates Windows ISO
 
.DESCRIPTION 
   This script injects drivers into the boot,wim and install.wim file and creates an Windows ISO file.
        
.NOTES 
    Author: Erwin Klaver - Orange Business 
    Last Updated: 25/10/2022 
    Version 0.1

    #DISCLAIMER
    The script is provided AS IS without warranty of any kind.

#>

#region Set variables

        #Source directory for WinPE drivers. All drivers in this directory will be injected into the boot.wim file.

        $WinPESourceDir = "C:\Drivers\WinPE"

        #Source directory for device drivers. All drivers in this directory will be injected into the install.wim file.

        $DriverSourceDir = "C:\Drivers\GWL"

        #Directory used to mount and unmount the .wim files.

        $MountDir = "C:\MountDir"

        #Source directory Windows files. All files will be copied to this directory.

        $WinSourceDir = "C:\Windows-Source"

        #Path to Oscdimg.exe

        $PathToOscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"

        #Blob storage URL

        $ContainerUrl = "https://raw.githubusercontent.com/gemeentewestland-nl/intune-public/main"

        #Filename for the ISO file

        $ISOFile = "gwl_nl-nl_windows_11_pro_version_22h2_updated_aug_2023_x64_dvd_fa582095.iso"

#endregion

#region Browse for Windows iso

		Add-Type -AssemblyName System.Windows.Forms
		
		$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop') 
        Filter = 'iso file|*.iso'
        }
		
		$null = $FileBrowser.ShowDialog()

       if ([string]::IsNullOrEmpty($FileBrowser.FileName)){
            exit
        }
        

#endregion



#region Create folders

        $ScriptFolder = $MountDir

        if(Test-Path $ScriptFolder) {} 
        else    
                {
                New-Item -Path $ScriptFolder -ItemType "directory"
                }
        $ScriptFolder = $WinSourceDir

        if(Test-Path $ScriptFolder) {} 
        else    
                {
                New-Item -Path $ScriptFolder -ItemType "directory"
                }

#endregion

#region Mount Windows ISO and copy files to $WinSourceDir

    $mountiso = Mount-DiskImage -ImagePath $FileBrowser.FileName -PassThru
    $driveletter = ($mountiso | Get-Volume).DriveLetter
    Copy-Item -Path $driveletter':\*' -Destination $WinSourceDir -Force -Recurse -PassThru | Where-Object { -not $_.PSIsContainer } | Set-ItemProperty -Name IsReadOnly -Value $false
    Dismount-DiskImage -ImagePath $FileBrowser.FileName

#endregion

Start-Transcript -Path "$WinSourceDir\Logfile.txt" -IncludeInvocationHeader -Force

#region Add drivers to boot.wim index 1

        #Mount boot.wim index 1

		DISM.exe /Mount-Image /ImageFile:$WinSourceDir\sources\boot.wim /index:1 /MountDir:$MountDir
		
		#Inject the WinPE drivers
		
		DISM.exe /Image:$MountDir /Add-Driver /Driver:$WinPESourceDir /recurse

		#Unmount the boot.wim
		
		DISM /UnMount-Image /MountDir:$MountDir /Commit

#endregion

#region Add drivers to boot.wim index 2

        #Mount boot.wim index 2

		DISM.exe /Mount-Image /ImageFile:$WinSourceDir\sources\boot.wim /index:2 /MountDir:$MountDir
		
		#Inject the WinPE drivers
		
		DISM.exe /Image:$MountDir /Add-Driver /Driver:$WinPESourceDir /recurse

		#Unmount the boot.wim
		
		DISM /UnMount-Image /MountDir:$MountDir /Commit


#endregion

#region Add drivers to install.wim index 5 (Windows Professional Edition)

        #Mount install.wim index 5

		DISM /Mount-Image /ImageFile:$WinSourceDir\sources\install.wim /index:5 /MountDir:$MountDir
		
		#Inject the drivers to install.wim
		
		DISM /Image:$MountDir /Add-Driver /Driver:$DriverSourceDir /recurse

		#Unmount the install.wim
		
		DISM /UnMount-Image /MountDir:$MountDir /Commit


#endregion


#region Create folders and download start.cmd in $WinSourceDir

        #Create folders
        
        $Folder1 = '$OEM$'
        $Folder2 = '$$'
        $Folder3 = 'System32'

        $ScriptFolder1 = "$WinSourceDir\sources\$Folder1"

        if(Test-Path $ScriptFolder1) {} 
        else    
                {
                New-Item -Path $ScriptFolder1 -ItemType "directory"
                }


        $ScriptFolder2 = "$WinSourceDir\sources\$Folder1\$Folder2"

        if(Test-Path $ScriptFolder2) {} 
        else    
                {
                New-Item -Path $ScriptFolder2 -ItemType "directory"
                }

        $ScriptFolder3 = "$WinSourceDir\sources\$Folder1\$Folder2\$Folder3"

        if(Test-Path $ScriptFolder3) {} 
        else    
                {
                New-Item -Path $ScriptFolder3 -ItemType "directory"
                }

        # copy start.cmd from blob storage

        Invoke-WebRequest -Uri $ContainerUrl/autopilot/start.cmd -OutFile $ScriptFolder3\start.cmd

        # copy autounattend from blob storage

        Invoke-WebRequest -Uri $ContainerUrl/autounattend/autounattend.xml -OutFile $WinSourceDir\autounattend.xml

#endregion

#region Export-Image Index
       
        Dism /Export-Image /SourceImageFile:$WinSourceDir\sources\install.wim /SourceIndex:5 /DestinationImageFile:$WinSourceDir\sources\install2.wim
        Remove-Item -Path $WinSourceDir\sources\install.wim -Force
        Rename-Item -Path $WinSourceDir\sources\install2.wim -NewName $WinSourceDir\sources\install.wim

#endregion

Stop-Transcript

#region Create ISO

        $BootData='2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$WinSourceDir\boot\etfsboot.com","$WinSourceDir\efi\Microsoft\boot\efisys.bin"
  
        $Proc = Start-Process -FilePath "$PathToOscdimg\oscdimg.exe" -ArgumentList @("-bootdata:$BootData",'-m','-o','-u2','-udfver102',"$WinSourceDir","$WinSourceDir\$ISOFile") -PassThru -Wait -NoNewWindow
        if($Proc.ExitCode -ne 0)
        {
            Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
        }

#endregion

