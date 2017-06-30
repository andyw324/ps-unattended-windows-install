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
    <#
    
    #>
    
    Param(
        [string]$VMSwitchname
    )
    
    $Item = (Get-VMSwitch | Where-Object -Property Name -EQ -Value $VMSwitchname).count
    If($Item -eq '1'){Return $true}else{Return $false}

}

# Function to test whether named VM exists
Function Test-FAVMExistence
{
    <#
    
    #>
    
    Param(
        [string]$VMName
    )
    
    $Item = (Get-VM | Where-Object -Property Name -EQ -Value $VMName).count
    If($Item -eq '1'){Return $true}else{Return $false}

}


function Get-PaddedOutArray
{
    <#
    
    
    
    #>
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
    <#
    
    
    
    
    
    
    #>

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
    <#
    
    
    
    
    #>
    Param(
        [Parameter(Mandatory=$true)][string]$VMName,
        [Parameter(Mandatory=$true)][string]$statusName,
        [Parameter(Mandatory=$true)][string]$completeValue,
        [string]$Command,
        [int]$refreshRateSeconds=2,
        [int]$timeout=10,
        [int]$lineLength=50,
        [switch]$runCmd,
        [string]$runCmdStatus,
        [switch]$hideProgress
    )

    $status = $null
    $timeOff = 0
    $vmStatus="Running"
    $curLineLength = 1
    $cmdRun = $false
    do
    {
        $newStatus = Get-VMCustomStatus -VMName $VMName -GuestParamName $statusName
        if (!($hideProgress)) {
            #$newStatus = Get-VMCustomStatus -VMName $VMName -GuestParamName $statusName
            if ($runCmd) {
                if (($newStatus -eq $runCmdStatus) -and !($cmdRun)) {
                    PowerShell $Command
                    $cmdRun = $True
                }
            }
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
                    Write-Host ""
                    $continue = Read-Host -Prompt "The VM has been powered off for more than $timeout seconds. Do you wish to exit the progress status?[Y/N]"
                    if ($continue -ne "Y") {
                        $timeoff = 0
                    } else {
                        Write-Host "Warning, user disabled status prompt, VM may still be in-use. Check before removing"
                        Write-Host ""
                        break
                    }
                }
            }
        }
        Start-Sleep -Seconds $refreshRateSeconds
    }
    until ($newStatus -eq $completeValue) 
    Write-Host ""
    if ($newStatus -eq $completeValue) {
        Write-Output "Process Completed!"
        Write-Output ""
    } else {
        Write-Output "Some possible error encountered - check deployment before proceeding"
        Write-Output ""
    }
}


function Add-AutoUnattendDisk
{
    Param(
        [switch]$IsBootDisk
    )

    if ($IsBootDisk) {
                
        $Pass1_DiskConfig = '                    <CreatePartitions>
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
                    </CreatePartitions>'
    } else {
        $Pass1_DiskConfig = '                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>1</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>'
    }

    return $Pass1_DiskConfig

}


function Set-AutoUnattendDisk
{
    Param(
        [string]$DriveLetter,
        [switch]$IsBootDisk,
        [switch]$IsSetupDisk
    )
    if ($IsBootDisk -or $IsSetupDisk) {
        $Pass1_DiskConfig = '                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>2</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>'
    } else {
        $Pass1_DiskConfig = '                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Letter>' + $DriveLetter + '</Letter>
                            <PartitionID>1</PartitionID>
                            <Order>1</Order>
                        </ModifyPartition>
                    </ModifyPartitions>'
        
    }

    return $Pass1_DiskConfig
}


function Set-AutoUnattendRunSyncCmd
{
    Param(
        [Parameter(Mandatory=$True)][string]$Command,
        [Parameter(Mandatory=$True)][int]$Order,
        [string]$Description = "None Provided",
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
        [string]$Description = "None Provided",
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
        [Parameter(Mandatory=$true)][string]$adminPWD,
        [Parameter(Mandatory=$true)][string]$autologinPWD,
        [Parameter(Mandatory=$true)][string]$adminUserName,
        [string]$UnattendDiskConfigSection = "",
        [string]$UnattendRunSyncCmdSpecialize = "",
        [string]$UnattendRunSyncCmdOOBE = "",
        [string]$FullName ="NotDefined",
        [string]$OrganisationName = "NotDefined"
    )
    
    $DefaultWinAdminPWD="UABhAHMAcwB3AG8AcgBkADEAMgAzACEAQQBkAG0AaQBuAGkAcwB0AHIAYQB0AG8AcgBQAGEAcwBzAHcAbwByAGQA"
    $DefaultWinAutoLoginPWD="UABhAHMAcwB3AG8AcgBkADEAMgAzACEAUABhAHMAcwB3AG8AcgBkAA=="


    $findString = "[[--DiskConfig--]]"
    $NewUnattendXM = (Get-Content $TempUnattend) | foreach {$_.replace($findString,$UnattendDiskConfigSection)}    
    $findString = "[[--ComputerName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$VMName)}
    $findString = "[[--RunSyncSpecializePass--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$UnattendRunSyncCmdSpecialize)}
    $findString = "[[--RunSyncOOBEPass--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$UnattendRunSyncCmdOOBE)}
    $findString = "[[--OrganisationName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$OrganisationName)}
    $findString = "[[--RegOrganisationName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$OrganisationName)}
    $findString = "[[--FullName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$FullName)}

    $findString = "[[--AutoLoginPwd--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$autologinPWD)}
    
    $findString = "[[--AutoLoginPlainText--]]"
    if ($autologinPWD -eq $DefaultWinAutoLoginPWD) {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"False")}
    } else {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"True")}
    }

    $findString = "[[--AdminUserName--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$adminUserName)}
    $findString = "[[--AdminPwd--]]"
    $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,$adminPWD)}
    
    $findString = "[[--AdminPwdPlainText--]]"
    if ($adminPWD -eq $DefaultWinAdminPWD) {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"False")}
    } else {
        $NewUnattendXM = $NewUnattendXM | foreach {$_.replace($findString,"True")}
    }


    Set-Content ($autoUnattendPath + "\AutoUnattend.xml") ( $NewUnattendXM | ? {$_.trim() } ) -Encoding UTF8
}

Function New-SQLServerConfigFile
{
    Param(
        [Parameter(Mandatory=$true)][string]$TempConfig,
        [Parameter(Mandatory=$true)][ValidateLength(1,15)][string]$COMPUTERNAME,
        [string]$SQLSERVERFEATURES = "SQLENGINE,DQ,AS,DQC,CONN,IS,BC,SDK,BOL,SNAC_SDK",
        [string]$MSSQLINSTANCENAME = "MSSQLSERVER",
        [string]$INSTALLDRIVE = "C",
        [string]$DATADRIVE ="C",
        [string]$LOGDRIVE ="C",
        [string]$BACKUPDRIVE = "C",
        [string]$TEMPDBDRIVE = "C"
    )
    
    $findString = "<<--SQLSERVERFEATURES-->>"
    $NewSQLConf = (Get-Content $TempConfig) | foreach {$_.replace($findString,$SQLSERVERFEATURES)}
    $findString = "<<--MSSQLINSTANCENAME-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$MSSQLINSTANCENAME)}
    $findString = "<<--INSTALLDRIVE-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$INSTALLDRIVE)}
    $findString = "<<--DATADRIVE-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$DATADRIVE)}
    $findString = "<<--LOGDRIVE-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$LOGDRIVE)}
    $findString = "<<--BACKUPDRIVE-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$BACKUPDRIVE)}
    $findString = "<<--TEMPDBDRIVE-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$TEMPDBDRIVE)}
    $findString = "<<--COMPUTERNAME-->>"
    $NewSQLConf = $NewSQLConf | foreach {$_.replace($findString,$COMPUTERNAME)}    


    return $NewSQLConf
}
########## possibly create new ps1 script containing below as function and following function as the run script for ansible task
Function Test-SMBShareName {
<#
    Test whether a SMBShare name is already in use.
    Will append provided name with incremental number if name already in use
#>

    Param(
        [Parameter(Mandatory=$True)][string]$Name
    )
    $i = 1
    $TestName = $Name
    While ( (Get-SmbShare | Where-Object {$_.Name -eq $TestName}).Path.Count -eq 1)
    {
        $TestName = $Name + '_' + $i
        $i += 1
    }
    Return $TestName

}


Function Set-SMBSharePermissions {
<#

    This function will create a new folder share (if not already exists) and grant 'ReadAndExecute'
    rights [default setting, can overwrite] to a specific user

#>

    Param(
        [Parameter(Mandatory=$True)][string]$Path,
        [Parameter(Mandatory=$True)][string]$Name,
        [Parameter(Mandatory=$True)][string]$UserName,
        [ValidateSet('ReadAndExecute','FullControl')][string]$FileSystemRights = 'ReadAndExecute',
        [string]$Description
    )

    if ( (Get-SmbShare | Where-Object {$_.Path -eq $Path}).Path.Count -eq 0) {

        $Name = Test-SMBShareName -Name $Name
        New-SmbShare -Name $Name -Path $Path §
                     -FullAccess 'BUILTIN\Administrators, Everyone' `
                     -Description $Description
    }

    $acl = Get-Acl -Path $Path
    $perm = $UserName, $FileSystemRights, 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perm
    $acl.SetAccessRule($rule)
    $acl | Set-Acl -Path $Path

    Write-Output "Shared '$Path' with the name '$Name' and added the following ACL permissions:" $rule

}
############### see comment above

Function New-HyperVWindowsServer
{
    <#
    
    #>
    
    
    Param(
        [Parameter(Mandatory=$true)][string]$unattendPath,
        [Parameter(Mandatory=$true)][string]$autoISOPath,
        [Parameter(Mandatory=$true)][string]$windowsISOpath,
        [Parameter(Mandatory=$true)][string]$unattendTemplatePath,
        [string]$VMName = "Hyper-V Server 2012",
        [string]$VMSwitch = "vSwitch",
        [int]$numCores = 1,
        [long]$ramSize = 2GB,
        [array]$vhdPathArray = @('$path + "\hyper-v.vhd"'),
        [array]$vhdSizeArray = @(10GB),
        [array]$vhdBlockSizeArray = @(32MB),
        [array]$vhdSectorSizeArray = @(512),
        [array]$vhdAllocationUnitSize = @(4KB),
        [array]$vhdDriveLetter = @('C'),
        [array]$vhdLabelArray = @(''),
        [int]$numDrives = 1,
        [int]$vmGen = 2,
        [string]$setupVHDXPath = "C:\Users\ABCD Family Admin\Documents\Hyper-V\SetupFiles.vhdx",
        [string]$DeploymentScriptPath,
        [switch]$includeSetupVHD,
        [switch]$killVM,
        [switch]$confirmVMSettings,
        [switch]$showProgress,
        [string]$SQLConfigTemplatePath,
        [string]$SQLSERVERFEATURES,
        [switch]$FixIPAddress,
        [string]$IPAddress,
        [string]$DefaultGateway,
        [string]$WinAdminPWD="UABhAHMAcwB3AG8AcgBkADEAMgAzACEAQQBkAG0AaQBuAGkAcwB0AHIAYQB0AG8AcgBQAGEAcwBzAHcAbwByAGQA",
        [string]$WinAutoLoginPWD="UABhAHMAcwB3AG8AcgBkADEAMgAzACEAUABhAHMAcwB3AG8AcgBkAA==",
        [string]$AdminUserName="Administrator",
        [switch]$InstallSSMS,
        [string]$LogFileSSMS,
        [switch]$InstallSSDT,
        [switch]$LogFileSSDT,
        [switch]$InstallPBI,
        [string]$pbirsInstallDirectory,
        [string]$LogFilePBIRS,
        [string]$pbirsProdKey,
        [switch]$dryRun

    )

# 
# 
# 
# 
# 

    # Define and set some baseline parameters
    $FirstLogonCommandOrder = 1
    $SpecialiseRunSyncCommandOrder = 1
    $InitPartFormatDrives = 'Write-Output "Begining Initializing, partitioning and formatting system disks"'


    #Pad out arrays
    $vhdPathArray = Get-PaddedOutArray -Array $vhdPathArray -Length $numDrives
    $vhdSizeArray = Get-PaddedOutArray -Array $vhdSizeArray -Length $numDrives
    $vhdBlockSizeArray = Get-PaddedOutArray -Array $vhdBlockSizeArray -Length $numDrives
    $vhdSectorSizeArray = Get-PaddedOutArray -Array $vhdSectorSizeArray -Length $numDrives
    $vhdLabelArray = Get-PaddedOutArray -Array $vhdLabelArray -Length $numDrives
    $vhdDriveLetter = Get-PaddedOutArray -Array $vhdDriveLetter -Length $numDrives -IsDriveLetter

    
# 
# 
# 
# 
# 
    
    if ($confirmVMSettings -or $dryRun) {
        # VM Input Parameters:
        Write-Output "VM Settings:"
        Write-Output "------------"
        Write-Output "VM Name: $VMName"
        Write-Output "Cores: $numCores"
        Write-Output "RAM: $ramSize"
        Write-Output "Switch Name: $VMSwitch"
        Write-Output ""

        Write-Output "Virtual Drive Creation Details:"
        Write-Output "_______________________________"
        for ($i=0;$i -lt $numDrives; $i++) {
            Write-Output ('vhd path: ' + $vhdPathArray[$i])
            Write-Output ('Size: ' + $vhdSizeArray[$i])
            Write-Output ('Block Size: ' + $vhdBlockSizeArray[$i])
            Write-Output ('Sector Size: ' + $vhdSectorSizeArray[$i])
            Write-Output ('Allocation Unit Size: ' + $vhdAllocationUnitSize[$i])
            Write-Output ('Drive Letter: ' + $vhdDriveLetter[$i])
            Write-Output ('Drive Label: ' + $vhdLabelArray[$i])
            Write-Output '--------------------------------------------------'
            Write-Output ''
        }
        
        if ($confirmVMSettings) {
            $continue = Read-Host -Prompt "Do you wish to continue with the server deployment using these settings?[Y/N] "
            if ($continue -eq "N") {
                Write-Output "User aborted process - exiting"
                Return
            }
        }

        if ($dryRun) {
            Write-Output "Dry run only - nothing started"
            return
        }

    }

# 
# 
# 
# 
# 

    # Clear out existing VMs of the same name and virtual HDD and relevant ISOs
    if (Test-FAVMExistence -VMName $VMName) {
        Stop-VM -Name $VMName -Force -TurnOff
        Remove-VM  -Name $VMName -Force
    }

#
    if (Test-Path $autoISOPath) { del -Force $autoISOPath }
    for ($i=0;$i -lt $numDrives; $i++) {
        if (Test-Path $vhdPathArray[$i]) { del -Force $vhdPathArray[$i] }
    }

#
    if (Test-Path ($unattendPath + "\AutoUnattend.xml")) { del ($unattendPath + "\AutoUnattend.xml") }

# 
# 
# 
# 
# 

    # Check defined virtual switch exists. If not then create a Private Vitual Switch
    if (!(Test-FAVMSwitchexistence -VMSwitchname $VMSwitch)) { New-VMSwitch -Name $VMSwitch -SwitchType Private -Notes "Internal to VMs only" }

    # Begin creating the VM and setting the relevant settings
    New-VM -Name $VMName -SwitchName $VMSwitch -Generation $vmGen
    Set-VMProcessor -VMName $VMName -Count $numCores
    Set-VMMemory -VMName $VMName -StartupBytes $ramSize


# 
# 
# 
# 
# 
#

    # Create and add Virtual HDDs and generate Disk Configuration settings for the Unattended Answer File (AutoUnattend.xml)
    $UnattendDiskConfigSection = "`n"   
    for ($i=0;$i -lt $numDrives; $i++) {
        New-VHD -Path $vhdPathArray[$i] -BlockSizeBytes $vhdBlockSizeArray[$i] -LogicalSectorSizeBytes $vhdSectorSizeArray[$i] -SizeBytes $vhdSizeArray[$i]
        Add-VMHardDiskDrive -VMName $VMName -Path $vhdPathArray[$i] -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
        
        $UnattendDiskConfigSection += '                <Disk wcm:action="add">'
        if ($i -eq 0) {
            $UnattendDiskConfigSection += "`r`n" + (Add-AutoUnattendDisk -DiskNumber $i -IsBootDisk)
            $UnattendDiskConfigSection += "`r`n" + (Set-AutoUnattendDisk -DiskNumber $i -IsBootDisk -DriveLetter $vhdDriveLetter[$i])
        } else {
            $InitPartFormatDrives += "`r`nGet-Disk -Number $i | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -DriveLetter " + ($vhdDriveLetter[$i]) + " | Format-Volume -FileSystem NTFS -NewFileSystemLabel " + ($vhdLabelArray[$i]) + " -AllocationUnitSize " + ( $vhdAllocationUnitSize[$i]) + ' -Confirm:$False'
        }
        $UnattendDiskConfigSection += "`r`n" + '                    <DiskID>' + $i + '</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
    }


# 
# 
# 
# 
# 
#
#

    # Attach a pre-formatted virtual HDD that houses the relevant setupfiles needed. Assign this to Drive "Z" for easy reference to auto setup scripts etc
    # to be included in the autounattend.xml file.
    if ($includeSetupVHD) {
        # Check whether setup vhdx is already attached to a VM
        if ((Get-VHD -Path $setupVHDXPath).Attached) 
        {
            if ((Get-VMHardDiskDrive -VMName $VMName | where {$_.Path -eq $setupVHDXPath}) -ne $null)
            {
                Get-VMHardDiskDrive -VMName $VMName | where {$_.Path -eq $setupVHDXPath} | Remove-VMHardDiskDrive
            } else {
                Dismount-VHD -Path $setupVHDXPath
            }
        }

        # Add custom scripts to be called from the FirstLogonCommands during the OODE Pass of the windows install
        $setupDisk = Mount-VHD –Path $setupVHDXPath –PassThru | Get-Disk | Get-Partition | Get-Volume

#

        if (Test-Path -Path ($setupDisk.DriveLetter + ':\temp')) {Remove-Item ($setupDisk.DriveLetter + ':\temp') -Force -Recurse}
        if (Test-Path -Path ($setupDisk.DriveLetter + ':\Deployment_Scripts')) {Remove-Item ($setupDisk.DriveLetter + ':\Deployment_Scripts') -Force -Recurse}
 
 
 #
 
        mkdir ($setupDisk.DriveLetter + ':\temp')

        Set-Content ($setupDisk.DriveLetter + ':\temp\ConfigDrives.ps1') $InitPartFormatDrives -Encoding UTF8
    
        if ($DeploymentScriptPath -ne "") {
            Copy-Item $DeploymentScriptPath -Destination ($setupDisk.DriveLetter + ':\Deployment_Scripts') -Recurse
        }


#

        if ($SQLConfigTemplatePath -ne "") {
            $SQLConfigFileContent = ( New-SQLServerConfigFile -TempConfig $SQLConfigTemplatePath `
                                                            -COMPUTERNAME $VMName `
                                                            -MSSQLINSTANCENAME TESTSQLSVR `
                                                            -INSTALLDRIVE S `
                                                            -DATADRIVE D `
                                                            -LOGDRIVE E `
                                                            -TEMPDBDRIVE F `
                                                            -BACKUPDRIVE G `
                                                            -SQLSERVERFEATURES $SQLSERVERFEATURES)
            Set-Content ($setupDisk.DriveLetter + ':\temp\ConfigurationFile.ini') $SQLConfigFileContent -Encoding UTF8
        }

#

        Set-Content ($setupDisk.DriveLetter + ':\temp\logDotNetInstall.ps1') "Write-Output 'Installing .Net Framework v4.5.2' `r`nZ:\Deployment_Scripts\LatestDotNetFramework_Deployment.ps1 -Force -DoRestart | Out-File C:\automation_log -Append" -Encoding UTF8
        if ($pbirsProdKey -ne "") {
            Set-Content ($setupDisk.DriveLetter + ':\temp\logPBIInstall.ps1') "Write-Output 'Installing Power BI Report Server' `r`nZ:\Deployment_Scripts\PowerBIReportServer_Deployment.ps1 -InstallDirectory $pbirsInstallDirectory -logLocation $LogFilePBIRS -productKey $pbirsProdKey | Out-File C:\automation_log -Append" -Encoding UTF8
        } else {
            Set-Content ($setupDisk.DriveLetter + ':\temp\logPBIInstall.ps1') "Write-Output 'Installing Power BI Report Server' `r`nZ:\Deployment_Scripts\PowerBIReportServer_Deployment.ps1 -InstallDirectory $pbirsInstallDirectory -logLocation $LogFilePBIRS | Out-File C:\automation_log -Append" -Encoding UTF8
        }
        Set-Content ($setupDisk.DriveLetter + ':\temp\logSQLInstall.ps1') "Write-Output 'Installing SQL Server 2016' `r`nZ:\Deployment_Scripts\SQL_Server_Deployment.ps1 -ConfigFilePath Z:\temp\ConfigurationFile.ini -Restart | Out-File C:\automation_log -Append" -Encoding UTF8

        


#
#
#
#
#
#

#

        Dismount-VHD -Path $setupVHDXPath

        # Add setup VHD to VM
        Add-VMHardDiskDrive -VMName $VMName -Path $setupVHDXPath -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
        $setupDisk = Get-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $i
        $setupDiskNumber = $i
        $UnattendDiskConfigSection += "`r`n" + '                <Disk wcm:action="add">'
        $UnattendDiskConfigSection += "`r`n" + (Set-AutoUnattendDisk -DiskNumber $i -IsSetupDisk -DriveLetter "Z")
        $UnattendDiskConfigSection += "`r`n" + '                    <DiskID>' + $i + '</DiskID>
                    <WillWipeDisk>false</WillWipeDisk>
                </Disk>'
    }


#
#
#
#
#
#

#

    # Create the relevant runSynchronous commands to be run during the Specialise pass of the Windows install
    $UnattendRunSyncCmdSpecialise += "`r`n" + (Set-AutoUnattendRunSyncCmd -Command 'REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d Specialize-Pass' -Order $SpecialiseRunSyncCommandOrder)
    $SpecialiseRunSyncCommandOrder += 1
    

#

    # Create the relevant FirstLogonCommand commands to be run during the OOBE pass of the windows install

#
    if (($IPAddress -ne "") -and ($DefaultGateway -ne "")) {
        $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command ('PowerShell -Command "Get-NetIPConfiguration | New-NetIPAddress -IPAddress ' + $IPAddress + ' -PrefixLength 24 -DefaultGateway ' + $DefaultGateway + '"') -Order $FirstLogonCommandOrder)
        $FirstLogonCommandOrder += 1
    }


#

    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command ('PowerShell Set-Disk ' + $setupDiskNumber + ' -IsOffline $false') -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1
 
 
 #
 
 
 
 
 
 
 
 
 
 
 
 
 
 
    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command 'PowerShell Z:\temp\ConfigDrives.ps1' -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1
 

    #
    
    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command 'PowerShell Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -Enabled True' -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1 


 #
 
    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command 'REG ADD "HKLM\SOFTWARE\MICROSOFT\Virtual Machine\Guest" /f /v OSInstallStatus /t REG_SZ /d Complete' -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1


































































    # Include some sort of check for .Net version before commencing with install???
    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command 'PowerShell Z:\temp\logDotNetInstall.ps1' -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1
    
#  
    $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command "Echo Skipped due to restart" -Order $FirstLogonCommandOrder)
    $FirstLogonCommandOrder += 1
    
#   
    if ($InstallPBI) {
        $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command ('PowerShell Z:\temp\logPBIInstall.ps1') -Order $FirstLogonCommandOrder)
        $FirstLogonCommandOrder += 1

#
        # $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command "Echo Skipped due to restart" -Order $FirstLogonCommandOrder)
        # $FirstLogonCommandOrder += 1
    }

#
    if ($SQLConfigTemplatePath -ne "") {
        $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command 'PowerShell Z:\Deployment_Scripts\SQL_Server_Deployment.ps1 -ConfigFilePath Z:\temp\ConfigurationFile.ini' -Order $FirstLogonCommandOrder)
        $FirstLogonCommandOrder += 1

#
        $UnattendFirstLogonCmd += "`r`n" + (Set-AutoUnattendFirstLogonCmd -Command "Echo Skipped due to restart" -Order $FirstLogonCommandOrder)
        $FirstLogonCommandOrder += 1
    }

#
#
#
#
#
#    

    New-AutoUnattendXML -TempUnattend $unattendTemplatePath `
                        -VMName $VMName `
                        -autoUnattendPath $unattendPath `
                        -UnattendDiskConfigSection $UnattendDiskConfigSection `
                        -UnattendRunSyncCmdSpecialize $UnattendRunSyncCmdSpecialise `
                        -UnattendRunSyncCmdOOBE $UnattendFirstLogonCmd `
                        -autologinPWD $WinAutoLoginPWD `
                        -adminPWD $WinAdminPWD `
                        -adminUserName $AdminUserName

    
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

#
#
#
#
#

    #Start the VM
    Start-VM -Name $VMName

    if ($showProgress) {
    
        Write-Output ""
        Write-Output "Starting VM Deployment"
        Write-Output ""
        Measure-Command { Wait-VMStatus -statusName "OSInstallStatus" -completeValue "Complete" -VMName $VMName -Command "Get-VMDvdDrive -VMName $VMName | Remove-VMDvdDrive" -runCmd -runCmdStatus "Specialize-Pass" }

        Write-Output "Installing latest .Net Framework"
        Write-Output ""
        Measure-Command { Wait-VMStatus -statusName "DotNetInstallStatus" -completeValue "Complete" -VMName $VMName }

        if ((Test-FAVMExistence -VMName $VMName) -and ((Get-VM -Name $VMName).State -eq "Running") -and ($InstallPBI)) {
            Write-Output ""
            Write-Output "Starting Power BI Report Server Deployment"
            Write-Output ""
            Measure-Command { Wait-VMStatus -statusName "PBIRSInstallStatus" -completeValue "Complete" -VMName $VMName }
        }

        if ((Test-FAVMExistence -VMName $VMName) -and ((Get-VM -Name $VMName).State -eq "Running") -and ($SQLConfigTemplatePath -ne "")) {
            Write-Output ""
            Write-Output "Starting SQL Server Deployment"
            Write-Output ""
            Measure-Command { Wait-VMStatus -statusName "SQLInstallStatus" -completeValue "Complete" -VMName $VMName }
        }


    } else {

        Write-Output "Starting VM Deployment"
        Measure-Command { Wait-VMStatus -statusName "OSInstallStatus" -completeValue "Complete" -VMName $VMName -Command "Get-VMDvdDrive -VMName $VMName | Remove-VMDvdDrive" -runCmd -runCmdStatus "Specialize-Pass" -hideProgress }

        Write-Output "Installing latest .Net Framework"
        Measure-Command { Wait-VMStatus -statusName "DotNetInstallStatus" -completeValue "Complete" -VMName $VMName -hideProgress }

        if ((Test-FAVMExistence -VMName $VMName) -and ((Get-VM -Name $VMName).State -eq "Running") -and ($InstallPBI)) {
            Write-Output "Starting Power BI Report Server Deployment"
            Measure-Command { Wait-VMStatus -statusName "PBIRSInstallStatus" -completeValue "Complete" -VMName $VMName -hideProgress }
        }

        if ((Test-FAVMExistence -VMName $VMName) -and ((Get-VM -Name $VMName).State -eq "Running") -and ($SQLConfigTemplatePath -ne "")) {
            Write-Output "Starting SQL Server Deployment"
            Measure-Command { Wait-VMStatus -statusName "SQLInstallStatus" -completeValue "Complete" -VMName $VMName -hideProgress }
        }


    }

#
#
#
#
#

    # Need to include script to copy over install files or figure out way of tracking when silent installs of SSMS SSDT PBIRS etc complete.

    # Remove drive from VM
    $setupDisk | Remove-VMHardDiskDrive
    # Mount drive locally
    $setupDisk = Mount-VHD –Path $setupVHDXPath –PassThru | Get-Disk | Get-Partition | Get-Volume
    # Remove temp files to prevent wrong scripts being run
    if (Test-Path -Path ($setupDisk.DriveLetter + ':\temp')) {Remove-Item ($setupDisk.DriveLetter + ':\temp') -Force -Recurse}
    if (Test-Path -Path ($setupDisk.DriveLetter + ':\Deployment_Scripts')) {Remove-Item ($setupDisk.DriveLetter + ':\Deployment_Scripts') -Force -Recurse}
    Dismount-VHD -Path $setupVHDXPath


#
#
#
#
#

    if ($killVM) {
        Write-Output "When you press enter the Virtual Machine will be stopped and deleted"
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

    #Add in clean up tasks - to include clean up of setup.vhdx and removal of autounattend.xml from windows

}