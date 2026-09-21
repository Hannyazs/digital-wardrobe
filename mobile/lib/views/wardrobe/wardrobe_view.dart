import 'package:flutter/material.dart';

import '../upload/upload_view.dart';

/// Armário: listagem e organização por categoria (MVP #1, #2).
class WardrobeView extends StatelessWidget {
  const WardrobeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Guarda-Roupa')),
      body: const Center(child: Text('TODO: listagem de peças por categoria')),
      // Navegação mínima para tornar a UploadView (E1.F1.1) alcançável e
      // testável — não fazia parte do escopo original da PBI, ver log de
      // implementação em docs/PBIs/E1-F1-adicionar-foto/.
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar peça',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const UploadView()),
          );
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
