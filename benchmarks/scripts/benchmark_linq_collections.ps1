# Benchmark LINQ & Collections for .NET and Scala Play
# Output: JSON file with LINQ/Collections performance metrics

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "LINQ & Collections Benchmark"
Write-Host "==================================="
Write-Host ""
Write-Host "NOTE: This benchmark requires /api/linq-benchmark endpoint"
Write-Host ""

# Configuration
$TEST_SIZES = @(1000, 10000, 50000, 100000)

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

# Function to check if endpoint exists
function Test-EndpointExists {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to benchmark LINQ operations
function Benchmark-LinqOperations {
    param(
        [string]$Name,
        [string]$BaseUrl,
        [array]$TestSizes
    )

    Write-Host ""
    Write-Host "Benchmarking $Name LINQ operations..."

    $results = @{}

    foreach ($size in $TestSizes) {
        Write-Host "  Testing with data size: $size"

        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/linq-benchmark/$size" `
                -Method Get `
                -TimeoutSec 30 `
                -ErrorAction Stop

            $results["size_$size"] = @{
                dataSize = $response.dataSize
                linqTimeMs = if ($Name -eq ".NET") { $response.linqTimeMs } else { $response.functionalTimeMs }
                forLoopTimeMs = $response.forLoopTimeMs
                complexLinqTimeMs = if ($Name -eq ".NET") { $response.complexLinqTimeMs } else { $response.complexFunctionalTimeMs }
                linqSlowerByPercent = if ($Name -eq ".NET") { $response.linqSlowerByPercent } else { $response.functionalSlowerByPercent }
                resultCount = $response.resultCount
            }

            Write-Host "    LINQ/Functional: $($results["size_$size"].linqTimeMs)ms, Loop: $($results["size_$size"].forLoopTimeMs)ms"
        }
        catch {
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $results["size_$size"] = @{
                error = $_.Exception.Message
            }
        }
    }

    return $results
}

# Function to benchmark collection operations
function Benchmark-CollectionOperations {
    param(
        [string]$Name,
        [string]$BaseUrl,
        [array]$TestSizes
    )

    Write-Host ""
    Write-Host "Benchmarking $Name collection operations..."

    $results = @{}

    foreach ($size in $TestSizes) {
        Write-Host "  Testing with data size: $size"

        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/collection-benchmark/$size" `
                -Method Get `
                -TimeoutSec 30 `
                -ErrorAction Stop

            $results["size_$size"] = @{
                dataSize = $response.dataSize
                list = $response.list
                array = $response.array
                hashSet = if ($Name -eq ".NET") { $response.hashSet } else { $response.set }
            }

            Write-Host "    List add: $($results["size_$size"].list.addTimeMs)ms, Array add: $($results["size_$size"].array.addTimeMs)ms"
        }
        catch {
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $results["size_$size"] = @{
                error = $_.Exception.Message
            }
        }
    }

    return $results
}

# Ensure applications are built
Write-Host "Ensuring applications are built..."
Write-Host ""

Set-Location "$ProjectRoot\dotnet-api"
if (-not (Test-Path ".\publish")) {
    Write-Host "  Building .NET application..."
    dotnet publish -c Release -o .\publish *> $null
}

# Test .NET
Write-Host ""
Write-Host "Starting .NET application..."
Set-Location "$ProjectRoot\dotnet-api"
$dotnetProcess = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden
Write-Host "  Started with PID: $($dotnetProcess.Id)"

$serviceReady = Wait-ForService -Url "http://127.0.0.1:5000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $dotnetProcess.Id -Force -ErrorAction SilentlyContinue
    throw "Failed to start .NET service"
}

# Check if LINQ endpoint exists
$linqEndpointExists = Test-EndpointExists -Url "http://127.0.0.1:5000/api/linq-benchmark/1000"
$collectionEndpointExists = Test-EndpointExists -Url "http://127.0.0.1:5000/api/collection-benchmark/1000"

if (-not $linqEndpointExists -or -not $collectionEndpointExists) {
    Write-Host "  LINQ or Collection benchmark endpoint not found!" -ForegroundColor Red
    Stop-Process -Id $dotnetProcess.Id -Force -ErrorAction SilentlyContinue

    # Generate placeholder results
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $report = @{
        timestamp = $timestamp
        note = "LINQ/Collection benchmark endpoints not found"
        status = "skipped"
        message = "Endpoints exist in code but service may need rebuild"
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\linq_collections_results.json"
    Write-Host ""
    Write-Host "Placeholder results saved. Please rebuild the applications." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "==================================="
    Write-Host "LINQ Benchmark Skipped"
    Write-Host "==================================="
    exit 0
}

Write-Host "  LINQ benchmark endpoint found!"
Write-Host "  Collection benchmark endpoint found!"

# Benchmark .NET
$dotnetLinqResults = Benchmark-LinqOperations -Name ".NET" -BaseUrl "http://127.0.0.1:5000" -TestSizes $TEST_SIZES
$dotnetCollectionResults = Benchmark-CollectionOperations -Name ".NET" -BaseUrl "http://127.0.0.1:5000" -TestSizes $TEST_SIZES

# Stop .NET
Write-Host ""
Write-Host "Stopping .NET application..."
Stop-Process -Id $dotnetProcess.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Test Scala Play
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

# Check if LINQ endpoint exists
$linqEndpointExists = Test-EndpointExists -Url "http://127.0.0.1:9000/api/linq-benchmark/1000"
$collectionEndpointExists = Test-EndpointExists -Url "http://127.0.0.1:9000/api/collection-benchmark/1000"

if ($linqEndpointExists) {
    Write-Host "  LINQ benchmark endpoint found!"
} else {
    Write-Host "  Warning: LINQ benchmark endpoint not found" -ForegroundColor Yellow
}

if ($collectionEndpointExists) {
    Write-Host "  Collection benchmark endpoint found!"
} else {
    Write-Host "  Warning: Collection benchmark endpoint not found" -ForegroundColor Yellow
}

# Benchmark Scala Play
$scalaLinqResults = @{}
$scalaCollectionResults = @{}

if ($linqEndpointExists) {
    $scalaLinqResults = Benchmark-LinqOperations -Name "Scala Play" -BaseUrl "http://127.0.0.1:9000" -TestSizes $TEST_SIZES
}

if ($collectionEndpointExists) {
    $scalaCollectionResults = Benchmark-CollectionOperations -Name "Scala Play" -BaseUrl "http://127.0.0.1:9000" -TestSizes $TEST_SIZES
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

# Generate report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$report = @{
    timestamp = $timestamp
    status = "completed"
    testSizes = $TEST_SIZES
    dotnet = @{
        linq = $dotnetLinqResults
        collections = $dotnetCollectionResults
    }
    scala_play = @{
        linq = $scalaLinqResults
        collections = $scalaCollectionResults
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\linq_collections_results.json"

Write-Host "Results saved to: $ResultsDir\linq_collections_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "LINQ Benchmark Complete"
Write-Host "==================================="
