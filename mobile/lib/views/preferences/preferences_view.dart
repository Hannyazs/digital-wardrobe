import 'package:flutter/material.dart';

/// Configuração de preferências de estilo (MVP #6): cores favoritas,
/// sobreposições, estilos preferidos, peças a evitar, nível de criatividade.
class PreferencesView extends StatelessWidget {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de Estilo')),
      body: const Center(child: Text('TODO: formulário de preferências')),
    );
  }
}
