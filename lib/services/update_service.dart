import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Versão do app. Mantenha em sincronia com o `version:` do pubspec.yaml ao
/// publicar uma release — é o número comparado com a última tag do GitHub.
const String appVersao = '1.8.0';

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
  static Future<VersaoDisponivel?> verificar() async {
    try {
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoAtualizacao/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);

      if (resposta.statusCode != 200) return null;

      final json = jsonDecode(resposta.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      if (tag.isEmpty || !ehMaisNova(tag, appVersao)) return null;

      final assets = (json['assets'] as List?) ?? const [];
      final apk = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        orElse: () => <String, dynamic>{},
      );

      return VersaoDisponivel(
        versao: tag,
        notas: (json['body'] as String?) ?? '',
        urlApk: (apk['browser_download_url'] as String?) ?? '',
        urlRelease: (json['html_url'] as String?) ?? '',
        tamanhoBytes: (apk['size'] as int?) ?? 0,
      );
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
