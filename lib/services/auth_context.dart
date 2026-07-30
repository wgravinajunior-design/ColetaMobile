/// Contexto global do usuário autenticado
/// Persiste durante toda a sessão até logout
class AuthContext {
  static late int usuarioId;
  static late String usuarioLogin;
  static late String usuarioPerfil;
  static late int? motoristaId; // FK para TB_PESSOA se for motorista
  static late String? motoristaLogin;

  /// Verifica se o usuário logado é motorista
  static bool get ehMotorista => motoristaId != null;

  /// Limpa o contexto ao fazer logout
  static Future<void> logout() async {
    usuarioId = 0;
    usuarioLogin = '';
    usuarioPerfil = '';
    motoristaId = null;
    motoristaLogin = null;
  }

  /// Inicializa com dados do login
  static void inicializar({
    required int id,
    required String login,
    required String perfil,
    int? motoristaIdVinculado,
    String? motoristaLoginVinculado,
  }) {
    usuarioId = id;
    usuarioLogin = login;
    usuarioPerfil = perfil;
    motoristaId = motoristaIdVinculado;
    motoristaLogin = motoristaLoginVinculado;
  }
}
