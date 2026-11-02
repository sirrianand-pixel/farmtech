param(
    [string]$PythonExe = "",
    [string]$TaskName = "FarmTech Mandi Scraper",
    [int]$IntervalMinutes = 30,
    [string]$ServiceAccountPath = ""
)

if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1439) {
    throw "IntervalMinutes must be between 1 and 1439."
}

$scriptPath = Join-Path $PSScriptRoot "mandi_price_scraper.py"
if (-not (Test-Path $scriptPath)) {
    throw "Scraper script not found at $scriptPath"
}

if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $pythonCandidates = @(
        (Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "C:\Users\Anandh\AppData\Local\Python\bin\python.exe",
        "C:\Users\Anandh\AppData\Local\Microsoft\WindowsApps\python.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if (-not $pythonCandidates) {
        throw "Python executable not found. Pass -PythonExe with the full path to python.exe."
    }

    $PythonExe = $pythonCandidates[0]
}

$serviceArg = ""
if (-not [string]::IsNullOrWhiteSpace($ServiceAccountPath)) {
    if (-not (Test-Path $ServiceAccountPath)) {
        throw "Service account file not found at $ServiceAccountPath"
    }
    $serviceArg = "`$env:FARMTECH_SERVICE_ACCOUNT_PATH='$ServiceAccountPath'; "
}

$batPath = Join-Path (Split-Path $PSScriptRoot -Parent) "run_mandi_scraper.bat"
if (-not (Test-Path $batPath)) {
    $batPath = $scriptPath
}

$result = schtasks /Create /TN "$TaskName" /TR "`"$batPath`"" /SC MINUTE /MO $IntervalMinutes /F
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Registered Windows scheduled task '$TaskName' to run every $IntervalMinutes minutes."
} else {
    Write-Warning "Could not register task: $result"
}


