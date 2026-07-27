import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/coleta_provider.dart';
import '../../services/api_service.dart';

/// Cadastro de veículo pelo celular.
///
/// Só o essencial — placa, descrição e modelo — o bastante para saber qual
/// carro sai para a coleta. O resto do cadastro fica na retaguarda.
///
/// A consulta por placa vai à base da retaguarda: se o carro já existir, o
/// formulário passa a editá-lo em vez de criar um segundo registro.
class VeiculoForm extends StatefulWidget {
  const VeiculoForm({super.key});

  @override
  State<VeiculoForm> createState() => _VeiculoFormState();
}

class _VeiculoFormState extends State<VeiculoForm> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _modeloController = TextEditingController();

  VeiculoStatus _status = VeiculoStatus.ativo;

  /// Preenchido quando a consulta encontra a placa: dali em diante o formulário
  /// altera esse registro em vez de incluir um novo.
  int? _idExistente;

  bool _consultando = false;
  bool _salvando = false;
  String? _avisoPlaca;

  @override
  void dispose() {
    _placaController.dispose();
    _descricaoController.dispose();
    _modeloController.dispose();
    super.dispose();
  }

  Future<void> _consultarPlaca() async {
    final placa = _placaController.text.trim();
    if (placa.isEmpty) {
      setState(() => _avisoPlaca = 'Digite a placa para consultar.');
      return;
    }

    setState(() {
      _consultando = true;
      _avisoPlaca = null;
    });

    try {
      final dados = await ApiService.consultarVeiculoPorPlaca(placa);
      if (!mounted) return;

      if (dados == null) {
        setState(() {
          _idExistente = null;
          _avisoPlaca = 'Placa não cadastrada — preencha para incluir.';
        });
        return;
      }

      setState(() {
        _idExistente = dados['id'] as int?;
        _placaController.text = '${dados['placa'] ?? placa}';
        _descricaoController.text = '${dados['descricao'] ?? ''}';
        _modeloController.text = '${dados['modelo'] ?? ''}';
        _status = '${dados['status']}' == 'INATIVO'
            ? VeiculoStatus.inativo
            : VeiculoStatus.ativo;
        _avisoPlaca = 'Veículo encontrado. Os dados vieram da base.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _avisoPlaca = 'Não foi possível consultar agora: sem conexão '
            'com a retaguarda.',
      );
      debugPrint('[VeiculoForm] consulta de placa falhou: $e');
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final provider = Provider.of<ColetaProvider>(context, listen: false);
    try {
      await provider.salvarVeiculo(
        Veiculo(
          id: _idExistente ?? 0,
          placa: _placaController.text.trim().toUpperCase(),
          descricao: _descricaoController.text.trim(),
          modelo: _modeloController.text.trim(),
          status: _status,
        ),
        idExistente: _idExistente,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _idExistente == null ? 'Veículo cadastrado.' : 'Veículo atualizado.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      // O cadastro precisa chegar ao ERP; dar como salvo aqui esconderia que
      // ele não existe para as rotas.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar: ${e.toString().replaceFirst("Exception: ", "")}'
            '\nConfira a conexão com a retaguarda e tente de novo.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editando = _idExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar veículo' : 'Novo veículo'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, const Color(0xFF1E3A8A)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _placaController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        _MaiusculasFormatter(),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Placa',
                        prefixIcon: const Icon(Icons.credit_card),
                        hintText: 'ABC1D23',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Informe a placa completa'
                          : null,
                      onFieldSubmitted: (_) => _consultarPlaca(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _consultando ? null : _consultarPlaca,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _consultando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
              if (_avisoPlaca != null) ...[
                const SizedBox(height: 8),
                Text(
                  _avisoPlaca!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: editando
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
              ],

              const SizedBox(height: 18),
              TextFormField(
                controller: _descricaoController,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Como o carro é chamado: "Caminhão 1"',
                  prefixIcon: const Icon(Icons.local_shipping_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _modeloController,
                decoration: InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<VeiculoStatus>(
                decoration: InputDecoration(
                  labelText: 'Situação',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                initialValue: _status,
                items: const [
                  DropdownMenuItem(
                    value: VeiculoStatus.ativo,
                    child: Text('Ativo'),
                  ),
                  DropdownMenuItem(
                    value: VeiculoStatus.inativo,
                    child: Text('Inativo'),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        editando ? 'Salvar alterações' : 'Salvar veículo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mantém a placa em maiúsculas enquanto se digita.
class _MaiusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
