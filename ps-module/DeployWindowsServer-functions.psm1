function New-IsoFile
{
  <#
   .Synopsis
    Creates a new .iso file
   .Description
    The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders
   .Example
    New-IsoFile "c:\tools","c:Downloads\utils"
    Description
    -----------
    This command creates a .iso file in $env:temp folder (default location) that contains c:\tools and c:\downloads\utils folders. The folders themselves are added in the root of the .iso image.
   .Example
    dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile etfsboot.com -Media DVDPLUSR -Title "WinPE"
    Description
    -----------
    This command creates a bootable .iso file containing the content from c:\WinPE folder, but the folder itself isn't included. Boot file etfsboot.com can be found in Windows AIK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types:

      http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx
   .Notes
    NAME:  New-IsoFile
    AUTHOR: Chris Wu
    LASTEDIT: 03/06/2012 14:06:16
 #>

  Param (
    [parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]$Source,
    [parameter(Position=1)][string]$Path = "$($env:temp)\" + (Get-Date).ToString("yyyyMMdd-HHmmss.ffff") + ".iso",
    [string] $BootFile = $null,
    [string] $Media = "Disk",
    [string] $Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),
    [switch] $Force
  )#End Param

  Begin {
    ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = "/unsafe"
    if (!("ISOFile" -as [type])) {
      Add-Type -CompilerParameters $cp -TypeDefinition @"
public class ISOFile
{
    public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
    {
        int bytes = 0;
        byte[] buf = new byte[BlockSize];
        System.IntPtr ptr = (System.IntPtr)(&bytes);
        System.IO.FileStream o = System.IO.File.OpenWrite(Path);
        System.Runtime.InteropServices.ComTypes.IStream i = Stream as System.Runtime.InteropServices.ComTypes.IStream;

        if (o == null) { return; }
        while (TotalBlocks-- > 0) {
            i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
        }
        o.Flush(); o.Close();
    }
}
"@
    }#End If

    if ($BootFile -and (Test-Path $BootFile)) {
      ($Stream = New-Object -ComObject ADODB.Stream).Open()
      $Stream.Type = 1  # adFileTypeBinary
      $Stream.LoadFromFile((Get-Item $BootFile).Fullname)
      ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream)
    }#End If

    $MediaType = @{CDR=2; CDRW=3; DVDRAM=5; DVDPLUSR=6; DVDPLUSRW=7; `
      DVDPLUSR_DUALLAYER=8; DVDDASHR=9; DVDDASHRW=10; DVDDASHR_DUALLAYER=11; `
      DISK=12; DVDPLUSRW_DUALLAYER=13; BDR=18; BDRE=19 }
    
    if ($MediaType[$Media] -eq $null) { write-debug "Unsupported Media Type: $Media"; write-debug ("Choose one from: " + $MediaType.Keys); break }
    ($Image = new-object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$Title}).ChooseImageDefaultsForMediaType($MediaType[$Media])

    if ((Test-Path $Path) -and (!$Force)) { "File Exists $Path"; break }
    if (!($Target = New-Item -Path $Path -ItemType File -Force)) { "Cannot create file $Path"; break }
  }

  Process {
    switch ($Source) {
      { $_ -is [string] } { $Image.Root.AddTree((Get-Item $_).FullName, $true); continue }
      { $_ -is [IO.FileInfo] } { $Image.Root.AddTree($_.FullName, $true); continue }
      { $_ -is [IO.DirectoryInfo] } { $Image.Root.AddTree($_.FullName, $true); continue }
    }#End switch
  }#End Process
  
  End {
    if ($Boot) { $Image.BootImageOptions=$Boot }
    $Result = $Image.CreateResultImage()
    [ISOFile]::Create($Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks)
    $Target
  }#End End
}#End function New-IsoFile

# Function to test whether named switch exists
Function Test-FAVMSwitchexistence
{
    Param(
        [string]$VMSwitchname
    )
        $Item = (Get-VMSwitch | Where-Object -Property Name -EQ -Value $VMSwitchname).count
        If($Item -eq '1'){Return $true}else{Return $false}
}

# Function to test whether named VM exists
Function Test-FAVMExistence
{
    Param(
        [string]$VMName
    )
        $Item = (Get-VM | Where-Object -Property Name -EQ -Value $VMName).count
        If($Item -eq '1'){Return $true}else{Return $false}
}

function Get-PaddedOutArray
{
    Param(
        [array]$Array,
        [int]$Length,
        [switch]$IsDriveLetter
    )
    if ($IsDriveLetter) {
        $LastArrChar = [byte][char]($Array[-1].ToUpper())
        if ($LastArrChar -le 67 -or $LastArrChar -ge 90) {$LastArrChar = 67}
        While ($Array.Length -lt $Length) {
            $LastArrChar += 1        
            $Array += [char]$LastArrChar
        }
    } else {
        While ($Array.Length -lt $Length) {
            $Array += $Array[0]
        }
    }
    Return $Array
}

Function Get-VMCustomStatus {
    Param(
        [string]$VMName="Hyper-V Server 2012",
        [string]$GuestParamName="Sessions"
    )
    
    $vm = Get-WmiObject -Namespace root\virtualization\v2 -Query "SELECT * FROM Msvm_ComputerSystem WHERE ElementName = '$VMName' "
    $singleNode = (($vm.GetRelated("Msvm_KvpExchangeComponent").GuestExchangeItems | % { ([XML]$_) }).INSTANCE.PROPERTY | Where {$_.VALUE -eq $GuestParamName })
    if (!($singleNode -eq $null)) {
        $customStatus = $singleNode.ParentNode.SelectSingleNode('PROPERTY[@NAME="Data"]/VALUE').InnerXML
        Return $customStatus
        
    }
    Return $null

}

Function Wait-VMStatus {
    Param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [Parameter(Mandatory=$true)][string]$statusName,
        [Parameter(Mandatory=$true)][string]$completeValue,
        [int]$refreshRateSeconds=2,
        [int]$timeout=10,
        [int]$lineLength=50
    )

    $status = $null
    $timeOff = 0
    $vmStatus="Running"
    $curLineLength = 0
    do
    {
        $newStatus = Get-VMCustomStatus -VMName $VMName -GuestParamName $statusName
        if ($newStatus -eq $status) {
            if ($curLineLength -ge $lineLength) {
                Write-Host "." -ForegroundColor Yellow
                $curLineLength = 0
            } else {
                Write-Host "." -NoNewline -ForegroundColor Yellow
            }
            $curLineLength += 1
        } else {
            if ($curLineLength -ge $lineLength) {
                Write-Host $newStatus -ForegroundColor White
                $curLineLength = 0
            } else {
                Write-Host $newStatus -NoNewline -ForegroundColor White
            }
           
            $status = $newStatus
            $curLineLength += $newStatus.Length
        }
        if (( Get-VM -VMName $VMName).State -eq "Running") {
            $timeOff = 0
        } else {
            $timeOff += $refreshRateSeconds
            if ($timeOff -gt $timeout) {
                echo ""
                $continue = Read-Host -Prompt "The VM has been powered off for more than $timeout seconds. Do you wish to exit the progress status?[Y/N]"
                if ($continue -ne "Y") {
                    $timeoff = 0
                } else {
                    echo "Warning, user disabled status prompt, VM may still be in-use. Check before removing"
                    echo ""
                    break
                }
            }
        }
        Start-Sleep -Seconds $refreshRateSeconds
    }
    until ($newStatus -eq $completeValue) 
    ""
    if ($newStatus -eq $completeValue) {
        "Process Completed!"
        ""
    } else {
        "Some possible error encountered - check deployment before proceeding"
        ""
    }
}


function Add-AutoUnattendDisk
{
    Param(
        [Parameter(Mandatory=$True)][int]$DiskNumber,
        [switch]$IsBootDisk
    )

    if ($IsBootDisk) {
                
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>350</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>2</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
    } else {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>1</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
    }

    return $Pass1_DiskConfig

}


function Set-AutoUnattendDisk
{
    Param(
        [Parameter(Mandatory=$True)][int]$DiskNumber,
        [string]$DriveLetter,
        [switch]$IsBootDisk,
        [switch]$IsSetupDisk
    )
    if ($IsBootDisk -or $IsSetupDisk) {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>2</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>false</WillWipeDisk>
                </Disk>'
    } else {
        $Pass1_DiskConfig = '                <Disk wcm:action="add">
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>1</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>' + $DiskNumber + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
        
    }

    return $Pass1_DiskConfig
}


function Set-AutoUnattendRunSyncCmd
{
    Param(
        [Parameter(Mandatory=$True)][string]$Command,
        [Parameter(Mandatory=$True)][int]$Order,
        [string]$Description,
        [Parameter(Mandatory=$False)][ValidateSet('Never','Always','OnRequest')][string]$WillReboot='Never'
    )

    $RunCommand = $Command.Replace('"','&quot;')
    
    $RunSyncCommandBlock = '                <RunSynchronousCommand wcm:action="add">
                    <Description>' + $Description + '</Description>
                    <WillReboot>' + $WillReboot + '</WillReboot>
                    <Order>' + $Order + '</Order>
                    <Path>' + $RunCommand + '</Path>
                </RunSynchronousCommand>'
    
    return $RunSyncCommandBlock

}

function Set-AutoUnattendFirstLogonCmd
{
    Param(
        [Parameter(Mandatory=$True)][string]$Command,
        [Parameter(Mandatory=$True)][int]$Order,
        [string]$Description,
        [switch]$RequiresUserinput
    )
        $RunCommand = $Command.Replace('"','&quot;')
        if ($RequiresUsernput) { 
            $RequiresUserInputValue = "true"
        } else {
            $RequiresUserInputValue = "false"
        }

        $RunFirstLogonCommandBlock = '                <SynchronousCommand wcm:action="add">
                    <Description>' + $Description + '</Description>
                    <CommandLine>' + $RunCommand + '</CommandLine>
                    <Order>' + $Order + '</Order>
                    <RequiresUserInput>' + $RequiresUserInputValue + '</RequiresUserInput>
                </SynchronousCommand>'

        return $RunFirstLogonCommandBlock
}


Function New-AutoUnattendXML
{
    Param(
        [Parameter(Mandatory=$true)][string]$TempUnattend,
        [Parameter(Mandatory=$true)][ValidateLength(1,15)][string]$VMName,
        [Parameter(Mandatory=$true)][string]$autoUnattendPath,
        [string]$UnattendDiskConfigSection = "",
        [string]$UnattendRunSyncCmdSpecialize = "",
        [string]$UnattendRunSyncCmdOOBE = "",
        [string]$FullName ="",
        [string]$OrganisationName = ""
    )

    $findString = "[[--DiskConfig--]]"
    $NewUnattendXM = (Get-Content $TempUnattend) | foreach {$_.replace($findString,$UnattendDiskConfigSection)}
    
    $findString = "[[--ComputerName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$VMName)}

    $findString = "[[--RunSyncSpecializePass--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$UnattendRunSyncCmdSpecialize)}

    $findString = "[[--RunSyncOOBEPass--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$UnattendRunSyncCmdOOBE)}


    $findString = "[[--OrganisationName--]]"
    if ($OrganisationName.length -gt 0) {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,'            <Organization>' + $OrganisationName + '</Organization>')}
    } else {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"")}
    }
     
    $findString = "[[--RegOrganisationName--]]"
    if ($OrganisationName.length -gt 0) {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,'            <RegisteredOrganization>' + $OrganisationName + '</RegisteredOrganization>')}
    } else {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"")}
    }

    $findString = "[[--FullName--]]"
    if ($FullName.Length -gt 0) {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,'                <FullName>' + $FullName + '</FullName>')}
    } else {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,'')}
    }

    Set-Content ($autoUnattendPath + "\AutoUnattend.xml") $NewUnattendXM -Encoding UTF8
}


Function New-HyperVWindowsServer
{

    Param(
        [Parameter(Mandatory=$true)][string]$unattendPath,
        [Parameter(Mandatory=$true)][string]$autoISOPath,
        [Parameter(Mandatory=$true)][string]$windowsISOpath,
        [Parameter(Mandatory=$true)][string]$unattendTemplatePath,
        [string]$VMName = "Hyper-V Server 2012",
        [string]$switch = "vSwitch",
        [int]$numCores = 1,
        [long]$ramSize = 2GB,
        [array]$vhdPathArray = @('$path + "\hyper-v.vhd"'),
        [array]$vhdSizeArray = @(10GB),
        [array]$vhdBlockSizeArray = @(32MB),
        [array]$vhdSectorSizeArray = @(512),
        [array]$vhdDriveLetter = @('C'),
        [int]$numDrives = 1,
        [int]$vmGen = 2,
        [string]$setupVHDXPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\SetupFiles.vhdx",
        [switch]$includeSetupVHD,
        [switch]$killVM,
        [switch]$confirmVMSettings,
        [switch]$showProgress
    )


    # Credit to script by Albal
    
    #Pad out arrays
    $vhdPathArray = Get-PaddedOutArray -Array $vhdPathArray -Length $numDrives
    $vhdSizeArray = Get-PaddedOutArray -Array $vhdSizeArray -Length $numDrives
    $vhdBlockSizeArray = Get-PaddedOutArray -Array $vhdBlockSizeArray -Length $numDrives
    $vhdSectorSizeArray = Get-PaddedOutArray -Array $vhdSectorSizeArray -Length $numDrives
    $vhdDriveLetter = Get-PaddedOutArray -Array $vhdDriveLetter -Length $numDrives -IsDriveLetter

    if ($confirmVMSettings) {
        # VM Input Parameters:
        echo "VM Settings:"
        echo "------------"
        echo "VM Name: $VMName"
        echo "Cores: $numCores"
        echo "RAM: $ramSize"
        echo "Switch Name: $switch"
        echo ""

        echo "Virtual Drive Creation Details:"
        echo "_______________________________"
        for ($i=0;$i -lt $numDrives; $i++) {
            echo ('vhd path: ' + $vhdPathArray[$i])
            echo ('Size Array: ' + $vhdSizeArray[$i])
            echo ('Block Array: ' + $vhdBlockSizeArray[$i])
            echo ('Sector Array: ' + $vhdSectorSizeArray[$i])
            echo ('Drive Letter: ' + $vhdDriveLetter[$i])
            echo '--------------------------------------------------'
            echo ''
        }
        
        $continue = Read-Host -Prompt "Do you wish to continue with the server deployment using these settings?[Y/N] "

        if ($continue -eq "N") {
            echo "User aborted process - exiting"
            Return
        }
    }

    
    # Don't change anything below this line - ignore the errors below, just in case you run the script again without having exited expectedly

    # Clear out existing VMs of the same name and virtual HDD and relevant ISOs
    if (Test-FAVMExistence -VMName $VMName) {
        Stop-VM -Name $VMName -Force -TurnOff
        Remove-VM  -Name $VMName -Force
    }

    if (Test-Path $autoISOPath) { del -Force $autoISOPath }
    for ($i=0;$i -lt $numDrives; $i++) {
        if (Test-Path $vhdPathArray[$i]) { del -Force $vhdPathArray[$i] }
    }

    if (Test-Path ($unattendPath + "\AutoUnattend.xml")) { del ($unattendPath + "\AutoUnattend.xml") }

    # Check defined virtual switch exists. If not then create a Private Vitual Switch
    if (!(Test-FAVMSwitchexistence -VMSwitchname $switch)) { New-VMSwitch -Name $switch -SwitchType Private -Notes "Internal to VMs only" }

    # Begin creating the VM and setting the relevant settings
    New-VM -Name $VMName -SwitchName $switch -Generation $vmGen
    Set-VMProcessor -VMName $VMName -Count $numCores
    Set-VMMemory -VMName $VMName -StartupBytes $ramSize
    

    # Create and add Virtual HDDs and generate Disk Configuration settings for the Unattended Answer File (AutoUnattend.xml)
    for ($i=0;$i -lt $numDrives; $i++) {
        #"Drive ID = " + ($i+1) + " of size " + $array[$i] + " added"
        New-VHD -Path $vhdPathArray[$i] -BlockSizeBytes $vhdBlockSizeArray[$i] -LogicalSectorSizeBytes $vhdSectorSizeArray[$i] -SizeBytes $vhdSizeArray[$i]
        Add-VMHardDiskDrive -VMName $VMName -Path $vhdPathArray[$i] -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
        if ($i -eq 0) {
            $UnattendDiskConfigSection += `n Add-AutoUnattendDisk -DiskNumber $i -IsBootDisk
            $UnattendDiskConfigSection += `n Set-AutoUnattendDisk -DiskNumber $i -IsBootDisk -DriveLetter $vhdDriveLetter[$i]
        } else {
            $UnattendDiskConfigSection += `n Add-AutoUnattendDisk -DiskNumber $i
            $UnattendDiskConfigSection += `n Set-AutoUnattendDisk -DiskNumber $i -DriveLetter $vhdDriveLetter[$i]
        }
    }

    # Attach a pre-formatted virtual HDD that houses the relevant setupfiles needed. Assign this to Drive "Z" for easy reference to auto setup scripts etc
    # to be included in the autounattend.xml file.
    if ($includeSetupVHD) {
        if ((Get-VHD -Path $setupVHDXPath).Attached) {Dismount-VHD -Path $setupVHDXPath}
        #$i += 1
        Add-VMHardDiskDrive -VMName $VMName -Path $setupVHDXPath -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
        $setupDiskNumber = $i
        #$UnattendDiskConfigSection += Add-AutoUnattendDisk -DiskNumber $i
        $UnattendDiskConfigSection += Set-AutoUnattendDisk -DiskNumber $i -IsSetupDisk -DriveLetter "Z"
        
    }

    # Create the relevant runSynchronous commands to be run during the Specialise pass of the Windows install
    $UnattendRunSyncCmdSpecialise = Set-AutoUnattendRunSyncCmd -Command 'REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d Specialize-Pass' -Order 1
    $UnattendRunSyncCmdSpecialise += `n Set-AutoUnattendRunSyncCmd -Command ('PowerShell Set-Disk ' + $setupDiskNumber + ' -IsOffline $false') -Order 2
    
    # Create the relevant FirstLogonCommand commands to be run during the OOBE pass of the windows install
    $UnattendFirstLogonCmd = Set-AutoUnattendFirstLogonCmd -Command 'REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d Complete' -Order 1
    
    
    for ($i=1;$i -lt $numDrives; $i++) {
        
    }

    New-AutoUnattendXML -TempUnattend $unattendTemplatePath `
                        -VMName $VMName `
                        -autoUnattendPath $unattendPath `
                        -UnattendDiskConfigSection $UnattendDiskConfigSection `
                        -UnattendRunSyncCmdSpecialize $UnattendRunSyncCmdSpecialise `
                        -UnattendRunSyncCmdOOBE $UnattendFirstLogonCmd
    
    echo "Check AutoUnattend.xml created before continuing"
    Pause
    
    # Create ISO with the autogenerated AutoUnattend.xml file
    dir $unattendPath\autounattend.xml | New-IsoFile -Path $autoISOPath -Media CDR -Title "Unattend"
    
    # Add ISO with Windows Install and AutoUnattend
    if ($vmGen -eq 1) {
        Set-VMDvdDrive -VMName $VMName -Path $windowsISOpath -ControllerNumber 1 -ControllerLocation 0
        Add-VMDvdDrive -VMName $VMName -Path $autoISOPath -ControllerNumber 1 -ControllerLocation 1
        
    } else {
        Add-VMDvdDrive -VMName $VMName -Path $windowsISOPath -ControllerNumber 0 -ControllerLocation ($i+1)
        $bootDevice = Get-VMDvdDrive -VMName $VMName
        Add-VMDvdDrive -VMName $VMName -Path $autoISOPath -ControllerNumber 0 -ControllerLocation ($i+2)        
        Set-VMFirmware -VMName $VMName -FirstBootDevice $bootDevice
        Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

    }

    #Start the VM
    Start-VM -Name $VMName

    if ($showProgress) {
    
        echo ""
        echo "Starting VM Deployment"
        echo ""
        Measure-Command { Wait-VMStatus -statusName "OSInstallStatus" -completeValue "Complete" -VMName $VMName }

        if ((Test-FAVMExistence -VMName $VMName) -and (!(Get-VM -Name $VMName).State -eq "Off")) {
            echo ""
            echo "Starting SQL Server Deployment"
            echo ""
            Measure-Command { Wait-VMStatus -statusName "SQLInstallStatus" -completeValue "Complete" -VMName $VMName }
        }
    }
    
    if ($killVM) {
        echo "When you press enter the Virtual Machine will be stopped and deleted"
        pause
        if (Test-FAVMExistence -VMName $VMName) {
            Stop-VM -Name $VMName -Force -TurnOff
            Remove-VM  -Name $VMName -Force
        }
        for ($i=0;$i -lt $numDrives; $i++) {
            if (Test-Path $vhdPathArray[$i]) { del -Force $vhdPathArray[$i] }
        }
        if (Test-Path $autoISOPath) { del $autoISOPath }
        if (Test-Path ($unattendPath + "\AutoUnattend.xml")) { del ($unattendPath + "\AutoUnattend.xml") }
    }


<#
    Test-FAVMExistence -VMName "Win2012"
    Test-FAVMSwitchexistence -VMSwitchname "vSwitch"
#>
}