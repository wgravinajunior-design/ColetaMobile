import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../services/server_config.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/auth_context.dart';
import '../widgets/update_dialogs.dart';
import 'home_page.dart';

// ---------------------------------------------------------------------------
// Tela de Login
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  /// Uma vez por execução, mesmo que a tela seja reconstruída ou o usuário
  /// saia e volte ao login.
  static bool _jaVerificouVersao = false;

  @override
  void initState() {
    super.initState();
    if (_jaVerificouVersao) return;
    _jaVerificouVersao = true;
    // Na abertura do app, e não depois do login: quem está desatualizado
    // precisa saber antes de começar a usar. Roda solto para não segurar a
    // tela, e falha de rede é ignorada pelo próprio serviço.
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarVersao());
  }

  Future<void> _verificarVersao() async {
    final anterior = await UpdateService.versaoVista();
    if (anterior == null) {
      await UpdateService.marcarVersaoVista(appVersao);
    } else if (anterior != appVersao) {
      // Acabou de atualizar: mostra o que mudou antes de qualquer outra coisa.
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _abrirConfiguracoes() {
    showDialog(
      context: context,
      builder: (context) => const _ConfiguracaoDialog(),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      // Antes de navegar: é o que decide se este aparelho vai baixar as rotas
      // de um motorista só ou as de todos.
      AuthContext.inicializar(user);
      final perfil = AuthContext.usuarioPerfil;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage(userRole: perfil)),
      );
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A1A8C).withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sistema de Rotas',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A1A8C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gestão e rastreabilidade de coletas',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
                const SizedBox(height: 6),
                // Versão instalada à vista: é o primeiro dado que se confere
                // quando se desconfia de que a atualização não chegou.
                Text(
                  'Versão $appVersao',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),

                // Card do formulário
                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mensagem de erro
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Campo Usuário
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Usuário',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe o usuário'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Campo Senha
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Informe a senha'
                                : null,
                          ),
                          const SizedBox(height: 28),

                          // Botão Entrar
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _handleLogin(),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Entrar no Sistema'),
                          ),
                          const SizedBox(height: 12),

                          // Botão Configuração
                          OutlinedButton.icon(
                            onPressed: _abrirConfiguracoes,
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            label: const Text('Configuração do Servidor'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog de Configuração do Servidor
// ---------------------------------------------------------------------------
class _ConfiguracaoDialog extends StatefulWidget {
  const _ConfiguracaoDialog();

  @override
  State<_ConfiguracaoDialog> createState() => _ConfiguracaoDialogState();
}

class _ConfiguracaoDialogState extends State<_ConfiguracaoDialog> {
  final _ipController = TextEditingController();
  final _portaController = TextEditingController();
  bool _testando = false;
  bool _salvando = false;
  String? _statusTeste;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  Future<void> _carregarConfig() async {
    _ipController.text = await ServerConfig.getIp();
    _portaController.text = await ServerConfig.getPorta();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portaController.dispose();
    super.dispose();
  }

  /// Endereço com domínio ou porta embutida dispensa o campo de porta.
  bool get _semPorta => ServerConfig.portaDispensavel(_ipController.text);

  /// URL que será realmente chamada, mostrada abaixo dos campos.
  String get _urlPrevia =>
      ServerConfig.montarUrl(_ipController.text, _portaController.text);

  Future<void> _testar() async {
    final ip = _ipController.text.trim();
    final porta = _portaController.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _testando = true;
      _statusTeste = null;
    });
    final erro = await ServerConfig.testarConexao(ip, porta);
    if (mounted)
      setState(() {
        _testando = false;
        _statusTeste = erro ?? '';
      });
  }

  Future<void> _salvar() async {
    final ip = _ipController.text.trim();
    final porta = _portaController.text.trim();
    if (ip.isEmpty) return;
    setState(() => _salvando = true);
    await ServerConfig.salvar(ip, porta);
    if (mounted) {
      setState(() => _salvando = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração salva com sucesso!'),
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
              'Informe o IP e a porta do servidor da retaguarda na rede local.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _ipController,
              // Teclado de URL: precisa de letras e ponto para o domínio.
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
                controller: _portaController,
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
                const Icon(Icons.link, size: 14, color: AppColors.textLight),
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
