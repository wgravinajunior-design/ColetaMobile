import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

// ============================================================================
// ENUMS
// ============================================================================

enum ResfriadorStatus { ativo, inativo, manutencao }

enum ProdutorStatus { ativo, inativo }

enum VeiculoStatus { ativo, inativo, manutencao }

enum MotoristaStatus { ativo, inativo }

enum ColaboradorStatus { ativo, inativo }

enum ColetaStatus { pendente, confirmado, recusado, adiado }

enum RotaStatus { pendente, liberada, emAndamento, finalizada }

// ============================================================================
// MODELOS DE CADASTRO BASE
// ============================================================================

class Resfriador {
  final int id;
  final String numeroIdentificador;
  final String marcaModelo;
  final int anoFabricacao;
  final double capacidadeLitros;
  final DateTime? ultimaManutencao;
  final ResfriadorStatus status;
  Resfriador({
    required this.id,
    required this.numeroIdentificador,
    required this.marcaModelo,
    required this.anoFabricacao,
    required this.capacidadeLitros,
    this.ultimaManutencao,
    required this.status,
  });
}

class Produtor {
  final int id;
  final String nome;
  final String endereco;
  final double latitude;
  final double longitude;
  final double volumeMedioDiario;
  final String horarioColetaPrevisto;
  final double kmAteTanquePrincipal;
  final int? idResfriador;
  final ProdutorStatus status;
  Produtor({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    required this.volumeMedioDiario,
    required this.horarioColetaPrevisto,
    required this.kmAteTanquePrincipal,
    this.idResfriador,
    required this.status,
  });
}

class Veiculo {
  final int id;
  final String descricao;
  final String placa;
  final String modelo;
  final double capacidadeLitros;
  final double consumoMedio;
  final VeiculoStatus status;
  Veiculo({
    required this.id,
    required this.descricao,
    required this.placa,
    this.modelo = '',
    this.capacidadeLitros = 0,
    this.consumoMedio = 0,
    required this.status,
  });
}

class Motorista {
  final int id;
  final String nome;
  final String cnh;
  final String categoriaCnh;
  final int? idVeiculo;
  final MotoristaStatus status;
  Motorista({
    required this.id,
    required this.nome,
    required this.cnh,
    required this.categoriaCnh,
    this.idVeiculo,
    required this.status,
  });
}

class Colaborador {
  final int id;
  final String nome;
  final String cpf;
  final String funcaoCargo;
  final String permissoesAcesso;
  final ColaboradorStatus status;
  Colaborador({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.funcaoCargo,
    required this.permissoesAcesso,
    required this.status,
  });
}

// ============================================================================
// MODELOS DE MOVIMENTAÇÃO
// ============================================================================

class ColetaDetalhe {
  final int id;
  final Produtor produtor;
  final int ordemVisita;
  DateTime? dataHoraRegistro;
  double volumeColetadoLitros;
  double temperaturaLeiteC;
  String observacao;
  String motivoAdiamento;
  ColetaStatus status;
  String? fotoCaminho;

  ColetaDetalhe({
    required this.id,
    required this.produtor,
    required this.ordemVisita,
    this.dataHoraRegistro,
    this.volumeColetadoLitros = 0.0,
    this.temperaturaLeiteC = 0.0,
    this.observacao = '',
    this.motivoAdiamento = '',
    this.status = ColetaStatus.pendente,
    this.fotoCaminho,
  });

  bool get resolvido => status != ColetaStatus.pendente;
}

class Rota {
  final int id;
  final String nome;
  final String veiculoDescricao;
  final String motoristaNome;
  final DateTime data;
  RotaStatus status;
  DateTime? dataHoraInicio;
  DateTime? dataHoraFim;
  final List<ColetaDetalhe> coletas;

  Rota({
    required this.id,
    required this.nome,
    required this.veiculoDescricao,
    required this.motoristaNome,
    required this.data,
    this.status = RotaStatus.pendente,
    this.dataHoraInicio,
    this.dataHoraFim,
    required this.coletas,
  });

  int get totalFazendas => coletas.length;
  int get coletadas =>
      coletas.where((c) => c.status == ColetaStatus.confirmado).length;
  int get recusadas =>
      coletas.where((c) => c.status == ColetaStatus.recusado).length;
  int get adiadas =>
      coletas.where((c) => c.status == ColetaStatus.adiado).length;
  int get pendentes =>
      coletas.where((c) => c.status == ColetaStatus.pendente).length;
  bool get todasResolvidas => coletas.every((c) => c.resolvido);
  double get totalLitros => coletas.fold(
    0.0,
    (s, c) =>
        c.status == ColetaStatus.confirmado ? s + c.volumeColetadoLitros : s,
  );
}

// ============================================================================
// PROVIDER
// ============================================================================

enum SyncStatus { idle, syncing, ok, error }

class ColetaProvider extends ChangeNotifier {
  /// Verdadeiro só enquanto a carga inicial roda de fato.
  ///
  /// Começava em `true` antes de qualquer coisa ter começado, o que travou a
  /// tela de login numa versão anterior: ela esperava esse sinal, e a carga só
  /// vinha depois de autenticar. Nada de nascer "carregando" sem estar.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;

  // Itens registrados localmente aguardando envio ao servidor (pending_sync = 1).
  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  // Fotos ainda só no device, aguardando upload.
  int _pendingFotos = 0;
  int get pendingFotos => _pendingFotos;

  Timer? _pollingTimer;

  final List<Resfriador> _resfriadores = [];
  final List<Produtor> _produtores = [];
  final List<Veiculo> _veiculos = [];
  final List<Motorista> _motoristas = [];
  final List<Colaborador> _colaboradores = [];
  final List<Rota> _rotas = [];

  List<Resfriador> get resfriadores => List.unmodifiable(_resfriadores);
  List<Produtor> get produtores => List.unmodifiable(_produtores);
  List<Veiculo> get veiculos => List.unmodifiable(_veiculos);
  List<Motorista> get motoristas => List.unmodifiable(_motoristas);
  List<Colaborador> get colaboradores => List.unmodifiable(_colaboradores);
  List<Rota> get rotas => List.unmodifiable(_rotas);

  List<ColetaDetalhe> get coletasDoDia =>
      _rotas.isNotEmpty ? _rotas.first.coletas : [];
  double get totalLitrosColetados =>
      _rotas.fold(0.0, (s, r) => s + r.totalLitros);
  int get quantidadeColetasRealizadas =>
      _rotas.fold(0, (s, r) => s + r.coletadas);
  int get quantidadeColetasRecusadas =>
      _rotas.fold(0, (s, r) => s + r.recusadas);
  int get quantidadeColetasPendentes =>
      _rotas.fold(0, (s, r) => s + r.pendentes);

  ColetaProvider() {
    // Sem carga aqui: o provider nasce junto do app, e abrir o banco +
    // sincronizar antes do login deixava a tela inicial presa em
    // "carregando banco de dados". Quem chama é a Home, depois de autenticar.
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  bool _flushing = false;
  StreamSubscription<ConnectivityResult>? _connSub;
  bool _online = true;

  bool _iniciado = false;

  /// Abre o banco local, sincroniza e liga o polling.
  ///
  /// Chamado pela Home logo após o login — antes disso não há por que tocar no
  /// banco nem na rede. Repetir a chamada não faz nada.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    await _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    // Envia primeiro o que ficou pendente de sessões anteriores,
    // depois baixa as novidades do ERP (o download preserva o que está pendente).
    await flushPending();
    final ok = await ApiService.syncAll();
    _syncStatus = ok ? SyncStatus.ok : SyncStatus.error;

    await _loadFromDatabase();
    _isLoading = false;
    notifyListeners();

    // Polling a cada 2 minutos como rede de segurança (só dados operacionais).
    _pollingTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _syncCycle(),
    );

    // Ao reconectar, faz um ciclo COMPLETO (cadastros + rotas) para pôr tudo em dia.
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      final agoraOnline = result != ConnectivityResult.none;
      final voltou = agoraOnline && !_online;
      _online = agoraOnline;
      if (voltou) _syncCycle(full: true);
    });
  }

  /// Um ciclo de sincronização: envia pendências e rebaixa os dados do ERP.
  /// [full] = também rebaixa os cadastros; senão, só rotas/detalhes (cache leve).
  /// Reentrância protegida via [_flushing] no flushPending.
  /// Ciclo completo pedido pelo usuário — o toque na faixa de status.
  ///
  /// Se o app entrou offline, o banco ainda não foi aberto: [iniciar] cuida
  /// disso e já faz o primeiro ciclo.
  Future<void> sincronizarAgora() async {
    if (!_iniciado) return iniciar();
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    await _syncCycle(full: true);
    if (_syncStatus == SyncStatus.syncing) _syncStatus = SyncStatus.error;
    notifyListeners();
  }

  Future<void> _syncCycle({bool full = false}) async {
    await flushPending();
    final synced = full
        ? await ApiService.syncAll()
        : await ApiService.syncOperacional();
    if (synced) {
      _syncStatus = SyncStatus.ok;
      _resfriadores.clear();
      _produtores.clear();
      _veiculos.clear();
      _motoristas.clear();
      _colaboradores.clear();
      _rotas.clear();
      await _loadFromDatabase();
      notifyListeners();
    }
  }

  /// Envia ao servidor todas as coletas/rotas registradas localmente e ainda
  /// não sincronizadas (pending_sync = 1). Itens confirmados pelo servidor têm
  /// o pending_sync zerado; falhas permanecem pendentes para nova tentativa.
  /// Seguro para chamar repetidamente (reentrância protegida).
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final r in await DatabaseService.getPendingRotas()) {
        final ok = await ApiService.pushRotaStatus(
          r['id'] as int,
          r['status'] as String,
          dataHoraInicio: r['data_hora_inicio'] as String?,
          dataHoraFim: r['data_hora_fim'] as String?,
        );
        if (ok) await DatabaseService.markRotaSynced(r['id'] as int);
      }
      for (final d in await DatabaseService.getPendingDetalhes()) {
        final id = d['id'] as int;
        var fotoCaminho = d['foto_caminho'] as String?;

        // Foto tirada offline ainda em caminho local do device → tenta subir o
        // arquivo agora. Caminho do servidor começa com 'uploads/'.
        if (fotoCaminho != null &&
            fotoCaminho.isNotEmpty &&
            !fotoCaminho.startsWith('uploads/')) {
          final serverPath = await ApiService.uploadFotoColeta(id, fotoCaminho);
          if (serverPath != null) {
            fotoCaminho = serverPath;
            await DatabaseService.updateColetaDetalhe(id, {
              'foto_caminho': serverPath,
            });
            _setFotoEmMemoria(id, serverPath);
          }
        }

        final ok = await ApiService.pushColetaDetalhe(id, {
          'volume_coletado_litros': d['volume_coletado_litros'],
          'temperatura_leite_c': d['temperatura_leite_c'],
          'observacao': d['observacao'],
          'motivo_adiamento': d['motivo_adiamento'],
          'foto_caminho': fotoCaminho,
          'data_hora_registro': d['data_hora_registro'],
          'status': d['status'],
        });
        if (ok) await DatabaseService.markDetalheSynced(id);
      }

      // Retenta fotos que ficaram só no device (ex.: detalhe já sincronizado
      // mas o upload da foto falhou/foi rejeitado antes). Roda depois do laço
      // acima, então só pega as que ainda estão locais.
      for (final d in await DatabaseService.getDetalhesComFotoLocal()) {
        final id = d['id'] as int;
        final local = d['foto_caminho'] as String;
        final serverPath = await ApiService.uploadFotoColeta(id, local);
        if (serverPath != null) {
          await DatabaseService.updateColetaDetalhe(id, {
            'foto_caminho': serverPath,
          });
          _setFotoEmMemoria(id, serverPath);
          await ApiService.pushColetaDetalhe(id, {'foto_caminho': serverPath});
        }
      }
    } finally {
      _flushing = false;
      _pendingCount = await DatabaseService.countPending();
      _pendingFotos = await DatabaseService.countPendingFotos();
      notifyListeners();
    }
  }

  /// Envia o arquivo de foto de uma coleta ao servidor (best-effort).
  /// Em sucesso, troca o caminho local pelo caminho gerenciado do servidor
  /// (em memória e no SQLite). Offline/erro: mantém o caminho local — o retry
  /// acontece depois no flushPending.
  Future<void> uploadFotoColeta(int coletaId, String localPath) async {
    final serverPath = await ApiService.uploadFotoColeta(coletaId, localPath);
    if (serverPath == null) return;

    await DatabaseService.updateColetaDetalhe(coletaId, {
      'foto_caminho': serverPath,
    });
    _setFotoEmMemoria(coletaId, serverPath);
  }

  /// Atualiza o caminho da foto no modelo em memória e notifica a UI.
  void _setFotoEmMemoria(int coletaId, String caminho) {
    for (final r in _rotas) {
      for (final c in r.coletas) {
        if (c.id == coletaId) {
          c.fotoCaminho = caminho;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Força uma nova sincronização manual com o servidor.
  Future<void> refresh() async {
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    await flushPending();
    final ok = await ApiService.syncAll();
    _syncStatus = ok ? SyncStatus.ok : SyncStatus.error;

    _resfriadores.clear();
    _produtores.clear();
    _veiculos.clear();
    _motoristas.clear();
    _colaboradores.clear();
    _rotas.clear();

    await _loadFromDatabase();
    notifyListeners();
  }

  Future<void> _loadFromDatabase() async {
    final resRows = await DatabaseService.getResfriadores();
    final prodRows = await DatabaseService.getProdutores();
    final veicRows = await DatabaseService.getVeiculos();
    final motRows = await DatabaseService.getMotoristas();
    final colabRows = await DatabaseService.getColaboradores();
    final rotaRows = await DatabaseService.getColetasRotaComJoin();

    _resfriadores.addAll(resRows.map(_resfriadorFromMap));
    _produtores.addAll(prodRows.map(_produtorFromMap));
    _veiculos.addAll(veicRows.map(_veiculoFromMap));
    _motoristas.addAll(motRows.map(_motoristaFromMap));
    _colaboradores.addAll(colabRows.map(_colaboradorFromMap));

    for (final row in rotaRows) {
      final detalheRows = await DatabaseService.getColetasDetalheComJoin(
        row['id'] as int,
      );
      _rotas.add(
        _rotaFromMap(row, detalheRows.map(_coletaDetalheFromMap).toList()),
      );
    }
  }

  // ============================================================================
  // PARSERS (DB → Modelo)
  // ============================================================================

  static Resfriador _resfriadorFromMap(Map<String, dynamic> m) => Resfriador(
    id: m['id'] as int,
    numeroIdentificador: m['numero_identificador'] as String,
    marcaModelo: m['marca_modelo'] as String,
    anoFabricacao: m['ano_fabricacao'] as int,
    capacidadeLitros: (m['capacidade_litros'] as num).toDouble(),
    ultimaManutencao: m['ultima_manutencao'] != null
        ? DateTime.tryParse(m['ultima_manutencao'] as String)
        : null,
    status: _parseResfriadorStatus(m['status'] as String),
  );

  static Produtor _produtorFromMap(Map<String, dynamic> m) => Produtor(
    id: m['id'] as int,
    nome: m['nome'] as String,
    endereco: m['endereco'] as String,
    latitude: (m['latitude'] as num).toDouble(),
    longitude: (m['longitude'] as num).toDouble(),
    volumeMedioDiario: (m['volume_medio_diario'] as num).toDouble(),
    horarioColetaPrevisto: m['horario_coleta_previsto'] as String,
    kmAteTanquePrincipal: (m['km_ate_tanque_principal'] as num).toDouble(),
    idResfriador: m['id_resfriador'] as int?,
    status: _parseProdutorStatus(m['status'] as String),
  );

  static Veiculo _veiculoFromMap(Map<String, dynamic> m) => Veiculo(
    id: m['id'] as int,
    descricao: m['descricao'] as String,
    placa: m['placa'] as String,
    modelo: (m['modelo'] as String?) ?? '',
    capacidadeLitros: (m['capacidade_litros'] as num?)?.toDouble() ?? 0,
    consumoMedio: (m['consumo_medio'] as num?)?.toDouble() ?? 0,
    status: _parseVeiculoStatus(m['status'] as String),
  );

  static Motorista _motoristaFromMap(Map<String, dynamic> m) => Motorista(
    id: m['id'] as int,
    nome: m['nome'] as String,
    cnh: m['cnh'] as String,
    categoriaCnh: m['categoria_cnh'] as String,
    idVeiculo: m['id_veiculo'] as int?,
    status: _parseMotoristaStatus(m['status'] as String),
  );

  static Colaborador _colaboradorFromMap(Map<String, dynamic> m) => Colaborador(
    id: m['id'] as int,
    nome: m['nome'] as String,
    cpf: m['cpf'] as String,
    funcaoCargo: m['funcao_cargo'] as String,
    permissoesAcesso: m['permissoes'] as String,
    status: _parseColaboradorStatus(m['status'] as String),
  );

  static ColetaDetalhe _coletaDetalheFromMap(Map<String, dynamic> m) {
    final produtor = Produtor(
      id: m['id_produtor'] as int,
      nome: m['produtor_nome'] as String,
      endereco: m['produtor_endereco'] as String,
      latitude: (m['latitude'] as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
      volumeMedioDiario: (m['volume_medio_diario'] as num).toDouble(),
      horarioColetaPrevisto: m['horario_coleta_previsto'] as String,
      kmAteTanquePrincipal: (m['km_ate_tanque_principal'] as num).toDouble(),
      idResfriador: m['id_resfriador'] as int?,
      status: _parseProdutorStatus(m['produtor_status'] as String),
    );
    return ColetaDetalhe(
      id: m['id'] as int,
      produtor: produtor,
      ordemVisita: m['ordem_visita'] as int,
      dataHoraRegistro: m['data_hora_registro'] != null
          ? DateTime.tryParse(m['data_hora_registro'] as String)
          : null,
      volumeColetadoLitros:
          (m['volume_coletado_litros'] as num?)?.toDouble() ?? 0.0,
      temperaturaLeiteC: (m['temperatura_leite_c'] as num?)?.toDouble() ?? 0.0,
      observacao: m['observacao'] as String? ?? '',
      motivoAdiamento: m['motivo_adiamento'] as String? ?? '',
      status: _parseColetaStatus(m['status'] as String),
      fotoCaminho: m['foto_caminho'] as String?,
    );
  }

  static Rota _rotaFromMap(
    Map<String, dynamic> m,
    List<ColetaDetalhe> coletas,
  ) => Rota(
    id: m['id'] as int,
    nome: m['nome'] as String,
    veiculoDescricao: '${m['veiculo_placa']} · ${m['veiculo_descricao']}',
    motoristaNome: m['motorista_nome'] as String,
    data: DateTime.parse(m['data_coleta'] as String),
    status: _parseRotaStatus(m['status'] as String),
    dataHoraInicio: m['data_hora_inicio'] != null
        ? DateTime.tryParse(m['data_hora_inicio'] as String)
        : null,
    dataHoraFim: m['data_hora_fim'] != null
        ? DateTime.tryParse(m['data_hora_fim'] as String)
        : null,
    coletas: coletas,
  );

  // ============================================================================
  // CONVERSORES STATUS (enum → String e String → enum)
  // ============================================================================

  static ResfriadorStatus _parseResfriadorStatus(String s) {
    switch (s) {
      case 'INATIVO':
        return ResfriadorStatus.inativo;
      case 'MANUTENCAO':
        return ResfriadorStatus.manutencao;
      default:
        return ResfriadorStatus.ativo;
    }
  }

  static String _resfriadorStatusStr(ResfriadorStatus s) {
    switch (s) {
      case ResfriadorStatus.inativo:
        return 'INATIVO';
      case ResfriadorStatus.manutencao:
        return 'MANUTENCAO';
      default:
        return 'ATIVO';
    }
  }

  static ProdutorStatus _parseProdutorStatus(String s) =>
      s == 'INATIVO' ? ProdutorStatus.inativo : ProdutorStatus.ativo;
  static String _produtorStatusStr(ProdutorStatus s) =>
      s == ProdutorStatus.inativo ? 'INATIVO' : 'ATIVO';

  static VeiculoStatus _parseVeiculoStatus(String s) {
    switch (s) {
      case 'INATIVO':
        return VeiculoStatus.inativo;
      case 'MANUTENCAO':
        return VeiculoStatus.manutencao;
      default:
        return VeiculoStatus.ativo;
    }
  }

  static String _veiculoStatusStr(VeiculoStatus s) {
    switch (s) {
      case VeiculoStatus.inativo:
        return 'INATIVO';
      case VeiculoStatus.manutencao:
        return 'MANUTENCAO';
      default:
        return 'ATIVO';
    }
  }

  static MotoristaStatus _parseMotoristaStatus(String s) =>
      s == 'INATIVO' ? MotoristaStatus.inativo : MotoristaStatus.ativo;
  static String _motoristaStatusStr(MotoristaStatus s) =>
      s == MotoristaStatus.inativo ? 'INATIVO' : 'ATIVO';

  static ColaboradorStatus _parseColaboradorStatus(String s) =>
      s == 'INATIVO' ? ColaboradorStatus.inativo : ColaboradorStatus.ativo;
  static String _colaboradorStatusStr(ColaboradorStatus s) =>
      s == ColaboradorStatus.inativo ? 'INATIVO' : 'ATIVO';

  static ColetaStatus _parseColetaStatus(String s) {
    switch (s) {
      case 'CONFIRMADO':
        return ColetaStatus.confirmado;
      case 'RECUSADO':
        return ColetaStatus.recusado;
      case 'ADIADO':
        return ColetaStatus.adiado;
      default:
        return ColetaStatus.pendente;
    }
  }

  static String _coletaStatusStr(ColetaStatus s) {
    switch (s) {
      case ColetaStatus.confirmado:
        return 'CONFIRMADO';
      case ColetaStatus.recusado:
        return 'RECUSADO';
      case ColetaStatus.adiado:
        return 'ADIADO';
      default:
        return 'PENDENTE';
    }
  }

  static RotaStatus _parseRotaStatus(String s) {
    switch (s) {
      case 'LIBERADA':
        return RotaStatus.liberada;
      case 'EM_ANDAMENTO':
        return RotaStatus.emAndamento;
      case 'CONCLUIDA':
        return RotaStatus.finalizada;
      default:
        return RotaStatus.pendente;
    }
  }

  // ============================================================================
  // OPERAÇÕES DE ROTA
  // ============================================================================

  Rota? rotaPorId(int id) {
    try {
      return _rotas.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  void iniciarRota(int rotaId) {
    final rota = rotaPorId(rotaId);
    if (rota == null) return;
    // Aceita pendente ou liberada (liberada = disponível para o motorista)
    if (rota.status == RotaStatus.finalizada) return;
    final now = DateTime.now();
    rota.status = RotaStatus.emAndamento;
    rota.dataHoraInicio = now;
    notifyListeners();
    final nowStr = now.toIso8601String();
    DatabaseService.updateColetaRota(rotaId, {
      'status': 'EM_ANDAMENTO',
      'data_hora_inicio': nowStr,
      'pending_sync': 1,
    }).then((_) => flushPending());
  }

  void realizarColeta({
    required int rotaId,
    required int coletaId,
    required double volume,
    required double temperatura,
    required String observacao,
    String? fotoPath,
    required bool recusada,
  }) {
    final coleta = _coletaPorId(rotaId, coletaId);
    if (coleta == null) return;
    final now = DateTime.now();
    coleta.volumeColetadoLitros = volume;
    coleta.temperaturaLeiteC = temperatura;
    coleta.observacao = observacao;
    coleta.fotoCaminho = fotoPath;
    coleta.dataHoraRegistro = now;
    coleta.status = recusada ? ColetaStatus.recusado : ColetaStatus.confirmado;
    _atualizarStatusRota(rotaId);
    notifyListeners();
    final detalheData = {
      'volume_coletado_litros': volume,
      'temperatura_leite_c': temperatura,
      'observacao': observacao,
      'foto_caminho': fotoPath,
      'data_hora_registro': now.toIso8601String(),
      'status': _coletaStatusStr(coleta.status),
      'pending_sync': 1,
    };
    DatabaseService.updateColetaDetalhe(
      coletaId,
      detalheData,
    ).then((_) => flushPending());
  }

  void adiarColeta({
    required int rotaId,
    required int coletaId,
    required String motivo,
  }) {
    final coleta = _coletaPorId(rotaId, coletaId);
    if (coleta == null) return;
    final now = DateTime.now();
    coleta.status = ColetaStatus.adiado;
    coleta.motivoAdiamento = motivo;
    coleta.dataHoraRegistro = now;
    _atualizarStatusRota(rotaId);
    notifyListeners();
    final detalheData = {
      'status': 'ADIADO',
      'motivo_adiamento': motivo,
      'data_hora_registro': now.toIso8601String(),
      'pending_sync': 1,
    };
    DatabaseService.updateColetaDetalhe(
      coletaId,
      detalheData,
    ).then((_) => flushPending());
  }

  void finalizarRota(int rotaId) {
    final rota = rotaPorId(rotaId);
    if (rota == null) return;
    final now = DateTime.now();
    rota.status = RotaStatus.finalizada;
    rota.dataHoraFim = now;
    notifyListeners();
    final nowStr = now.toIso8601String();
    DatabaseService.updateColetaRota(rotaId, {
      'status': 'CONCLUIDA',
      'data_hora_fim': nowStr,
      'pending_sync': 1,
    }).then((_) => flushPending());
  }

  void _atualizarStatusRota(int rotaId) {
    final rota = rotaPorId(rotaId);
    if (rota != null && rota.status == RotaStatus.pendente)
      rota.status = RotaStatus.emAndamento;
  }

  ColetaDetalhe? _coletaPorId(int rotaId, int coletaId) {
    final rota = rotaPorId(rotaId);
    if (rota == null) return null;
    try {
      return rota.coletas.firstWhere((c) => c.id == coletaId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // CADASTROS (persistem no banco e atualizam memória)
  // ============================================================================

  Future<void> addResfriador(Resfriador r) async {
    final id = await DatabaseService.insertResfriador({
      'numero_identificador': r.numeroIdentificador,
      'marca_modelo': r.marcaModelo,
      'ano_fabricacao': r.anoFabricacao,
      'capacidade_litros': r.capacidadeLitros,
      'ultima_manutencao': r.ultimaManutencao?.toIso8601String(),
      'status': _resfriadorStatusStr(r.status),
    });
    _resfriadores.add(
      Resfriador(
        id: id,
        numeroIdentificador: r.numeroIdentificador,
        marcaModelo: r.marcaModelo,
        anoFabricacao: r.anoFabricacao,
        capacidadeLitros: r.capacidadeLitros,
        ultimaManutencao: r.ultimaManutencao,
        status: r.status,
      ),
    );
    notifyListeners();
  }

  Future<void> addProdutor(Produtor p) async {
    final id = await DatabaseService.insertProdutor({
      'nome': p.nome,
      'endereco': p.endereco,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'volume_medio_diario': p.volumeMedioDiario,
      'horario_coleta_previsto': p.horarioColetaPrevisto,
      'km_ate_tanque_principal': p.kmAteTanquePrincipal,
      'id_resfriador': p.idResfriador,
      'status': _produtorStatusStr(p.status),
    });
    _produtores.add(
      Produtor(
        id: id,
        nome: p.nome,
        endereco: p.endereco,
        latitude: p.latitude,
        longitude: p.longitude,
        volumeMedioDiario: p.volumeMedioDiario,
        horarioColetaPrevisto: p.horarioColetaPrevisto,
        kmAteTanquePrincipal: p.kmAteTanquePrincipal,
        idResfriador: p.idResfriador,
        status: p.status,
      ),
    );
    notifyListeners();
  }

  /// Cadastra ou altera um veículo.
  ///
  /// Vai primeiro ao servidor: o veículo precisa existir na base do ERP para
  /// aparecer nas rotas, e o id que vale é o de lá. Antes isto gravava só no
  /// SQLite do aparelho, e o cadastro sumia na sincronização seguinte.
  ///
  /// Lança se o servidor recusar ou estiver fora do ar — quem chamou mostra o
  /// motivo, em vez de dar o cadastro como salvo.
  Future<void> salvarVeiculo(Veiculo v, {int? idExistente}) async {
    final idNoErp = await ApiService.salvarVeiculo({
      'placa': v.placa,
      'descricao': v.descricao,
      'modelo': v.modelo,
    }, id: idExistente);

    final linha = {
      'descricao': v.descricao,
      'placa': v.placa,
      'modelo': v.modelo,
      'capacidade_litros': v.capacidadeLitros,
      'consumo_medio': v.consumoMedio,
      'status': _veiculoStatusStr(v.status),
    };

    // Espelha localmente com o id do ERP, para a lista já mostrar o veículo
    // sem depender da próxima sincronização.
    final id = idNoErp ?? idExistente;
    if (id != null) {
      await DatabaseService.upsertVeiculo({'id': id, ...linha});
    } else {
      await DatabaseService.insertVeiculo(linha);
    }

    final novo = Veiculo(
      id: id ?? 0,
      descricao: v.descricao,
      placa: v.placa,
      modelo: v.modelo,
      capacidadeLitros: v.capacidadeLitros,
      consumoMedio: v.consumoMedio,
      status: v.status,
    );
    final i = _veiculos.indexWhere((x) => x.id == novo.id && novo.id != 0);
    if (i >= 0) {
      _veiculos[i] = novo;
    } else {
      _veiculos.add(novo);
    }
    notifyListeners();
  }

  Future<void> addMotorista(Motorista m) async {
    final id = await DatabaseService.insertMotorista({
      'nome': m.nome,
      'cnh': m.cnh,
      'categoria_cnh': m.categoriaCnh,
      'id_veiculo': m.idVeiculo,
      'status': _motoristaStatusStr(m.status),
    });
    _motoristas.add(
      Motorista(
        id: id,
        nome: m.nome,
        cnh: m.cnh,
        categoriaCnh: m.categoriaCnh,
        idVeiculo: m.idVeiculo,
        status: m.status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateMotorista(Motorista m) async {
    final data = {
      'nome': m.nome,
      'cnh': m.cnh,
      'categoria_cnh': m.categoriaCnh,
      'id_veiculo': m.idVeiculo,
      'status': _motoristaStatusStr(m.status),
    };
    await DatabaseService.updateMotorista(m.id, data);
    final idx = _motoristas.indexWhere((x) => x.id == m.id);
    if (idx != -1) _motoristas[idx] = m;
    notifyListeners();
  }

  Future<void> deleteMotorista(int id) async {
    await DatabaseService.deleteMotorista(id);
    _motoristas.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Future<void> addColaborador(Colaborador c) async {
    final id = await DatabaseService.insertColaborador({
      'nome': c.nome,
      'cpf': c.cpf,
      'funcao_cargo': c.funcaoCargo,
      'permissoes': c.permissoesAcesso,
      'status': _colaboradorStatusStr(c.status),
    });
    _colaboradores.add(
      Colaborador(
        id: id,
        nome: c.nome,
        cpf: c.cpf,
        funcaoCargo: c.funcaoCargo,
        permissoesAcesso: c.permissoesAcesso,
        status: c.status,
      ),
    );
    notifyListeners();
  }

  Future<void> updateColaborador(Colaborador c) async {
    final data = {
      'nome': c.nome,
      'cpf': c.cpf,
      'funcao_cargo': c.funcaoCargo,
      'permissoes': c.permissoesAcesso,
      'status': _colaboradorStatusStr(c.status),
    };
    await DatabaseService.updateColaborador(c.id, data);
    final idx = _colaboradores.indexWhere((x) => x.id == c.id);
    if (idx != -1) _colaboradores[idx] = c;
    notifyListeners();
  }

  Future<void> deleteColaborador(int id) async {
    await DatabaseService.deleteColaborador(id);
    _colaboradores.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}
