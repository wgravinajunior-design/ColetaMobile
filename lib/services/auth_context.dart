/// Quem está logado nesta sessão do app.
///
/// Existe para o app saber, depois do login, se quem entrou é um motorista — e,
/// nesse caso, baixar e mostrar apenas as rotas dele. Vale até o logout.
class AuthContext {
  static int? usuarioId;
  static String usuarioLogin = '';
  static String usuarioPerfil = 'OPERADOR';

  /// PES_ID do motorista vinculado ao usuário (TB_USUARIO.USU_MOTORISTA_ID),
  /// ou null quando o usuário não é motorista — ou quando a base ainda não tem
  /// a coluna do vínculo.
  static int? motoristaId;

  /// Verdadeiro só quando há motorista vinculado. É o que decide entre baixar
  /// as rotas de um motorista ou as de todos.
  static bool get ehMotorista => motoristaId != null;

  /// Preenche a partir da resposta de `/auth/login`.
  ///
  /// Deliberadamente tolerante: a mesma resposta pode vir do servidor ou do
  /// cache offline, e nem toda instalação tem o vínculo de motorista. Um campo
  /// ausente, nulo ou de tipo inesperado não pode derrubar o login — antes
  /// disto um `as int` num campo que chegava String impedia qualquer um de
  /// entrar.
  static void inicializar(Map<String, dynamic> user) {
    usuarioId = _inteiro(user['id']);
    // O login offline guarda o próprio login em 'id'; online ele vem em chave
    // própria e 'id' é o USU_ID numérico.
    usuarioLogin = (user['login'] ?? user['id'] ?? '').toString().trim();
    final perfil = (user['perfil'] ?? '').toString().trim();
    usuarioPerfil = perfil.isEmpty ? 'OPERADOR' : perfil;
    motoristaId = _inteiro(user['motorista_id']);
  }

  static void logout() {
    usuarioId = null;
    usuarioLogin = '';
    usuarioPerfil = 'OPERADOR';
    motoristaId = null;
  }

  static int? _inteiro(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v'.trim());
  }
}
