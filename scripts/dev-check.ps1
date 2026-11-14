# Nestin Monorepo Validation Helper (Windows PowerShell)
param(
  [switch]$SkipFlutterTests,
  [switch]$SkipBackendE2e
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Write-Host "=== [1/2] Validating Mobile (apps/mobile) ===" -ForegroundColor Cyan
Push-Location "$root\apps\mobile"
try {
  flutter pub get
  flutter analyze --no-pub
  if (-not $SkipFlutterTests) {
    flutter test --no-pub
  }
} finally {
  Pop-Location
}

Write-Host "=== [2/2] Validating Backend (apps/backend) ===" -ForegroundColor Cyan
Push-Location "$root\apps\backend"
try {
  npm run typecheck
  npm run build
  npm test
  if (-not $SkipBackendE2e) {
    npm run test:e2e
  }
} finally {
  Pop-Location
}

Write-Host "All requested Nestin monorepo checks finished cleanly." -ForegroundColor Green
