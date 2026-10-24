import 'package:flutter/material.dart';

import '../../../models/colecao.dart';
import '../references_controller.dart' show notaDaReferenciaMax;

/// Resposta do diálogo de nova referência: a nota (vazia = sem nota) e a
/// coleção escolhida (`null` = sem coleção).
typedef DadosDaNovaReferencia = ({String nota, String? colecaoId});

/// Diálogo só da nota (opcional, até 500 caracteres). Devolve o texto sem
/// espaços nas pontas (vazio = sem nota) ou `null` se o usuário cancelou.
Future<String?> pedirNotaDaReferencia(
  BuildContext context, {
  required String titulo,
  String? notaAtual,
}) async {
  final dados = await showDialog<DadosDaNovaReferencia>(
    context: context,
    builder: (_) => _DialogoDeNota(titulo: titulo, notaAtual: notaAtual),
  );
  return dados?.nota;
}

/// Diálogo da referência que vai ser enviada: nota opcional e a coleção
/// (iniciando em [colecaoInicial]). Devolve `null` se o usuário cancelou.
Future<DadosDaNovaReferencia?> pedirDadosDaNovaReferencia(
  BuildContext context, {
  required List<Colecao> colecoes,
  String? colecaoInicial,
}) {
  return showDialog<DadosDaNovaReferencia>(
    context: context,
    builder: (_) => _DialogoDeNota(
      titulo: 'Nova referência',
      colecoes: colecoes,
      colecaoInicial: colecaoInicial,
    ),
  );
}

class _DialogoDeNota extends StatefulWidget {
  const _DialogoDeNota({
    required this.titulo,
    this.notaAtual,
    this.colecoes,
    this.colecaoInicial,
  });

  final String titulo;
  final String? notaAtual;

  /// Quando não nulo, o diálogo mostra o seletor de coleção.
  final List<Colecao>? colecoes;
  final String? colecaoInicial;

  @override
  State<_DialogoDeNota> createState() => _DialogoDeNotaState();
}

class _DialogoDeNotaState extends State<_DialogoDeNota> {
  late final _controller = TextEditingController(text: widget.notaAtual);
  late String? _colecaoId =
      widget.colecoes?.any((c) => c.id == widget.colecaoInicial) ?? false
          ? widget.colecaoInicial
          : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colecoes = widget.colecoes;
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLength: notaDaReferenciaMax,
              maxLines: 3,
              minLines: 1,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ex.: gostei da combinação de cores',
              ),
            ),
            if (colecoes != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _colecaoId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Coleção'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Sem coleção')),
                  for (final c in colecoes)
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.nome)),
                ],
                onChanged: (valor) => setState(() => _colecaoId = valor),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            nota: _controller.text.trim(),
            colecaoId: _colecaoId,
          )),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
