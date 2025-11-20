# Cleanup and run startup benchmark
# This script attempts to clean up ports and run the benchmark

Write-Host "========================================="
Write-Host "Startup Benchmark - Cleanup and Run"
Write-Host "========================================="
Write-Host ""

# Function to force kill processes on a port
function Force-KillPort {
    param([int]$Port)

    Write-Host "Checking port $Port..."

    $connections = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"

    if ($connections) {
        foreach ($conn in $connections) {
            $parts = $conn -split '\s+' | Where-Object { $_ -ne '' }
            $pid = $parts[-1]

            if ($pid -match '^\d+$') {
                Write-Host "  Found process $pid using port $Port"

                # Try normal stop first
                try {
                    Stop-Process -Id $pid -Force -ErrorAction Stop
                    Write-Host "  Successfully killed process $pid" -ForegroundColor Green
                    Start-Sleep -Milliseconds 500
                }
                catch {
                    Write-Host "  Could not kill process $pid - May require administrator rights" -ForegroundColor Yellow
                    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow

                    # Try taskkill as fallback
                    try {
                        $result = taskkill /PID $pid /F 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  Successfully killed process $pid with taskkill" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  taskkill also failed - Administrator rights required" -ForegroundColor Red
                            return $false
                        }
                    }
                    catch {
                        Write-Host "  All kill attempts failed" -ForegroundColor Red
                        return $false
                    }
                }
            }
        }
    }
    else {
        Write-Host "  Port $Port is free" -ForegroundColor Green
    }

    return $true
}

Write-Host "Step 1: Cleaning up ports 5000 and 9000"
Write-Host ""

$port5000Clean = Force-KillPort -Port 5000
$port9000Clean = Force-KillPort -Port 9000

Write-Host ""

if (-not $port5000Clean) {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "ERROR: Cannot free port 5000" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please do ONE of the following:" -ForegroundColor Yellow
    Write-Host "1. Run this script as Administrator:" -ForegroundColor Yellow
    Write-Host "   Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "   Then run: .\cleanup_and_run.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2. Manually kill the process:" -ForegroundColor Yellow
    Write-Host "   - Open Task Manager (Ctrl+Shift+Esc)" -ForegroundColor Yellow
    Write-Host "   - Find process with PID 35604" -ForegroundColor Yellow
    Write-Host "   - Right-click -> End Task" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not $port9000Clean) {
    Write-Host "Warning: Could not free port 9000, but continuing..." -ForegroundColor Yellow
}

Write-Host "Step 2: Waiting for ports to fully release..."
Start-Sleep -Seconds 2

Write-Host "Step 3: Running startup benchmark..."
Write-Host ""

.\benchmark_startup.ps1
