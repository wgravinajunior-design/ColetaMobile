import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';
import '../rota_detalhe_page.dart';

class MovimentacoesTab extends StatelessWidget {
  final String userRole;
  const MovimentacoesTab({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ColetaProvider>(context);
    final rotas = provider.rotas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Rotas de Coleta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text('${rotas.length} rota(s) disponível(is)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]),
          ]),
        ),
        const Divider(height: 1),

        // Lista de rotas
        Expanded(
          child: rotas.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_outlined, size: 56, color: AppColors.textLight),
                      SizedBox(height: 12),
                      Text('Nenhuma rota disponível.',
                          style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: rotas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RotaCard(rota: rotas[i]),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de rota
// ---------------------------------------------------------------------------
class _RotaCard extends StatelessWidget {
  final Rota rota;
  const _RotaCard({required this.rota});

  Color get _statusColor {
    switch (rota.status) {
      case RotaStatus.pendente:    return AppColors.textLight;
      case RotaStatus.liberada:    return AppColors.primary;
      case RotaStatus.emAndamento: return AppColors.warning;
      case RotaStatus.finalizada:  return AppColors.success;
    }
  }

  String get _statusLabel {
    switch (rota.status) {
      case RotaStatus.pendente:    return 'Pendente';
      case RotaStatus.liberada:    return 'Liberada';
      case RotaStatus.emAndamento: return 'Em andamento';
      case RotaStatus.finalizada:  return 'Finalizada';
    }
  }

  IconData get _statusIcon {
    switch (rota.status) {
      case RotaStatus.pendente:    return Icons.hourglass_empty_rounded;
      case RotaStatus.liberada:    return Icons.check_box_outlined;
      case RotaStatus.emAndamento: return Icons.directions_car_rounded;
      case RotaStatus.finalizada:  return Icons.check_circle_rounded;
    }
  }

  String _formatDate(DateTime d) {
    final hoje  = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    if (d.year == hoje.year  && d.month == hoje.month  && d.day == hoje.day)  return 'Hoje';
    if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) return 'Ontem';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final concluidas = rota.coletadas + rota.recusadas + rota.adiadas;
    final progresso  = rota.totalFazendas > 0 ? concluidas / rota.totalFazendas : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RotaDetalhePage(rotaId: rota.id)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _statusColor.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome + status
              Row(children: [
                Expanded(
                  child: Text(rota.nome,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ),
                const SizedBox(width: 8),
                _badge(_statusLabel, _statusColor, _statusIcon),
              ]),
              const SizedBox(height: 10),

              // Infos
              _infoRow(Icons.local_shipping_outlined, rota.veiculoDescricao),
              const SizedBox(height: 4),
              _infoRow(Icons.badge_outlined, rota.motoristaNome),
              const SizedBox(height: 4),
              _infoRow(Icons.calendar_today_outlined, _formatDate(rota.data)),
              const SizedBox(height: 12),

              // Barra de progresso
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$concluidas de ${rota.totalFazendas} fazenda(s)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                Text('${(progresso * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: _statusColor, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progresso,
                  minHeight: 7,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                ),
              ),

              // Pills de resumo
              if (rota.coletadas > 0 || rota.adiadas > 0 || rota.pendentes > 0) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  if (rota.coletadas > 0) _miniPill('${rota.coletadas} coletadas', AppColors.success),
                  if (rota.recusadas > 0) _miniPill('${rota.recusadas} recusadas', AppColors.error),
                  if (rota.adiadas > 0)   _miniPill('${rota.adiadas} adiadas', AppColors.warning),
                  if (rota.pendentes > 0) _miniPill('${rota.pendentes} pendentes', AppColors.textLight),
                ]),
              ],

              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(rota.status == RotaStatus.finalizada ? 'Ver detalhes' : 'Abrir rota',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 14, color: AppColors.textLight),
    const SizedBox(width: 6),
    Expanded(child: Text(text,
        style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
        overflow: TextOverflow.ellipsis)),
  ]);

  Widget _badge(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _miniPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}
