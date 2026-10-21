import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../models/evitadas.dart';
import '../../looks/widgets/pecas_do_look.dart';
import '../escolher_par_view.dart';
import '../preferences_controller.dart';

/// Seção "Combinações que evito" (E4.F4.3): pares de peças que o usuário não
/// quer ver juntas. Lê o mesmo [evitadasProvider] da seção de peças evitadas.
class SecaoCombinacoesEvitadas extends ConsumerWidget {
  const SecaoCombinacoesEvitadas({super.key});

  static String _nome(CombinacaoEvitada par) =>
      par.pecas.map((peca) => peca.categoria).join(' + ');

  Future<void> _remover(BuildContext context, WidgetRef ref, CombinacaoEvitada par) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover esta combinação?'),
        content: Text('"${_nome(par)}" poderá ser sugerida junta de novo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await ref.read(preferenciaServiceProvider).pararDeEvitarCombinacao(par.id);
      ref.invalidate(evitadasProvider);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        // Já não existe (ex.: uma das peças foi excluída e o backend apagou o
        // par em cascata): só atualiza a lista, sem tratar como falha.
        ref.invalidate(evitadasProvider);
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroEvitadas(error, 'remover a combinação'))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroEvitadas(error, 'remover a combinação'))),
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
            Text('Combinações que evito', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Peças que você usa, mas não quer ver juntas no mesmo look.',
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
                  const Expanded(child: Text('Não foi possível carregar as combinações evitadas.')),
                  TextButton(
                    onPressed: () => ref.invalidate(evitadasProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
              data: (evitadas) => evitadas.combinacoes.isEmpty
                  ? const Text(
                      'Nenhuma combinação evitada. Ex.: uma camisa e uma calça que '
                      'você usa, mas nunca juntas.',
                    )
                  : Column(
                      children: [
                        for (final par in evitadas.combinacoes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      PecasDoLook(pecas: par.pecas),
                                      const SizedBox(height: 4),
                                      Text(_nome(par)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remover ${_nome(par)}',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _remover(context, ref, par),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Adicionar par de peças',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EscolherParView()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
