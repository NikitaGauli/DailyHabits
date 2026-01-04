param(
    [string]$device = "",
    [switch]$clean
)

# Ensure script runs from project root (where pubspec.yaml lives)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# If pubspec.yaml is not in the current folder, try to find the nearest one
if (-not (Test-Path -Path (Join-Path $PWD 'pubspec.yaml'))) {
    Write-Host "pubspec.yaml not found in $PWD — searching subfolders..."
    $found = Get-ChildItem -Path $scriptDir -Recurse -Filter pubspec.yaml -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $projectRoot = Split-Path -Parent $found.FullName
        Write-Host "Found pubspec.yaml at: $($found.FullName) — switching to $projectRoot"
        Set-Location $projectRoot
    } else {
        Write-Host "ERROR: Could not find pubspec.yaml under $scriptDir. Please run this script from a Flutter project folder." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Working directory: $PWD"
Write-Host "Running 'flutter pub get'..."
flutter pub get

if ($clean) {
    Write-Host "Running 'flutter clean'..."
    flutter clean
}

if ($device -ne "") {
    Write-Host "Running flutter on device: $device"
    flutter run -d $device
} else {
    Write-Host "Running flutter (default device)..."
    flutter run
}
