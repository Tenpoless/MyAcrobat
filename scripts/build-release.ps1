param(
    [string]$ApiBaseUrl = "http://192.168.1.100:3000",
    [switch]$SkipAndroid,
    [switch]$SkipWindows,
    [switch]$SkipWeb
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot "app"
$BackendDir = Join-Path $RepoRoot "backend"
$DistDir = Join-Path $RepoRoot "dist"
$BackendPublicDir = Join-Path $BackendDir "public"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackendPublicDir | Out-Null

Write-Host "=== Building MyAcrobat Release Artifacts (API_BASE_URL=$ApiBaseUrl) ===" -ForegroundColor Cyan

Push-Location $BackendDir
try {
    Write-Host "[1/4] Building Backend TypeScript..." -ForegroundColor Yellow
    npm run build
} finally {
    Pop-Location
}

Push-Location $AppDir
try {
    flutter pub get

    if (-not $SkipWeb) {
        Write-Host "[2/4] Building Flutter Web Bundle -> backend/public/..." -ForegroundColor Yellow
        flutter build web --release --dart-define="API_BASE_URL=$ApiBaseUrl"
        Copy-Item -Path "build/web/*" -Destination $BackendPublicDir -Recurse -Force
    }

    if (-not $SkipAndroid) {
        Write-Host "[3/4] Building Android APK -> dist/MyAcrobat-release.apk..." -ForegroundColor Yellow
        flutter build apk --release --dart-define="API_BASE_URL=$ApiBaseUrl"
        Copy-Item -Path "build/app/outputs/flutter-apk/app-release.apk" -Destination (Join-Path $DistDir "MyAcrobat-release.apk") -Force
    }

    if (-not $SkipWindows) {
        Write-Host "[4/4] Building Windows Desktop -> dist/MyAcrobat-windows.zip..." -ForegroundColor Yellow
        flutter build windows --release --dart-define="API_BASE_URL=$ApiBaseUrl"
        $WindowsReleaseDir = "build/windows/x64/runner/Release"
        if (Test-Path $WindowsReleaseDir) {
            Compress-Archive -Path "$WindowsReleaseDir/*" -DestinationPath (Join-Path $DistDir "MyAcrobat-windows.zip") -Force
        }
    }
} finally {
    Pop-Location
}

Write-Host "Selesai! Artefak rilis tersedia di folder dist/ dan backend/public/." -ForegroundColor Green
