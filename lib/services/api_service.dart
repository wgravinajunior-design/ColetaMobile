import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_config.dart';
import 'sessao_offline.dart';
import 'database_service.dart';
import 'auth_context.dart';

const _kTimeout = Duration(seconds: 10);
const _kTokenKey = 'auth_token';

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([
    this.message = 'Sessão expirada. Faça login novamente.',
  ]);
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
  /// Valida se o token expirou; se expirou, limpa para forçar novo login.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    _authToken = token;

    if (token != null && _tokenExpirou(token)) {
      await _clearToken();
    }
  }

  /// Verifica se o token JWT expirou olhando o claim 'exp' no payload.
  /// Sem decodificar a assinatura, só sabe se o timestamp passou.
  static bool _tokenExpirou(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decode payload (base64url)
      String payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'] as int?;

      if (exp == null) return false;

      final expirationTime =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expirationTime.isBefore(DateTime.now());
    } catch (_) {
      // Se não conseguir decodificar, assume que está ok para não deixar
      // o app inteiro quebrado por token malformado.
      return false;
    }
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

  static Future<http.Response> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .put(Uri.parse('$base$path'), headers: _headers, body: jsonEncode(body))
        .timeout(_kTimeout);
    _checkUnauthorized(res);
    return res;
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final base = await ServerConfig.baseUrl;
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
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

  /// Extrai a lista de itens da resposta, aceitando os dois formatos:
  /// `{success, data:[...]}` (padrão atual do backend) ou um array puro.
  static List _extractList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List)
      return decoded['data'] as List;
    return const [];
  }

  // ─── Autenticação ──────────────────────────────────────────────────────────

  /// Autentica o usuário no servidor.
  /// Salva o Bearer token retornado em SharedPreferences.
  /// Retorna o Map com {id, nome, perfil, login, token} em caso de sucesso.
  /// Autentica no servidor; sem rede, cai para a credencial guardada no
  /// aparelho.
  ///
  /// O app roda em rota, onde o sinal cai e a retaguarda pode estar desligada.
  /// Sem a alternativa offline o motorista ficava preso na tela de login mesmo
  /// com todas as rotas já baixadas. Senha errada continua sendo recusada: o
  /// cache só entra quando o servidor não responde, nunca quando ele responde
  /// negando.
  static Future<Map<String, dynamic>> login(String login, String senha) async {
    try {
      final base = await ServerConfig.baseUrl;
      final res = await http
          .post(
            Uri.parse('$base/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'login': login, 'senha': senha}),
          )
          .timeout(_kTimeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _saveToken(token);
        }
        // Guarda para permitir entrar quando o servidor estiver fora.
        await SessaoOffline.guardar(
          login: login,
          senha: senha,
          perfil: (data['perfil'] as String?) ?? 'OPERADOR',
          nome: (data['nome'] as String?) ?? login,
          usuarioId: data['id'] is int ? data['id'] as int : null,
          motoristaId:
              data['motorista_id'] is int ? data['motorista_id'] as int : null,
        );
        return data;
      }
      // O servidor respondeu recusando: não é caso de cache.
      throw _CredencialRecusada(
        (data['error'] as String?) ?? 'Erro desconhecido (${res.statusCode})',
      );
    } on _CredencialRecusada catch (e) {
      throw Exception(e.mensagem);
    } catch (_) {
      // Servidor inalcançável — tenta a credencial guardada.
      final offline = await SessaoOffline.validar(login, senha);
      if (offline != null) return offline;

      final temCache = await SessaoOffline.disponivel;
      throw Exception(
        temCache
            ? 'Sem conexão com a retaguarda, e a senha não confere com o '
                  'último acesso feito neste aparelho.'
            : 'Sem conexão com a retaguarda. É preciso entrar conectado ao '
                  'menos uma vez neste aparelho antes de usar offline.',
      );
    }
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
  /// Baixa TUDO (cadastros + rotas). Usar no login, refresh manual e ao
  /// reconectar após período offline.
  static Future<bool> syncAll() async {
    try {
      await _syncCadastros();
      await _syncRotas();
      return true;
    } catch (e, st) {
      debugPrint('[ApiService.syncAll] Falha na sincronização: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Cadastros base (mudam raramente) — resfriadores, produtores, veículos,
  /// motoristas, colaboradores.
  static Future<void> _syncCadastros() async {
    await Future.wait([
      _syncResfriadores(),
      _syncProdutores(),
      _syncVeiculos(),
      _syncMotoristas(),
      _syncColaboradores(),
    ]);
  }

  /// Só os dados operacionais (rotas + detalhes), que mudam durante o turno.
  /// Usar no polling periódico para não re-baixar cadastros à toa (cache leve).
  /// Se o usuário logado é motorista, sincroniza apenas suas rotas.
  static Future<bool> syncOperacional() async {
    // Se é motorista, sincroniza apenas suas rotas
    if (AuthContext.ehMotorista) {
      return syncOperacionalMotorista(AuthContext.motoristaId!);
    }
    // Se é gestor/admin, sincroniza todas
    return syncOperacionalAdmin();
  }

  /// Sincronização operacional para motorista logado.
  /// Baixa apenas rotas e detalhes do motorista vinculado.
  static Future<bool> syncOperacionalMotorista(int motoristaId) async {
    try {
      final res = await _get('/coleta/rotas/motorista/$motoristaId');
      if (res.statusCode != 200) {
        debugPrint(
          '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
        );
        return false;
      }

      final list = _extractList(res.body);
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final rotaId = m['id'] as int;
        final status = m['status'] ?? 'PENDENTE';

        await DatabaseService.upsertColetaRota({
          'id': rotaId,
          'nome': m['nome'] ?? '',
          'id_motorista': m['id_motorista'] ?? 0,
          'id_veiculo': m['id_veiculo'] ?? 0,
          'data_coleta': m['data_coleta'] ?? '',
          'data_hora_inicio': m['data_hora_inicio'],
          'data_hora_fim': m['data_hora_fim'],
          'status': status,
        });

        // Rota concluída não muda mais — no ciclo leve, não re-baixa os detalhes.
        if (status == 'CONCLUIDA') continue;
        await _syncDetalhesRota(rotaId);
      }
      return true;
    } catch (e, st) {
      debugPrint('[ApiService.syncOperacionalMotorista] Falha: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Sincronização operacional para admin/gestor.
  /// Baixa todas as rotas e detalhes.
  static Future<bool> syncOperacionalAdmin() async {
    try {
      await _syncRotas(soAtivas: true);
      return true;
    } catch (e, st) {
      debugPrint('[ApiService.syncOperacionalAdmin] Falha: $e');
      debugPrint('$st');
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
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertResfriador({
        'id': m['id'],
        'numero_identificador': m['numero_identificador'] ?? '',
        'marca_modelo': m['marca_modelo'] ?? '',
        'ano_fabricacao': m['ano_fabricacao'] ?? 0,
        'capacidade_litros':
            (m['capacidade_litros'] as num?)?.toDouble() ?? 0.0,
        'ultima_manutencao': m['ultima_manutencao'],
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncProdutores() async {
    final res = await _get('/coleta/produtores');
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertProdutor({
        'id': m['id'],
        'nome': m['nome'] ?? '',
        'endereco': m['endereco'] ?? '',
        'latitude': (m['latitude'] as num?)?.toDouble() ?? 0.0,
        'longitude': (m['longitude'] as num?)?.toDouble() ?? 0.0,
        'volume_medio_diario':
            (m['volume_medio_diario'] as num?)?.toDouble() ?? 0.0,
        'horario_coleta_previsto': m['horario_coleta_previsto'] ?? '',
        'km_ate_tanque_principal':
            (m['km_ate_tanque_principal'] as num?)?.toDouble() ?? 0.0,
        'id_resfriador': m['id_resfriador'],
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncVeiculos() async {
    final res = await _get('/coleta/veiculos');
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertVeiculo({
        'id': m['id'],
        'descricao': m['descricao'] ?? '',
        'placa': m['placa'] ?? '',
        'capacidade_litros':
            (m['capacidade_litros'] as num?)?.toDouble() ?? 0.0,
        'consumo_medio': (m['consumo_medio'] as num?)?.toDouble() ?? 0.0,
        'status': m['status'] ?? 'ATIVO',
      });
    }
  }

  static Future<void> _syncMotoristas() async {
    final res = await _get('/coleta/motoristas');
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
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
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
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

  /// Baixa as rotas e, para cada uma, suas paradas/detalhes.
  /// [soAtivas] = pula o download de detalhes de rotas já CONCLUÍDAS (que não
  /// mudam mais) — evita o custo N+1 no ciclo periódico. No sync completo
  /// (login/refresh/reconexão) baixa tudo, inclusive o histórico concluído.
  static Future<void> _syncRotas({bool soAtivas = false}) async {
    final res = await _get('/coleta/rotas');
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final rotaId = m['id'] as int;
      final status = m['status'] ?? 'PENDENTE';

      await DatabaseService.upsertColetaRota({
        'id': rotaId,
        'nome': m['nome'] ?? '',
        'id_motorista': m['id_motorista'] ?? 0,
        'id_veiculo': m['id_veiculo'] ?? 0,
        'data_coleta': m['data_coleta'] ?? '',
        'data_hora_inicio': m['data_hora_inicio'],
        'data_hora_fim': m['data_hora_fim'],
        'status': status,
      });

      // Rota concluída não muda mais — no ciclo leve, não re-baixa os detalhes.
      if (soAtivas && status == 'CONCLUIDA') continue;
      await _syncDetalhesRota(rotaId);
    }
  }

  static Future<void> _syncDetalhesRota(int rotaId) async {
    final res = await _get('/coleta/rotas/$rotaId/detalhes');
    if (res.statusCode != 200) {
      debugPrint(
        '[ApiService] ${res.request?.url} → ${res.statusCode}: ${res.body}',
      );
      return;
    }
    final list = _extractList(res.body);
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      await DatabaseService.upsertColetaDetalhe({
        'id': m['id'],
        'id_coleta_rota': rotaId,
        'id_produtor': m['id_produtor'] ?? 0,
        'ordem_visita': m['ordem_visita'] ?? 0,
        'data_hora_registro': m['data_hora_registro'],
        'volume_coletado_litros':
            (m['volume_coletado_litros'] as num?)?.toDouble() ?? 0.0,
        'temperatura_leite_c':
            (m['temperatura_leite_c'] as num?)?.toDouble() ?? 0.0,
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

  // ─── Veículos ─────────────────────────────────────────────────────────────

  /// Consulta uma placa na base da retaguarda.
  ///
  /// Devolve os dados do veículo se a placa já estiver cadastrada, ou nulo se
  /// não estiver (404) — é assim que o formulário sabe se está incluindo ou
  /// editando. Lança se o servidor estiver fora do ar, para a tela poder
  /// avisar em vez de dar a placa como inexistente.
  static Future<Map<String, dynamic>?> consultarVeiculoPorPlaca(
    String placa,
  ) async {
    final res = await _get(
      '/coleta/veiculos/placa/${Uri.encodeComponent(placa.trim())}',
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Servidor respondeu ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }

  /// Envia um veículo à retaguarda. Sem [id], inclui; com [id], altera.
  ///
  /// Devolve o id gravado na base do ERP. O servidor também trata placa
  /// repetida como alteração, então cadastrar duas vezes não gera duplicado.
  static Future<int?> salvarVeiculo(
    Map<String, dynamic> dados, {
    int? id,
  }) async {
    final res = id == null
        ? await _post('/coleta/veiculos', dados)
        : await _put('/coleta/veiculos/$id', dados);

    if (res.statusCode != 200 && res.statusCode != 201) {
      debugPrint(
        '[ApiService] salvarVeiculo → ${res.statusCode}: ${res.body}',
      );
      throw Exception(_mensagemDeErro(res.body, res.statusCode));
    }

    final body = jsonDecode(res.body);
    if (body is Map && body['id'] is int) return body['id'] as int;
    return id;
  }

  /// Extrai a mensagem que o servidor mandou, quando ele mandou alguma.
  static String _mensagemDeErro(String corpo, int status) {
    try {
      final body = jsonDecode(corpo);
      if (body is Map) {
        final msg = body['message'] ?? body['error'] ?? body['mensagem'];
        if (msg != null && '$msg'.trim().isNotEmpty) return '$msg';
      }
    } catch (_) {
      // corpo não era JSON — cai no genérico
    }
    return 'O servidor respondeu $status.';
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

  /// Envia o arquivo de foto de uma coleta (multipart/form-data) ao servidor.
  /// Retorna o caminho gerenciado no servidor (uploads/paradas/...) em sucesso,
  /// ou null se offline/erro (nesse caso o caminho local é mantido).
  static Future<String?> uploadFotoColeta(
    int coletaId,
    String localPath,
  ) async {
    try {
      final base = await ServerConfig.baseUrl;
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$base/coleta/detalhes/$coletaId/foto'),
      );
      final headers = _headers
        ..remove('Content-Type'); // multipart define sozinho
      req.headers.addAll(headers);
      req.files.add(await http.MultipartFile.fromPath('foto', localPath));

      final streamed = await req.send().timeout(_kTimeout);
      if (streamed.statusCode != 200) return null;
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['foto_path'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// O servidor respondeu recusando a credencial — diferente de não responder.
/// Só o segundo caso justifica cair para o cache offline.
class _CredencialRecusada implements Exception {
  const _CredencialRecusada(this.mensagem);
  final String mensagem;
}
