import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';
import '../rota_detalhe_page.dart';

class MovimentacoesTab extends StatefulWidget {
  final String userRole;
  const MovimentacoesTab({super.key, required this.userRole});

  @override
  State<MovimentacoesTab> createState() => _MovimentacoesTabState();
}

class _MovimentacoesTabState extends State<MovimentacoesTab> {
  /// Começa no dia de hoje: é a rota que o motorista vai rodar agora.
  DateTime? _data = DateTime.now();
  RotaStatus? _status;

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Rota> _filtrar(List<Rota> rotas) {
    return rotas.where((r) {
      if (_data != null && !_mesmoDia(r.data, _data!)) return false;
      if (_status != null && r.status != _status) return false;
      return true;
    }).toList();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data ?? hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 1),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  String get _rotuloData {
    if (_data == null) return 'Todas as datas';
    final hoje = DateTime.now();
    if (_mesmoDia(_data!, hoje)) return 'Hoje';
    if (_mesmoDia(_data!, hoje.subtract(const Duration(days: 1)))) {
      return 'Ontem';
    }
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(_data!.day)}/${dois(_data!.month)}/${_data!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ColetaProvider>(context);
    final visiveis = _filtrar(provider.rotas);

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
              Text('${visiveis.length} de ${provider.rotas.length} rota(s)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]),
          ]),
        ),
        _buildFiltros(),
        const Divider(height: 1),

        // Lista de rotas
        Expanded(
          child: visiveis.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_outlined, size: 56, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text(
                        _data != null || _status != null
                            ? 'Nenhuma rota para este filtro.'
                            : 'Nenhuma rota disponível.',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                      ),
                      if (_data != null || _status != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Limpar filtros'),
                          onPressed: () => setState(() {
                            _data = null;
                            _status = null;
                          }),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: visiveis.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RotaCard(rota: visiveis[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltros() {
    const statusLabels = {
      RotaStatus.pendente: 'Pendente',
      RotaStatus.liberada: 'Liberada',
      RotaStatus.emAndamento: 'Em andamento',
      RotaStatus.finalizada: 'Finalizada',
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_rotuloData, overflow: TextOverflow.ellipsis),
              onPressed: _escolherData,
            ),
          ),
          // Só aparece com filtro de data ativo — volta para "todas as datas".
          if (_data != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Todas as datas',
              onPressed: () => setState(() => _data = null),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<RotaStatus?>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Status'),
              items: [
                const DropdownMenuItem<RotaStatus?>(
                  value: null,
                  child: Text('Todos os status'),
                ),
                ...statusLabels.entries.map(
                  (e) => DropdownMenuItem<RotaStatus?>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
          ),
        ],
      ),
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
