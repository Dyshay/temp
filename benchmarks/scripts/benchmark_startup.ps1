# Benchmark startup times (cold, warm, hot) for .NET and Scala Play
# Output: JSON file with startup times

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Create results directory
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Startup Time Benchmark"
Write-Host "==================================="

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ""
Write-Host "Pre-flight checks..."
if ($isAdmin) {
    Write-Host "  Running with Administrator privileges" -ForegroundColor Green
}
else {
    Write-Host "  WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  If cleanup fails, re-run as Administrator" -ForegroundColor Yellow
}

# Function to kill all processes of a specific name
function Stop-ProcessByName {
    param([string]$ProcessName)

    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "  Cleaning up $ProcessName processes..."
        foreach ($proc in $processes) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Host "    Killed process $($proc.Id)" -ForegroundColor Green
            }
            catch {
                Write-Host "    Could not kill process $($proc.Id): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        Start-Sleep -Seconds 1
    }
}

# Function to kill processes using a specific port
function Stop-ProcessOnPort {
    param([int]$Port)

    try {
        $connections = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"
        foreach ($conn in $connections) {
            $parts = $conn -split '\s+' | Where-Object { $_ -ne '' }
            $pid = $parts[-1]
            if ($pid -match '^\d+$') {
                Write-Host "  Killing process $pid on port $Port..."
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            }
        }
    }
    catch {
        # Ignore errors if no process found
    }
}

# Function to measure startup time
function Measure-Startup {
    param([string]$Url)

    $maxAttempts = 60
    $attempt = 0
    $start = Get-Date

    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $end = Get-Date
                $elapsed = ($end - $start).TotalSeconds
                return [math]::Round($elapsed, 3)
            }
        }
        catch {
            # Service not ready yet
        }
        $attempt++
        Start-Sleep -Milliseconds 500
    }

    Write-Error "ERROR: Service did not start in time"
    return 0
}

# Function to test .NET startup
function Test-DotNetStartup {
    param([string]$Type)

    Write-Host "  Testing $Type startup..."

    # Ensure port is free
    Stop-ProcessOnPort -Port 5000

    Set-Location "$ProjectRoot\dotnet-api"

    # Start the application in background
    $process = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden

    # Measure time to first successful response
    # Use 127.0.0.1 instead of localhost to avoid IPv6 timeout issues
    $startupTime = Measure-Startup -Url "http://127.0.0.1:5000/api/hello"

    # Stop the application and all child processes
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Stop-ProcessOnPort -Port 5000

    # Small delay between tests
    Start-Sleep -Seconds 2

    Write-Host "    Startup time: ${startupTime}s"
    return $startupTime
}

# Function to test Scala Play startup
function Test-ScalaStartup {
    param([string]$Type)

    Write-Host "  Testing $Type startup..."

    # Ensure port is free
    Stop-ProcessOnPort -Port 9000

    Set-Location "$ProjectRoot\scala-play-api"

    # Use PowerShell script instead of .bat to avoid Windows "line too long" error
    $startScript = Join-Path $ProjectRoot "scala-play-api\start-play.ps1"

    if (-not (Test-Path $startScript)) {
        throw "Scala Play PowerShell start script not found at: $startScript"
    }

    # Start the application in background using PowerShell
    $process = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$startScript`"" `
        -PassThru -WindowStyle Hidden

    # Measure time to first successful response
    # Use 127.0.0.1 instead of localhost to avoid IPv6 timeout issues
    $startupTime = Measure-Startup -Url "http://127.0.0.1:9000/api/hello"

    # Stop the application and all child processes
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Stop-ProcessOnPort -Port 9000

    # Small delay between tests
    Start-Sleep -Seconds 2

    Write-Host "    Startup time: ${startupTime}s"
    return $startupTime
}

# Initial cleanup - kill any existing dotnet/java processes
Write-Host ""
Write-Host "Cleaning up existing processes..."
Stop-ProcessByName -ProcessName "dotnet"
Stop-ProcessByName -ProcessName "java"

Write-Host ""
Write-Host "Verifying ports are free..."
$port5000Check = netstat -ano | Select-String ":5000" | Select-String "LISTENING"
$port9000Check = netstat -ano | Select-String ":9000" | Select-String "LISTENING"

if ($port5000Check) {
    Write-Host "  WARNING: Port 5000 is still in use after cleanup" -ForegroundColor Red
    Write-Host "  Attempting forced cleanup..." -ForegroundColor Yellow
    Stop-ProcessOnPort -Port 5000
    Start-Sleep -Seconds 2

    # Check again
    $port5000Check = netstat -ano | Select-String ":5000" | Select-String "LISTENING"
    if ($port5000Check) {
        Write-Host "  ERROR: Cannot free port 5000. Please run as Administrator." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  Port 5000 is free" -ForegroundColor Green

if ($port9000Check) {
    Stop-ProcessOnPort -Port 9000
    Start-Sleep -Seconds 1
}
Write-Host "  Port 9000 is free" -ForegroundColor Green

# Ensure applications are built
Write-Host ""
Write-Host "Ensuring applications are built..."

Set-Location "$ProjectRoot\dotnet-api"
if (-not (Test-Path ".\publish")) {
    Write-Host "  Building .NET application..."
    dotnet publish -c Release -o .\publish *> $null
}

Set-Location "$ProjectRoot\scala-play-api"
if (-not (Test-Path ".\target\universal\stage")) {
    Write-Host "  Building Scala Play application..."
    sbt stage *> $null
}

# Test .NET startup times
Write-Host ""
Write-Host "Testing .NET startup times..."

Write-Host "  Cold start (first run after build):"
$DotNetCold = Test-DotNetStartup -Type "cold"

Write-Host "  Warm start (second run):"
$DotNetWarm = Test-DotNetStartup -Type "warm"

Write-Host "  Hot start (third run):"
$DotNetHot = Test-DotNetStartup -Type "hot"

# Calculate average
$DotNetAvg = [math]::Round(($DotNetCold + $DotNetWarm + $DotNetHot) / 3, 3)
Write-Host "  Average: ${DotNetAvg}s"

# Test Scala Play startup times
Write-Host ""
Write-Host "Testing Scala Play startup times..."

Write-Host "  Cold start (first run after build):"
$ScalaCold = Test-ScalaStartup -Type "cold"

Write-Host "  Warm start (second run):"
$ScalaWarm = Test-ScalaStartup -Type "warm"

Write-Host "  Hot start (third run):"
$ScalaHot = Test-ScalaStartup -Type "hot"

# Calculate average
$ScalaAvg = [math]::Round(($ScalaCold + $ScalaWarm + $ScalaHot) / 3, 3)
Write-Host "  Average: ${ScalaAvg}s"

# Generate JSON report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$coldDiff = [math]::Round($ScalaCold - $DotNetCold, 3)
$warmDiff = [math]::Round($ScalaWarm - $DotNetWarm, 3)
$hotDiff = [math]::Round($ScalaHot - $DotNetHot, 3)
$avgDiff = [math]::Round($ScalaAvg - $DotNetAvg, 3)
$dotnetFasterPercent = if ($ScalaAvg -ne 0) {
    [math]::Round((($ScalaAvg - $DotNetAvg) / $ScalaAvg) * 100, 2)
} else {
    0
}

$report = @{
    timestamp = $timestamp
    dotnet = @{
        cold_start_seconds = $DotNetCold
        warm_start_seconds = $DotNetWarm
        hot_start_seconds = $DotNetHot
        average_seconds = $DotNetAvg
    }
    scala_play = @{
        cold_start_seconds = $ScalaCold
        warm_start_seconds = $ScalaWarm
        hot_start_seconds = $ScalaHot
        average_seconds = $ScalaAvg
    }
    comparison = @{
        cold_start_difference_seconds = $coldDiff
        warm_start_difference_seconds = $warmDiff
        hot_start_difference_seconds = $hotDiff
        average_difference_seconds = $avgDiff
        dotnet_faster_by_percent = $dotnetFasterPercent
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\startup_results.json"

Write-Host "Results saved to: $ResultsDir\startup_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "Startup Benchmark Complete"
Write-Host "==================================="
