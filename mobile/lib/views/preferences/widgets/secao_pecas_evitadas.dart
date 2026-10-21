import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/peca.dart';
import '../preferences_controller.dart';

/// Seção "Peças que evito" (E4.F4.2): lista as peças marcadas no detalhe da
/// peça e permite deixar de evitá-las. Tem carregamento/erro próprios, porque
/// vem de outro endpoint que o resto da tela de preferências.
class SecaoPecasEvitadas extends ConsumerWidget {
  const SecaoPecasEvitadas({super.key});

  Future<void> _pararDeEvitar(BuildContext context, WidgetRef ref, Peca peca) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Voltar a sugerir esta peça?'),
        content: Text('"${peca.categoria}" poderá aparecer de novo nas sugestões.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Parar de evitar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await ref.read(preferenciaServiceProvider).pararDeEvitarPeca(peca.id);
      ref.invalidate(evitadasProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroEvitadas(error, 'atualizar a peça'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evitadasAsync = ref.watch(evitadasProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Peças que evito', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Elas não serão usadas nas sugestões automáticas de looks (em breve).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            evitadasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Row(
                children: [
                  const Expanded(child: Text('Não foi possível carregar as peças evitadas.')),
                  TextButton(
                    onPressed: () => ref.invalidate(evitadasProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
              data: (evitadas) => evitadas.pecas.isEmpty
                  ? const Text(
                      'Nenhuma peça evitada. Para marcar, abra uma peça no armário e '
                      'toque em "Evitar nas sugestões".',
                    )
                  : Column(
                      children: [
                        for (final peca in evitadas.pecas)
                          _LinhaPecaEvitada(
                            peca: peca,
                            onRemover: () => _pararDeEvitar(context, ref, peca),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaPecaEvitada extends StatelessWidget {
  const _LinhaPecaEvitada({required this.peca, required this.onRemover});

  final Peca peca;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final detalhe = [peca.subcategoria, peca.corPrincipal].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              AppConstants.resolveMediaUrl(peca.imagemUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peca.categoria),
                if (detalhe.isNotEmpty)
                  Text(detalhe, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Parar de evitar ${peca.categoria}',
            icon: const Icon(Icons.close),
            onPressed: onRemover,
          ),
        ],
      ),
    );
  }
}
