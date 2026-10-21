import 'package:flutter/material.dart';

/// Seção de preferência por chips de seleção múltipla (E4.F2.1; reaproveitada
/// pelos estilos na E4.F3.1).
///
/// Mostra [opcoes] e, ao fim, os valores de [selecionadas] que não estão nelas
/// (ex.: salvos por outro cliente), marcados, para não sumirem sem o usuário
/// perceber. Não calcula a nova lista: avisa qual opção foi tocada
/// ([onAlternar]) e quem chama decide a partir do estado **atual**, para dois
/// toques seguidos nunca partirem de uma lista já superada.
class SecaoDeChips extends StatelessWidget {
  const SecaoDeChips({
    super.key,
    required this.titulo,
    required this.apoio,
    required this.opcoes,
    required this.selecionadas,
    required this.onAlternar,
  });

  final String titulo;

  /// Linha de apoio sob o título (ex.: o que significa nenhuma marcação).
  final String apoio;
  final List<String> opcoes;
  final List<String> selecionadas;
  final ValueChanged<String> onAlternar;

  @override
  Widget build(BuildContext context) {
    final exibidas = [...opcoes, ...selecionadas.where((s) => !opcoes.contains(s))];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(apoio, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final opcao in exibidas)
                  FilterChip(
                    label: Text(opcao),
                    selected: selecionadas.contains(opcao),
                    onSelected: (_) => onAlternar(opcao),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
