import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart' show Gaveta;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import '../../core/widgets/clothing_card.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/peca.dart';
import '../looks/looks_view.dart';
import '../upload/upload_view.dart';
import 'gaveta_view.dart';
import 'peca_detail_view.dart';
import 'wardrobe_controller.dart';
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
            titulo: 'Meu Guarda-Roupa',
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
    final pecasAsync = ref.watch(pecaListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pecaListProvider);
        await ref.read(pecaListProvider.future);
      },
      child: pecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Erro(
          mensagem: mensagemDeErroArmario(error),
          onTentarNovamente: () => ref.invalidate(pecaListProvider),
        ),
        data: (pecas) => pecas.isEmpty ? const _ArmarioVazio() : _ArmarioFiltravel(pecas: pecas),
      ),
    );
  }
}

String mensagemDeErroArmario(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível carregar seu armário.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível carregar seu armário. Tente novamente.';
    }
  }
  return 'Não foi possível carregar seu armário. Tente novamente.';
}

class _ArmarioFiltravel extends ConsumerWidget {
  const _ArmarioFiltravel({required this.pecas});

  final List<Peca> pecas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroArmarioProvider);
    final filtrados = filtrarPecas(pecas, filtro);

    return Column(
      children: [
        BarraDeFiltros(
          texto: rotuloQuantidadePecas(filtrados.length, pecas.length),
          quantidadeFiltros: filtro.quantidade,
          onFiltros: () => abrirFiltrosDePecas(context, filtroArmarioProvider, pecas),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? SemResultadoFiltro(
                  onLimpar: () =>
                      ref.read(filtroArmarioProvider.notifier).state = const FiltroPecas(),
                )
              : _Gavetas(grupos: agruparPorGaveta(filtrados)),
        ),
      ],
    );
  }
}

class _Gavetas extends StatelessWidget {
  const _Gavetas({required this.grupos});

  final Map<Gaveta, List<Peca>> grupos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('armario-lista-categorias'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      children: [
        for (final entry in grupos.entries)
          CategorySection(
            titulo: entry.key.nome,
            contagem: entry.value.length,
            itemCount: entry.value.length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => GavetaView(gaveta: entry.key)),
            ),
            itemBuilder: (context, index) => cardDaPeca(context, entry.value[index]),
          ),
      ],
    );
  }
}

/// Card de peça do armário (tela principal e gavetas): tocar abre o detalhe;
/// peça com cadastro incompleto ganha o selo (E5.F4.1).
Widget cardDaPeca(BuildContext context, Peca peca) {
  return ClothingCard(
    imagemUrl: peca.imagemUrl,
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
                Text('Toque em + para adicionar sua primeira peça'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text(mensagem, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AppButton(label: 'Tentar novamente', onPressed: onTentarNovamente),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
