import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show AppColors;
import '../services/update_service.dart';

/// Renderiza o subconjunto de Markdown usado nas notas de release (títulos
/// `##`, itens `-`, `**negrito**`), sem trazer um pacote só para isso.
class NotasRelease extends StatelessWidget {
  const NotasRelease(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    for (final linha in texto.split('\n')) {
      final t = linha.trim();
      if (t.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      if (t.startsWith('|') || t.startsWith('```')) continue;

      if (t.startsWith('##')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              t.replaceAll(RegExp(r'^#+\s*'), ''),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        );
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: _rico(context, t.substring(2))),
              ],
            ),
          ),
        );
        continue;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _rico(context, t),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _rico(BuildContext context, String t) {
    final spans = <TextSpan>[];
    final padrao = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    var indice = 0;

    for (final m in padrao.allMatches(t)) {
      if (m.start > indice) {
        spans.add(TextSpan(text: t.substring(indice, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1) ?? m.group(2),
          style: m.group(1) != null
              ? const TextStyle(fontWeight: FontWeight.bold)
              : const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
      indice = m.end;
    }
    if (indice < t.length) spans.add(TextSpan(text: t.substring(indice)));

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 13, height: 1.4),
        children: spans,
      ),
    );
  }
}

/// Verificação pedida pelo usuário, com resposta visível nos dois desfechos.
///
/// A checagem da abertura é silenciosa quando não há novidade — o que faz
/// parecer que nada aconteceu. Aqui sempre há retorno.
Future<void> verificarAtualizacaoManualmente(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Procurando atualizações...')),
        ],
      ),
    ),
  );

  final nova = await UpdateService.verificar();

  if (!context.mounted) return;
  Navigator.of(context).pop(); // fecha o "procurando"

  if (nova == null) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 10),
            Text('Tudo em dia'),
          ],
        ),
        content: Text('Você já está na versão mais recente ($appVersao).'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    return;
  }

  await DialogoAtualizacao.mostrar(context, nova);
}

/// Avisa que há uma versão nova e leva o usuário ao download.
///
/// Instalar um APK exige a confirmação do próprio Android, então o app abre o
/// arquivo no navegador em vez de tentar instalar por conta — evita depender
/// da permissão de instalar pacotes de fontes desconhecidas.
class DialogoAtualizacao extends StatelessWidget {
  const DialogoAtualizacao({required this.versao, super.key});

  final VersaoDisponivel versao;

  static Future<void> mostrar(BuildContext context, VersaoDisponivel v) =>
      showDialog(
        context: context,
        builder: (_) => DialogoAtualizacao(versao: v),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Nova versão', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versão ${versao.versao} · você está na $appVersao',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 12),
              NotasRelease(versao.notas),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Agora não'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: Text(
            versao.tamanhoBytes > 0
                ? 'Baixar (${versao.tamanhoMb.toStringAsFixed(0)} MB)'
                : 'Baixar',
          ),
          onPressed: () async {
            final url = versao.urlApk.isNotEmpty
                ? versao.urlApk
                : versao.urlRelease;
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// Mostra as melhorias logo depois de uma atualização.
class DialogoNovidades extends StatelessWidget {
  const DialogoNovidades({required this.notas, super.key});

  final String notas;

  static Future<void> mostrar(BuildContext context, String notas) => showDialog(
    context: context,
    builder: (_) => DialogoNovidades(notas: notas),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('App atualizado', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Faixa com a build instalada: é a primeira pergunta de quem
              // acabou de atualizar.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Build $appVersao instalada',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              NotasRelease(notas),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
