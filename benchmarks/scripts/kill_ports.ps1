# Kill processes using ports 5000 and 9000
function Stop-ProcessOnPort {
    param([int]$Port)

    try {
        $connections = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"
        foreach ($conn in $connections) {
            $parts = $conn -split '\s+' | Where-Object { $_ -ne '' }
            $pid = $parts[-1]
            if ($pid -match '^\d+$') {
                Write-Host "Killing process $pid on port $Port..."
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            }
        }
    }
    catch {
        Write-Host "No process found on port $Port or unable to kill"
    }
}

Write-Host "Cleaning up ports 5000 and 9000..."
Stop-ProcessOnPort -Port 5000
Stop-ProcessOnPort -Port 9000
Write-Host "Done!"
