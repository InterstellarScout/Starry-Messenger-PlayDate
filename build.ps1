param(
    [switch]$RunSimulator
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sdkRoot = if ($env:PLAYDATE_SDK_PATH) { $env:PLAYDATE_SDK_PATH } else { (Resolve-Path (Join-Path $projectRoot "..\\..")).Path }
$pdc = Join-Path $sdkRoot "bin\\pdc.exe"
$simulator = Join-Path $sdkRoot "bin\\PlaydateSimulator.exe"
$sourceDir = Join-Path $projectRoot "Source"
$outputDir = Join-Path $projectRoot "StarryMessenger.pdx"

if (-not (Test-Path $pdc)) {
    throw "Playdate compiler not found at $pdc"
}

if (Test-Path $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}

& $pdc -sdkpath $sdkRoot $sourceDir $outputDir

if ($RunSimulator) {
    if (-not (Test-Path $simulator)) {
        throw "Playdate Simulator not found at $simulator"
    }

    Start-Process -FilePath $simulator -ArgumentList "`"$outputDir`""
}
