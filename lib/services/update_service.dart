import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versão em execução, lida do próprio pacote.
///
/// Antes era uma constante mantida à mão em paralelo ao `version:` do
/// `pubspec.yaml`. Bastava esquecer de sincronizar para o app comparar a
/// versão errada com a última tag do GitHub — deixando de oferecer uma
/// atualização que existe, ou oferecendo uma que já está instalada.
class AppInfo {
  const AppInfo._();

  /// Vale até [carregar] terminar; a interface só consulta depois disso.
  static String _versao = '0.0.0';

  static String get versao => _versao;

  /// Lê a versão do bundle. Chamada uma vez no arranque.
  static Future<void> carregar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Descarta um eventual sufixo de build ("1.9.0+12"): ele não entra na
      // comparação com a tag do GitHub nem na exibição.
      final limpa = info.version.split('+').first.trim();
      if (limpa.isNotEmpty) _versao = limpa;
    } catch (e) {
      debugPrint('[AppInfo] não foi possível ler a versão do pacote: $e');
    }
  }
}

/// Atalho usado pela interface e pelo verificador de atualização.
String get appVersao => AppInfo.versao;

/// Repositório público de onde saem as atualizações.
const String repoAtualizacao = 'wgravinajunior-design/ColetaMobile';

class VersaoDisponivel {
  final String versao;
  final String notas;
  final String urlApk;
  final String urlRelease;
  final int tamanhoBytes;

  const VersaoDisponivel({
    required this.versao,
    required this.notas,
    required this.urlApk,
    required this.urlRelease,
    required this.tamanhoBytes,
  });

  double get tamanhoMb => tamanhoBytes / 1048576;
}

/// Verifica atualizações nas releases públicas do GitHub.
///
/// O repositório é público de propósito: o download não exige token embutido
/// no APK.
class UpdateService {
  static const _timeout = Duration(seconds: 12);
  static const _chaveVersaoVista = 'ultima_versao_vista';

  /// Última release, ou null se já estamos atualizados / a rede falhou.
  /// Nunca lança: uma checagem de atualização não pode impedir o app de abrir.
  /// Detecta qualquer versão mais nova (inclui beta/prerelease).
  static Future<VersaoDisponivel?> verificar() async {
    try {
      // /releases/latest ignora prerelease; busca todas e pega a mais nova
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoAtualizacao/releases?per_page=10',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);

      if (resposta.statusCode != 200) return null;

      final releases = (jsonDecode(resposta.body) as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];

      // Procura primeira release que é mais nova que a atual
      for (final release in releases) {
        final tag =
            (release['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
        if (tag.isEmpty || !ehMaisNova(tag, appVersao)) continue;

        final assets = (release['assets'] as List?) ?? const [];
        final apk = assets.cast<Map<String, dynamic>>().firstWhere(
          (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );

        if (apk.isEmpty) continue; // sem APK, ignora

        return VersaoDisponivel(
          versao: tag,
          notas: (release['body'] as String?) ?? '',
          urlApk: (apk['browser_download_url'] as String?) ?? '',
          urlRelease: (release['html_url'] as String?) ?? '',
          tamanhoBytes: (apk['size'] as int?) ?? 0,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[UpdateService] falha ao verificar: $e');
      return null;
    }
  }

  /// Compara duas versões no formato `x.y.z`.
  static bool ehMaisNova(String candidata, String atual) {
    List<int> partes(String v) => v
        .split('+')
        .first
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();

    final a = partes(candidata);
    final b = partes(atual);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<String?> versaoVista() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveVersaoVista);
  }

  static Future<void> marcarVersaoVista(String versao) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveVersaoVista, versao);
  }

  /// Notas da release da versão em execução, para o popup de novidades.
  static Future<String?> notasDaVersaoAtual() async {
    try {
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoAtualizacao/releases/tags/v$appVersao',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);
      if (resposta.statusCode != 200) return null;
      final json = jsonDecode(resposta.body) as Map<String, dynamic>;
      return json['body'] as String?;
    } catch (_) {
      return null;
    }
  }
}
