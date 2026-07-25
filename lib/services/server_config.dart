import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Endereço da retaguarda.
///
/// Aceita três formas, porque o servidor tanto pode estar na rede local quanto
/// atrás de um túnel (Cloudflare, por exemplo):
///
/// - `192.168.10.9`            → `http://192.168.10.9:8080` (usa a porta)
/// - `coleta.goupsistemas.uk`  → `https://coleta.goupsistemas.uk` (túnel, sem porta)
/// - `http://10.0.0.5:9000`    → usado exatamente como digitado
class ServerConfig {
  /// Mantém a chave antiga para não perder o que já está salvo no aparelho.
  static const _keyEndereco = 'server_ip';
  static const _keyPorta = 'server_porta';

  static const String _defaultEndereco = '192.168.1.1';

  // Backend embutido na retaguarda escuta em 0.0.0.0:8080.
  static const String _defaultPorta = '8080';

  /// O que o usuário digitou: IP, domínio ou URL completa.
  static Future<String> getEndereco() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEndereco) ?? _defaultEndereco;
  }

  /// Mantido para o código que ainda fala em "IP".
  static Future<String> getIp() => getEndereco();

  static Future<String> getPorta() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPorta) ?? _defaultPorta;
  }

  static Future<void> salvar(String endereco, String porta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndereco, endereco.trim());
    await prefs.setString(_keyPorta, porta.trim());
  }

  static Future<String> get baseUrl async =>
      montarUrl(await getEndereco(), await getPorta());

  /// Verdadeiro quando o texto é um IPv4 — e não um nome de domínio.
  static bool ehIp(String host) =>
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host.trim());

  /// Monta a URL base a partir do que foi digitado.
  ///
  /// Um domínio implica túnel ou proxy, que atende em HTTPS na porta padrão —
  /// por isso a porta só entra quando o endereço é um IP ou `localhost`.
  static String montarUrl(String endereco, String porta) {
    var e = endereco.trim();
    if (e.isEmpty) return '';

    // Já veio com esquema: respeita exatamente o que foi escrito.
    if (e.startsWith('http://') || e.startsWith('https://')) {
      return e.replaceAll(RegExp(r'/+$'), '');
    }

    e = e.replaceAll(RegExp(r'/+$'), '');

    // Porta colada ao endereço tem prioridade sobre o campo separado.
    if (RegExp(r':\d+$').hasMatch(e)) {
      final host = e.split(':').first;
      final esquema = ehIp(host) || host == 'localhost' ? 'http' : 'https';
      return '$esquema://$e';
    }

    if (ehIp(e) || e == 'localhost') {
      final p = porta.trim().isEmpty ? _defaultPorta : porta.trim();
      return 'http://$e:$p';
    }

    // Domínio: o túnel termina o TLS, então HTTPS na porta padrão.
    return 'https://$e';
  }

  /// Verdadeiro quando o endereço dispensa o campo de porta.
  static bool portaDispensavel(String endereco) {
    final e = endereco.trim();
    if (e.isEmpty) return false;
    if (e.startsWith('http://') || e.startsWith('https://')) return true;
    if (RegExp(r':\d+$').hasMatch(e)) return true;
    return !ehIp(e) && e != 'localhost';
  }

  /// Tenta conectar. Retorna null em caso de sucesso, ou o motivo da falha.
  static Future<String?> testarConexao(String endereco, String porta) async {
    final base = montarUrl(endereco, porta);
    if (base.isEmpty) return 'Informe o endereço do servidor.';

    try {
      final response = await http
          .get(Uri.parse('$base/ping'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null; // sucesso
      }
      return 'O servidor respondeu com código ${response.statusCode}.';
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused')) {
        return ehIp(endereco.trim())
            ? 'Não foi possível conectar. Verifique o IP, a porta e se o '
                  'celular está na mesma rede da retaguarda.'
            : 'Não foi possível conectar a $base. Verifique o endereço e se o '
                  'túnel está no ar.';
      }
      if (msg.contains('TimeoutException')) {
        return 'Tempo limite esgotado. O servidor não respondeu.';
      }
      if (msg.contains('HandshakeException') || msg.contains('CERTIFICATE')) {
        return 'Falha no certificado HTTPS de $base.';
      }
      return 'Erro de conexão: $msg';
    }
  }
}
