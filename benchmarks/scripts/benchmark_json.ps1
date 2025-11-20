# Benchmark JSON serialization/deserialization for .NET and Scala Play
# Output: JSON file with serialization performance metrics
# NOTE: This requires /api/json-benchmark endpoint in both applications

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "JSON Serialization Benchmark"
Write-Host "==================================="

# Configuration
$OBJECT_COUNTS = @(100, 1000, 5000, 10000)
$WARMUP_REQUESTS = 10

# Function to wait for service to be ready
function Wait-ForService {
    param([string]$Url)

    Write-Host "  Waiting for service at $Url..."
    $maxAttempts = 30
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "  Service is ready!"
                return $true
            }
        }
        catch {
            # Service not ready yet
        }
        $attempt++
        Start-Sleep -Seconds 2
    }
    Write-Host "  ERROR: Service did not start in time"
    return $false
}

# Function to benchmark JSON
function Benchmark-Json {
    param(
        [string]$Url,
        [int]$Count
    )

    try {
        $body = @{ objectCount = $Count } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $Url -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
        return $response
    }
    catch {
        Write-Host "    Error: $_" -ForegroundColor Red
        return $null
    }
}

# Check if endpoint exists
Write-Host ""
Write-Host "NOTE: This benchmark requires /api/json-benchmark endpoint" -ForegroundColor Yellow
Write-Host "If the endpoint doesn't exist, this benchmark will be skipped" -ForegroundColor Yellow
Write-Host ""

# Ensure applications are built
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

# Start .NET application
Write-Host ""
Write-Host "Starting .NET application..."
Set-Location "$ProjectRoot\dotnet-api"
$dotnetProcess = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden
$DOTNET_PID = $dotnetProcess.Id
Write-Host "  Started with PID: $DOTNET_PID"

$serviceReady = Wait-ForService -Url "http://127.0.0.1:5000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
    throw "Failed to start .NET service"
}

# Check if JSON benchmark endpoint exists
$endpointExists = $false
try {
    $testBody = @{ objectCount = 10 } | ConvertTo-Json
    $testResponse = Invoke-RestMethod -Uri "http://127.0.0.1:5000/api/json-benchmark" -Method Post -Body $testBody -ContentType "application/json" -ErrorAction Stop
    $endpointExists = $true
    Write-Host "  JSON benchmark endpoint found!" -ForegroundColor Green
}
catch {
    Write-Host "  JSON benchmark endpoint not found - using fallback /api/data" -ForegroundColor Yellow
}

if ($endpointExists) {
    # Warmup .NET
    Write-Host "  Warming up..."
    for ($i = 0; $i -lt $WARMUP_REQUESTS; $i++) {
        $warmupBody = @{ objectCount = 100 } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://127.0.0.1:5000/api/json-benchmark" -Method Post -Body $warmupBody -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    }
    Start-Sleep -Seconds 2

    # Benchmark .NET
    Write-Host ""
    Write-Host "Benchmarking .NET JSON serialization..."
    $dotnetResults = @{}

    foreach ($count in $OBJECT_COUNTS) {
        Write-Host "  Testing with $count objects..."

        $totalSerialize = 0
        $totalDeserialize = 0
        $totalSize = 0
        $runs = 5

        for ($run = 0; $run -lt $runs; $run++) {
            $result = Benchmark-Json -Url "http://127.0.0.1:5000/api/json-benchmark" -Count $count
            if ($result) {
                $totalSerialize += $result.serializationTimeMs
                $totalDeserialize += $result.deserializationTimeMs
                $totalSize += $result.jsonSizeBytes
            }
        }

        $avgSerialize = [math]::Round($totalSerialize / $runs, 3)
        $avgDeserialize = [math]::Round($totalDeserialize / $runs, 3)
        $avgSize = [math]::Round($totalSize / $runs, 0)

        Write-Host "    Avg Serialize: ${avgSerialize}ms, Avg Deserialize: ${avgDeserialize}ms, Size: ${avgSize} bytes"

        $dotnetResults[$count.ToString()] = @{
            serializationTimeMs = $avgSerialize
            deserializationTimeMs = $avgDeserialize
            jsonSizeBytes = $avgSize
        }
    }
}
else {
    Write-Host "  Skipping detailed JSON benchmark - endpoint not available" -ForegroundColor Yellow
    $dotnetResults = @{ note = "Endpoint not available" }
}

# Stop .NET
Write-Host ""
Write-Host "Stopping .NET application..."
Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start Scala Play application
Write-Host ""
Write-Host "Starting Scala Play application..."
Set-Location "$ProjectRoot\scala-play-api"

if (-not (Test-Path ".\target\universal\stage")) {
    Write-Host "  Building first..."
    cmd /c sbt stage *> $null
}

# Use PowerShell script instead of .bat to avoid Windows "line too long" error
$startScript = Join-Path $ProjectRoot "scala-play-api\start-play.ps1"

if (-not (Test-Path $startScript)) {
    throw "Scala Play PowerShell start script not found at: $startScript"
}

# Start the application in background using PowerShell
$scalaProcess = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$startScript`"" `
    -PassThru -WindowStyle Hidden

# Wait a bit for Java process to start
Start-Sleep -Seconds 3

# Find the actual Java process (child of PowerShell)
$javaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt (Get-Date).AddSeconds(-10) } |
    Select-Object -First 1

if ($javaProcess) {
    $SCALA_PID = $javaProcess.Id
    Write-Host "  Started with PID: $SCALA_PID (Java process)"
} else {
    $SCALA_PID = $scalaProcess.Id
    Write-Host "  Started with PID: $SCALA_PID (PowerShell wrapper)"
}

$serviceReady = Wait-ForService -Url "http://127.0.0.1:9000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $scalaProcess.Id -Force -ErrorAction SilentlyContinue
    if ($javaProcess) {
        Stop-Process -Id $javaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw "Failed to start Scala Play service"
}

# Check if JSON benchmark endpoint exists
$endpointExists = $false
try {
    $testBody = @{ objectCount = 10 } | ConvertTo-Json
    $testResponse = Invoke-RestMethod -Uri "http://127.0.0.1:9000/api/json-benchmark" -Method Post -Body $testBody -ContentType "application/json" -ErrorAction Stop
    $endpointExists = $true
    Write-Host "  JSON benchmark endpoint found!" -ForegroundColor Green
}
catch {
    Write-Host "  JSON benchmark endpoint not found - skipping" -ForegroundColor Yellow
}

if ($endpointExists) {
    # Warmup Scala Play
    Write-Host "  Warming up..."
    for ($i = 0; $i -lt $WARMUP_REQUESTS; $i++) {
        $warmupBody = @{ objectCount = 100 } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://127.0.0.1:9000/api/json-benchmark" -Method Post -Body $warmupBody -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    }
    Start-Sleep -Seconds 2

    # Benchmark Scala Play
    Write-Host ""
    Write-Host "Benchmarking Scala Play JSON serialization..."
    $scalaResults = @{}

    foreach ($count in $OBJECT_COUNTS) {
        Write-Host "  Testing with $count objects..."

        $totalSerialize = 0
        $totalDeserialize = 0
        $totalSize = 0
        $runs = 5

        for ($run = 0; $run -lt $runs; $run++) {
            $result = Benchmark-Json -Url "http://127.0.0.1:9000/api/json-benchmark" -Count $count
            if ($result) {
                $totalSerialize += $result.serializationTimeMs
                $totalDeserialize += $result.deserializationTimeMs
                $totalSize += $result.jsonSizeBytes
            }
        }

        $avgSerialize = [math]::Round($totalSerialize / $runs, 3)
        $avgDeserialize = [math]::Round($totalDeserialize / $runs, 3)
        $avgSize = [math]::Round($totalSize / $runs, 0)

        Write-Host "    Avg Serialize: ${avgSerialize}ms, Avg Deserialize: ${avgDeserialize}ms, Size: ${avgSize} bytes"

        $scalaResults[$count.ToString()] = @{
            serializationTimeMs = $avgSerialize
            deserializationTimeMs = $avgDeserialize
            jsonSizeBytes = $avgSize
        }
    }
}
else {
    Write-Host "  Skipping detailed JSON benchmark - endpoint not available" -ForegroundColor Yellow
    $scalaResults = @{ note = "Endpoint not available" }
}

# Stop Scala Play
Write-Host ""
Write-Host "Stopping Scala Play application..."
# Stop both PowerShell wrapper and Java process
Stop-Process -Id $scalaProcess.Id -Force -ErrorAction SilentlyContinue
if ($javaProcess) {
    Stop-Process -Id $javaProcess.Id -Force -ErrorAction SilentlyContinue
}
# Also kill any remaining java processes
Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Generate JSON report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$report = @{
    timestamp = $timestamp
    object_counts_tested = $OBJECT_COUNTS
    dotnet = $dotnetResults
    scala_play = $scalaResults
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\json_results.json"

Write-Host "Results saved to: $ResultsDir\json_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "JSON Benchmark Complete"
Write-Host "==================================="
