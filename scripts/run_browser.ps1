$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$localFlutter = Join-Path $projectRoot '.tooling\flutter\bin\flutter.bat'
if (Test-Path -LiteralPath $localFlutter) {
    $flutterCommand = $localFlutter
    $env:PUB_CACHE = Join-Path $projectRoot '.tooling\pub-cache'
} else {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
}
Write-Host 'Open http://localhost:8080 after the server is ready. Keep this terminal open; Ctrl+C stops it.'
& $flutterCommand run -d web-server --web-hostname localhost --web-port 8080
