import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart' show Gaveta;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import 'wardrobe_controller.dart';
import 'wardrobe_view.dart' show cardDaPeca;
import 'widgets/carrosseis_paginados.dart';
import 'widgets/filtros_de_pecas.dart';

/// Uma gaveta do armário aberta: carrosséis por categoria (ex.: Camisetas,
/// Camisas) ou, na gaveta de uma categoria só, por subcategoria. Usa o mesmo
/// filtro da aba Armário — o que foi filtrado lá continua valendo aqui.
///
/// As peças chegam por página (E11.F1.3): ao rolar até o fim da lista a
/// seguinte é pedida e acrescentada. As seções são calculadas sobre o que já
/// foi carregado, então a composição delas pode mudar conforme a rolagem avança.
class GavetaView extends ConsumerWidget {
  const GavetaView({super.key, required this.gaveta});

  final Gaveta gaveta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroArmarioProvider);
    final consulta = ConsultaPecas.daGaveta(gaveta, filtro);
    final pecasAsync = ref.watch(pecasPaginadasProvider(consulta));
    // Peças da gaveta sem filtro: o "de M" do rótulo e a diferença entre
    // "gaveta vazia" e "o filtro escondeu tudo".
    final totalDaGaveta = ref
        .watch(totalDePecasProvider(ConsultaPecas.daGaveta(gaveta)))
        .valueOrNull;

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
                  onPressed: () =>
                      ref.invalidate(pecasPaginadasProvider(consulta)),
                ),
              ],
            ),
          ),
        ),
        data: (dados) {
          if (dados.itens.isEmpty && !filtro.ativo) {
            return const Center(child: Text('Nenhuma peça nesta gaveta.'));
          }
          final visiveis = dados.total ?? dados.itens.length;
          return Column(
            children: [
              BarraDeFiltros(
                texto:
                    rotuloQuantidadePecas(visiveis, totalDaGaveta ?? visiveis),
                quantidadeFiltros: filtro.quantidade,
                onFiltros: () => abrirFiltrosDePecas(
                  context,
                  filtroArmarioProvider,
                  dados.itens,
                  escopo: ConsultaPecas.daGaveta(gaveta),
                ),
              ),
              Expanded(
                child: dados.itens.isEmpty
                    ? SemResultadoFiltro(
                        onLimpar: () =>
                            ref.read(filtroArmarioProvider.notifier).state = const FiltroPecas(),
                      )
                    : _Secoes(gaveta: gaveta, consulta: consulta, dados: dados),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Secoes extends ConsumerWidget {
  const _Secoes(
      {required this.gaveta, required this.consulta, required this.dados});

  final Gaveta gaveta;
  final ConsultaPecas consulta;
  final PecasPaginadas dados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secoes = secoesDaGaveta(gaveta, dados.itens).entries.toList();
    // O rodapé é o gatilho: só é construído quando a rolagem chega perto do fim.
    final rodape = rodapeDePaginacao(ref, consulta, dados);

    return RefreshIndicator(
      // Puxar para atualizar reinicia a lista: é o remédio contra a limitação do offset.
      onRefresh: () async {
        invalidarPecas(ref);
        try {
          await ref.read(pecasPaginadasProvider(consulta).future);
        } catch (_) {}
      },
      child: ListView.builder(
        key: const Key('gaveta-secoes'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: secoes.length + (rodape == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == secoes.length) return rodape!;
          final secao = secoes[index];
          return CategorySection(
            titulo: secao.key,
            contagem: secao.value.length,
            itemCount: secao.value.length,
            itemBuilder: (context, i) => cardDaPeca(context, secao.value[i]),
          );
        },
      ),
    );
  }
}
