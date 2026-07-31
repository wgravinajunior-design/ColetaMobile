import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show AppColors;
import '../providers/coleta_provider.dart';
import 'coleta_form_page.dart';

class RotaDetalhePage extends StatelessWidget {
  final int rotaId;
  const RotaDetalhePage({super.key, required this.rotaId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ColetaProvider>(
      builder: (context, provider, _) {
        final rota = provider.rotaPorId(rotaId);
        if (rota == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rota não encontrada')),
            body: const Center(child: Text('Rota não encontrada.')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rota.nome, style: const TextStyle(fontSize: 15)),
              Text(_statusLabel(rota.status),
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              // Resumo da rota
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  _resumoPill(Icons.local_shipping_outlined, rota.veiculoDescricao, AppColors.primary),
                  const SizedBox(width: 8),
                  _resumoPill(Icons.route_outlined,
                      '${rota.totalFazendas} fazenda(s)', AppColors.secondary),
                ]),
              ),
              const Divider(height: 1),

              // Lista de fazendas. Vazia significa que as paradas ainda não
              // desceram do servidor — antes a tela ficava só branca aqui.
              if (rota.coletas.isEmpty)
                Expanded(
                  child: _SemParadas(onSincronizar: provider.sincronizarAgora),
                )
              else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: rota.coletas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final coleta = rota.coletas[i];
                    return _FazendaTile(
                      coleta: coleta,
                      rotaId: rotaId,
                      rotaStatus: rota.status,
                      onCollect:  () => _abrirFormColeta(context, rota, coleta),
                      onAdiar:    () => _mostrarDialogAdiar(context, provider, rota, coleta),
                      onImprimir: () => _imprimirColeta(context, rota, coleta),
                      onWhatsapp: () => _enviarWhatsapp(context, rota, coleta),
                      onAlterar: (rota.status != RotaStatus.finalizada && coleta.resolvido)
                          ? () => _alterarColeta(context, rota, coleta)
                          : null,
                      onFinalizar: rota.todasResolvidas && rota.status != RotaStatus.finalizada
                          ? () => _confirmarFinalizar(context, provider, rota)
                          : null,
                    );
                  },
                ),
              ),

              // Botão finalizar (quando todas resolvidas)
              if (rota.todasResolvidas && rota.status != RotaStatus.finalizada)
                _BotaoFinalizar(onTap: () => _confirmarFinalizar(context, provider, rota)),

              if (rota.status == RotaStatus.finalizada)
                _RodapeFinalizada(rota: rota),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Navegação
  // ---------------------------------------------------------------------------

  void _abrirFormColeta(BuildContext context, Rota rota, ColetaDetalhe coleta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ColetaFormPage(rotaId: rota.id, coleta: coleta),
      ),
    ).then((_) {
      if (!context.mounted) return;
      final provider = Provider.of<ColetaProvider>(context, listen: false);
      final rotaAtual = provider.rotaPorId(rota.id);
      if (rotaAtual != null && rotaAtual.todasResolvidas && rotaAtual.status != RotaStatus.finalizada) {
        _confirmarFinalizar(context, provider, rotaAtual);
      }
    });
  }

  void _alterarColeta(BuildContext context, Rota rota, ColetaDetalhe coleta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ColetaFormPage(rotaId: rota.id, coleta: coleta, isEdicao: true),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Impressão
  // ---------------------------------------------------------------------------

  void _imprimirColeta(BuildContext context, Rota rota, ColetaDetalhe coleta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bsCtx) => _PreviewImpressao(rota: rota, coleta: coleta),
    );
  }

  // ---------------------------------------------------------------------------
  // WhatsApp
  // ---------------------------------------------------------------------------

  void _enviarWhatsapp(BuildContext context, Rota rota, ColetaDetalhe coleta) async {
    final texto = _formatarMensagemWhatsapp(rota, coleta);
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(texto)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp não encontrado no dispositivo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dialogs existentes
  // ---------------------------------------------------------------------------

  void _mostrarDialogAdiar(BuildContext context, ColetaProvider provider, Rota rota, ColetaDetalhe coleta) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Adiar Coleta', style: TextStyle(color: AppColors.textDark, fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(coleta.produtor.nome,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo do adiamento *',
                hintText: 'Ex: Produtor ausente, portão fechado...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.edit_note_rounded),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.warning, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final motivo = controller.text.trim();
              if (motivo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe o motivo do adiamento.'), backgroundColor: AppColors.warning),
                );
                return;
              }
              provider.adiarColeta(rotaId: rota.id, coletaId: coleta.id, motivo: motivo);
              Navigator.of(ctx).pop();

              final rotaAtual = provider.rotaPorId(rota.id);
              if (rotaAtual != null && rotaAtual.todasResolvidas && rotaAtual.status != RotaStatus.finalizada) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) _confirmarFinalizar(context, provider, rotaAtual);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: const Text('Confirmar Adiamento'),
          ),
        ],
      ),
    );
  }

  void _confirmarFinalizar(BuildContext context, ColetaProvider provider, Rota rota) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flag_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Finalizar Rota', style: TextStyle(color: AppColors.textDark, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Todas as fazendas foram processadas.\nDeseja finalizar a rota "${rota.nome}"?',
                style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                _resumoItem(Icons.check_circle_rounded, '${rota.coletadas} coletadas', AppColors.success),
                if (rota.recusadas > 0) _resumoItem(Icons.cancel_rounded, '${rota.recusadas} recusadas', AppColors.error),
                if (rota.adiadas > 0)  _resumoItem(Icons.schedule_rounded, '${rota.adiadas} adiadas', AppColors.warning),
                _resumoItem(Icons.opacity, '${rota.totalLitros.toStringAsFixed(0)} L coletados', AppColors.primary),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ainda não', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              provider.finalizarRota(rota.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rota "${rota.nome}" finalizada com sucesso!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Finalizar Rota'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _statusLabel(RotaStatus s) {
    switch (s) {
      case RotaStatus.pendente:    return 'Pendente';
      case RotaStatus.liberada:    return 'Liberada';
      case RotaStatus.emAndamento: return 'Em andamento';
      case RotaStatus.finalizada:  return 'Finalizada';
    }
  }

  Widget _resumoPill(IconData icon, String text, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );

  Widget _resumoItem(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Helpers estáticos de formatação e PDF
// ---------------------------------------------------------------------------

String _fmtDataHora(DateTime? d) {
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

String _fmtData(DateTime? d) {
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

String _statusTexto(ColetaStatus s) {
  switch (s) {
    case ColetaStatus.confirmado: return 'COLETADO';
    case ColetaStatus.recusado:   return 'RECUSADO';
    case ColetaStatus.adiado:     return 'ADIADO';
    case ColetaStatus.pendente:   return 'PENDENTE';
  }
}

String _formatarMensagemWhatsapp(Rota rota, ColetaDetalhe coleta) {
  final buf = StringBuffer();
  buf.writeln('*REGISTRO DE COLETA DE LEITE*');
  buf.writeln('─────────────────────────────');
  buf.writeln('*Rota:* ${rota.nome}');
  buf.writeln('*Data:* ${_fmtData(rota.data)}');
  buf.writeln('');
  buf.writeln('*FAZENDA / PRODUTOR*');
  buf.writeln('*Nome:* ${coleta.produtor.nome}');
  buf.writeln('*Endereço:* ${coleta.produtor.endereco}');
  buf.writeln('*Ordem de visita:* ${coleta.ordemVisita}');
  buf.writeln('');
  buf.writeln('*DADOS DA COLETA*');
  buf.writeln('*Status:* ${_statusTexto(coleta.status)}');
  if (coleta.status == ColetaStatus.confirmado) {
    buf.writeln('*Volume coletado:* ${coleta.volumeColetadoLitros.toStringAsFixed(0)} L');
    buf.writeln('*Temperatura:* ${coleta.temperaturaLeiteC.toStringAsFixed(1)}°C');
    buf.writeln('*Horário registro:* ${_fmtDataHora(coleta.dataHoraRegistro)}');
    if (coleta.observacao.isNotEmpty) buf.writeln('*Observações:* ${coleta.observacao}');
  } else if (coleta.status == ColetaStatus.recusado) {
    buf.writeln('*Motivo da recusa:* ${coleta.observacao}');
    buf.writeln('*Horário registro:* ${_fmtDataHora(coleta.dataHoraRegistro)}');
  } else if (coleta.status == ColetaStatus.adiado) {
    buf.writeln('*Motivo do adiamento:* ${coleta.motivoAdiamento}');
  }
  buf.writeln('─────────────────────────────');
  buf.writeln('_Sistema Coleta Digital_');
  return buf.toString();
}

Future<pw.Document> _gerarPdfColeta(Rota rota, ColetaDetalhe coleta) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('REGISTRO DE COLETA DE LEITE',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Sistema Coleta Digital',
                    style: pw.TextStyle(color: PdfColors.grey200, fontSize: 11)),
              ]),
            ),
            pw.SizedBox(height: 20),

            // Rota
            _pdfSecao('INFORMAÇÕES DA ROTA', [
              _pdfLinha('Rota', rota.nome),
              _pdfLinha('Data', _fmtData(rota.data)),
              _pdfLinha('Veículo', rota.veiculoDescricao),
              _pdfLinha('Motorista', rota.motoristaNome),
            ]),
            pw.SizedBox(height: 14),

            // Produtor
            _pdfSecao('PRODUTOR / FAZENDA', [
              _pdfLinha('Nome', coleta.produtor.nome),
              _pdfLinha('Endereço', coleta.produtor.endereco),
              _pdfLinha('Ordem de visita', '${coleta.ordemVisita}'),
              _pdfLinha('Horário previsto', coleta.produtor.horarioColetaPrevisto),
              _pdfLinha('Volume previsto', '${coleta.produtor.volumeMedioDiario.toStringAsFixed(0)} L'),
            ]),
            pw.SizedBox(height: 14),

            // Coleta
            _pdfSecao('DADOS DA COLETA', [
              _pdfLinha('Status', _statusTexto(coleta.status)),
              if (coleta.status == ColetaStatus.confirmado) ...[
                _pdfLinha('Volume coletado', '${coleta.volumeColetadoLitros.toStringAsFixed(0)} L'),
                _pdfLinha('Temperatura', '${coleta.temperaturaLeiteC.toStringAsFixed(1)} °C'),
                _pdfLinha('Horário de registro', _fmtDataHora(coleta.dataHoraRegistro)),
                if (coleta.observacao.isNotEmpty) _pdfLinha('Observações', coleta.observacao),
              ] else if (coleta.status == ColetaStatus.recusado) ...[
                _pdfLinha('Motivo da recusa', coleta.observacao),
                _pdfLinha('Horário de registro', _fmtDataHora(coleta.dataHoraRegistro)),
              ] else if (coleta.status == ColetaStatus.adiado) ...[
                _pdfLinha('Motivo do adiamento', coleta.motivoAdiamento),
              ],
            ]),

            pw.Spacer(),

            // Rodapé
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Text(
                'Gerado em ${_fmtDataHora(DateTime.now())} · Sistema Coleta Digital',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _pdfSecao(String titulo, List<pw.Widget> linhas) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(titulo,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      ),
      pw.SizedBox(height: 8),
      ...linhas,
    ],
  );
}

pw.Widget _pdfLinha(String label, String valor) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5, left: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text('$label:',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(
          child: pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Bottom Sheet: Preview de Impressão
// ---------------------------------------------------------------------------
class _PreviewImpressao extends StatelessWidget {
  final Rota rota;
  final ColetaDetalhe coleta;

  const _PreviewImpressao({required this.rota, required this.coleta});

  @override
  Widget build(BuildContext context) {
    final c = coleta;
    final Color statusColor = c.status == ColetaStatus.confirmado
        ? AppColors.success
        : c.status == ColetaStatus.recusado
            ? AppColors.error
            : c.status == ColetaStatus.adiado
                ? AppColors.warning
                : AppColors.textMedium;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // Título
          Row(children: [
            const Icon(Icons.print_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Impressão da Coleta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark))),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textLight),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
          const Divider(height: 20),

          // Preview do conteúdo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('REGISTRO DE COLETA DE LEITE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 12),

              _previewSecao('ROTA', [
                _previewLinha('Rota', rota.nome),
                _previewLinha('Data', _fmtData(rota.data)),
                _previewLinha('Veículo', rota.veiculoDescricao),
              ]),
              const SizedBox(height: 10),

              _previewSecao('FAZENDA', [
                _previewLinha('Nome', c.produtor.nome),
                _previewLinha('Endereço', c.produtor.endereco),
                _previewLinha('Ordem', '${c.ordemVisita}'),
              ]),
              const SizedBox(height: 10),

              _previewSecao('COLETA', [
                Row(children: [
                  const Text('Status: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(_statusTexto(c.status),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                  ),
                ]),
                if (c.status == ColetaStatus.confirmado) ...[
                  _previewLinha('Volume', '${c.volumeColetadoLitros.toStringAsFixed(0)} L'),
                  _previewLinha('Temperatura', '${c.temperaturaLeiteC.toStringAsFixed(1)}°C'),
                  _previewLinha('Horário', _fmtDataHora(c.dataHoraRegistro)),
                  if (c.observacao.isNotEmpty) _previewLinha('Obs.', c.observacao),
                ] else if (c.status == ColetaStatus.recusado) ...[
                  _previewLinha('Motivo', c.observacao),
                ] else if (c.status == ColetaStatus.adiado) ...[
                  _previewLinha('Adiamento', c.motivoAdiamento),
                ],
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Botões de ação
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _enviarWhatsappDaqui(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _imprimir(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Imprimir / Salvar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Future<void> _imprimir(BuildContext context) async {
    Navigator.of(context).pop();
    final doc = await _gerarPdfColeta(rota, coleta);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _enviarWhatsappDaqui(BuildContext context) async {
    Navigator.of(context).pop();
    final texto = _formatarMensagemWhatsapp(rota, coleta);
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(texto)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp não encontrado no dispositivo.')),
        );
      }
    }
  }

  Widget _previewSecao(String titulo, List<Widget> linhas) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(titulo,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ),
      const SizedBox(height: 6),
      ...linhas,
    ]);
  }

  Widget _previewLinha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, left: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text('$label:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium)),
        ),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 11, color: AppColors.textDark))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de cada fazenda
// ---------------------------------------------------------------------------
class _FazendaTile extends StatelessWidget {
  final ColetaDetalhe coleta;
  final int rotaId;
  final RotaStatus rotaStatus;
  final VoidCallback onCollect;
  final VoidCallback onAdiar;
  final VoidCallback onImprimir;
  final VoidCallback onWhatsapp;
  final VoidCallback? onAlterar;
  final VoidCallback? onFinalizar;

  const _FazendaTile({
    required this.coleta,
    required this.rotaId,
    required this.rotaStatus,
    required this.onCollect,
    required this.onAdiar,
    required this.onImprimir,
    required this.onWhatsapp,
    this.onAlterar,
    this.onFinalizar,
  });

  Color get _accentColor {
    switch (coleta.status) {
      case ColetaStatus.pendente:   return AppColors.primary;
      case ColetaStatus.confirmado: return AppColors.success;
      case ColetaStatus.recusado:   return AppColors.error;
      case ColetaStatus.adiado:     return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPendente   = coleta.status == ColetaStatus.pendente;
    final isConfirmado = coleta.status == ColetaStatus.confirmado;
    final isRecusado   = coleta.status == ColetaStatus.recusado;
    final isAdiado     = coleta.status == ColetaStatus.adiado;
    final podeAlterar  = onAlterar != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da fazenda
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(children: [
              // Número de ordem
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${coleta.ordemVisita}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _accentColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(coleta.produtor.nome,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text(coleta.produtor.endereco,
                      style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              // Status badge
              _statusBadge(),
              // Menu de opções
              PopupMenuButton<String>(
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textLight, size: 22),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'imprimir',
                    child: Row(children: const [
                      Icon(Icons.print_rounded, size: 18, color: AppColors.textDark),
                      SizedBox(width: 10),
                      Text('Imprimir coleta'),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'whatsapp',
                    child: Row(children: const [
                      Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                      SizedBox(width: 10),
                      Text('Enviar pelo WhatsApp'),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'alterar',
                    enabled: podeAlterar,
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18,
                          color: podeAlterar ? AppColors.primary : AppColors.textLight),
                      const SizedBox(width: 10),
                      Text(
                        rotaStatus == RotaStatus.finalizada
                            ? 'Alterar coleta (rota finalizada)'
                            : !coleta.resolvido
                                ? 'Alterar coleta (pendente)'
                                : 'Alterar coleta',
                        style: TextStyle(
                          color: podeAlterar ? AppColors.textDark : AppColors.textLight,
                        ),
                      ),
                    ]),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'imprimir') onImprimir();
                  if (value == 'whatsapp') onWhatsapp();
                  if (value == 'alterar' && podeAlterar) onAlterar!();
                },
              ),
            ]),
          ),

          // Info previsto
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              _infoChip(Icons.access_time_rounded, coleta.produtor.horarioColetaPrevisto, AppColors.textLight),
              const SizedBox(width: 8),
              _infoChip(Icons.opacity, '${coleta.produtor.volumeMedioDiario.toStringAsFixed(0)} L previstos', AppColors.textLight),
            ]),
          ),

          // Resultado (se já registrado)
          if (isConfirmado) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text('${coleta.volumeColetadoLitros.toStringAsFixed(0)} L coletados · ${coleta.temperaturaLeiteC.toStringAsFixed(1)}°C',
                      style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ] else if (isRecusado) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Leite recusado · ${coleta.observacao}',
                      style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ] else if (isAdiado) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Adiado · ${coleta.motivoAdiamento}',
                      style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, indent: 14, endIndent: 14),

          // Botões de ação (só se pendente)
          if (isPendente)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAdiar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: const Text('Adiar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onCollect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.opacity, size: 16),
                    label: const Text('Coletar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                isConfirmado ? 'Coleta registrada com sucesso'
                    : isRecusado ? 'Leite recusado e registrado'
                    : 'Coleta adiada',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _accentColor, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    String label;
    IconData icon;
    switch (coleta.status) {
      case ColetaStatus.pendente:
        label = 'Pendente'; icon = Icons.hourglass_empty_rounded;
        break;
      case ColetaStatus.confirmado:
        label = 'Coletado'; icon = Icons.check_circle_rounded;
        break;
      case ColetaStatus.recusado:
        label = 'Recusado'; icon = Icons.cancel_rounded;
        break;
      case ColetaStatus.adiado:
        label = 'Adiado';   icon = Icons.schedule_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _accentColor),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: _accentColor, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 11, color: color)),
  ]);
}

// ---------------------------------------------------------------------------
// Rota sem paradas baixadas
// ---------------------------------------------------------------------------
class _SemParadas extends StatelessWidget {
  final Future<void> Function() onSincronizar;
  const _SemParadas({required this.onSincronizar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined, size: 44, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text(
              'As fazendas desta rota ainda não chegaram ao aparelho.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textMedium, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Conecte-se à retaguarda e sincronize para baixar as paradas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSincronizar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sincronizar agora'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botão flutuante de finalizar rota
// ---------------------------------------------------------------------------
class _BotaoFinalizar extends StatelessWidget {
  final VoidCallback onTap;
  const _BotaoFinalizar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.flag_rounded, size: 20),
        label: const Text('FINALIZAR ROTA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rodapé para rota finalizada
// ---------------------------------------------------------------------------
class _RodapeFinalizada extends StatelessWidget {
  final Rota rota;
  const _RodapeFinalizada({required this.rota});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.success.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rota finalizada!',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${rota.totalLitros.toStringAsFixed(0)} L coletados · ${rota.coletadas} fazendas',
                style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
