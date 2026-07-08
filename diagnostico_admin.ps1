# Diagnóstico de rede como admin
Write-Host "=== DIAGNÓSTICO REDE ADMIN ===" -ForegroundColor Cyan

Write-Host "`n-- Provedores WFP ativos --" -ForegroundColor Yellow
netsh wfp show providers 2>&1 | Select-String -Pattern "providerName|serviceName" | Select-Object -First 30

Write-Host "`n-- Testar NIO Pipe com Java --" -ForegroundColor Yellow
$javaHome = "C:\Program Files\Java\jdk-17"
$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;$env:PATH"
$env:JAVA_TOOL_OPTIONS = "-Djava.net.preferIPv4Stack=true"

$testCode = @"
import java.nio.channels.*;
import java.net.*;
public class PipeTest {
    public static void main(String[] args) throws Exception {
        System.out.println("Testando ServerSocketChannel...");
        ServerSocketChannel ssc = ServerSocketChannel.open();
        ssc.socket().bind(new InetSocketAddress(InetAddress.getByName("127.0.0.1"), 0));
        int port = ssc.socket().getLocalPort();
        System.out.println("Servidor na porta: " + port);
        SocketChannel sc = SocketChannel.open();
        sc.socket().bind(null);
        System.out.println("Cliente bind OK");
        sc.connect(new InetSocketAddress("127.0.0.1", port));
        System.out.println("Conexao loopback OK!");
        sc.close(); ssc.close();
    }
}
"@

$testDir = "$env:TEMP\javatest"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$testCode | Out-File "$testDir\PipeTest.java" -Encoding ASCII
& java -cp $testDir "$testDir\PipeTest.java" 2>&1
# Try direct run
Set-Location $testDir
& javac PipeTest.java 2>&1
& java PipeTest 2>&1

Write-Host "`nPressione Enter para fechar..."
Read-Host
