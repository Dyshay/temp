# Common functions for benchmark scripts

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

# Function to start Scala Play application properly on Windows
function Start-ScalaPlayApp {
    param(
        [string]$ProjectRoot
    )

    Set-Location "$ProjectRoot\scala-play-api"

    if (-not (Test-Path ".\target\universal\stage")) {
        Write-Host "  Building Scala Play application..."
        cmd /c sbt stage *> $null
    }

    # Launch Java directly to avoid PowerShell wrapper issues
    $StageDir = Join-Path $ProjectRoot "scala-play-api\target\universal\stage"
    Set-Location $StageDir

    # Build classpath
    $jars = Get-ChildItem -Path ".\lib" -Filter "*.jar" | ForEach-Object { "lib\$($_.Name)" }
    $classpath = ($jars -join ";") + ";conf"

    # Start Java in background
    $javaProcess = Start-Process -FilePath "java" `
        -ArgumentList "-cp", "`"$classpath`"", "play.core.server.ProdServerStart" `
        -PassThru -WindowStyle Hidden

    Write-Host "  Started with PID: $($javaProcess.Id) (Java process)"

    return @{
        PowerShellProcess = $null
        JavaProcess = $javaProcess
        PID = $javaProcess.Id
    }
}

# Function to stop Scala Play application
function Stop-ScalaPlayApp {
    param(
        $ProcessInfo
    )

    # Stop both PowerShell wrapper and Java process
    if ($ProcessInfo.PowerShellProcess) {
        Stop-Process -Id $ProcessInfo.PowerShellProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($ProcessInfo.JavaProcess) {
        Stop-Process -Id $ProcessInfo.JavaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    # Also kill any remaining java processes
    Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
