# Fix port conflict and run startup benchmark
# Run this script as Administrator if you get permission errors

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Fixing Port Conflicts and Running Benchmark" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "Running with Administrator privileges" -ForegroundColor Green
}
else {
    Write-Host "WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "If port cleanup fails, re-run as Administrator" -ForegroundColor Yellow
}
Write-Host ""

# Kill all dotnet and java processes that might be using the ports
Write-Host "Cleaning up processes..."

# Get all dotnet processes
$dotnetProcesses = Get-Process -Name "dotnet" -ErrorAction SilentlyContinue
if ($dotnetProcesses) {
    foreach ($proc in $dotnetProcesses) {
        Write-Host "  Killing dotnet process $($proc.Id)..."
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "    Success" -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "  No dotnet processes found" -ForegroundColor Green
}

# Get all java processes
$javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
if ($javaProcesses) {
    foreach ($proc in $javaProcesses) {
        Write-Host "  Killing java process $($proc.Id)..."
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "    Success" -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "  No java processes found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Waiting for ports to release..."
Start-Sleep -Seconds 3

# Verify ports are free
Write-Host "Verifying ports are free..."
$port5000 = netstat -ano | Select-String ":5000" | Select-String "LISTENING"
$port9000 = netstat -ano | Select-String ":9000" | Select-String "LISTENING"

if ($port5000) {
    Write-Host "  ERROR: Port 5000 is still in use!" -ForegroundColor Red
    Write-Host "  Please run this script as Administrator" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "  Port 5000 is free" -ForegroundColor Green
}

if ($port9000) {
    Write-Host "  WARNING: Port 9000 is still in use" -ForegroundColor Yellow
}
else {
    Write-Host "  Port 9000 is free" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Starting Benchmark" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Change to benchmarks directory and run the benchmark
Set-Location "benchmarks\scripts"
.\benchmark_startup.ps1
