# Build do APK release do app mobile Coleta.
#
# Contorna a falha "java.io.IOException: Unable to establish loopback connection"
# desta maquina: sockets AF_UNIX nao funcionam dentro de %TEMP% (nem em
# AppData\Local) - o bind passa, o connect falha com "Invalid argument". O Gradle
# usa Selector/Pipe, que no Windows saem por AF_UNIX no %TEMP%, e por isso o
# build morria antes de comecar. A correcao e apontar esses sockets para uma
# pasta onde AF_UNIX funciona (C:\Temp\gradle-uds).
#
# Nao e necessario desativar antivirus nem mexer em adaptadores de rede.
#
# Uso:  .\build_apk.ps1
#       .\build_apk.ps1 -SkipCopy      (nao copia para releases\)
#
# Obs.: manter este arquivo somente em ASCII (PowerShell 5.1 le .ps1 como ANSI).

param(
    [switch]$SkipCopy,
    [string]$ReleaseDir = 'C:\Users\Walter Gravina\OneDrive\PROJETOS\Coleta\releases\v2.0.0\mobile'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$tempDir = 'C:\Temp\coleta-build'
Write-Host "==> Redirecionando TEMP para $tempDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force $tempDir | Out-Null

# Vale para todo o processo filho (flutter -> gradlew -> daemon Java), que herda
# o ambiente. E de onde o Java tira o java.io.tmpdir, onde ele cria os sockets
# AF_UNIX do Selector. Nao adianta usar -Djdk.net.unixdomain.tmpdir no
# org.gradle.jvmargs: o Gradle remove os -D da linha de comando do daemon.
$env:TEMP = $tempDir
$env:TMP = $tempDir

Write-Host '==> flutter build apk --release' -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Falha no build do APK.' }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK nao encontrado em $apk" }

$versao = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$tamanho = [math]::Round((Get-Item $apk).Length / 1MB, 1)
Write-Host "    OK: $apk ($tamanho MB) - versao $versao" -ForegroundColor Green

if ($SkipCopy) { return }

$nome = 'ColetaMobile-v' + ($versao -replace '\+', '-build') + '-release.apk'
$destino = Join-Path $ReleaseDir $nome
New-Item -ItemType Directory -Force $ReleaseDir | Out-Null
Copy-Item $apk $destino -Force
Write-Host "==> Copiado para $destino" -ForegroundColor Green
