import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import '../../core/widgets/clothing_card.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/peca.dart';
import '../upload/upload_view.dart';
import 'peca_detail_view.dart';
import 'wardrobe_controller.dart';

/// Armário: listagem agrupada por categoria (E2.F1.1) com filtro por cor,
/// estação e ocasião (E2.F2.1). Visual alinhado ao redesign (Etapa 3):
/// carrosséis por categoria com `CategorySection`/`ClothingCard`.
class WardrobeView extends ConsumerWidget {
  const WardrobeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pecasAsync = ref.watch(pecaListProvider);

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            titulo: 'Meu Guarda-Roupa',
            subtitulo: 'Suas peças, organizadas por categoria.',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pecaListProvider);
                await ref.read(pecaListProvider.future);
              },
              child: pecasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _Erro(
                  mensagem: _mensagemDeErro(error),
                  onTentarNovamente: () => ref.invalidate(pecaListProvider),
                ),
                data: (pecas) =>
                    pecas.isEmpty ? const _ArmarioVazio() : _ArmarioFiltravel(pecas: pecas),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar peça',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const UploadView()),
          );
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  String _mensagemDeErro(Object error) {
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
        _PainelFiltros(pecas: pecas, filtro: filtro),
        Expanded(
          child: filtrados.isEmpty
              ? _SemResultadoFiltro(
                  onLimpar: () =>
                      ref.read(filtroArmarioProvider.notifier).state = const FiltroArmario(),
                )
              : _ArmarioComPecas(grupos: agruparPorCategoria(filtrados)),
        ),
      ],
    );
  }
}

class _PainelFiltros extends ConsumerWidget {
  const _PainelFiltros({required this.pecas, required this.filtro});

  final List<Peca> pecas;
  final FiltroArmario filtro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = coresDisponiveis(pecas);
    final estacoes = estacoesDisponiveis(pecas);
    final notifier = ref.read(filtroArmarioProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cores.isNotEmpty)
            _LinhaFiltro(
              rotulo: 'Cor',
              opcoes: cores,
              selecionado: filtro.corPrincipal,
              onSelecionar: (valor) => notifier.state = filtro.copyWith(
                corPrincipal: () => filtro.corPrincipal == valor ? null : valor,
              ),
            ),
          if (estacoes.isNotEmpty)
            _LinhaFiltro(
              rotulo: 'Estação',
              opcoes: estacoes,
              selecionado: filtro.estacao,
              onSelecionar: (valor) => notifier.state = filtro.copyWith(
                estacao: () => filtro.estacao == valor ? null : valor,
              ),
            ),
          _LinhaFiltro(
            rotulo: 'Ocasião',
            opcoes: ocasioesDisponiveis(pecas),
            selecionado: filtro.ocasiao,
            onSelecionar: (valor) => notifier.state = filtro.copyWith(
              ocasiao: () => filtro.ocasiao == valor ? null : valor,
            ),
          ),
          if (filtro.ativo)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Limpar filtros',
                variant: AppButtonVariant.text,
                onPressed: () => notifier.state = const FiltroArmario(),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LinhaFiltro extends StatelessWidget {
  const _LinhaFiltro({
    required this.rotulo,
    required this.opcoes,
    required this.selecionado,
    required this.onSelecionar,
  });

  final String rotulo;
  final List<String> opcoes;
  final String? selecionado;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text('$rotulo:', style: AppTextStyles.labelCategoria()),
          for (final opcao in opcoes)
            FilterChip(
              label: Text(opcao),
              selected: selecionado == opcao,
              onSelected: (_) => onSelecionar(opcao),
            ),
        ],
      ),
    );
  }
}

class _SemResultadoFiltro extends StatelessWidget {
  const _SemResultadoFiltro({required this.onLimpar});

  final VoidCallback onLimpar;

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
                const Text('Nenhuma peça encontrada com esses filtros'),
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

class _ArmarioComPecas extends StatelessWidget {
  const _ArmarioComPecas({required this.grupos});

  final Map<String, List<Peca>> grupos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('armario-lista-categorias'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final entry in grupos.entries)
          CategorySection(
            titulo: entry.key,
            contagem: entry.value.length,
            itemCount: entry.value.length,
            itemBuilder: (context, index) {
              final peca = entry.value[index];
              return ClothingCard(
                imagemUrl: peca.imagemUrl,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PecaDetailView(peca: peca)),
                ),
              );
            },
          ),
      ],
    );
  }
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
