import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show AppColors;
import '../providers/coleta_provider.dart';
import '../services/server_config.dart';
import '../services/api_service.dart';
import '../services/perfil.dart';
import '../services/update_service.dart';
import '../widgets/update_dialogs.dart';
import 'tabs/cadastros_tab.dart';
import 'tabs/movimentacoes_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'atualizar_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  final String userRole;
  const HomePage({super.key, required this.userRole});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  /// Só uma vez por execução, mesmo que a Home seja reconstruída.
  static bool _jaVerificouAtualizacao = false;

  bool get _isMotorista => Perfil.ehMotorista(widget.userRole);

  /// Cadastrar pelo celular é exclusivo do administrador.
  bool get _isAdmin => Perfil.ehAdministrador(widget.userRole);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Só aqui o banco é aberto e sincronizado: antes do login não há por que
      // tocar nele, e fazer isso no construtor do provider prendia a tela
      // inicial em "carregando banco de dados".
      context.read<ColetaProvider>().iniciar();

      if (!_jaVerificouAtualizacao) {
        _jaVerificouAtualizacao = true;
        _rodarAtualizacao();
      }
    });
  }

  /// Mostra as novidades da versão recém instalada e depois avisa se há uma
  /// versão mais nova. Nunca interrompe o uso: falha de rede é ignorada.
  Future<void> _rodarAtualizacao() async {
    final anterior = await UpdateService.versaoVista();
    if (anterior == null) {
      // Primeira execução: só registra, sem popup de novidades.
      await UpdateService.marcarVersaoVista(appVersao);
    } else if (anterior != appVersao) {
      final notas = await UpdateService.notasDaVersaoAtual();
      await UpdateService.marcarVersaoVista(appVersao);
      if (mounted && notas != null && notas.trim().isNotEmpty) {
        await DialogoNovidades.mostrar(context, notas);
      }
    }

    if (!mounted) return;
    final nova = await UpdateService.verificar();
    if (!mounted || nova == null) return;
    await DialogoAtualizacao.mostrar(context, nova);
  }

  /// Abas visíveis para o perfil. Cadastros só existe para o administrador —
  /// não basta desabilitar os botões: a aba inteira sai do caminho.
  List<Widget> get _tabs => [
    MovimentacoesTab(userRole: widget.userRole),
    if (_isAdmin) CadastrosTab(userRole: widget.userRole),
    if (!_isMotorista) DashboardTab(userRole: widget.userRole),
  ];

  /// Itens da barra inferior, na mesma ordem de [_tabs].
  List<BottomNavigationBarItem> get _itensNavegacao => [
    const BottomNavigationBarItem(
      icon: Icon(Icons.local_shipping_outlined),
      activeIcon: Icon(Icons.local_shipping),
      label: 'Movimentações',
    ),
    if (_isAdmin)
      const BottomNavigationBarItem(
        icon: Icon(Icons.app_registration_outlined),
        activeIcon: Icon(Icons.app_registration),
        label: 'Cadastros',
      ),
    if (!_isMotorista)
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
  ];

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar Saída',
          style: TextStyle(color: AppColors.textDark),
        ),
        content: const Text(
          'Tem certeza que deseja sair do sistema?',
          style: TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ApiService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _abrirConfiguracoes() {
    showDialog(
      context: context,
      builder: (_) => const _ConfiguracaoHomeDialog(),
    );
  }

  void _abrirAtualizar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AtualizarPage()));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ColetaLeite ERP'),
            Text(
              'Perfil: ${widget.userRole}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          const _SyncIndicator(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded, size: 26),
            tooltip: 'Menu',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: Colors.white,
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'atualizar') _abrirAtualizar();
              if (value == 'configuracoes') _abrirConfiguracoes();
              if (value == 'versao') verificarAtualizacaoManualmente(context);
              if (value == 'sair') _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'atualizar',
                child: _MenuItemRow(
                  icon: Icons.sync_rounded,
                  label: 'Atualizar Dados',
                  color: AppColors.primary,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'configuracoes',
                child: _MenuItemRow(
                  icon: Icons.settings_outlined,
                  label: 'Configurações',
                  color: AppColors.textMedium,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'versao',
                child: _MenuItemRow(
                  icon: Icons.system_update,
                  label: 'Verificar atualizações',
                  color: AppColors.textMedium,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'sair',
                child: _MenuItemRow(
                  icon: Icons.logout_rounded,
                  label: 'Sair',
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex.clamp(0, tabs.length - 1),
                children: tabs,
              ),
            ),
            if (tabs.length < 2) const _RodapeVersao(),
          ],
        ),
      ),
      // Com uma aba só não há o que navegar — a barra vira ruído.
      bottomNavigationBar: tabs.length < 2
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BottomNavigationBar(
                  currentIndex: _currentIndex.clamp(0, tabs.length - 1),
                  onTap: (i) => setState(() => _currentIndex = i),
                  items: _itensNavegacao,
                ),
                const _RodapeVersao(),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
class _RodapeVersao extends StatelessWidget {
  const _RodapeVersao();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Versão $appVersao',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '─── Desenvolvido por Go Up Sistemas ───',
            style: TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItemRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class _ConfiguracaoHomeDialog extends StatefulWidget {
  const _ConfiguracaoHomeDialog();

  @override
  State<_ConfiguracaoHomeDialog> createState() =>
      _ConfiguracaoHomeDialogState();
}

class _ConfiguracaoHomeDialogState extends State<_ConfiguracaoHomeDialog> {
  final _ipCtrl = TextEditingController();
  final _portaCtrl = TextEditingController();
  bool _testando = false;
  bool _salvando = false;
  String? _statusTeste;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _ipCtrl.text = await ServerConfig.getIp();
    _portaCtrl.text = await ServerConfig.getPorta();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portaCtrl.dispose();
    super.dispose();
  }

  /// Endereço com domínio ou porta embutida dispensa o campo de porta.
  bool get _semPorta => ServerConfig.portaDispensavel(_ipCtrl.text);

  /// URL que será realmente chamada, mostrada abaixo dos campos.
  String get _urlPrevia =>
      ServerConfig.montarUrl(_ipCtrl.text, _portaCtrl.text);

  Future<void> _testar() async {
    final ip = _ipCtrl.text.trim();
    final porta = _portaCtrl.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _testando = true;
      _statusTeste = null;
    });
    final erro = await ServerConfig.testarConexao(ip, porta);
    if (mounted) {
      setState(() {
        _testando = false;
        _statusTeste = erro ?? '';
      });
    }
  }

  Future<void> _salvar() async {
    final ip = _ipCtrl.text.trim();
    final porta = _portaCtrl.text.trim();
    if (ip.isEmpty) return;
    setState(() => _salvando = true);
    await ServerConfig.salvar(ip, porta);
    if (mounted) {
      setState(() => _salvando = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração salva!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sucesso = _statusTeste == '';
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.dns_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Configuração do Servidor',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Informe o IP da retaguarda na rede local, ou o endereço do '
              'túnel para acessar de fora.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ipCtrl,
              // Teclado de URL: precisa de letras, ponto e barra para o domínio.
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                hintText: '192.168.1.100  ou  coleta.goupsistemas.uk',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              onChanged: (_) => setState(() => _statusTeste = null),
            ),
            // Domínio implica túnel, que atende na porta padrão do HTTPS —
            // manter o campo só confundiria.
            if (!_semPorta) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _portaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porta',
                  hintText: '8080',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                onChanged: (_) => setState(() => _statusTeste = null),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _urlPrevia.isEmpty
                        ? 'Informe o endereço acima'
                        : _urlPrevia,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _testando ? null : _testar,
              icon: _testando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(_testando ? 'Testando...' : 'Testar Conexão'),
            ),
            if (_statusTeste != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: sucesso
                      ? AppColors.success.withValues(alpha: 0.08)
                      : AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sucesso
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sucesso ? Icons.check_circle : Icons.error_outline,
                      color: sucesso ? AppColors.success : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sucesso
                            ? 'Servidor conectado com sucesso!'
                            : _statusTeste!,
                        style: TextStyle(
                          color: sucesso ? AppColors.success : AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Versão $appVersao',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '─── Desenvolvido por Go Up Sistemas ───',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.textLight),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Indicador de sincronização no AppBar: mostra spinner ao sincronizar,
/// um badge com a contagem de coletas pendentes de envio, ou o ícone de
/// "sincronizado". Tocar força o envio das pendências.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<ColetaProvider>(
      builder: (context, p, _) {
        if (p.syncStatus == SyncStatus.syncing) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        final pend = p.pendingCount;
        final fotos = p.pendingFotos;
        final temPendencia = pend > 0 || fotos > 0;
        final semRede = p.syncStatus == SyncStatus.error;
        final IconData icon = temPendencia
            ? Icons.cloud_upload_rounded
            : (semRede ? Icons.cloud_off_rounded : Icons.cloud_done_rounded);
        final badge = pend > 0 ? pend : fotos;

        String tooltip;
        if (temPendencia) {
          final partes = <String>[
            if (pend > 0) '$pend pendente${pend > 1 ? 's' : ''}',
            if (fotos > 0) '$fotos foto${fotos > 1 ? 's' : ''}',
          ];
          tooltip = '${partes.join(' · ')} — tocar para sincronizar';
        } else {
          tooltip = semRede ? 'Sem conexão' : 'Sincronizado';
        }

        return IconButton(
          tooltip: tooltip,
          onPressed: () => context.read<ColetaProvider>().flushPending(),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white),
              if (temPendencia)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
