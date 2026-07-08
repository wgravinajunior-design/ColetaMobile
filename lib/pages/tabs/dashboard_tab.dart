import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';

class DashboardTab extends StatefulWidget {
  final String userRole;
  const DashboardTab({super.key, required this.userRole});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late DateTime _dataInicial;
  late DateTime _dataFinal;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _dataInicial = DateTime(hoje.year, hoje.month, hoje.day);
    _dataFinal   = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({required bool isInicial}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicial ? _dataInicial : _dataFinal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isInicial) {
        _dataInicial = DateTime(picked.year, picked.month, picked.day);
        if (_dataInicial.isAfter(_dataFinal)) {
          _dataFinal = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      } else {
        _dataFinal = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        if (_dataFinal.isBefore(_dataInicial)) {
          _dataInicial = DateTime(picked.year, picked.month, picked.day);
        }
      }
    });
  }

  void _resetarHoje() {
    final hoje = DateTime.now();
    setState(() {
      _dataInicial = DateTime(hoje.year, hoje.month, hoje.day);
      _dataFinal   = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
    });
  }

  bool _dentroDoPeriodo(DateTime? data) {
    if (data == null) return false;
    return !data.isBefore(_dataInicial) && !data.isAfter(_dataFinal);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ColetaProvider>(context);

    // Filtra coletas do período selecionado (todas as rotas)
    final todasColetas = provider.rotas.expand((r) => r.coletas).toList();
    final coletasPeriodo = todasColetas.where((c) => _dentroDoPeriodo(c.dataHoraRegistro)).toList();

    final totalLitros   = coletasPeriodo.fold(0.0, (s, c) => c.status == ColetaStatus.confirmado ? s + c.volumeColetadoLitros : s);
    final qtdRealizadas = coletasPeriodo.where((c) => c.status == ColetaStatus.confirmado).length;
    final qtdRecusadas  = coletasPeriodo.where((c) => c.status == ColetaStatus.recusado).length;
    final qtdAdiadas    = coletasPeriodo.where((c) => c.status == ColetaStatus.adiado).length;
    final qtdPendentes  = todasColetas.where((c) => c.status == ColetaStatus.pendente).length;

    // Rotas do período (por data da rota)
    final rotasPeriodo  = provider.rotas.where((r) => _dentroDoPeriodo(r.data) || _dentroDoPeriodo(r.dataHoraInicio)).toList();
    final rotasConcluidas = rotasPeriodo.where((r) => r.status == RotaStatus.finalizada).length;

    // Alertas
    final alertasTemp = coletasPeriodo.where((c) => c.status == ColetaStatus.confirmado && c.temperaturaLeiteC > 7.0).toList();
    final resfriadoresManutencao = provider.resfriadores.where((r) => r.status == ResfriadorStatus.manutencao).toList();

    final bool isHoje = _fmt(_dataInicial) == _fmt(DateTime.now()) && _fmt(_dataFinal) == _fmt(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filtro de período ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Período de Análise',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const Spacer(),
                  if (!isHoje)
                    GestureDetector(
                      onTap: _resetarHoje,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.today_rounded, size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Hoje', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _DateButton(
                    label: 'Data Inicial',
                    value: _fmt(_dataInicial),
                    onTap: () => _pickDate(isInicial: true),
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: const Text('até', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                  ),
                  Expanded(child: _DateButton(
                    label: 'Data Final',
                    value: _fmt(_dataFinal),
                    onTap: () => _pickDate(isInicial: false),
                  )),
                ]),
                if (isHoje) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textLight),
                    const SizedBox(width: 5),
                    Text('Exibindo dados de hoje · ${_fmt(_dataInicial)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── KPIs principais ───────────────────────────────────────────────
          _SectionTitle(icon: Icons.bar_chart_rounded, title: 'Indicadores do Período'),
          const SizedBox(height: 10),

          // Linha 1: litros + rotas
          Row(children: [
            Expanded(child: _KpiCard(
              title: 'Litros Coletados',
              value: '${totalLitros.toStringAsFixed(0)} L',
              icon: Icons.opacity_rounded,
              color: AppColors.primary,
              subtitle: '${coletasPeriodo.where((c) => c.status == ColetaStatus.confirmado).length} coleta(s)',
            )),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard(
              title: 'Rotas Finalizadas',
              value: '$rotasConcluidas de ${rotasPeriodo.length}',
              icon: Icons.flag_rounded,
              color: AppColors.success,
              subtitle: rotasPeriodo.isEmpty ? 'nenhuma rota' : '${((rotasConcluidas / rotasPeriodo.length) * 100).toStringAsFixed(0)}% concluídas',
            )),
          ]),
          const SizedBox(height: 10),

          // Linha 2: realizadas + recusadas + adiadas + pendentes
          Row(children: [
            Expanded(child: _MiniKpi(
              title: 'Realizadas',
              value: '$qtdRealizadas',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi(
              title: 'Recusadas',
              value: '$qtdRecusadas',
              icon: Icons.cancel_rounded,
              color: AppColors.error,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi(
              title: 'Adiadas',
              value: '$qtdAdiadas',
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi(
              title: 'Pendentes',
              value: '$qtdPendentes',
              icon: Icons.hourglass_empty_rounded,
              color: AppColors.textLight,
            )),
          ]),
          const SizedBox(height: 20),

          // ── Volume por fazenda no período ────────────────────────────────
          _SectionTitle(icon: Icons.opacity_rounded, title: 'Volume por Fazenda'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            padding: const EdgeInsets.all(14),
            child: coletasPeriodo.isEmpty
                ? const _EmptyState(message: 'Nenhuma coleta no período selecionado.')
                : Column(children: [
                    ...coletasPeriodo.map((c) {
                      final confirmado = c.status == ColetaStatus.confirmado;
                      final recusado   = c.status == ColetaStatus.recusado;
                      final adiado     = c.status == ColetaStatus.adiado;
                      final vol = confirmado ? c.volumeColetadoLitros : 0.0;
                      final maxVol = c.produtor.volumeMedioDiario > 0 ? c.produtor.volumeMedioDiario * 1.5 : 1000.0;
                      final pct  = (vol / maxVol).clamp(0.0, 1.0);

                      Color barColor = AppColors.primaryLight;
                      String valText = confirmado
                          ? '${c.volumeColetadoLitros.toStringAsFixed(0)} L'
                          : recusado ? 'Recusado' : adiado ? 'Adiado' : 'Pendente';
                      Color valColor = confirmado ? AppColors.primary
                          : recusado ? AppColors.error
                          : adiado   ? AppColors.warning
                          : AppColors.textLight;
                      if (recusado) barColor = AppColors.error;
                      if (adiado)   barColor = AppColors.warning;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text(c.produtor.nome,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13))),
                            const SizedBox(width: 8),
                            Text(valText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: valColor)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 9,
                              backgroundColor: AppColors.cardBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                          if (confirmado) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.thermostat_rounded, size: 11, color: c.temperaturaLeiteC > 7 ? AppColors.error : AppColors.textLight),
                              const SizedBox(width: 3),
                              Text('${c.temperaturaLeiteC.toStringAsFixed(1)}°C',
                                  style: TextStyle(fontSize: 10, color: c.temperaturaLeiteC > 7 ? AppColors.error : AppColors.textLight)),
                              const SizedBox(width: 10),
                              Icon(Icons.access_time_rounded, size: 11, color: AppColors.textLight),
                              const SizedBox(width: 3),
                              Text(c.dataHoraRegistro != null ? _fmtHora(c.dataHoraRegistro!) : '--',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                            ]),
                          ],
                        ]),
                      );
                    }),
                  ]),
          ),
          const SizedBox(height: 20),

          // ── Rotas do período ─────────────────────────────────────────────
          _SectionTitle(icon: Icons.route_rounded, title: 'Rotas no Período'),
          const SizedBox(height: 10),
          rotasPeriodo.isEmpty
              ? Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  padding: const EdgeInsets.all(20),
                  child: const _EmptyState(message: 'Nenhuma rota no período selecionado.'),
                )
              : Column(children: rotasPeriodo.map((r) => _RotaResumoTile(rota: r)).toList()),
          const SizedBox(height: 20),

          // ── Alertas ────────────────────────────────────────────────────
          _SectionTitle(icon: Icons.warning_amber_rounded, title: 'Alertas e Qualidade'),
          const SizedBox(height: 10),

          if (alertasTemp.isEmpty && resfriadoresManutencao.isEmpty)
            _AlertTile(
              title: 'Tudo sob controle!',
              description: 'Nenhum alerta de temperatura ou manutenção.',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
            ),

          ...alertasTemp.map((a) => _AlertTile(
            title: 'Temperatura Elevada!',
            description: '${a.produtor.nome} · ${a.temperaturaLeiteC.toStringAsFixed(1)}°C (máx: 7.0°C)',
            icon: Icons.thermostat_rounded,
            color: AppColors.error,
          )),

          ...resfriadoresManutencao.map((r) => _AlertTile(
            title: 'Resfriador em Manutenção',
            description: 'ID: ${r.numeroIdentificador} (${r.marcaModelo}) — ${r.capacidadeLitros.toStringAsFixed(0)} L',
            icon: Icons.build_outlined,
            color: AppColors.warning,
          )),
          const SizedBox(height: 20),

          // ── Sincronização ──────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_sync_outlined, color: AppColors.secondary),
              ),
              title: const Text('Sincronização com Servidor',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
              subtitle: const Text('Aguardando conexão com o servidor.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Offline',
                    style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _fmtHora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
  ]);
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ]),
        ]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Icon(Icons.trending_up_rounded, size: 16, color: color.withValues(alpha: 0.5)),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniKpi({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _AlertTile({required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _RotaResumoTile extends StatelessWidget {
  final Rota rota;
  const _RotaResumoTile({required this.rota});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rota.nome, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 13)),
          Text('${rota.coletadas} coletadas · ${rota.totalFazendas} fazendas · ${rota.totalLitros.toStringAsFixed(0)} L',
              style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_statusLabel, style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Column(children: [
    const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textLight),
    const SizedBox(height: 8),
    Text(message, style: const TextStyle(color: AppColors.textLight, fontSize: 13), textAlign: TextAlign.center),
  ]);
}
