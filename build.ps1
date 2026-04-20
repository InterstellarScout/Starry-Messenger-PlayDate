param(
    [switch]$RunSimulator,
    [switch]$InstallDevice
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sdkRoot = if ($env:PLAYDATE_SDK_PATH) { $env:PLAYDATE_SDK_PATH } else { (Resolve-Path (Join-Path $projectRoot "..\\..")).Path }
$pdc = Join-Path $sdkRoot "bin\\pdc.exe"
$simulator = Join-Path $sdkRoot "bin\\PlaydateSimulator.exe"
$sourceDir = Join-Path $projectRoot "Source"
$outputDir = Join-Path $projectRoot "StarryMessenger.pdx"
$deviceLabel = "PLAYDATE"
$deviceGamesFolder = "Games"
$deviceInstallAttempts = 3
$deviceWaitSeconds = 3

function Get-PlaydateDriveRoot {
    $volume = Get-Volume | Where-Object { $_.FileSystemLabel -eq $deviceLabel -and $_.DriveLetter } | Select-Object -First 1
    if (-not $volume) {
        return $null
    }

    return ($volume.DriveLetter + ":\")
}

function Wait-ForPlaydateDrive {
    param(
        [int]$TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $driveRoot = Get-PlaydateDriveRoot
        if ($driveRoot) {
            return $driveRoot
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw "Playdate drive '$deviceLabel' was not found."
}

function Install-ToPlaydateDevice {
    $lastError = $null

    for ($attempt = 1; $attempt -le $deviceInstallAttempts; $attempt++) {
        try {
            $driveRoot = Wait-ForPlaydateDrive
            $gamesRoot = Join-Path $driveRoot $deviceGamesFolder
            $targetDir = Join-Path $gamesRoot "StarryMessenger.pdx"

            if (-not (Test-Path $gamesRoot)) {
                New-Item -ItemType Directory -Path $gamesRoot -Force | Out-Null
            }

            if (Test-Path $targetDir) {
                Remove-Item -LiteralPath $targetDir -Recurse -Force
            }

            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

            $null = robocopy $outputDir $targetDir /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
            if ($LASTEXITCODE -gt 7) {
                throw "robocopy failed with exit code $LASTEXITCODE"
            }

            Write-Host "Installed build to $targetDir"
            return
        } catch {
            $lastError = $_
            if ($attempt -lt $deviceInstallAttempts) {
                Start-Sleep -Seconds $deviceWaitSeconds
            }
        }
    }

    throw "Failed to install to Playdate after $deviceInstallAttempts attempts. $lastError"
}

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

if ($InstallDevice) {
    Install-ToPlaydateDevice
}
