import 'package:flutter/material.dart';

/// Cadastro de peça por foto (MVP #1): captura -> processar-imagem -> revisão -> POST /pecas.
class UploadView extends StatelessWidget {
  const UploadView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Peça')),
      body: const Center(child: Text('TODO: captura de foto e revisão de metadados sugeridos')),
    );
  }
}
