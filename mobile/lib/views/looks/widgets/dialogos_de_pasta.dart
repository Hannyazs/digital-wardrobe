import 'package:flutter/material.dart';

import '../pastas_controller.dart' show nomeDaPastaMax;

/// Diálogo do nome de uma pasta de looks (criar ou renomear), no desenho de
/// `dialogos_de_colecao.dart`. Devolve o nome sem espaços nas pontas, ou
/// `null` se cancelado. Nome vazio não fecha.
Future<String?> pedirNomeDaPasta(BuildContext context, {required String titulo, String? nomeAtual}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoNomeDaPasta(titulo: titulo, nomeAtual: nomeAtual),
  );
}

class _DialogoNomeDaPasta extends StatefulWidget {
  const _DialogoNomeDaPasta({required this.titulo, this.nomeAtual});

  final String titulo;
  final String? nomeAtual;

  @override
  State<_DialogoNomeDaPasta> createState() => _DialogoNomeDaPastaState();
}

class _DialogoNomeDaPastaState extends State<_DialogoNomeDaPasta> {
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
        maxLength: nomeDaPastaMax,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirmar(),
        decoration: const InputDecoration(
          labelText: 'Nome da pasta',
          hintText: 'Ex.: Trabalho de verão',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Confirmação de exclusão de pasta: os looks dela não são apagados.
Future<bool> confirmarExclusaoDaPasta(BuildContext context, String nome) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('Excluir a pasta "$nome"?'),
      content: const Text('Os looks dela não serão apagados: ficam sem pasta.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Excluir')),
      ],
    ),
  );
  return confirmou == true;
}
