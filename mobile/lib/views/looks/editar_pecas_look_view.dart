import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import '../../core/widgets/clothing_card.dart';
import '../../models/look.dart';
import '../wardrobe/wardrobe_controller.dart';
import '../wardrobe/widgets/filtros_de_pecas.dart';
import 'looks_controller.dart';
import 'montar_look_controller.dart' show lookServiceProvider;
import '../../models/peca.dart';

/// Trocar as peças de um look salvo (E3.F5.2): mesmos carrosséis por
/// categoria e filtros da montagem, com as peças do look já marcadas.
/// A seleção é estado local da tela — não usa `selecaoLookProvider`, que é da
/// aba de montagem (sempre montada no `HomeShell`).
class EditarPecasLookView extends ConsumerStatefulWidget {
  const EditarPecasLookView({super.key, required this.look});

  final Look look;

  @override
  ConsumerState<EditarPecasLookView> createState() => _EditarPecasLookViewState();
}

class _EditarPecasLookViewState extends ConsumerState<EditarPecasLookView> {
  late final Set<String> _originais = widget.look.pecas.map((p) => p.id).toSet();
  late Set<String> _selecao = {..._originais};
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Fora do build: provider não pode mudar durante a montagem da árvore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(filtroEdicaoLookProvider.notifier).state = const FiltroPecas();
    });
  }

  bool get _mudou =>
      _selecao.length != _originais.length || !_selecao.containsAll(_originais);

  void _alternar(String pecaId) {
    setState(() {
      _selecao = _selecao.contains(pecaId)
          ? ({..._selecao}..remove(pecaId))
          : {..._selecao, pecaId};
    });
  }

  Future<void> _salvar() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      await ref
          .read(lookServiceProvider)
          .atualizarLook(widget.look.id, {'peca_ids': _selecao.toList()});
      ref.invalidate(lookListProvider);
      // O calendário da Casa mostra as peças do look nos dias de uso.
      ref.invalidate(historicoProvider);
      ref.invalidate(historicoMesProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Peças de "${widget.look.nome}" atualizadas.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _salvando = false);
      messenger.showSnackBar(SnackBar(content: Text(_mensagemDeErro(error))));
    }
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'Sessão expirada ou inválida. Não foi possível salvar o look.';
      if (status == 404) return 'Look não encontrado. Atualize a lista e tente novamente.';
      if (status == 422) return 'Alguma peça escolhida não existe mais. Atualize e tente novamente.';
      if (error.type == DioExceptionType.connectionError) {
        return 'Sem conexão com o servidor. Não foi possível salvar o look.';
      }
    }
    return 'Não foi possível salvar o look. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(pecaListProvider);
    final filtro = ref.watch(filtroEdicaoLookProvider);
    final texto = switch (_selecao.length) {
      0 => 'Escolha pelo menos uma peça',
      1 => '1 peça selecionada',
      final n => '$n peças selecionadas',
    };

    return Scaffold(
      appBar: AppBar(title: Text('Editar peças · ${widget.look.nome}')),
      body: pecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar seu armário.'),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Tentar novamente',
                  onPressed: () => ref.invalidate(pecaListProvider),
                ),
              ],
            ),
          ),
        ),
        data: (pecas) {
          final grupos = agruparPorCategoria(filtrarPecas(pecas, filtro));
          return Column(
            children: [
              BarraDeFiltros(
                texto: texto,
                quantidadeFiltros: filtro.quantidade,
                onFiltros: () => abrirFiltrosDePecas(context, filtroEdicaoLookProvider, pecas),
              ),
              Expanded(
                child: grupos.isEmpty
                    ? SemResultadoFiltro(
                        onLimpar: () => ref.read(filtroEdicaoLookProvider.notifier).state =
                            const FiltroPecas(),
                      )
                    : ListView(
                        key: const Key('editar-pecas-lista'),
                        padding: const EdgeInsets.only(top: 4, bottom: 16),
                        children: [
                          for (final entry in grupos.entries)
                            CategorySection(
                              titulo: entry.key,
                              itemCount: entry.value.length,
                              itemBuilder: (context, index) {
                                final peca = entry.value[index];
                                return ClothingCard(
                                  imagemUrl: peca.imagemUrl,
                                  rotulo: descricaoPeca(peca),
                                  selecionavel: true,
                                  selecionada: _selecao.contains(peca.id),
                                  onTap: _salvando ? null : () => _alternar(peca.id),
                                );
                              },
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Salvar',
            loading: _salvando,
            onPressed: _selecao.isNotEmpty && _mudou ? _salvar : null,
          ),
        ),
      ),
    );
  }
}
