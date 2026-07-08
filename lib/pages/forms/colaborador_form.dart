import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';

class ColaboradorForm extends StatefulWidget {
  final Colaborador? colaborador; // null = novo, não-null = editar
  const ColaboradorForm({super.key, this.colaborador});

  @override
  State<ColaboradorForm> createState() => _ColaboradorFormState();
}

class _ColaboradorFormState extends State<ColaboradorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _cpfController;
  late final TextEditingController _funcaoCargoController;
  late String _selectedPermissao;
  late ColaboradorStatus _selectedStatus;
  bool _isSaving = false;

  final List<String> _permissoes = ['Administrador', 'Operador', 'Visualizador'];

  bool get _isEditing => widget.colaborador != null;

  @override
  void initState() {
    super.initState();
    final c = widget.colaborador;
    _nomeController        = TextEditingController(text: c?.nome ?? '');
    _cpfController         = TextEditingController(text: c?.cpf ?? '');
    _funcaoCargoController = TextEditingController(text: c?.funcaoCargo ?? '');
    _selectedPermissao     = c?.permissoesAcesso ?? 'Operador';
    _selectedStatus        = c?.status ?? ColaboradorStatus.ativo;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _funcaoCargoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = Provider.of<ColetaProvider>(context, listen: false);

    final colaborador = Colaborador(
      id: widget.colaborador?.id ?? 0,
      nome: _nomeController.text.trim(),
      cpf: _cpfController.text.trim(),
      funcaoCargo: _funcaoCargoController.text.trim(),
      permissoesAcesso: _selectedPermissao,
      status: _selectedStatus,
    );

    if (_isEditing) {
      await provider.updateColaborador(colaborador);
    } else {
      await provider.addColaborador(colaborador);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Colaborador atualizado com sucesso!'
            : 'Colaborador cadastrado com sucesso!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.textMedium, fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color get _permissaoColor {
    switch (_selectedPermissao) {
      case 'Administrador':
        return AppColors.error;
      case 'Visualizador':
        return AppColors.textMedium;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Colaborador' : 'Novo Colaborador'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF1E3A8A)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner de modo edição ───────────────────────────────────
              if (_isEditing)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editando: ${widget.colaborador!.nome}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Card: Dados pessoais ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Dados do Colaborador', Icons.people_rounded),
                    TextFormField(
                      controller: _nomeController,
                      decoration: _fieldDecoration('Nome Completo', Icons.person_outline),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                        'CPF / Identificação',
                        Icons.badge_outlined,
                        hint: '000.000.000-00',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _funcaoCargoController,
                      decoration: _fieldDecoration(
                        'Função / Cargo',
                        Icons.work_outline,
                        hint: 'Ex: Gerente, Auxiliar',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Card: Permissões e Status ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Permissões e Status', Icons.admin_panel_settings_outlined),
                    DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Nível de Permissão', Icons.shield_outlined),
                      value: _selectedPermissao,
                      items: _permissoes.map((p) {
                        return DropdownMenuItem<String>(value: p, child: Text(p));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPermissao = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _permissaoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _permissaoColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 12, color: _permissaoColor),
                          const SizedBox(width: 4),
                          Text(
                            _selectedPermissao == 'Administrador'
                                ? 'Acesso total ao sistema'
                                : _selectedPermissao == 'Operador'
                                    ? 'Lançamentos e consultas'
                                    : 'Somente visualização',
                            style: TextStyle(
                              fontSize: 11,
                              color: _permissaoColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ColaboradorStatus>(
                      decoration: _fieldDecoration('Status', Icons.toggle_on_outlined),
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(
                          value: ColaboradorStatus.ativo,
                          child: Text('Ativo'),
                        ),
                        DropdownMenuItem(
                          value: ColaboradorStatus.inativo,
                          child: Text('Inativo'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Botão Salvar ────────────────────────────────────────────
              ElevatedButton(
                onPressed: _isSaving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing ? AppColors.warning : AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isEditing ? Icons.check_rounded : Icons.save_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Salvar Alterações' : 'Cadastrar Colaborador',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
