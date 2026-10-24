import 'package:flutter/material.dart';

import '../references_controller.dart' show nomeDaColecaoMax;

/// Diálogo do nome de uma coleção (criar ou renomear). Devolve o nome sem
/// espaços nas pontas, ou `null` se o usuário cancelou. Nome vazio não fecha.
Future<String?> pedirNomeDaColecao(
  BuildContext context, {
  required String titulo,
  String? nomeAtual,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoNomeDaColecao(titulo: titulo, nomeAtual: nomeAtual),
  );
}

class _DialogoNomeDaColecao extends StatefulWidget {
  const _DialogoNomeDaColecao({required this.titulo, this.nomeAtual});

  final String titulo;
  final String? nomeAtual;

  @override
  State<_DialogoNomeDaColecao> createState() => _DialogoNomeDaColecaoState();
}

class _DialogoNomeDaColecaoState extends State<_DialogoNomeDaColecao> {
  late final _controller = TextEditingController(text: widget.nomeAtual);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nome = _controller.text.trim();
    if (nome.isNotEmpty) Navigator.of(context).pop(nome);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controller,
        maxLength: nomeDaColecaoMax,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirmar(),
        decoration: const InputDecoration(
          labelText: 'Nome da coleção',
          hintText: 'Ex.: Festa, Trabalho',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Confirmação de exclusão de coleção: as referências dela não são apagadas.
Future<bool> confirmarExclusaoDaColecao(
    BuildContext context, String nome) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('Excluir a coleção "$nome"?'),
      content: const Text(
          'As referências dela não serão apagadas: ficam sem coleção.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogo).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmou == true;
}
