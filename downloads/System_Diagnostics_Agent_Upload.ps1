<#
  Eclipse Vale Upload Diagnostics Agent

  This agent is visible and consent-based.
  It asks the user with a normal Yes/No window before collecting and sending a report.
  It does not install itself, does not create autorun, and does not read private files.
#>

$ApiUrl = "https://project-ntr90.vercel.app/api/reports"
$DashboardUrl = "https://project-ntr90.vercel.app/admin-reports.html"
$AgentName = "Eclipse Vale Upload Diagnostics Agent"
$AgentVersion = "1.1.0"

function Show-ConsentDialog {
  $message = "This tool will collect technical system diagnostics and send them to your Eclipse Portal dashboard. It will not read personal files, passwords, browser cookies, or documents. Continue?"
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    $result = [System.Windows.MessageBox]::Show($message, $AgentName, "YesNo", "Information")
    return $result -eq "Yes"
  } catch {
    Write-Host $message -ForegroundColor Yellow
    $answer = Read-Host "Continue? Type Y to continue or N to exit"
    return $answer -match "^[Yy]$"
  }
}

function Convert-BytesToGB {
  param([Nullable[double]]$Bytes)
  if ($null -eq $Bytes -or $Bytes -le 0) { return $null }
  return [Math]::Round(($Bytes / 1GB), 2)
}

function Safe-Run {
  param([Parameter(Mandatory=$true)][scriptblock]$Script, $Fallback = $null)
  try { return & $Script } catch { return $Fallback }
}

function Get-IsAdmin {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Eclipse Vale Upload Diagnostics Agent" -ForegroundColor Magenta
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Show-ConsentDialog)) {
  Write-Host "Cancelled by user." -ForegroundColor Red
  Start-Sleep -Seconds 2
  exit 0
}

Write-Host "Collecting system diagnostics..." -ForegroundColor Cyan

$os = Safe-Run { Get-CimInstance Win32_OperatingSystem }
$computer = Safe-Run { Get-CimInstance Win32_ComputerSystem }
$cpu = Safe-Run { Get-CimInstance Win32_Processor }
$bios = Safe-Run { Get-CimInstance Win32_BIOS }
$baseboard = Safe-Run { Get-CimInstance Win32_BaseBoard }
$ramModules = Safe-Run { Get-CimInstance Win32_PhysicalMemory }
$gpus = Safe-Run { Get-CimInstance Win32_VideoController }
$disks = Safe-Run { Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" }
$networkAdapters = Safe-Run { Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" }
$hotfixes = Safe-Run { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 }

$publicIp = Safe-Run {
  $ipInfo = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 4
  $ipInfo.ip
} "Unavailable"

$antivirus = Safe-Run {
  Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct | Select-Object displayName, productState
} @()

$firewallProfiles = Safe-Run {
  Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
} @()

$ramInfo = @()
if ($ramModules) {
  $ramInfo = $ramModules | ForEach-Object {
    [PSCustomObject]@{
      CapacityGB = Convert-BytesToGB $_.Capacity
      SpeedMHz = $_.Speed
      Manufacturer = $_.Manufacturer
      PartNumber = ($_.PartNumber -as [string]).Trim()
      FormFactor = $_.FormFactor
    }
  }
}

$gpuInfo = @()
if ($gpus) {
  $gpuInfo = $gpus | ForEach-Object {
    [PSCustomObject]@{
      Name = $_.Name
      DriverVersion = $_.DriverVersion
      AdapterRAMGB = Convert-BytesToGB $_.AdapterRAM
      VideoProcessor = $_.VideoProcessor
      CurrentResolution = if ($_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution) { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" } else { "Unknown" }
    }
  }
}

$diskInfo = @()
if ($disks) {
  $diskInfo = $disks | ForEach-Object {
    [PSCustomObject]@{
      DeviceID = $_.DeviceID
      FileSystem = $_.FileSystem
      SizeGB = Convert-BytesToGB $_.Size
      FreeSpaceGB = Convert-BytesToGB $_.FreeSpace
      UsedSpaceGB = if ($_.Size -and $_.FreeSpace) { [Math]::Round((($_.Size - $_.FreeSpace) / 1GB), 2) } else { $null }
    }
  }
}

$networkInfo = @()
if ($networkAdapters) {
  $networkInfo = $networkAdapters | ForEach-Object {
    [PSCustomObject]@{
      Description = $_.Description
      DHCPEnabled = $_.DHCPEnabled
      IPAddress = $_.IPAddress
      DefaultGateway = $_.DefaultIPGateway
      DNSServers = $_.DNSServerSearchOrder
    }
  }
}

$latestUpdates = @()
if ($hotfixes) {
  $latestUpdates = $hotfixes | ForEach-Object {
    [PSCustomObject]@{
      HotFixID = $_.HotFixID
      Description = $_.Description
      InstalledOn = if ($_.InstalledOn) { $_.InstalledOn.ToString("yyyy-MM-dd") } else { "Unknown" }
    }
  }
}

$totalMemoryGB = if ($computer.TotalPhysicalMemory) { Convert-BytesToGB $computer.TotalPhysicalMemory } else { $null }
$uptime = if ($os.LastBootUpTime) { New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date) } else { $null }

$report = [PSCustomObject]@{
  metadata = [PSCustomObject]@{
    agentName = $AgentName
    agentVersion = $AgentVersion
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    reportId = [Guid]::NewGuid().ToString()
    consentBased = $true
    uploadMode = "Visible user-confirmed upload"
  }
  system = [PSCustomObject]@{
    computerName = $env:COMPUTERNAME
    userDomain = $env:USERDOMAIN
    isAdministrator = Get-IsAdmin
    powerShellVersion = $PSVersionTable.PSVersion.ToString()
    executionPolicy = Safe-Run { Get-ExecutionPolicy } "Unknown"
  }
  operatingSystem = [PSCustomObject]@{
    caption = $os.Caption
    version = $os.Version
    buildNumber = $os.BuildNumber
    architecture = $os.OSArchitecture
    installDate = if ($os.InstallDate) { $os.InstallDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
    lastBootTime = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
    uptime = if ($uptime) { "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" } else { "Unknown" }
  }
  hardware = [PSCustomObject]@{
    manufacturer = $computer.Manufacturer
    model = $computer.Model
    systemType = $computer.SystemType
    totalMemoryGB = $totalMemoryGB
    baseBoardManufacturer = $baseboard.Manufacturer
    baseBoardProduct = $baseboard.Product
    biosManufacturer = $bios.Manufacturer
    biosVersion = ($bios.SMBIOSBIOSVersion -join " ")
  }
  processor = @($cpu | ForEach-Object {
    [PSCustomObject]@{
      name = $_.Name
      manufacturer = $_.Manufacturer
      cores = $_.NumberOfCores
      logicalProcessors = $_.NumberOfLogicalProcessors
      maxClockSpeedMHz = $_.MaxClockSpeed
      architecture = $_.Architecture
    }
  })
  memoryModules = $ramInfo
  graphics = $gpuInfo
  disks = $diskInfo
  network = [PSCustomObject]@{
    publicIp = $publicIp
    adapters = $networkInfo
  }
  security = [PSCustomObject]@{
    antivirus = $antivirus
    firewallProfiles = $firewallProfiles
    latestHotfixes = $latestUpdates
  }
  privacyExclusions = @(
    "No personal files collected",
    "No browser cookies collected",
    "No saved passwords collected",
    "No private documents collected",
    "No Windows product key collected",
    "No running process list collected"
  )
}

$json = $report | ConvertTo-Json -Depth 12

$desktop = [Environment]::GetFolderPath("Desktop")
if (-not (Test-Path $desktop)) { $desktop = (Get-Location).Path }
$backupPath = Join-Path $desktop ("EclipseVale-UploadedReport-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$json | Out-File -FilePath $backupPath -Encoding UTF8

Write-Host "Uploading report to dashboard..." -ForegroundColor Cyan

try {
  $result = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $json -ContentType "application/json" -TimeoutSec 20
  if ($result.ok -eq $true) {
    Write-Host "Report uploaded successfully." -ForegroundColor Green
    Write-Host "Local backup saved: $backupPath" -ForegroundColor DarkGray
    Start-Process $DashboardUrl
  } else {
    Write-Host "Upload returned an unexpected response." -ForegroundColor Yellow
    Write-Host ($result | ConvertTo-Json -Depth 8)
  }
} catch {
  Write-Host "Upload failed." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Yellow
  Write-Host "Local backup saved: $backupPath" -ForegroundColor DarkGray
}

Write-Host ""
Read-Host "Press Enter to close"
