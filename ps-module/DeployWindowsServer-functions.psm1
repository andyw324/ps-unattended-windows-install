﻿function New-IsoFile
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
        [int]$Length
    )

    While ($Array.Length -lt $Length) {
        $Array += $Array[0]
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
                $curLineLenth = 0
            } else {
                Write-Host "." -NoNewline -ForegroundColor Yellow
            }
            $curLineLength += 1
        } else {
            if ($curLineLength -ge $lineLength) {
                Write-Host $newStatus -ForegroundColor White
                $curLineLenth = 0
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
                ""
                $continue = Read-Host -Prompt "The VM has been powered off for more than $timeout seconds. Do you wish to exit the progress status?[Y/N]"
                if ($continue -ne "Y") {
                    $timeoff = 0
                } else {
                    "Warning, user disabled status prompt, VM may still be in-use. Check before removing"
                    ""
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


Function New-AutoUnattendXML
{
    Param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [Parameter(Mandatory=$true)][string]$autoISOPath,
        [Parameter(Mandatory=$true)][string]$windowsISOpath
    )
}


Function New-HyperVWindowsServer
{

    Param(
        [Parameter(Mandatory=$true)][string]$unattendPath,
        [Parameter(Mandatory=$true)][string]$autoISOPath,
        [Parameter(Mandatory=$true)][string]$windowsISOpath,
        [string]$name = "Hyper-V Server 2012",
        [string]$switch = "vSwitch",
        [int]$numCores = 1,
        [long]$ramSize = 2GB,
        [array]$vhdPathArray = @('$path + "\hyper-v.vhd"'),
        [array]$vhdSizeArray = @(10GB),
        [array]$vhdBlockSizeArray = @(32MB),
        [array]$vhdSectorSizeArray = @(512),
        [int]$numDrives = 1,
        [int]$vmGen = 2,
        [string]$setupVHDXPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\SetupFiles.vhdx",
        [switch]$includeSetupVHD,
        [switch]$killVM,
        [switch]$confirmVMSettings,
        [switch]$showProgress
    )


    # Begin script by Albal to create New-VM based on autounattend.xml -
    # Assumes all required files are in, and will be written to <USER>\Downloads
    # Change the below parameters if needed

    if ($confirmVMSettings) {
        # VM Input Parameters:
        "VM Settings:"
        "------------"
        "VM Name: " + $name
        "Cores: " + $numCores
        "RAM: " + $ramSize
        "Switch Name: " + $switch
        ""

        "Virtual Drive Creation Details:"
        "_______________________________"
        for ($i=0;$i -lt $numDrives; $i++) {
            "vhd path: " + $vhdPathArray[$i]
            "Size Array: " + $vhdSizeArray[$i]
            "Block Array: " + $vhdBlockSizeArray[$i]
            "Sector Array: " + $vhdSectorSizeArray[$i]
            "--------------------------------------------------"
            ""
        }
        
        $continue = Read-Host -Prompt "Do you wish to continue with the server deployment using these settings?[Y/N] "

        if ($continue -eq "N") {
            "User aborted process - exiting"
            Return
        }
    }



    $vhdPathArray = Get-PaddedOutArray -Array $vhdPathArray -Length $numDrives
    $vhdSizeArray = Get-PaddedOutArray -Array $vhdSizeArray -Length $numDrives
    $vhdBlockSizeArray = Get-PaddedOutArray -Array $vhdBlockSizeArray -Length $numDrives
    $vhdSectorSizeArray = Get-PaddedOutArray -Array $vhdSectorSizeArray -Length $numDrives
    
    # Don't change anything below this line - ignore the errors below, just in case you run the script again without having exited expectedly

    if (Test-FAVMExistence -VMName $name) {
        Stop-VM -Name $name -Force -TurnOff
        Remove-VM  -Name $name -Force
    }

    if (Test-Path $autoISOPath) { del -Force $autoISOPath }
    for ($i=0;$i -lt $numDrives; $i++) {
        if (Test-Path $vhdPathArray[$i]) { del -Force $vhdPathArray[$i] }
    }

    dir $unattendPath\autounattend.xml | New-IsoFile -Path $autoISOPath -Media CDR -Title "Unattend"

    if (!(Test-FAVMSwitchexistence -VMSwitchname $switch)) { New-VMSwitch -Name $switch -SwitchType Private -Notes "Internal to VMs only" }

    New-VM -Name $name -SwitchName $switch -Generation $vmGen
    Set-VMProcessor -VMName $name -Count $numCores
    Set-VMMemory -VMName $name -StartupBytes $ramSize
    
    if ($includeSetupVHD) {
        $numDrives= 1
    }

    for ($i=0;$i -lt $numDrives; $i++) {
        #"Drive ID = " + ($i+1) + " of size " + $array[$i] + " added"
        New-VHD -Path $vhdPathArray[$i] -BlockSizeBytes $vhdBlockSizeArray[$i] -LogicalSectorSizeBytes $vhdSectorSizeArray[$i] -SizeBytes $vhdSizeArray[$i]
        Add-VMHardDiskDrive -VMName $name -Path $vhdPathArray[$i] -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
    }

    if ($includeSetupVHD) {
        if ((Get-VHD -Path $setupVHDXPath).Attached) {Dismount-VHD -Path $setupVHDXPath}
        Add-VMHardDiskDrive -VMName $name -Path $setupVHDXPath -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
        $i += 1
    } else {

    }

    if ($vmGen -eq 1) {
        Set-VMDvdDrive -VMName $name -Path $windowsISOpath -ControllerNumber 1 -ControllerLocation 0
        Add-VMDvdDrive -VMName $name -Path $autoISOPath -ControllerNumber 1 -ControllerLocation 1
        
    } else {
        Add-VMDvdDrive -VMName $name -Path $windowsISOPath -ControllerNumber 0 -ControllerLocation ($i+1)
        $bootDevice = Get-VMDvdDrive -VMName $name
        Add-VMDvdDrive -VMName $name -Path $autoISOPath -ControllerNumber 0 -ControllerLocation ($i+2)        
        Set-VMFirmware -VMName $name -FirstBootDevice $bootDevice
        Set-VMFirmware -VMName $name -EnableSecureBoot Off

    }
    

    #Add-VMHardDiskDrive -VMName $name -Path $vhdPath -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0
    #Add-VMDvdDrive -VMName $name -Path $windowsISOPath -ControllerNumber 0 -ControllerLocation ($i+1)
    #$bootDevice = Get-VMDvdDrive -VMName $name
    #Add-VMDvdDrive -VMName $name -Path $autoISOPath -ControllerNumber 0 -ControllerLocation ($i+2)

    
    Start-VM -Name $name

    ""
    "Starting VM Deployment"
    ""
    if ($showProgress) {
        Measure-Command { Wait-VMStatus -statusName "OSInstallStatus" -completeValue "Complete" -VMName $name }
    }
    
    if ($killVM) {
        echo "When you press enter the Virtual Machine will be stopped and deleted"
        pause
        if (Test-FAVMExistence -VMName $name) {
            Stop-VM -Name $name -Force -TurnOff
            Remove-VM  -Name $name -Force
        }
        for ($i=0;$i -lt $numDrives; $i++) {
            if (Test-Path $vhdPathArray[$i]) { del -Force $vhdPathArray[$i] }
        }
        if (Test-Path $autoISOPath) { del $autoISOPath }
    }


<#
    Test-FAVMExistence -VMName "Win2012"
    Test-FAVMSwitchexistence -VMSwitchname "vSwitch"
#>
}