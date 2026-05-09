# Quick Cache Verification for Windows PowerShell
# Uso: .\cache_verify.ps1

Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   PROFILE PICTURE CACHE VERIFICATION" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Colors
$Green = @{ ForegroundColor = "Green" }
$Red = @{ ForegroundColor = "Red" }
$Yellow = @{ ForegroundColor = "Yellow" }
$Blue = @{ ForegroundColor = "Cyan" }

Write-Host "[PASO 1/4] Verificando Flutter..." @Blue
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutterPath) {
    Write-Host "✗ Flutter no encontrado" @Red
    exit 1
}
Write-Host "✓ Flutter encontrado" @Green
Write-Host ""

Write-Host "[PASO 2/4] Verificando dispositivos conectados..." @Blue
$devices = & adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "device|emulator" }
if ($devices.Count -eq 0) {
    Write-Host "⚠ Sin dispositivos/emuladores conectados" @Yellow
    Write-Host "Ejecuta: adb devices"
} else {
    Write-Host "✓ Dispositivo(s) conectado(s): $($devices.Count)" @Green
}
Write-Host ""

Write-Host "[PASO 3/4] Ubicación del caché en Firebase Storage:" @Blue
Write-Host "Firebase Console > Storage" @Yellow
Write-Host "  Ruta: users/{userId}/profile_picture.jpg" @Yellow
Write-Host ""

Write-Host "[PASO 4/4] Ejecutar app con logs de caché..." @Blue
Write-Host "Los logs mostrarán operaciones de caché con estos iconos:" @Yellow
Write-Host "  🗑️  Removing old cache" @Yellow
Write-Host "  ✅ Old cache removed successfully" @Yellow
Write-Host "  📥 Pre-caching new image" @Yellow
Write-Host "  ✅ Pre-cached successfully" @Yellow
Write-Host ""

$response = Read-Host "¿Iniciar la app con logging? (s/n)"
if ($response -eq "s" -or $response -eq "S") {
    Write-Host "Iniciando Flutter run con filtro de caché..." @Blue
    Write-Host ""

    cd "C:\Users\USUARIO\StudioProjects\UniandesSport-Flutter"
    flutter run -v 2>&1 | Select-String "ProfileViewModel|cache|Cache"
}

Write-Host ""
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "VERIFICACIÓN COMPLETADA" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

