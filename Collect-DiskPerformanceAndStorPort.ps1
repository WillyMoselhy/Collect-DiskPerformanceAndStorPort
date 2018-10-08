<#
.SYNOPSIS
    Collect Performance Counters and StorPort traces for a specified duration.
.DESCRIPTION
    This script automates the collection of Performance Counters and StorPort traces
    to troubleshoot disk performance issues.
    The script is run for the speified duration with the option to compress output.
.EXAMPLE
    PS C:\> .\Collect-DiskPerformanceAndStorPort.ps1 -FilePrefix Case1234 -PerformanceCounters -StorPortTrace -DurationInMinutes 10

    This will create performance counters and StorPort traces and save them under C:\PerfLogs\Case1234
    The traces will run for 10 minutes
.EXAMPLE
    PS C:\> .\Collect-DiskPerformanceAndStorPort.ps1 -FilePrefix Case1234 -StorPortTrace -DurationInMinutes 10 -Compress

    This will create only StorPort Traces for 10 minutes, the result will be compressed into a ZIP file
.LINK
    https://github.com/WillyMoselhy/Collect-DiskPerformanceAndStorPort
#>
Param(
    # Path to save output
    # Default is C:\PerLogs
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $FolderPath = "C:\PerfLogs",

    # FileName Prefix
    # Default is DiskPerformanceScript
    # Use Case ID for example!
    [Parameter(Mandatory = $false)]
    [string] $FilePrefix = "DiskPerformanceScript",

    # Collect Performance Counters
    [Parameter(Mandatory = $false)]
    [switch] $PerformanceCounters,

    # Collect StorPort traces
    [Parameter(Mandatory = $false)]
    [switch] $StorPortTrace,
       
    # Performance Counters maximum file size
    # Default is 512 MB
    [Parameter(Mandatory = $false)]
    [int] $PerfCountersMaxSizeMB = 512,

    # Performance Counters sample interval
    # Default is one second: 00:00:01
    [Parameter(Mandatory = $false, Position  = 1)]
    [ValidatePattern("^\d\d:\d\d:\d\d$")]
    [string] $PerfCountersInterval = "00:00:01",

    # Storport trace maximum file size
    # Default is 4096 MB
    [Parameter(Mandatory = $false)]
    [int] $StorPortMaxSizeMB = 4096,

    # Tracing duration
    [Parameter(Mandatory = $true)]
    [int] $DurationInMinutes,

    # Compress results into Zip file
    # Does not work on Windows Server 2012 R2
    [Parameter(Mandatory = $false)]
    [switch] $Compress
)
 
#Logging Configuration
$ScriptMode = $false
$HostMode = $true
$Trace = ""
$LogLevel = 0

$ErrorActionPreference = "Stop"
#region: Logging Functions
    
    #This writes the actual output - used by other functions
    function WriteLine ([string]$line,[string]$ForegroundColor, [switch]$NoNewLine){
        if($Script:ScriptMode){
            if($NoNewLine) {
                $Script:Trace += "$line"
            }
            else {
                $Script:Trace += "$line`r`n"
            }
            Set-Content -Path $script:LogPath -Value $Script:Trace
        }
        if($Script:HostMode){
            $Params = @{
                NoNewLine       = $NoNewLine -eq $true
                ForegroundColor = if($ForegroundColor) {$ForegroundColor} else {"White"}
            }
            Write-Host $line @Params
        }
    }
    
    #This handles informational logs
    function WriteInfo([string]$message,[switch]$WaitForResult,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){
        if($WaitForResult){
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message" -NoNewline
        }
        else{
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  
        }
        if($AdditionalStringArray){
                foreach ($String in $AdditionalStringArray){
                    WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$String"     
                }
       
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String"     
            }
       
        }
    }

    #This writes results - should be used after -WaitFor Result in WriteInfo
    function WriteResult([string]$message,[switch]$Pass,[switch]$Success){
        if($Pass){
            WriteLine " - Pass" -ForegroundColor Cyan
            if($message){
                WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Cyan
            }
        }
        if($Success){
            WriteLine " - Success" -ForegroundColor Green
            if($message){
                WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Green
            }
        } 
    }

    #This write highlighted info
    function WriteInfoHighlighted([string]$message,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){ 
        WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  -ForegroundColor Cyan
        if($AdditionalStringArray){
            foreach ($String in $AdditionalStringArray){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
            }
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
            }
        }
    }

    #This write warning logs
    function WriteWarning([string]$message,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){ 
        WriteLine "[$(Get-Date -Format hh:mm:ss)] WARNING: $("`t" * $script:LogLevel)$message"  -ForegroundColor Yellow
        if($AdditionalStringArray){
            foreach ($String in $AdditionalStringArray){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
            }
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
            }
        }
    }

    #This logs errors
    function WriteError([string]$message){
        WriteLine ""
        WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t`t" * $script:LogLevel)$message" -ForegroundColor Red
        
    }

    #This logs errors and terminated script
    function WriteErrorAndExit($message){
        WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t" * $script:LogLevel)$message"  -ForegroundColor Red
        Write-Host "Press any key to continue ..."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
        $HOST.UI.RawUI.Flushinputbuffer()
        Throw "Terminating Error: $message"
    }

#endregion: Logging Functions

#region: Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
    Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
    exit
}
WriteInfo "Script is running with elevated permissions"
#endregion: Verify Running as Admin

#region: Verify Compress-Archive is available
if($Compress){
    WriteInfo "Checking if Microsoft.PowerShell.Archive module is available." -WaitForResult
    if(Get-Module -Name Microsoft.PowerShell.Archive){
        WriteResult -Pass
    }
    else {
        WriteErrorAndExit "Microsoft.PowerShell.Archive module is not available on this system. Please remove -Compress parameter."
    }
}
#endregion: Verify Compress-Archive is available

#region: Prepare Folders
WriteInfo "Prepare Folders"
$LogLevel++

    WriteInfo "Looking for path $FolderPath\$FilePrefix"
    $PathFound = Test-Path -LiteralPath "$FolderPath\$FilePrefix" -PathType Container
    if($PathFound){
        WriteInfo "Folder already exists - will create a new one"
        $LogLevel++
            for ($i = 1; $i -lt 100; $i++) {
                $SuggestedPath = "$FolderPath\$FilePrefix`_$i"
                WriteInfo "Looking for $SuggestedPath"
                if(Test-Path -LiteralPath $SuggestedPath -PathType Container){
                    WriteInfo "Path already exists"
                    continue
                }
                else{
                    $FinalFolderPath = (New-Item -Path $SuggestedPath -ItemType Directory).FullName
                    $FinalFilePrefix = "$FilePrefix`_$i"
                    WriteInfoHighlighted "Created new folder $FinalFolderPath"
                    break
                }
            }
        $LogLevel--
    }
    else{
        WriteInfo "Folder does not exist - will create a new one"
        $FinalFolderPath = (New-Item -Path "$FolderPath\$FilePrefix" -ItemType Directory).FullName
        $FinalFilePrefix = "$FilePrefix"
        WriteInfoHighlighted "Created new folder $FinalFolderPath"
    }

$LogLevel--
#endregion: prepare Folders

#region: Perfomance Counters
if($PerformanceCounters){
    WriteInfo -message "Performance Counters"
    $LogLevel++
        $PerformanceCountersPath = New-Item -Path "$FinalFolderPath\PerformanceCounters" -ItemType Directory
        $CollectionName = "DiskPerformanceScript_$FinalFilePrefix"
        $CollectionFileName = "$PerformanceCountersPath\$FinalFilePrefix`_$env:COMPUTERNAME.blg"
        #$Counters = '"\LogicalDisk(*)\*" "\Memory\*" "\.NET CLR Memory(*)\*" "\Cache\*" "\Network Interface(*)\*" "\Netlogon(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Thread(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*"'
        #$LogManArgs = New-Object System.Collections.ArrayList
        <#$LogManArgs.AddRange(@("create",
                               "counter",
                               $CollectionName,
                               "-o $CollectionFileName",
                               "-f bincirc",
                               "-v mmddhhmm",
                               "-max $PerfCountersMaxSizeMB"))
                               #"-si $PerfCountersInterval"))
                               #"-c $Counters"))#>
        WriteInfo "Creating Performance Counters collection" -WaitForResult
            $PerfCountersCreated = Logman.exe create counter $CollectionName -o "$CollectionFileName" -f bincirc -v mmddhhmm -max $PerfCountersMaxSizeMB -c "\LogicalDisk(*)\*" "\Memory\*" "\.NET CLR Memory(*)\*" "\Cache\*" "\Network Interface(*)\*" "\Netlogon(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Thread(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*" -si $PerfCountersInterval 
            #Logman.exe "$LogManArgs" -c "\LogicalDisk(*)\*" "\Memory\*" "\.NET CLR Memory(*)\*" "\Cache\*" "\Network Interface(*)\*" "\Netlogon(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Thread(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*" -si 
            if($PerfCountersCreated -eq "The command completed successfully."){
                WriteResult -Success -message "Name: $CollectionName - Path: $CollectionFileName"
            }
            else{
                WriteErrorAndExit -message "$PerfCountersCreated"
            }
        WriteInfo "Starting Performance Counters" -WaitForResult
            $PerformanceCountersStarted = logman start $CollectionName
            if($PerformanceCountersStarted -eq "The command completed successfully."){
                WriteResult -Success
            }
            else{
                WriteErrorAndExit -message "$PerformanceCountersStarted"
            }                    
    $LogLevel--
}
#endregion: Perfomance Counters

#region: StorPort Trace
if($StorPortTrace){
    WriteInfo -message "StorPort Trace"
    $LogLevel++
    
    $StorPortTracePath = New-Item -Path "$FinalFolderPath\StorPortTrace" -ItemType Directory
    $StorPortTraceName = "DiskPerformanceScript_$FinalFilePrefix"
    $StorPortTraceFileName = "$StorPortTracePath\$FinalFilePrefix`_$env:COMPUTERNAME.etl"
    
    <#$StorPortArgs = New-Object System.Collections.ArrayList
    $StorPortArgs.AddRange(@("create",
                             "trace",
                             $StorPortTraceName,
                             "-ow",
                             "-o $StorPortTraceFileName",
                             '-p "Microsoft-Windows-StorPort" 0xffffffffffffffff 0xff',
                             "-nb 16 16",
                             "-bs 1024",
                             "-mode Circular",
                             "-f bincirc",
                             "-max $StorPortMaxSizeMB",
                             ,"-ets"))#>
    WriteInfo -message "Creating and starting StorPort trace" -WaitForResult
        $StorPortStarted = logman create trace "$StorPortTraceName" -ow -o $StorPortTraceFileName -p "Microsoft-Windows-StorPort" 0xffffffffffffffff 0xff -nb 16 16 -bs 1024 -mode Circular -f bincirc -max $StorPortMaxSizeMB -ets
        if($StorPortStarted -eq "The command completed successfully."){
            WriteResult -Success -message "Name: $StorPortTraceName - Path: $StorPortTraceFileName"
        }
        else{
            WriteErrorAndExit -message "$StorPortStarted"
        }

    $LogLevel--
}
#endregion: StorPort Trace

#region: Wait for specified duration
if($DurationInMinutes){
    WriteInfo "Waiting for $DurationInMinutes minutes"
        for($i = 0; $i -lt $DurationInMinutes*60 ; $i++){
            $Percentage = ($i / ($DurationInMinutes*60))*100
            Write-Progress -Activity "Waiting for $DurationInMinutes minutes" -PercentComplete $Percentage -SecondsRemaining (($DurationInMinutes*60) - $i) -Id 1
            Start-Sleep -Seconds 1
        }
        Write-Progress -Id 1 -Completed -Activity "Waiting for $DurationInMinutes minutes"
}
#endregion: Wait for specified duration

#region: Stop running traces
WriteInfo -message "Stop running counters and traces"
$LogLevel++

    if($PerformanceCounters){
        WriteInfo "Stopping Performnace counter collection" -WaitForResult
        $PerformanceCountersStopped = logman.exe stop $CollectionName
        if($PerformanceCountersStopped -eq "The command completed successfully."){
            WriteResult -Success
        }
        else{
            WriteErrorAndExit -message "$PerformanceCountersStopped"
        }        
    }

    if($StorPortTrace){
        WriteInfo "Stopping StorPort trace" -WaitForResult
        $StorPortStopped = logman.exe stop $StorPortTraceName -ets
        if($StorPortStopped -eq "The command completed successfully."){
            WriteResult -Success
        }
        else{
            WriteErrorAndExit -message "$StorPortStopped"
        }
    }

$LogLevel--
#endregion: Stop running traces

#region: Compress output
if($Compress){
    WriteInfo "Compressing output"
    $LogLevel++

        $ZipFileName ="$FolderPath\$FinalFilePrefix`_$(Get-Date -Format "yyMMdd-HHmmss").zip"
        Compress-Archive -Path "$FinalFolderPath\*" -DestinationPath $ZipFileName -CompressionLevel Optimal
        WriteInfoHighlighted "Trace files compressed."
        
        WriteInfo "Deleting save folder: $FinalFolderPath" -WaitForResult
        Remove-Item -Path $FinalFolderPath -Recurse
        WriteResult -Success
        
        WriteInfo "Opening compressed file location: $ZipFileName"
        explorer.exe "/select,$ZipFileName"
    
    $LogLevel--
}
else{
    WriteInfo "Opening save folder: $FinalFolderPath"
    explorer.exe $FinalFolderPath
}
#endregion: Compress output

#region: Cleanup Perfomance Counters
if($PerformanceCounters){
    WriteInfo "Cleaning up created Perfmance Counter Collection" -WaitForResult
    $PerformanceCountersDeleted = logman Delete $CollectionName
    if($PerformanceCountersDeleted -eq "The command completed successfully."){
        WriteResult -Success
    }
    else{
        WriteErrorAndExit -message "$PerformanceCountersDeleted"
    }
}
#endregion: Cleanup Perfomance Counters

WriteInfoHighlighted "Script will now terminate"