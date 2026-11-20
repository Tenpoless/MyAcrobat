param(
    [int]$Port = 3000
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RepoRoot "backend"

Write-Host "=== MyAcrobat Office Server Startup ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $BackendDir ".env"))) {
    Write-Warning "File backend/.env belum ditemukan. Menyalin dari backend/.env.example..."
    Copy-Item (Join-Path $BackendDir ".env.example") (Join-Path $BackendDir ".env")
    Write-Warning "Silakan isi kredensial MEGA_EMAIL dan MEGA_PASSWORD di backend/.env sebelum produksi."
}

$RuleName = "MyAcrobat Office Server TCP $Port"
$ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
if (-not $ExistingRule) {
    try {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
        Write-Host "Firewall rule '$RuleName' berhasil dibuka untuk jaringan LAN kantor." -ForegroundColor Green
    } catch {
        Write-Warning "Tidak dapat menambahkan rule Windows Firewall otomatis (jalankan sebagai Administrator bila perlu)."
    }
}

Push-Location $BackendDir
try {
    if (-not (Test-Path "dist/server.js")) {
        Write-Host "Mengompilasi TypeScript backend..." -ForegroundColor Yellow
        npm run build
    }

    if (Get-Command pm2 -ErrorAction SilentlyContinue) {
        Write-Host "Menjalankan MyAcrobat Backend menggunakan PM2..." -ForegroundColor Green
        pm2 start ecosystem.config.cjs --update-env
        pm2 save
    } else {
        Write-Host "PM2 tidak ditemukan. Menjalankan server secara langsung pada port $Port..." -ForegroundColor Yellow
        $env:PORT = "$Port"
        node dist/server.js
    }
} finally {
    Pop-Location
}
