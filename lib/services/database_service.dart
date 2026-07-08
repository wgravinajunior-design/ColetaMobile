import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'coleta_leite.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  // ---- DDL ----

  static Future<void> _createTables(Database db) async {
    final b = db.batch();

    b.execute('''CREATE TABLE resfriadores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numero_identificador TEXT NOT NULL,
      marca_modelo TEXT NOT NULL,
      ano_fabricacao INTEGER NOT NULL,
      capacidade_litros REAL NOT NULL,
      ultima_manutencao TEXT,
      status TEXT NOT NULL DEFAULT 'ATIVO'
    )''');

    b.execute('''CREATE TABLE produtores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      endereco TEXT NOT NULL,
      latitude REAL DEFAULT 0,
      longitude REAL DEFAULT 0,
      volume_medio_diario REAL DEFAULT 0,
      horario_coleta_previsto TEXT NOT NULL,
      km_ate_tanque_principal REAL DEFAULT 0,
      id_resfriador INTEGER,
      status TEXT NOT NULL DEFAULT 'ATIVO'
    )''');

    b.execute('''CREATE TABLE veiculos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      descricao TEXT NOT NULL,
      placa TEXT NOT NULL,
      capacidade_litros REAL NOT NULL,
      consumo_medio REAL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'ATIVO'
    )''');

    b.execute('''CREATE TABLE motoristas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      cnh TEXT NOT NULL,
      categoria_cnh TEXT NOT NULL,
      id_veiculo INTEGER,
      status TEXT NOT NULL DEFAULT 'ATIVO'
    )''');

    b.execute('''CREATE TABLE colaboradores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      cpf TEXT NOT NULL,
      funcao_cargo TEXT NOT NULL,
      permissoes TEXT NOT NULL DEFAULT 'Operador',
      status TEXT NOT NULL DEFAULT 'ATIVO'
    )''');

    b.execute('''CREATE TABLE coletas_rota (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      id_motorista INTEGER NOT NULL,
      id_veiculo INTEGER NOT NULL,
      data_coleta TEXT NOT NULL,
      data_hora_inicio TEXT,
      data_hora_fim TEXT,
      status TEXT NOT NULL DEFAULT 'PENDENTE'
    )''');

    b.execute('''CREATE TABLE coletas_detalhe (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_coleta_rota INTEGER NOT NULL,
      id_produtor INTEGER NOT NULL,
      ordem_visita INTEGER NOT NULL,
      data_hora_registro TEXT,
      volume_coletado_litros REAL DEFAULT 0,
      temperatura_leite_c REAL DEFAULT 0,
      observacao TEXT DEFAULT '',
      motivo_adiamento TEXT DEFAULT '',
      status TEXT NOT NULL DEFAULT 'PENDENTE',
      foto_caminho TEXT
    )''');

    await b.commit(noResult: true);
  }

  // ---- CRUD: Resfriadores ----

  static Future<int> insertResfriador(Map<String, dynamic> data) async =>
      (await database).insert('resfriadores', data);

  static Future<List<Map<String, dynamic>>> getResfriadores() async =>
      (await database).query('resfriadores', orderBy: 'numero_identificador');

  static Future<void> upsertResfriador(Map<String, dynamic> data) async =>
      (await database).insert('resfriadores', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- CRUD: Produtores ----

  static Future<int> insertProdutor(Map<String, dynamic> data) async =>
      (await database).insert('produtores', data);

  static Future<List<Map<String, dynamic>>> getProdutores() async =>
      (await database).query('produtores', orderBy: 'nome');

  static Future<void> upsertProdutor(Map<String, dynamic> data) async =>
      (await database).insert('produtores', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- CRUD: Veículos ----

  static Future<int> insertVeiculo(Map<String, dynamic> data) async =>
      (await database).insert('veiculos', data);

  static Future<List<Map<String, dynamic>>> getVeiculos() async =>
      (await database).query('veiculos', orderBy: 'descricao');

  static Future<void> upsertVeiculo(Map<String, dynamic> data) async =>
      (await database).insert('veiculos', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- CRUD: Motoristas ----

  static Future<int> insertMotorista(Map<String, dynamic> data) async =>
      (await database).insert('motoristas', data);

  static Future<List<Map<String, dynamic>>> getMotoristas() async =>
      (await database).query('motoristas', orderBy: 'nome');

  static Future<void> updateMotorista(int id, Map<String, dynamic> data) async =>
      (await database).update('motoristas', data, where: 'id = ?', whereArgs: [id]);

  static Future<void> deleteMotorista(int id) async =>
      (await database).delete('motoristas', where: 'id = ?', whereArgs: [id]);

  static Future<void> upsertMotorista(Map<String, dynamic> data) async =>
      (await database).insert('motoristas', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- CRUD: Colaboradores ----

  static Future<int> insertColaborador(Map<String, dynamic> data) async =>
      (await database).insert('colaboradores', data);

  static Future<List<Map<String, dynamic>>> getColaboradores() async =>
      (await database).query('colaboradores', orderBy: 'nome');

  static Future<void> updateColaborador(int id, Map<String, dynamic> data) async =>
      (await database).update('colaboradores', data, where: 'id = ?', whereArgs: [id]);

  static Future<void> deleteColaborador(int id) async =>
      (await database).delete('colaboradores', where: 'id = ?', whereArgs: [id]);

  static Future<void> upsertColaborador(Map<String, dynamic> data) async =>
      (await database).insert('colaboradores', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- CRUD: Coletas Rota ----

  static Future<int> insertColetaRota(Map<String, dynamic> data) async =>
      (await database).insert('coletas_rota', data);

  static Future<void> updateColetaRota(int id, Map<String, dynamic> data) async =>
      (await database).update('coletas_rota', data, where: 'id = ?', whereArgs: [id]);

  static Future<void> upsertColetaRota(Map<String, dynamic> data) async =>
      (await database).insert('coletas_rota', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Map<String, dynamic>>> getColetasRotaComJoin() async =>
      (await database).rawQuery('''
        SELECT cr.*,
               m.nome      AS motorista_nome,
               v.descricao AS veiculo_descricao,
               v.placa     AS veiculo_placa
        FROM coletas_rota cr
        JOIN motoristas m ON cr.id_motorista = m.id
        JOIN veiculos   v ON cr.id_veiculo   = v.id
        ORDER BY cr.data_coleta DESC, cr.id DESC
      ''');

  // ---- CRUD: Coletas Detalhe ----

  static Future<int> insertColetaDetalhe(Map<String, dynamic> data) async =>
      (await database).insert('coletas_detalhe', data);

  static Future<void> updateColetaDetalhe(int id, Map<String, dynamic> data) async =>
      (await database).update('coletas_detalhe', data, where: 'id = ?', whereArgs: [id]);

  static Future<void> upsertColetaDetalhe(Map<String, dynamic> data) async =>
      (await database).insert('coletas_detalhe', data,
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Map<String, dynamic>>> getColetasDetalheComJoin(int idColetaRota) async =>
      (await database).rawQuery('''
        SELECT cd.*,
               p.nome                    AS produtor_nome,
               p.endereco                AS produtor_endereco,
               p.latitude,
               p.longitude,
               p.volume_medio_diario,
               p.horario_coleta_previsto,
               p.km_ate_tanque_principal,
               p.id_resfriador,
               p.status                  AS produtor_status
        FROM coletas_detalhe cd
        JOIN produtores p ON cd.id_produtor = p.id
        WHERE cd.id_coleta_rota = ?
        ORDER BY cd.ordem_visita
      ''', [idColetaRota]);

  /// Retorna rotas com status EM_ANDAMENTO ou CONCLUIDA com seus detalhes,
  /// formatadas para o payload do POST /coleta/sync.
  static Future<List<Map<String, dynamic>>> getRotasParaSync() async {
    final db = await database;
    final rotas = await db.query(
      'coletas_rota',
      where: "status IN ('EM_ANDAMENTO', 'CONCLUIDA')",
    );

    final result = <Map<String, dynamic>>[];
    for (final rota in rotas) {
      final detalhes = await db.query(
        'coletas_detalhe',
        where: 'id_coleta_rota = ?',
        whereArgs: [rota['id']],
        orderBy: 'ordem_visita',
      );
      result.add({
        ...rota,
        'detalhes': detalhes.toList(),
      });
    }
    return result;
  }
}
