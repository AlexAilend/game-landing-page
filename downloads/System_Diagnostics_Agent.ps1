<#
    System_Diagnostics_Agent.ps1
    Eclipse Vale Consent-Based Diagnostics Agent

    SAFE BEHAVIOR:
    - Runs only when the user starts it manually.
    - Shows a consent prompt before collecting data.
    - Does not create persistence or autostart.
    - Does not hide windows or run silently.
    - Does not read personal files, passwords, browser cookies, tokens, or private documents.
    - Does not collect serial numbers, Windows product keys, or saved credentials.
    - Saves a local JSON report and opens the website dashboard for viewing.

    EDIT HERE:
    Change this URL to your real Vercel domain if needed.
#>

$DashboardUrl = "https://project-ntr90.vercel.app/agent-report.html"
$AgentName = "Eclipse Vale Diagnostics Agent"
$AgentVersion = "1.0.0"

function Convert-BytesToGB {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return $null }
    return [Math]::Round(($Bytes / 1GB), 2)
}

function Safe-Run {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Script,
        $Fallback = $null
    )

    try {
        return & $Script
    } catch {
        return $Fallback
    }
}

function Get-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Convert-ToBase64Url {
    param([Parameter(Mandatory=$true)][string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $base64 = [Convert]::ToBase64String($bytes)
    return $base64.TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Eclipse Vale Consent-Based Diagnostics Agent" -ForegroundColor Magenta
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tool will collect a technical device inventory from THIS computer." -ForegroundColor White
Write-Host "It will save a local JSON report and open the website dashboard." -ForegroundColor White
Write-Host ""
Write-Host "It will NOT read personal files, passwords, cookies, tokens, serial numbers, or documents." -ForegroundColor Yellow
Write-Host "It will NOT install anything, hide itself, or create autorun/persistence." -ForegroundColor Yellow
Write-Host ""

$consent = Read-Host "Type I AGREE to continue"
if ($consent -ne "I AGREE") {
    Write-Host "Consent was not provided. Exiting." -ForegroundColor Red
    Start-Sleep -Seconds 2
    exit 0
}

Write-Host ""
Write-Host "Collecting diagnostics..." -ForegroundColor Cyan

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
    Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct |
        Select-Object displayName, productState
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
        storedOnServer = $false
        notes = "Generated locally. The script opens the dashboard for viewing and saves a local JSON file."
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
        "No tokens or SSH keys collected",
        "No serial numbers collected",
        "No Windows product key collected",
        "No running process list collected"
    )
}

$jsonPretty = $report | ConvertTo-Json -Depth 12
$jsonCompact = $report | ConvertTo-Json -Depth 12 -Compress

$desktop = [Environment]::GetFolderPath("Desktop")
if (-not (Test-Path $desktop)) { $desktop = (Get-Location).Path }

$fileName = "EclipseVale-DeviceReport-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss")
$outputPath = Join-Path $desktop $fileName

$jsonPretty | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host ""
Write-Host "Report saved:" -ForegroundColor Green
Write-Host $outputPath -ForegroundColor White

$encoded = Convert-ToBase64Url $jsonCompact
$dashboardWithReport = "$DashboardUrl#report=$encoded"

try {
    if ($dashboardWithReport.Length -lt 7000) {
        Start-Process $dashboardWithReport
        Write-Host "Dashboard opened with the report loaded automatically." -ForegroundColor Green
    } else {
        Start-Process $DashboardUrl
        Write-Host "Dashboard opened. The report is large, so upload the JSON file manually on the page." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not open dashboard automatically. Open this URL manually:" -ForegroundColor Yellow
    Write-Host $DashboardUrl -ForegroundColor White
}

Write-Host ""
Write-Host "Done. You can upload the JSON file to the dashboard if it was not loaded automatically." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to close"
