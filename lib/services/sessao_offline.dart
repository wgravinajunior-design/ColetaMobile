import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Credencial do último login bem-sucedido, para entrar sem rede.
///
/// O app é usado em rota, onde o sinal cai — e a retaguarda pode estar
/// desligada. Sem isto, um servidor fora do ar prendia o motorista na tela de
/// login, mesmo com todas as rotas já baixadas no aparelho.
///
/// Guarda o hash da senha, nunca a senha. Não é autenticação forte: serve para
/// reconhecer quem já entrou naquele aparelho enquanto o servidor não responde.
class SessaoOffline {
  static const _kLogin = 'offline_login';
  static const _kSenhaHash = 'offline_senha_hash';
  static const _kPerfil = 'offline_perfil';
  static const _kNome = 'offline_nome';
  static const _kQuando = 'offline_quando';
  static const _kUsuarioId = 'offline_usuario_id';
  static const _kMotoristaId = 'offline_motorista_id';

  /// Quanto tempo a credencial em cache continua valendo sem novo login online.
  static const validade = Duration(days: 30);

  static String _hash(String login, String senha) =>
      sha256.convert(utf8.encode('$login::$senha')).toString();

  /// Chamado após um login online bem-sucedido.
  ///
  /// Guarda também o motorista vinculado: sem ele, um motorista que entrasse
  /// offline seria tratado como usuário sem vínculo e o app baixaria as rotas
  /// de todos — exatamente o que o vínculo existe para evitar.
  static Future<void> guardar({
    required String login,
    required String senha,
    required String perfil,
    required String nome,
    int? usuarioId,
    int? motoristaId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLogin, login.trim());
    await prefs.setString(_kSenhaHash, _hash(login.trim(), senha));
    await prefs.setString(_kPerfil, perfil);
    await prefs.setString(_kNome, nome);
    await prefs.setString(_kQuando, DateTime.now().toIso8601String());
    if (usuarioId == null) {
      await prefs.remove(_kUsuarioId);
    } else {
      await prefs.setInt(_kUsuarioId, usuarioId);
    }
    if (motoristaId == null) {
      await prefs.remove(_kMotoristaId);
    } else {
      await prefs.setInt(_kMotoristaId, motoristaId);
    }
  }

  /// Valida a credencial informada contra a que ficou guardada.
  ///
  /// Retorna os dados do usuário em caso de acerto, ou null se não há cache,
  /// se ele expirou, ou se login/senha não conferem.
  static Future<Map<String, dynamic>?> validar(
    String login,
    String senha,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_kLogin);
    final hash = prefs.getString(_kSenhaHash);
    if (guardado == null || hash == null) return null;

    final quando = DateTime.tryParse(prefs.getString(_kQuando) ?? '');
    if (quando == null || DateTime.now().difference(quando) > validade) {
      return null;
    }

    if (guardado != login.trim() || hash != _hash(login.trim(), senha)) {
      return null;
    }

    return {
      'id': prefs.getInt(_kUsuarioId),
      'login': guardado,
      'nome': prefs.getString(_kNome) ?? guardado,
      'perfil': prefs.getString(_kPerfil) ?? 'OPERADOR',
      'motorista_id': prefs.getInt(_kMotoristaId),
      'offline': true,
    };
  }

  /// Verdadeiro quando há credencial guardada e ainda válida.
  static Future<bool> get disponivel async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kSenhaHash) == null) return false;
    final quando = DateTime.tryParse(prefs.getString(_kQuando) ?? '');
    return quando != null && DateTime.now().difference(quando) <= validade;
  }

  static Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kLogin,
      _kSenhaHash,
      _kPerfil,
      _kNome,
      _kQuando,
      _kUsuarioId,
      _kMotoristaId,
    ]) {
      await prefs.remove(k);
    }
  }
}
