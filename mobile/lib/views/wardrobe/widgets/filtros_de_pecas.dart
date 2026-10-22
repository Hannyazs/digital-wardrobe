import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/filter_button.dart';
import '../../../core/widgets/painel_de_filtros.dart';
import '../../../models/peca.dart';
import '../wardrobe_controller.dart';

/// Painel de filtros de peças (cor, estação, ocasião), usado no armário, nas
/// gavetas e na montagem de look. As opções saem de [pecas] — só aparece o
/// que existe nas peças daquela tela.
Future<void> abrirFiltrosDePecas(
  BuildContext context,
  StateProvider<FiltroPecas> provider,
  List<Peca> pecas,
) {
  void atualizar(WidgetRef ref, FiltroPecas Function(FiltroPecas) mudar) =>
      ref.read(provider.notifier).update(mudar);

  return abrirPainelDeFiltros(
    context,
    secoes: (ref) {
      final filtro = ref.watch(provider);
      return [
        SecaoDeFiltro(
          titulo: 'Cor',
          opcoes: coresDisponiveis(pecas, filtro.cores),
          selecionada: filtro.cores.contains,
          alternar: (v) => atualizar(ref, (f) => f.alternarCor(v)),
        ),
        SecaoDeFiltro(
          titulo: 'Estação',
          opcoes: estacoesDisponiveis(pecas, filtro.estacoes),
          selecionada: filtro.estacoes.contains,
          alternar: (v) => atualizar(ref, (f) => f.alternarEstacao(v)),
        ),
        SecaoDeFiltro(
          titulo: 'Ocasião',
          opcoes: ocasioesDisponiveis(pecas, filtro.ocasioes),
          selecionada: filtro.ocasioes.contains,
          alternar: (v) => atualizar(ref, (f) => f.alternarOcasiao(v)),
        ),
      ];
    },
    ativo: (ref) => ref.watch(provider).ativo,
    limpar: (ref) => ref.read(provider.notifier).state = const FiltroPecas(),
    rotuloResultado: (ref) {
      final total = filtrarPecas(pecas, ref.watch(provider)).length;
      return total == 1 ? 'Ver 1 peça' : 'Ver $total peças';
    },
  );
}

/// Faixa acima de uma lista: um texto à esquerda (ex.: "5 peças") e o botão
/// de filtros à direita.
class BarraDeFiltros extends StatelessWidget {
  const BarraDeFiltros({
    super.key,
    required this.texto,
    required this.quantidadeFiltros,
    required this.onFiltros,
  });

  final String texto;
  final int quantidadeFiltros;
  final VoidCallback onFiltros;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          FilterButton(quantidade: quantidadeFiltros, onTap: onFiltros),
        ],
      ),
    );
  }
}

/// "5 peças" / "1 peça", com "de N" quando há filtro escondendo peças.
String rotuloQuantidadePecas(int visiveis, int total) {
  final base = visiveis == 1 ? '1 peça' : '$visiveis peças';
  return visiveis == total ? base : '$base de $total';
}

/// Lista vazia por causa dos filtros (não por falta de peças).
class SemResultadoFiltro extends StatelessWidget {
  const SemResultadoFiltro({super.key, required this.onLimpar, this.texto});

  final VoidCallback onLimpar;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_off, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(texto ?? 'Nenhuma peça encontrada com esses filtros'),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Limpar filtros',
                  variant: AppButtonVariant.text,
                  onPressed: onLimpar,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
