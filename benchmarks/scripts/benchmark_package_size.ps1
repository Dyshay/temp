# Benchmark package size for .NET and Scala Play
# Output: JSON file with package sizes

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Create results directory
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Package Size Benchmark"
Write-Host "==================================="

# Function to get directory size in bytes
function Get-DirectorySize {
    param([string]$Path)

    $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum

    if ($null -eq $size) { return 0 }
    return $size
}

# Function to format bytes to human readable
function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -lt 1KB) {
        return "${Bytes}B"
    }
    elseif ($Bytes -lt 1MB) {
        return "{0:N2}KB" -f ($Bytes / 1KB)
    }
    else {
        return "{0:N2}MB" -f ($Bytes / 1MB)
    }
}

# Measure .NET package size
Write-Host ""
Write-Host "Measuring .NET package size..."
Set-Location "$ProjectRoot\dotnet-api"

if (-not (Test-Path ".\publish")) {
    Write-Host "  Building .NET application..."
    dotnet publish -c Release -o .\publish *> $null
}

$DotNetSizeBytes = Get-DirectorySize -Path ".\publish"
$DotNetSizeHuman = Format-Bytes -Bytes $DotNetSizeBytes
$DotNetSizeMB = [math]::Round($DotNetSizeBytes / 1MB, 2)
Write-Host "  - Published size: $DotNetSizeHuman ($DotNetSizeBytes bytes)"

# Count files
$DotNetFileCount = (Get-ChildItem -Path ".\publish" -Recurse -File).Count
Write-Host "  - File count: $DotNetFileCount"

# DLL size
$dllPath = ".\publish\DotNetApi.dll"
$DotNetDllSize = if (Test-Path $dllPath) {
    (Get-Item $dllPath).Length
} else {
    0
}
$DotNetDllSizeHuman = Format-Bytes -Bytes $DotNetDllSize
Write-Host "  - Main DLL size: $DotNetDllSizeHuman ($DotNetDllSize bytes)"

# Measure Scala Play package size
Write-Host ""
Write-Host "Measuring Scala Play package size..."
Set-Location "$ProjectRoot\scala-play-api"

if (-not (Test-Path ".\target\universal\stage")) {
    Write-Host "  Building Scala Play application..."
    sbt stage *> $null
}

$ScalaSizeBytes = Get-DirectorySize -Path ".\target\universal\stage"
$ScalaSizeHuman = Format-Bytes -Bytes $ScalaSizeBytes
$ScalaSizeMB = [math]::Round($ScalaSizeBytes / 1MB, 2)
Write-Host "  - Staged size: $ScalaSizeHuman ($ScalaSizeBytes bytes)"

# Count files
$ScalaFileCount = (Get-ChildItem -Path ".\target\universal\stage" -Recurse -File).Count
Write-Host "  - File count: $ScalaFileCount"

# Lib directory size
$libPath = ".\target\universal\stage\lib"
$ScalaLibSize = if (Test-Path $libPath) {
    Get-DirectorySize -Path $libPath
} else {
    0
}
$ScalaLibSizeHuman = Format-Bytes -Bytes $ScalaLibSize
Write-Host "  - Lib directory size: $ScalaLibSizeHuman ($ScalaLibSize bytes)"

# Generate JSON report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$sizeDiffBytes = $ScalaSizeBytes - $DotNetSizeBytes
$sizeDiffMB = [math]::Round($sizeDiffBytes / 1MB, 2)
$dotnetSmallerPercent = if ($ScalaSizeBytes -ne 0) {
    [math]::Round(($sizeDiffBytes / $ScalaSizeBytes) * 100, 2)
} else {
    0
}

$report = @{
    timestamp = $timestamp
    dotnet = @{
        total_size_bytes = $DotNetSizeBytes
        total_size_mb = $DotNetSizeMB
        total_size_human = $DotNetSizeHuman
        file_count = $DotNetFileCount
        main_dll_size_bytes = $DotNetDllSize
        main_dll_size_human = $DotNetDllSizeHuman
    }
    scala_play = @{
        total_size_bytes = $ScalaSizeBytes
        total_size_mb = $ScalaSizeMB
        total_size_human = $ScalaSizeHuman
        file_count = $ScalaFileCount
        lib_size_bytes = $ScalaLibSize
        lib_size_human = $ScalaLibSizeHuman
    }
    comparison = @{
        size_difference_bytes = $sizeDiffBytes
        size_difference_mb = $sizeDiffMB
        dotnet_smaller_by_percent = $dotnetSmallerPercent
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\package_size_results.json"

Write-Host "Results saved to: $ResultsDir\package_size_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "Package Size Benchmark Complete"
Write-Host "==================================="
