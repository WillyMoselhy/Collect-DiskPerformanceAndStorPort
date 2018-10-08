# Collect-DiskPerformanceAndStorPort
PowerShell script to collect Performance Counters and StorPort traces for a specified duration.

## Description
This script automates the collection of Performance Counters and StorPort traces
to troubleshoot disk performance issues.
The script is run for the speified duration with the option to compress output.

## Examples
* Performance Counters and StorPort Trace for 10 minutes
```PowerShell
PS C:\> .\Collect-DiskPerformanceAndStorPort.ps1 -FilePrefix "Case1234" -PerformanceCounters -StorPortTrace -DurationInMinutes 10
```
This will create performance counters and StorPort traces and save them under C:\PerfLogs\Case1234
The traces will run for 10 minutes
* Compress results into a ZIP file
```PowerShell
PS C:\> .\Collect-DiskPerformanceAndStorPort.ps1 -FilePrefix "Case1234" -StorPortTrace -DurationInMinutes 10 -Compress
```
This will create only StorPort Traces for 10 minutes, the result will be compressed into a ZIP file
This does not work with Windows Server 2012 R2 or older

## Collected Performance Counters
The following counters are collected:
* \LogicalDisk(*)\*
* \Memory\*
* \.NET CLR Memory(*)\*
* \Cache\* 
* \Network Interface(*)\* 
* \Netlogon(*)\* 
* \Paging File(*)\* 
* \PhysicalDisk(*)\* 
* \Processor(*)\* 
* \Processor Information(*)\* 
* \Process(*)\* 
* \Thread(*)\* 
* \Redirector\* 
* \Server\* 
* \System\* 
* \Server Work Queues(*)\* 
* \Terminal Services\*

## Parameters
| Parameter             | Required | Description                                                                                  | Example                                                |
|-----------------------|----------|----------------------------------------------------------------------------------------------|--------------------------------------------------------|
| Compress              |          | Compress results into Zip file<br> Does not work on Windows Server 2012 R2                   | This is a switch                                       |
| DurationInMinutes     | Yes      | Duration to collect counters and / or traces                                                 | -DurationInMinutes 25                                  |
| FilePrefix            | Yes      | Use to identify the output <br> Case ID is recommended <br> Default is DiskPerformanceScript | -FilePrefix 12345567897654                             |
| FolderPath            |          | Path to save output <br>  Default is C:\PerLogs                                              | -FolderPath C:\Example                                 |
| PerfCountersInterval  |          | Performance Counters sample interval <br> Default is one second: 00:00:01                    | -PerfCountersInterval 00:01:00 <br> This is one minute |
| PerfCountersMaxSizeMB |          | Performance Counters maximum file size <br> Default is 512 MB                                | -PerfCountersMaxSizeMB 256                             |
| PerformanceCounters   |          | Collect Performance Counters                                                                 | This is a switch                                       |
| StorPortMaxSizeMB     |          | Storport trace maximum file size <br> Default is 4096 MB                                     | -StorPortMaxSizeMB 1024                                |
| StorPortTrace         |          | Collect StorPort traces                                                                      | This is a switch                                       |
