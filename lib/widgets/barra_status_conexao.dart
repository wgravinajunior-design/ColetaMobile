import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show AppColors;
import '../providers/coleta_provider.dart';

/// Faixa fina abaixo da barra superior dizendo em que modo o app está.
///
/// Sem isto não dava para saber se o aparelho estava falando com a retaguarda
/// ou trabalhando só com o que tem no celular — e a diferença importa: offline,
/// as coletas ficam guardadas até a conexão voltar.
class BarraStatusConexao extends StatelessWidget {
  const BarraStatusConexao({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ColetaProvider>(
      builder: (context, p, _) {
        final pendentes = p.pendingCount + p.pendingFotos;

        final (texto, cor, icone, girando) = switch (p.syncStatus) {
          SyncStatus.syncing => (
            'Sincronizando com a retaguarda...',
            AppColors.primary,
            Icons.sync,
            true,
          ),
          SyncStatus.error when pendentes > 0 => (
            'Sem conexão · $pendentes ${pendentes == 1 ? "registro aguarda" : "registros aguardam"} envio',
            AppColors.error,
            Icons.cloud_off_rounded,
            false,
          ),
          SyncStatus.error => (
            'Sem conexão com a retaguarda · trabalhando offline',
            AppColors.error,
            Icons.cloud_off_rounded,
            false,
          ),
          SyncStatus.ok when pendentes > 0 => (
            '$pendentes ${pendentes == 1 ? "registro pendente" : "registros pendentes"} de envio',
            Colors.orange.shade800,
            Icons.cloud_upload_rounded,
            false,
          ),
          SyncStatus.ok => (
            'Conectado · tudo sincronizado',
            AppColors.success,
            Icons.cloud_done_rounded,
            false,
          ),
          // Antes do primeiro ciclo ainda não se sabe se há retaguarda.
          SyncStatus.idle => (
            'Aguardando sincronização',
            AppColors.textLight,
            Icons.cloud_queue_rounded,
            false,
          ),
        };

        return Material(
          color: cor.withValues(alpha: 0.10),
          child: InkWell(
            // Tocar força um ciclo: quem vê "sem conexão" quer justamente
            // tentar de novo assim que o sinal volta.
            onTap: girando ? null : p.sincronizarAgora,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                children: [
                  if (girando)
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cor,
                      ),
                    )
                  else
                    Icon(icone, size: 15, color: cor),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 12,
                        color: cor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!girando)
                    Text(
                      'Tentar agora',
                      style: TextStyle(
                        fontSize: 11,
                        color: cor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: cor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
