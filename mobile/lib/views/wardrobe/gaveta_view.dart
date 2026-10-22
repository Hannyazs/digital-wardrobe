import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart' show Gaveta;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import 'wardrobe_controller.dart';
import 'wardrobe_view.dart' show cardDaPeca, mensagemDeErroArmario;
import 'widgets/filtros_de_pecas.dart';

/// Uma gaveta do armário aberta: carrosséis por categoria (ex.: Camisetas,
/// Camisas) ou, na gaveta de uma categoria só, por subcategoria. Usa o mesmo
/// filtro da aba Armário — o que foi filtrado lá continua valendo aqui.
class GavetaView extends ConsumerWidget {
  const GavetaView({super.key, required this.gaveta});

  final Gaveta gaveta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pecasAsync = ref.watch(pecaListProvider);
    final filtro = ref.watch(filtroArmarioProvider);

    return Scaffold(
      appBar: AppBar(title: Text(gaveta.nome)),
      body: pecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text(mensagemDeErroArmario(error), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Tentar novamente',
                  onPressed: () => ref.invalidate(pecaListProvider),
                ),
              ],
            ),
          ),
        ),
        data: (todas) {
          final daGaveta = pecasDaGaveta(gaveta, todas);
          if (daGaveta.isEmpty) {
            return const Center(child: Text('Nenhuma peça nesta gaveta.'));
          }
          final filtradas = filtrarPecas(daGaveta, filtro);
          final secoes = secoesDaGaveta(gaveta, filtradas);
          return Column(
            children: [
              BarraDeFiltros(
                texto: rotuloQuantidadePecas(filtradas.length, daGaveta.length),
                quantidadeFiltros: filtro.quantidade,
                onFiltros: () => abrirFiltrosDePecas(context, filtroArmarioProvider, daGaveta),
              ),
              Expanded(
                child: filtradas.isEmpty
                    ? SemResultadoFiltro(
                        onLimpar: () =>
                            ref.read(filtroArmarioProvider.notifier).state = const FiltroPecas(),
                      )
                    : ListView(
                        key: const Key('gaveta-secoes'),
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        children: [
                          for (final secao in secoes.entries)
                            CategorySection(
                              titulo: secao.key,
                              contagem: secao.value.length,
                              itemCount: secao.value.length,
                              itemBuilder: (context, index) =>
                                  cardDaPeca(context, secao.value[index]),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
