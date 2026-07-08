import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ServerConfig {
  static const _keyIp = 'server_ip';
  static const _keyPorta = 'server_porta';

  static const String _defaultIp = '192.168.1.1';
  static const String _defaultPorta = '3000';

  static Future<String> getIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIp) ?? _defaultIp;
  }

  static Future<String> getPorta() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPorta) ?? _defaultPorta;
  }

  static Future<void> salvar(String ip, String porta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIp, ip.trim());
    await prefs.setString(_keyPorta, porta.trim());
  }

  static Future<String> get baseUrl async {
    final ip = await getIp();
    final porta = await getPorta();
    return 'http://$ip:$porta';
  }

  /// Tenta conectar ao servidor. Retorna null em caso de sucesso,
  /// ou uma mensagem de erro descritiva.
  static Future<String?> testarConexao(String ip, String porta) async {
    final url = Uri.parse('http://$ip:$porta/ping');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null; // sucesso
      }
      return 'Servidor respondeu com código ${response.statusCode}';
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        return 'Não foi possível conectar. Verifique IP e porta.';
      }
      if (msg.contains('TimeoutException')) {
        return 'Tempo limite esgotado. Servidor não respondeu.';
      }
      return 'Erro de conexão: $msg';
    }
  }
}
