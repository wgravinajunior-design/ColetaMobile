import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart' show AppColors;
import '../../providers/coleta_provider.dart';

class MotoristaForm extends StatefulWidget {
  final Motorista? motorista; // null = novo, não-null = editar
  const MotoristaForm({super.key, this.motorista});

  @override
  State<MotoristaForm> createState() => _MotoristaFormState();
}

class _MotoristaFormState extends State<MotoristaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _cnhController;
  late final TextEditingController _categoriaController;
  late int? _selectedVeiculoId;
  late MotoristaStatus _selectedStatus;
  bool _isSaving = false;

  bool get _isEditing => widget.motorista != null;

  @override
  void initState() {
    super.initState();
    final m = widget.motorista;
    _nomeController      = TextEditingController(text: m?.nome ?? '');
    _cnhController       = TextEditingController(text: m?.cnh ?? '');
    _categoriaController = TextEditingController(text: m?.categoriaCnh ?? '');
    _selectedVeiculoId   = m?.idVeiculo;
    _selectedStatus      = m?.status ?? MotoristaStatus.ativo;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cnhController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = Provider.of<ColetaProvider>(context, listen: false);

    final motorista = Motorista(
      id: widget.motorista?.id ?? 0,
      nome: _nomeController.text.trim(),
      cnh: _cnhController.text.trim(),
      categoriaCnh: _categoriaController.text.trim().toUpperCase(),
      idVeiculo: _selectedVeiculoId,
      status: _selectedStatus,
    );

    if (_isEditing) {
      await provider.updateMotorista(motorista);
    } else {
      await provider.addMotorista(motorista);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Motorista atualizado com sucesso!'
            : 'Motorista cadastrado com sucesso!'),
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

  @override
  Widget build(BuildContext context) {
    final veiculos = Provider.of<ColetaProvider>(context).veiculos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Motorista' : 'Novo Motorista'),
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
                          'Editando: ${widget.motorista!.nome}',
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
                    _sectionHeader('Dados do Motorista', Icons.badge_rounded),
                    TextFormField(
                      controller: _nomeController,
                      decoration: _fieldDecoration('Nome Completo', Icons.person_outline),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cnhController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration('Número CNH', Icons.badge_outlined),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _categoriaController,
                            decoration: _fieldDecoration('Categoria', Icons.star_outline,
                                hint: 'D, E…'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Card: Vínculo e Status ──────────────────────────────────
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
                    _sectionHeader('Vínculo e Status', Icons.link_rounded),
                    DropdownButtonFormField<int>(
                      decoration: _fieldDecoration('Veículo Vinculado', Icons.local_shipping_rounded),
                      value: _selectedVeiculoId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Nenhum veículo'),
                        ),
                        ...veiculos.map((v) => DropdownMenuItem<int>(
                              value: v.id,
                              child: Text('${v.descricao} (${v.placa})'),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedVeiculoId = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<MotoristaStatus>(
                      decoration: _fieldDecoration('Status', Icons.toggle_on_outlined),
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(
                          value: MotoristaStatus.ativo,
                          child: Text('Ativo'),
                        ),
                        DropdownMenuItem(
                          value: MotoristaStatus.inativo,
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
                            _isEditing ? 'Salvar Alterações' : 'Cadastrar Motorista',
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
