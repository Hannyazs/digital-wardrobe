import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart'
    show gavetaOutras, gavetasDoArmario;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/clothing_card.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/peca.dart';
import '../looks/looks_view.dart';
import '../upload/upload_view.dart';
import 'gaveta_view.dart';
import 'peca_detail_view.dart';
import 'wardrobe_controller.dart';
import 'widgets/carrosseis_paginados.dart';
import 'widgets/filtros_de_pecas.dart';

enum AbaArmario { pecas, looks }

/// Aba visível do armário. Sem `autoDispose`: sobrevive à troca de aba.
final abaArmarioProvider = StateProvider<AbaArmario>((ref) => AbaArmario.pecas);

/// Armário: guarda as peças cadastradas e os looks prontos (salvos).
///
/// - "Peças": uma seção por gaveta (Partes de cima, Partes de baixo, …) com
///   carrossel; tocar no nome da gaveta abre [GavetaView]. Filtros (E2.F2.1)
///   num painel aberto pelo botão de filtros.
/// - "Looks": a lista de looks salvos ([LooksView]), que antes ficava dentro
///   da montagem de look.
class WardrobeView extends ConsumerWidget {
  const WardrobeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aba = ref.watch(abaArmarioProvider);

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            titulo: 'Meu Armário',
            subtitulo: 'Suas peças e seus looks guardados.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<AbaArmario>(
                segments: const [
                  ButtonSegment(
                    value: AbaArmario.pecas,
                    label: Text('Peças'),
                    icon: Icon(Icons.checkroom),
                  ),
                  ButtonSegment(
                    value: AbaArmario.looks,
                    label: Text('Looks'),
                    icon: Icon(Icons.collections_bookmark_outlined),
                  ),
                ],
                selected: {aba},
                showSelectedIcon: false,
                onSelectionChanged: (s) => ref.read(abaArmarioProvider.notifier).state = s.first,
              ),
            ),
          ),
          Expanded(
            child: aba == AbaArmario.pecas ? const _AbaPecas() : const LooksView(),
          ),
        ],
      ),
      // O FAB de "Montar look" da aba Looks vem do próprio `LooksView`.
      floatingActionButton: aba == AbaArmario.pecas
          ? FloatingActionButton(
              tooltip: 'Adicionar peça',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const UploadView()),
                );
              },
              child: const Icon(Icons.add_a_photo),
            )
          : null,
    );
  }
}

class _AbaPecas extends ConsumerWidget {
  const _AbaPecas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroArmarioProvider);
    // Total do armário sem filtro (o "de M") e total que satisfaz o filtro.
    final totalGeral =
        ref.watch(totalDePecasProvider(const ConsultaPecas())).valueOrNull;
    final totalFiltrado = filtro.ativo
        ? ref
            .watch(totalDePecasProvider(ConsultaPecas(filtro: filtro)))
            .valueOrNull
        : totalGeral;
    final carregadas = pecasCarregadas(ref, gruposPorGaveta, filtro);

    return RefreshIndicator(
      onRefresh: () => recarregarGrupos(ref, gruposPorGaveta, filtro),
      child: Column(
        children: [
          // Armário vazio não tem o que filtrar: a orientação ocupa a tela.
          if (totalGeral != 0)
            BarraDeFiltros(
              texto: totalFiltrado == null
                  ? ''
                  : rotuloQuantidadePecas(
                      totalFiltrado, totalGeral ?? totalFiltrado),
              quantidadeFiltros: filtro.quantidade,
              onFiltros: () => abrirFiltrosDePecas(
                  context, filtroArmarioProvider, carregadas),
            ),
          Expanded(
            child: ListaDeCarrosseis(
              listKey: const Key('armario-lista-categorias'),
              grupos: gruposPorGaveta,
              filtro: filtro,
              mostrarContagem: true,
              padding: const EdgeInsets.only(top: 4, bottom: 88),
              itemBuilder: cardDaPeca,
              vazio: const _ArmarioVazio(),
              aoLimparFiltro: () => ref
                  .read(filtroArmarioProvider.notifier)
                  .state = const FiltroPecas(),
              aoAbrirGrupo: (grupo) {
                final gaveta = [...gavetasDoArmario, gavetaOutras]
                    .firstWhere((g) => g.nome == grupo.titulo);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => GavetaView(gaveta: gaveta)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de peça do armário (tela principal e gavetas): tocar abre o detalhe;
/// peça com cadastro incompleto ganha o selo (E5.F4.1).
Widget cardDaPeca(BuildContext context, Peca peca) {
  return ClothingCard(
    imagemUrl: peca.imagemUrl,
    rotulo: descricaoPeca(peca),
    incompleta: camposIncompletos(peca).isNotEmpty,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PecaDetailView(peca: peca)),
    ),
  );
}

class _ArmarioVazio extends StatelessWidget {
  const _ArmarioVazio();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checkroom, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text('Seu armário está vazio'),
                SizedBox(height: 8),
                Text('Toque no botão de câmera para adicionar sua primeira peça'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
