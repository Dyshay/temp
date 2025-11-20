# Test script to debug Scala Play startup

Write-Host "Testing Scala Play startup..."

# Import common functions
. ".\benchmarks\scripts\common_functions.ps1"

# Try to start Scala Play
try {
    $info = Start-ScalaPlayApp -ProjectRoot "C:\Users\dyl_c\IdeaProjects\temp"

    Write-Host ""
    Write-Host "Process Info:"
    Write-Host "  PowerShell PID: $($info.PowerShellProcess.Id)"
    Write-Host "  Java PID: $($info.JavaProcess.Id)"
    Write-Host "  Returned PID: $($info.PID)"

    # Wait for service
    Write-Host ""
    $serviceReady = Wait-ForService -Url "http://127.0.0.1:9000/api/hello"

    if ($serviceReady) {
        Write-Host "SUCCESS: Scala Play is running!"

        # Test endpoint
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:9000/api/hello"
        Write-Host "Response: $($response | ConvertTo-Json)"
    } else {
        Write-Host "FAILED: Scala Play did not start"
    }

    # Cleanup
    Write-Host ""
    Write-Host "Stopping Scala Play..."
    Stop-ScalaPlayApp -ProcessInfo $info

} catch {
    Write-Host "ERROR: $_"
    Write-Host $_.Exception.Message
    Write-Host $_.ScriptStackTrace
}
