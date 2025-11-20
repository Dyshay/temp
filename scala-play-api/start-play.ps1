# PowerShell wrapper to start Scala Play without Windows command line length issues
# Solution: Use Java directly with a shorter classpath

$StageDir = Join-Path $PSScriptRoot "target\universal\stage"
$LibDir = Join-Path $StageDir "lib"
$ConfDir = Join-Path $StageDir "conf"

# Build classpath with shorter relative paths
Set-Location $StageDir
$jars = Get-ChildItem -Path ".\lib" -Filter "*.jar" | ForEach-Object { "lib\$($_.Name)" }
$classpath = ($jars -join ";") + ";conf"

# Start Java directly with Play
java -cp "$classpath" play.core.server.ProdServerStart
