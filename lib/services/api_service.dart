import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';
import 'database_service.dart';

const _kTimeout = Duration(seconds: 10);
const _kTokenKey = 'auth_token';

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Sessão expirada. Faça login novamente.']);
  @override
  String toString() => message;
}

/// Sincroniza dados entre o servidor REST e o SQLite local.
///
/// Fluxo offline-first:
///   - Ao iniciar: tenta baixar dados do servidor e grava no SQLite.
///   - Se offline, usa o SQLite como fonte de verdade.
///   - Ao registrar coleta / mudar status de rota: atualiza SQLite
///     imediatamente e depois tenta empurrar ao servidor em background.
///   - Token Bearer armazenado em SharedPreferences após login.
class ApiService {
  static String? _authToken;

  // ─── Inicialização ─────────────────────────────────────────────────────────

  /// Deve ser chamado em main() antes de runApp para carregar o token salvo.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_kTokenKey);
  }

  // ─── Token ─────────────────────────────────────────────────────────────────

  static Future<void> _saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  static Future<void> _clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }

  static bool get isLoggedIn => _authToken != null && _authToken!.isNotEmpty;

  // ─── helpers ───────────────────────────────────────────────────────────────

  static Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_authToken';
    }
    return h;
  }

  static Future<http.Response> _get(String path) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .get(Uri.parse('$base$path'), headers: _headers)
        .timeout(_kTimeout);
    _checkUnauthorized(res);
    return res;
  }

  static Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .put(Uri.parse('$base$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_kTimeout);
    _checkUnauthorized(res);
    return res;
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .post(Uri.parse('$base$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(_kTimeout);
    _checkUnauthorized(res);
    return res;
  }

  static Future<http.Response> _delete(String path) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .delete(Uri.parse('$base$path'), headers: _headers)
        .timeout(_kTimeout);
    return res;
  }

  static void _checkUnauthorized(http.Response res) {
    if (res.statusCode == 401) {
      _authToken = null;
      throw const UnauthorizedException();
    }
  }

  // ─── Autenticação ──────────────────────────────────────────────────────────

  /// Autentica o usuário no servidor.
  /// Salva o Bearer token retornado em SharedPreferences.
  /// Retorna o Map com {id, nome, perfil, login, token} em caso de sucesso.
  static Future<Map<String, dynamic>> login(String login, String senha) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .post(
          Uri.parse('$base/auth/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'login': login, 'senha': senha}),
        )
        .timeout(_kTimeout);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }
      return data;
    }
    throw Exception(data['error'] ?? 'Erro desconhecido (${res.statusCode})');
  }

  /// Revoga o token no servidor e limpa o armazenamento local.
  static Future<void> logout() async {
    try {
      await _delete('/auth/logout');
    } catch (_) {
      // offline — apenas limpa localmente
    }
    await _clearToken();
  }

  // ─── Sincronização completa (download) ────────────────────────────────────

  /// Baixa todos os cadastros e rotas do servidor e grava no SQLite local.
  /// Retorna true se a sincronia foi bem-sucedida.
  static Future<bool> syncAll() async {
    try {
      await Future.wait([
        _syncResfriadores(),
        _syncProdutores(),
        _syncVeiculos(),
        _syncMotoristas(),
        _syncColaboradores(),
      ]);
      await _syncRotas();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Sync bulk upload (push offline → servidor) ───────────────────────────

  /// Envia dados pendentes locais ao servidor via endpoint bulk /coleta/sync.
  /// Chamado ao reconectar após período offline.
  static Future<bool> pushSync() async {
    try {
      // Coleta rotas em andamento ou pendentes com seus detalhes
      final rotas = await DatabaseService.getRotasParaSync();
      if (rotas.isEmpty) return true;

      final payload = <String, dynamic>{'rotas': rotas};
      final res = await _post('/coleta/sync', payload);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Sync por entidade (download) ─────────────────────────────────────────

  static Future<void> _syncResfriadores() async {
    final res = await _get('/coleta/resfriadores');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertResfriador({
        'id': m['id'],
        'numero_identificador': m['numero_identificador'] ?? '',
        'marca_modelo': m['marca_modelo'] ?? '',
        'ano_fabricacao': m['ano_fabricacao'] ?? 0,
        'capacidade_litros': (m['capacidade_litros'] as num?)?.toDouble() ?? 0.0,
        'ultima_manutencao': m['ultima_manutencao'],
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncProdutores() async {
    final res = await _get('/coleta/produtores');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertProdutor({
        'id': m['id'],
        'nome': m['nome'] ?? '',
        'endereco': m['endereco'] ?? '',
        'latitude': (m['latitude'] as num?)?.toDouble() ?? 0.0,
        'longitude': (m['longitude'] as num?)?.toDouble() ?? 0.0,
        'volume_medio_diario': (m['volume_medio_diario'] as num?)?.toDouble() ?? 0.0,
        'horario_coleta_previsto': m['horario_coleta_previsto'] ?? '',
        'km_ate_tanque_principal': (m['km_ate_tanque_principal'] as num?)?.toDouble() ?? 0.0,
        'id_resfriador': m['id_resfriador'],
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncVeiculos() async {
    final res = await _get('/coleta/veiculos');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertVeiculo({
        'id': m['id'],
        'descricao': m['descricao'] ?? '',
        'placa': m['placa'] ?? '',
        'capacidade_litros': (m['capacidade_litros'] as num?)?.toDouble() ?? 0.0,
        'consumo_medio': (m['consumo_medio'] as num?)?.toDouble() ?? 0.0,
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncMotoristas() async {
    final res = await _get('/coleta/motoristas');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertMotorista({
        'id': m['id'],
        'nome': m['nome'] ?? '',
        'cnh': m['cnh'] ?? '',
        'categoria_cnh': m['categoria_cnh'] ?? '',
        'id_veiculo': m['id_veiculo'],
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncColaboradores() async {
    final res = await _get('/coleta/colaboradores');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertColaborador({
        'id': m['id'],
        'nome': m['nome'] ?? '',
        'cpf': m['cpf'] ?? '',
        'funcao_cargo': m['funcao_cargo'] ?? '',
        'permissoes': m['permissoes'] ?? 'Operador',
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncRotas() async {
    final res = await _get('/coleta/rotas');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final rotaId = m['id'] as int;

      await DatabaseService.upsertColetaRota({
        'id': rotaId,
        'nome': m['nome'] ?? '',
        'id_motorista': m['id_motorista'] ?? 0,
        'id_veiculo': m['id_veiculo'] ?? 0,
        'data_coleta': m['data_coleta'] ?? '',
        'data_hora_inicio': m['data_hora_inicio'],
        'data_hora_fim': m['data_hora_fim'],
        'status': m['status'] ?? 'PENDENTE',
      });

      await _syncDetalhesRota(rotaId);
    }
  }

  static Future<void> _syncDetalhesRota(int rotaId) async {
    final res = await _get('/coleta/rotas/$rotaId/detalhes');
    if (res.statusCode != 200) return;
    final list = jsonDecode(res.body) as List;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertColetaDetalhe({
        'id': m['id'],
        'id_coleta_rota': rotaId,
        'id_produtor': m['id_produtor'] ?? 0,
        'ordem_visita': m['ordem_visita'] ?? 0,
        'data_hora_registro': m['data_hora_registro'],
        'volume_coletado_litros': (m['volume_coletado_litros'] as num?)?.toDouble() ?? 0.0,
        'temperatura_leite_c': (m['temperatura_leite_c'] as num?)?.toDouble() ?? 0.0,
        'observacao': m['observacao'] ?? '',
        'motivo_adiamento': m['motivo_adiamento'] ?? '',
        'status': m['status'] ?? 'PENDENTE',
        'foto_caminho': m['foto_caminho'],
      });
    }
  }

  // ─── Push de mudanças ao servidor ─────────────────────────────────────────

  /// Atualiza status da rota no servidor.
  /// Retorna true se o servidor confirmou (para limpar pending_sync local).
  /// Falhas são silenciosas (dado já está no SQLite e continua pendente).
  static Future<bool> pushRotaStatus(
    int id,
    String status, {
    String? dataHoraInicio,
    String? dataHoraFim,
  }) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (dataHoraInicio != null) body['data_hora_inicio'] = dataHoraInicio;
      if (dataHoraFim != null) body['data_hora_fim'] = dataHoraFim;
      final res = await _put('/coleta/rotas/$id', body);
      return res.statusCode == 200;
    } catch (_) {
      // offline — SQLite já foi atualizado, permanece pendente
      return false;
    }
  }

  /// Atualiza dados de uma coleta detalhe no servidor.
  /// Retorna true se o servidor confirmou (para limpar pending_sync local).
  static Future<bool> pushColetaDetalhe(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _put('/coleta/detalhes/$id', data);
      return res.statusCode == 200;
    } catch (_) {
      // offline — dado salvo localmente, permanece pendente
      return false;
    }
  }
}
