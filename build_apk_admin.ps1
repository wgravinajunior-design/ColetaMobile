$projectPath = "C:\Users\Walter Gravina\OneDrive\PROJETOS\Coleta\flutter_app"
$flutter = "C:\flutter\bin\flutter.bat"
$javaHome = "C:\Program Files\Java\jdk-17"

Write-Host "=== BUILD APK - COLETA ===" -ForegroundColor Cyan

Write-Host "Desabilitando Topaz OFD..." -ForegroundColor Yellow
$adapters = Get-NetAdapterBinding -ComponentID "nt_wsddntf" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled }
$adapters | ForEach-Object { Disable-NetAdapterBinding -Name $_.Name -ComponentID "nt_wsddntf" -Confirm:$false }

Write-Host "Desabilitando Windows Defender Real-Time Protection..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

$env:JAVA_TOOL_OPTIONS = "-Djava.net.preferIPv4Stack=true"
$env:_JAVA_OPTIONS = "-Djava.net.preferIPv4Stack=true"
$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;C:\flutter\bin;$env:PATH"

Write-Host "Iniciando build APK Release..." -ForegroundColor Green
Set-Location $projectPath
& $flutter build apk --release
$exitCode = $LASTEXITCODE

Write-Host "Reabilitando protecoes..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
$adapters | ForEach-Object { Enable-NetAdapterBinding -Name $_.Name -ComponentID "nt_wsddntf" -Confirm:$false }

if ($exitCode -eq 0) {
    $apk = "$projectPath\build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "APK GERADO COM SUCESSO!" -ForegroundColor Green
    if (Test-Path $apk) {
        $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
        Write-Host "Caminho: $apk" -ForegroundColor Cyan
        Write-Host "Tamanho: $size MB" -ForegroundColor Cyan
    }
} else {
    Write-Host "BUILD FALHOU (codigo $exitCode)" -ForegroundColor Red
}

Write-Host "Pressione Enter para fechar..."
Read-Host
