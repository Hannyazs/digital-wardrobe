import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// Um grupo de opções do painel (ex.: "Cor"), com seleção múltipla.
class SecaoDeFiltro {
  const SecaoDeFiltro({
    required this.titulo,
    required this.opcoes,
    required this.selecionada,
    required this.alternar,
  });

  final String titulo;
  final List<String> opcoes;
  final bool Function(String opcao) selecionada;
  final void Function(String opcao) alternar;
}

/// Abre o painel de filtros por baixo da tela (padrão de celular). Cada toque
/// aplica na hora — a lista atrás já muda — e o botão de baixo mostra quantos
/// resultados sobram. As funções recebem o `ref` do painel para ler o estado
/// atual do filtro (e reconstruir o painel quando ele muda).
Future<void> abrirPainelDeFiltros(
  BuildContext context, {
  required List<SecaoDeFiltro> Function(WidgetRef ref) secoes,
  required bool Function(WidgetRef ref) ativo,
  required void Function(WidgetRef ref) limpar,
  required String Function(WidgetRef ref) rotuloResultado,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PainelDeFiltros(
      secoes: secoes,
      ativo: ativo,
      limpar: limpar,
      rotuloResultado: rotuloResultado,
    ),
  );
}

class _PainelDeFiltros extends ConsumerWidget {
  const _PainelDeFiltros({
    required this.secoes,
    required this.ativo,
    required this.limpar,
    required this.rotuloResultado,
  });

  final List<SecaoDeFiltro> Function(WidgetRef ref) secoes;
  final bool Function(WidgetRef ref) ativo;
  final void Function(WidgetRef ref) limpar;
  final String Function(WidgetRef ref) rotuloResultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupos = secoes(ref).where((s) => s.opcoes.isNotEmpty).toList();
    final alturaMaxima = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: ativo(ref) ? () => limpar(ref) : null,
                    child: const Text('Limpar tudo'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  if (grupos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Ainda não há informações para filtrar.'),
                    ),
                  for (final secao in grupos) ...[
                    Text(secao.titulo, style: AppTextStyles.labelCategoria()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final opcao in secao.opcoes)
                          FilterChip(
                            label: Text(opcao),
                            selected: secao.selecionada(opcao),
                            onSelected: (_) => secao.alternar(opcao),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: AppButton(
                label: rotuloResultado(ref),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
