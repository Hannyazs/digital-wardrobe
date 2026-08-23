import 'package:flutter/material.dart';

/// Armário: listagem e organização por categoria (MVP #1, #2).
class WardrobeView extends StatelessWidget {
  const WardrobeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Guarda-Roupa')),
      body: const Center(child: Text('TODO: listagem de peças por categoria')),
    );
  }
}
