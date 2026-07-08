import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';
import '../forms/produtor_form.dart';
import '../forms/resfriador_form.dart';
import '../forms/veiculo_form.dart';
import '../forms/motorista_form.dart';
import '../forms/colaborador_form.dart';

class CadastrosTab extends StatefulWidget {
  final String userRole;
  const CadastrosTab({super.key, required this.userRole});

  @override
  State<CadastrosTab> createState() => _CadastrosTabState();
}

class _CadastrosTabState extends State<CadastrosTab> {
  String _activeCategory = 'Produtores';

  // ─── card de cadastro ────────────────────────────────────────────────────
  Widget _buildRegistrationCard({
    required String title,
    required IconData icon,
    required List<String> bullets,
    required Widget formWidget,
  }) {
    final isAllowed = widget.userRole == 'Administrador';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isAllowed) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => formWidget));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Apenas administradores podem cadastrar novos dados.'),
              backgroundColor: AppColors.error,
            ));
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...bullets.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              Expanded(
                                  child: Text(b,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMedium,
                                          height: 1.3))),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ─── botão de filtro ─────────────────────────────────────────────────────
  Widget _buildFilterChip(String name, IconData icon) {
    final isActive = _activeCategory == name;
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? AppColors.primary : AppColors.cardBorder),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isActive ? Colors.white : AppColors.textLight),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isActive ? Colors.white : AppColors.textMedium)),
          ],
        ),
      ),
    );
  }

  // ─── helper: badge status ────────────────────────────────────────────────
  Widget _statusBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      );

  // ─── helper: info pill ───────────────────────────────────────────────────
  Widget _infoPill(String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: color ?? AppColors.primary,
                fontWeight: FontWeight.w600)),
      );

  // ─── listas de registros ─────────────────────────────────────────────────
  Widget _buildActiveList(ColetaProvider provider) {
    switch (_activeCategory) {
      case 'Produtores':
        return _buildListWrapper(
          items: provider.produtores,
          builder: (prod) => _listTile(
            icon: Icons.agriculture,
            iconColor: AppColors.primary,
            title: prod.nome,
            subtitle: prod.endereco,
            trailing: Wrap(spacing: 6, children: [
              _infoPill('${prod.volumeMedioDiario} L/dia'),
              _infoPill(prod.horarioColetaPrevisto,
                  color: AppColors.textMedium),
            ]),
          ),
        );

      case 'Resfriadores':
        return _buildListWrapper(
          items: provider.resfriadores,
          builder: (res) {
            Color sc = AppColors.success;
            String sl = 'Ativo';
            if (res.status == ResfriadorStatus.inativo) {
              sc = AppColors.error;
              sl = 'Inativo';
            } else if (res.status == ResfriadorStatus.manutencao) {
              sc = AppColors.warning;
              sl = 'Manutenção';
            }
            return _listTile(
              icon: Icons.ac_unit_rounded,
              iconColor: AppColors.secondary,
              title: '${res.marcaModelo} — ${res.numeroIdentificador}',
              subtitle:
                  'Capacidade: ${res.capacidadeLitros} L · Ano: ${res.anoFabricacao}',
              trailing:
                  Wrap(spacing: 6, children: [_statusBadge(sl, sc)]),
            );
          },
        );

      case 'Veículos':
        return _buildListWrapper(
          items: provider.veiculos,
          builder: (v) => _listTile(
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF7B1FA2),
            title: v.descricao,
            subtitle: 'Placa: ${v.placa} · Cap: ${v.capacidadeLitros} L',
            trailing: Wrap(spacing: 6, children: [
              _statusBadge(
                  v.status == VeiculoStatus.ativo ? 'Ativo' : 'Manutenção',
                  v.status == VeiculoStatus.ativo
                      ? AppColors.success
                      : AppColors.warning),
            ]),
          ),
        );

      case 'Motoristas':
        return _buildListWrapper(
          items: provider.motoristas,
          builder: (m) {
            final v = provider.veiculos.firstWhere(
                (x) => x.id == m.idVeiculo,
                orElse: () => Veiculo(
                    id: 0,
                    descricao: 'Nenhum',
                    placa: '-',
                    capacidadeLitros: 0,
                    consumoMedio: 0,
                    status: VeiculoStatus.inativo));
            return _listTile(
              icon: Icons.badge_rounded,
              iconColor: AppColors.warning,
              title: m.nome,
              subtitle: 'CNH: ${m.cnh} (Cat. ${m.categoriaCnh})',
              trailing: Wrap(
                spacing: 6,
                children: [
                  _statusBadge(
                    m.status == MotoristaStatus.ativo ? 'Ativo' : 'Inativo',
                    m.status == MotoristaStatus.ativo ? AppColors.success : AppColors.error,
                  ),
                  _infoPill(v.descricao, color: AppColors.textMedium),
                ],
              ),
              onEdit: widget.userRole == 'Administrador'
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MotoristaForm(motorista: m),
                        ),
                      )
                  : null,
              onDelete: widget.userRole == 'Administrador'
                  ? () => _confirmDelete(
                        context,
                        nome: m.nome,
                        onConfirm: () => provider.deleteMotorista(m.id),
                      )
                  : null,
            );
          },
        );

      case 'Colaboradores':
        return _buildListWrapper(
          items: provider.colaboradores,
          builder: (col) => _listTile(
            icon: Icons.people_rounded,
            iconColor: const Color(0xFF0277BD),
            title: col.nome,
            subtitle: '${col.funcaoCargo} · ${col.permissoesAcesso}',
            trailing: Wrap(spacing: 6, children: [
              _statusBadge(
                col.status == ColaboradorStatus.ativo ? 'Ativo' : 'Inativo',
                col.status == ColaboradorStatus.ativo
                    ? AppColors.success
                    : AppColors.error,
              ),
            ]),
            onEdit: widget.userRole == 'Administrador'
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ColaboradorForm(colaborador: col),
                      ),
                    )
                : null,
            onDelete: widget.userRole == 'Administrador'
                ? () => _confirmDelete(
                      context,
                      nome: col.nome,
                      onConfirm: () => provider.deleteColaborador(col.id),
                    )
                : null,
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildListWrapper<T>({
    required List<T> items,
    required Widget Function(T) builder,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.textLight),
            SizedBox(height: 8),
            Text('Nenhum registro encontrado.',
                style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: builder(items[i]),
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 12)),
                const SizedBox(height: 6),
                trailing,
              ],
            ),
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _actionIconButton(
                    icon: Icons.edit_outlined,
                    color: AppColors.primary,
                    tooltip: 'Editar',
                    onTap: onEdit,
                  ),
                if (onDelete != null)
                  _actionIconButton(
                    icon: Icons.delete_outline,
                    color: AppColors.error,
                    tooltip: 'Excluir',
                    onTap: onDelete,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String nome,
    required Future<void> Function() onConfirm,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirmar exclusão',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        content: Text(
          'Deseja excluir "$nome"?\nEsta ação não pode ser desfeita.',
          style: const TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) await onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ColetaProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: const Row(children: [
              Icon(Icons.storage_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('CADASTROS — DADOS BASE',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.6)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Cards de cadastro ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildRegistrationCard(
                  title: 'Produtores',
                  icon: Icons.agriculture,
                  bullets: [
                    'Dados completos',
                    'Localização (GPS)',
                    'Volume médio · Horários de coleta',
                    'Resfriador vinculado',
                  ],
                  formWidget: const ProdutorForm(),
                ),
                const SizedBox(height: 10),
                _buildRegistrationCard(
                  title: 'Resfriadores',
                  icon: Icons.ac_unit_rounded,
                  bullets: [
                    'Nº Identificador · Marca / Modelo',
                    'Capacidade (L) · Ano',
                    'Manutenções · Status',
                  ],
                  formWidget: const ResfriadorForm(),
                ),
                const SizedBox(height: 10),
                _buildRegistrationCard(
                  title: 'Veículos / Caminhões',
                  icon: Icons.local_shipping_rounded,
                  bullets: [
                    'Placa · Capacidade',
                    'Consumo médio · Status',
                  ],
                  formWidget: const VeiculoForm(),
                ),
                const SizedBox(height: 10),
                _buildRegistrationCard(
                  title: 'Motoristas',
                  icon: Icons.badge_rounded,
                  bullets: [
                    'Dados pessoais · CNH / Categoria',
                    'Caminhão vinculado · Status',
                  ],
                  formWidget: const MotoristaForm(),
                ),
                const SizedBox(height: 10),
                _buildRegistrationCard(
                  title: 'Colaboradores',
                  icon: Icons.people_rounded,
                  bullets: [
                    'Função / Cargo',
                    'Permissões de acesso · Status',
                  ],
                  formWidget: const ColaboradorForm(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Visualização de registros ───────────────────────────────────
          const Text('Visualização de Registros',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildFilterChip('Produtores', Icons.agriculture),
              _buildFilterChip('Resfriadores', Icons.ac_unit_rounded),
              _buildFilterChip('Veículos', Icons.local_shipping_rounded),
              _buildFilterChip('Motoristas', Icons.badge_rounded),
              _buildFilterChip('Colaboradores', Icons.people_rounded),
            ]),
          ),
          const SizedBox(height: 14),
          _buildActiveList(provider),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
