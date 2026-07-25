import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../services/server_config.dart';
import '../services/api_service.dart';
import 'login_page.dart';

// Representa cada item da lista de sincronização
class _SyncItem {
  final String label;
  final IconData icon;
  int baixados;
  int total;
  _SyncStatus status;

  _SyncItem({
    required this.label,
    required this.icon,
    this.baixados = 0,
    this.total = 0,
    this.status = _SyncStatus.aguardando,
  });
}

enum _SyncStatus { aguardando, sincronizando, concluido, erro }

class AtualizarPage extends StatefulWidget {
  const AtualizarPage({super.key});

  @override
  State<AtualizarPage> createState() => _AtualizarPageState();
}

class _AtualizarPageState extends State<AtualizarPage> {
  String _modalidade = 'Apenas Modificados';
  bool _sincronizando = false;

  final List<_SyncItem> _itens = [
    _SyncItem(label: 'Envio de Coletas Pendentes', icon: Icons.upload_outlined),
    _SyncItem(label: 'Produtores', icon: Icons.person_pin_outlined),
    _SyncItem(label: 'Veículos', icon: Icons.local_shipping_outlined),
    _SyncItem(label: 'Motoristas', icon: Icons.drive_eta_outlined),
    _SyncItem(label: 'Resfriadores', icon: Icons.ac_unit_outlined),
    _SyncItem(label: 'Colaboradores', icon: Icons.badge_outlined),
    _SyncItem(label: 'Definição de Rotas', icon: Icons.alt_route_outlined),
    _SyncItem(
      label: 'Programação de Coletas',
      icon: Icons.calendar_month_outlined,
    ),
  ];

  Future<void> _iniciarAtualizacao() async {
    setState(() {
      _sincronizando = true;
      for (final item in _itens) {
        item.status = _SyncStatus.aguardando;
        item.baixados = 0;
        item.total = 0;
      }
    });

    final endereco = await ServerConfig.getEndereco();
    final porta = await ServerConfig.getPorta();

    // Verifica conexão antes de começar
    final erroConexao = await ServerConfig.testarConexao(endereco, porta);
    if (erroConexao != null) {
      if (mounted) {
        setState(() {
          _sincronizando = false;
          for (final item in _itens) {
            item.status = _SyncStatus.erro;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sem conexão com o servidor: $erroConexao'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // 1. Envia dados offline pendentes ao servidor
    setState(() => _itens[0].status = _SyncStatus.sincronizando);
    try {
      await ApiService.pushSync();
      if (mounted) setState(() => _itens[0].status = _SyncStatus.concluido);
    } on UnauthorizedException {
      _handleUnauthorized();
      return;
    } catch (_) {
      if (mounted) setState(() => _itens[0].status = _SyncStatus.erro);
    }

    // 2. Baixa todos os dados atualizados do servidor
    for (int i = 1; i < _itens.length; i++) {
      if (!mounted) return;
      setState(() => _itens[i].status = _SyncStatus.sincronizando);
    }

    try {
      final ok = await ApiService.syncAll();
      if (!mounted) return;
      for (int i = 1; i < _itens.length; i++) {
        setState(() {
          _itens[i].status = ok ? _SyncStatus.concluido : _SyncStatus.erro;
        });
      }
    } on UnauthorizedException {
      _handleUnauthorized();
      return;
    } catch (_) {
      if (!mounted) return;
      for (int i = 1; i < _itens.length; i++) {
        setState(() => _itens[i].status = _SyncStatus.erro);
      }
    }

    if (mounted) {
      setState(() => _sincronizando = false);
      final algumErro = _itens.any((i) => i.status == _SyncStatus.erro);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            algumErro
                ? 'Alguns itens falharam. Verifique a conexão.'
                : 'Atualização concluída!',
          ),
          backgroundColor: algumErro ? AppColors.error : AppColors.success,
        ),
      );
    }
  }

  void _handleUnauthorized() {
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sessão expirada. Faça login novamente.'),
        backgroundColor: AppColors.error,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Atualizar Dados'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Cabeçalho com seleção de modalidade + botão
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Combobox de modalidade
                DropdownButtonFormField<String>(
                  value: _modalidade,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de atualização',
                    prefixIcon: Icon(Icons.tune_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Apenas Modificados',
                      child: Text('Apenas Modificados'),
                    ),
                    DropdownMenuItem(value: 'Tudo', child: Text('Tudo')),
                  ],
                  onChanged: _sincronizando
                      ? null
                      : (v) => setState(() => _modalidade = v!),
                ),
                const SizedBox(height: 14),

                // Botão Atualizar
                ElevatedButton.icon(
                  onPressed: _sincronizando ? null : _iniciarAtualizacao,
                  icon: _sincronizando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 20),
                  label: Text(_sincronizando ? 'Atualizando...' : 'Atualizar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de itens de sincronização
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _itens.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final item = _itens[index];
                return _SyncItemTile(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile individual de sincronização
// ---------------------------------------------------------------------------
class _SyncItemTile extends StatelessWidget {
  final _SyncItem item;
  const _SyncItemTile({super.key, required this.item});

  Color get _statusColor {
    switch (item.status) {
      case _SyncStatus.concluido:
        return AppColors.success;
      case _SyncStatus.sincronizando:
        return AppColors.primary;
      case _SyncStatus.erro:
        return AppColors.error;
      case _SyncStatus.aguardando:
        return AppColors.textLight;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case _SyncStatus.concluido:
        return Icons.check_circle_rounded;
      case _SyncStatus.sincronizando:
        return Icons.sync_rounded;
      case _SyncStatus.erro:
        return Icons.error_rounded;
      case _SyncStatus.aguardando:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Ícone do item
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),

          // Label + contagem
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.baixados} / ${item.total}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),

          // Status
          if (item.status == _SyncStatus.sincronizando)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _statusColor,
              ),
            )
          else
            Icon(_statusIcon, color: _statusColor, size: 22),
        ],
      ),
    );
  }
}
