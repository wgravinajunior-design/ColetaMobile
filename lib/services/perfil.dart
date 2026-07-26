/// Perfis de acesso, no vocabulário que o ERP grava em `TB_USUARIO.USU_PERFIL`.
///
/// A comparação é feita sem diferenciar maiúsculas nem acentos: a checagem
/// antiga era `perfil == 'Administrador'`, exata e sensível a caixa, então
/// nenhum usuário real passava — o servidor devolve o valor como está no banco,
/// e quando é nulo manda `OPERADOR`.
class Perfil {
  const Perfil._();

  static String _normalizar(String? p) => (p ?? '')
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('Ã', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ô', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ç', 'C');

  /// Só o administrador cadastra pelo celular.
  static bool ehAdministrador(String? perfil) {
    final p = _normalizar(perfil);
    return p == 'ADMIN' || p == 'ADMINISTRADOR' || p == 'GESTOR';
  }

  static bool ehMotorista(String? perfil) => _normalizar(perfil) == 'MOTORISTA';

  /// Rótulo legível para exibir na barra superior.
  static String rotulo(String? perfil) {
    final p = (perfil ?? '').trim();
    if (p.isEmpty) return 'Operador';
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }
}
