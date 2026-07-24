import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart' show AppColors;
import '../providers/coleta_provider.dart';

class ColetaFormPage extends StatefulWidget {
  final int rotaId;
  final ColetaDetalhe coleta;
  final bool isEdicao;

  const ColetaFormPage({
    super.key,
    required this.rotaId,
    required this.coleta,
    this.isEdicao = false,
  });

  @override
  State<ColetaFormPage> createState() => _ColetaFormPageState();
}

class _ColetaFormPageState extends State<ColetaFormPage> {
  final _formKey    = GlobalKey<FormState>();
  final _volumeCtrl = TextEditingController();
  final _tempCtrl   = TextEditingController();
  final _obsCtrl    = TextEditingController();

  bool _recusar  = false;
  bool _salvando = false;
  final DateTime _chegada = DateTime.now();

  XFile?  _fotoNova;
  String? _fotoPathExistente;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isEdicao) {
      final c = widget.coleta;
      _recusar = c.status == ColetaStatus.recusado;
      if (!_recusar && c.volumeColetadoLitros > 0) {
        _volumeCtrl.text = c.volumeColetadoLitros.toStringAsFixed(0);
      }
      if (!_recusar && c.temperaturaLeiteC != 0) {
        _tempCtrl.text = c.temperaturaLeiteC.toStringAsFixed(1);
      }
      _obsCtrl.text = _recusar ? c.observacao : c.observacao;
      if (_recusar && c.observacao.isEmpty) {
        _obsCtrl.text = c.motivoAdiamento;
      }
      _fotoPathExistente = c.fotoCaminho;
    }
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _tempCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _tirarFoto() async {
    try {
      final foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (foto == null) return; // usuário cancelou

      // Valida o arquivo antes de aceitar (evita foto vazia/gigante).
      final tamanho = await File(foto.path).length();
      if (tamanho == 0) {
        _avisar('A foto veio vazia. Tente novamente.');
        return;
      }
      if (tamanho > 10 * 1024 * 1024) {
        _avisar('Foto muito grande (máx. 10 MB).');
        return;
      }

      setState(() {
        _fotoNova = foto;
        _fotoPathExistente = null;
      });
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      final negada = code.contains('access') ||
          code.contains('denied') ||
          code.contains('permission');
      _avisar(negada
          ? 'Permissão de câmera negada. Habilite nas configurações do app.'
          : 'Não foi possível abrir a câmera.');
    } catch (_) {
      _avisar('Erro inesperado ao capturar a foto.');
    }
  }

  void _avisar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _removerFoto() {
    setState(() {
      _fotoNova = null;
      _fotoPathExistente = null;
    });
  }

  String? get _fotoPathAtual => _fotoNova?.path ?? _fotoPathExistente;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final provider = Provider.of<ColetaProvider>(context, listen: false);
    provider.realizarColeta(
      rotaId:      widget.rotaId,
      coletaId:    widget.coleta.id,
      volume:      _recusar ? 0 : (double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0),
      temperatura: _recusar ? 0 : (double.tryParse(_tempCtrl.text.replaceAll(',', '.')) ?? 0),
      observacao:  _obsCtrl.text.trim(),
      fotoPath:    _fotoPathAtual,
      recusada:    _recusar,
    );

    // Se o usuário tirou uma foto nova, envia o arquivo ao servidor em background
    // (best-effort — o caminho local já ficou salvo na coleta).
    if (_fotoNova != null) {
      provider.uploadFotoColeta(widget.coleta.id, _fotoNova!.path);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdicao
              ? 'Coleta alterada com sucesso!'
              : _recusar
                  ? 'Leite recusado registrado para ${widget.coleta.produtor.nome}.'
                  : 'Coleta registrada com sucesso!'),
          backgroundColor: _recusar ? AppColors.error : AppColors.success,
        ),
      );
    }
  }

  String _horaFmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  InputDecoration _fieldDeco(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error, width: 1.8)),
        labelStyle: const TextStyle(color: AppColors.textMedium),
        hintStyle: const TextStyle(color: AppColors.textLight),
      );

  @override
  Widget build(BuildContext context) {
    final produtor = widget.coleta.produtor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdicao ? 'Alterar Coleta' : 'Registrar Coleta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da fazenda
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.isEdicao ? Icons.edit_rounded : Icons.edit_rounded,
                        color: AppColors.primary, size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      widget.isEdicao ? 'Alterar Coleta' : '3. Registrar Coleta',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    )),
                    Text('Chegada: ${_horaFmt(_chegada)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  ]),
                  const Divider(height: 18),
                  Text(produtor.nome,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(produtor.endereco,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _infoChip(Icons.access_time_rounded, produtor.horarioColetaPrevisto),
                    const SizedBox(width: 8),
                    _infoChip(Icons.opacity, '${produtor.volumeMedioDiario.toStringAsFixed(0)} L prev.'),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              // Card do formulário
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Toggle: Recusar Leite
                    Container(
                      decoration: BoxDecoration(
                        color: _recusar ? AppColors.error.withValues(alpha: 0.06) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _recusar ? AppColors.error.withValues(alpha: 0.4) : AppColors.cardBorder,
                        ),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        title: Text(
                          'Recusar Leite (Fora do Padrão)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _recusar ? AppColors.error : AppColors.textDark,
                          ),
                        ),
                        value: _recusar,
                        activeThumbColor: AppColors.error,
                        onChanged: (v) => setState(() { _recusar = v; }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Volume e Temperatura (só se não recusar)
                    if (!_recusar) ...[
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _volumeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            decoration: _fieldDeco('Volume (L)', hint: '0,00', icon: Icons.opacity),
                            validator: (v) {
                              if (_recusar) return null;
                              if (v == null || v.trim().isEmpty) return 'Informe o volume';
                              final d = double.tryParse(v.replaceAll(',', '.'));
                              if (d == null || d <= 0) return 'Volume inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tempCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
                            decoration: _fieldDeco('Temperatura (°C)', hint: '0,0', icon: Icons.thermostat_rounded),
                            validator: (v) {
                              if (_recusar) return null;
                              if (v == null || v.trim().isEmpty) return 'Informe a temp.';
                              final d = double.tryParse(v.replaceAll(',', '.'));
                              if (d == null) return 'Inválida';
                              return null;
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                    ],

                    // Observações
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 3,
                      decoration: _fieldDeco(
                        _recusar ? 'Motivo da recusa *' : 'Observações / Ocorrências',
                        hint: _recusar
                            ? 'Descreva o motivo da recusa...'
                            : 'Registre ocorrências, qualidade do leite...',
                        icon: Icons.notes_rounded,
                      ),
                      validator: (v) {
                        if (_recusar && (v == null || v.trim().isEmpty)) return 'Informe o motivo da recusa';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Foto
                    if (_fotoPathAtual != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_fotoPathAtual!),
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _removerFoto,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _tirarFoto,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Tirar Outra Foto', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: _tirarFoto,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Tirar Foto', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botão salvar
              ElevatedButton.icon(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recusar ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _salvando
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(
                        widget.isEdicao
                            ? Icons.check_rounded
                            : _recusar ? Icons.cancel_rounded : Icons.save_rounded,
                        size: 20,
                      ),
                label: Text(
                  _salvando
                      ? 'Salvando...'
                      : widget.isEdicao
                          ? 'SALVAR ALTERAÇÃO'
                          : _recusar ? 'REGISTRAR RECUSA' : 'REGISTRAR E SALVAR COLETA',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AppColors.textLight),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
  ]);
}
