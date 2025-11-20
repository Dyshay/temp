# Benchmark compilation time for .NET and Scala Play
# Output: JSON file with compilation times

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Create results directory
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Compilation Time Benchmark"
Write-Host "==================================="

# Function to measure time
function Measure-Command {
    param(
        [ScriptBlock]$Command
    )

    $start = Get-Date
    & $Command
    $end = Get-Date
    $elapsed = ($end - $start).TotalSeconds
    return [math]::Round($elapsed, 2)
}

# Clean previous builds
Write-Host ""
Write-Host "Cleaning previous builds..."
Set-Location "$ProjectRoot\dotnet-api"
if (Test-Path ".\bin") { Remove-Item -Recurse -Force bin -ErrorAction SilentlyContinue }
if (Test-Path ".\obj") { Remove-Item -Recurse -Force obj -ErrorAction SilentlyContinue }

Set-Location "$ProjectRoot\scala-play-api"
if (Test-Path ".\target") { Remove-Item -Recurse -Force target -ErrorAction SilentlyContinue }
if (Test-Path ".\project\target") { Remove-Item -Recurse -Force project\target -ErrorAction SilentlyContinue }
if (Test-Path ".\project\project") { Remove-Item -Recurse -Force project\project -ErrorAction SilentlyContinue }

# Benchmark .NET compilation
Write-Host ""
Write-Host "Benchmarking .NET compilation..."
Set-Location "$ProjectRoot\dotnet-api"

# Restore dependencies
Write-Host "  - Restoring dependencies..."
$DotNetRestoreTime = Measure-Command { dotnet restore *> $null }
Write-Host "    Restore time: ${DotNetRestoreTime}s"

# Build (Release mode)
Write-Host "  - Building (Release)..."
$DotNetBuildTime = Measure-Command { dotnet build -c Release --no-restore *> $null }
Write-Host "    Build time: ${DotNetBuildTime}s"

# Publish
Write-Host "  - Publishing..."
$DotNetPublishTime = Measure-Command { dotnet publish -c Release -o .\publish --no-build *> $null }
Write-Host "    Publish time: ${DotNetPublishTime}s"

$DotNetTotalTime = [math]::Round($DotNetRestoreTime + $DotNetBuildTime + $DotNetPublishTime, 2)
Write-Host "  - Total time: ${DotNetTotalTime}s"

# Benchmark Scala Play compilation
Write-Host ""
Write-Host "Benchmarking Scala Play compilation..."
Set-Location "$ProjectRoot\scala-play-api"

# Update dependencies
Write-Host "  - Updating dependencies..."
$ScalaUpdateTime = Measure-Command { sbt update *> $null }
Write-Host "    Update time: ${ScalaUpdateTime}s"

# Compile
Write-Host "  - Compiling..."
$ScalaCompileTime = Measure-Command { sbt compile *> $null }
Write-Host "    Compile time: ${ScalaCompileTime}s"

# Stage (package)
Write-Host "  - Staging..."
$ScalaStageTime = Measure-Command { sbt stage *> $null }
Write-Host "    Stage time: ${ScalaStageTime}s"

$ScalaTotalTime = [math]::Round($ScalaUpdateTime + $ScalaCompileTime + $ScalaStageTime, 2)
Write-Host "  - Total time: ${ScalaTotalTime}s"

# Generate JSON report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$dotnetFasterBySeconds = [math]::Round($ScalaTotalTime - $DotNetTotalTime, 2)
$dotnetFasterByPercent = [math]::Round((($ScalaTotalTime - $DotNetTotalTime) / $ScalaTotalTime) * 100, 2)

$report = @{
    timestamp = $timestamp
    dotnet = @{
        restore_time_seconds = $DotNetRestoreTime
        build_time_seconds = $DotNetBuildTime
        publish_time_seconds = $DotNetPublishTime
        total_time_seconds = $DotNetTotalTime
    }
    scala_play = @{
        update_time_seconds = $ScalaUpdateTime
        compile_time_seconds = $ScalaCompileTime
        stage_time_seconds = $ScalaStageTime
        total_time_seconds = $ScalaTotalTime
    }
    comparison = @{
        dotnet_faster_by_seconds = $dotnetFasterBySeconds
        dotnet_faster_by_percent = $dotnetFasterByPercent
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\compilation_results.json"

Write-Host "Results saved to: $ResultsDir\compilation_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "Compilation Benchmark Complete"
Write-Host "==================================="
