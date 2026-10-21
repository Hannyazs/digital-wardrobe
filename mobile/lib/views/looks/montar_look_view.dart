import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/category_section.dart';
import '../../core/widgets/clothing_card.dart';
import '../../core/widgets/filter_button.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/peca.dart';
import '../upload/upload_view.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'looks_controller.dart';
import 'looks_view.dart';
import 'montar_look_controller.dart';

/// Tela de montagem manual de um look (E3.F1.2): seleciona peças do
/// armário, nomeia e confirma. Ao salvar, invalida `lookListProvider`
/// (E3.F1.3) pra "Looks" já mostrar o look novo ao voltar.
///
/// Visual alinhado ao Figma "VIRTUALASSIST" (redesign visual, Etapa 2):
/// `ScreenHeader` + carrosséis por categoria com `ClothingCard` +
/// `FilterButton`. O botão de filtros aqui é só visual — esta tela não tem
/// filtro de peças implementado (diferente do armário, que tem desde a
/// E2.F2.1); tocar nele avisa isso em vez de fingir que funciona.
class MontarLookView extends ConsumerStatefulWidget {
  const MontarLookView({super.key});

  @override
  ConsumerState<MontarLookView> createState() => _MontarLookViewState();
}

class _MontarLookViewState extends ConsumerState<MontarLookView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nomeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _salvar() {
    final selecao = ref.read(selecaoLookProvider);
    if (!_formKey.currentState!.validate() || selecao.isEmpty) return;
    ref.read(montagemLookProvider.notifier).salvar(
          nome: _nomeController.text.trim(),
          pecaIds: selecao,
          ocasioes: ref.read(ocasioesLookProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(pecaListProvider);
    final selecao = ref.watch(selecaoLookProvider);
    final montagemState = ref.watch(montagemLookProvider);
    final enviando = montagemState is MontagemEnviando;
    final podeConfirmar =
        !enviando && _nomeController.text.trim().isNotEmpty && selecao.isNotEmpty;

    ref.listen<MontagemLookState>(montagemLookProvider, (previous, next) {
      if (next is MontagemSucesso) {
        ref.invalidate(lookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Look "${next.look.nome}" salvo.')),
        );
        Navigator.of(context).pop();
      } else if (next is MontagemErro) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.mensagem)));
      }
    });

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            titulo: 'Monte seu look',
            subtitulo: 'Escolha peças do seu armário.',
            acao: _acaoHeader(context),
          ),
          Expanded(
            child: pecasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Erro(
                mensagem: _mensagemDeErro(error),
                onTentarNovamente: () => ref.invalidate(pecaListProvider),
              ),
              data: (pecas) => pecas.isEmpty
                  ? const _ArmarioVazio()
                  : _buildConteudo(pecas, selecao, enviando),
            ),
          ),
        ],
      ),
      bottomNavigationBar: pecasAsync.maybeWhen(
        data: (pecas) => pecas.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: 'Salvar look',
                  onPressed: podeConfirmar ? _salvar : null,
                  loading: enviando,
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  /// Ação exibida no canto do `ScreenHeader`: "Meus looks" sempre, e um
  /// botão de voltar quando esta tela foi empurrada por cima de outra (ex:
  /// a partir da Home) — sem isso, remover a `AppBar` perderia a navegação
  /// de volta nesse caso.
  Widget _acaoHeader(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (Navigator.of(context).canPop())
          IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        IconButton(
          tooltip: 'Meus looks',
          icon: const Icon(Icons.collections_bookmark_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LooksView()),
          ),
        ),
      ],
    );
  }

  Widget _buildConteudo(List<Peca> pecas, Set<String> selecao, bool enviando) {
    final grupos = agruparPorCategoria(pecas);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nomeController,
                    enabled: !enviando,
                    decoration: const InputDecoration(labelText: 'Nome do look *'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Dê um nome ao look' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilterButton(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filtros ainda não disponíveis aqui.')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SeletorOcasiao(
            selecionadas: ref.watch(ocasioesLookProvider),
            habilitado: !enviando,
            onChanged: (valores) => ref.read(ocasioesLookProvider.notifier).state = valores,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                for (final entry in grupos.entries)
                  CategorySection(
                    titulo: entry.key,
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final peca = entry.value[index];
                      return ClothingCard(
                        imagemUrl: peca.imagemUrl,
                        selecionavel: true,
                        selecionada: selecao.contains(peca.id),
                        onTap: enviando
                            ? null
                            : () {
                                final notifier = ref.read(selecaoLookProvider.notifier);
                                final novaSelecao = {...notifier.state};
                                if (novaSelecao.contains(peca.id)) {
                                  novaSelecao.remove(peca.id);
                                } else {
                                  novaSelecao.add(peca.id);
                                }
                                notifier.state = novaSelecao;
                              },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException && error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível carregar seu armário.';
    }
    return 'Não foi possível carregar seu armário. Tente novamente.';
  }
}

/// Seletor opcional de ocasiões (E3.F3.2): seleção múltipla; tocar num chip
/// já marcado desmarca. Nunca bloqueia o salvamento.
class _SeletorOcasiao extends StatelessWidget {
  const _SeletorOcasiao({
    required this.selecionadas,
    required this.habilitado,
    required this.onChanged,
  });

  final List<String> selecionadas;
  final bool habilitado;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        children: [
          for (final ocasiao in ocasioesFixas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(ocasiao),
                selected: selecionadas.contains(ocasiao),
                onSelected: habilitado
                    ? (marcado) {
                        final marcadas = {...selecionadas};
                        marcado ? marcadas.add(ocasiao) : marcadas.remove(ocasiao);
                        // Ordem canônica (a de `ocasioesFixas`), não a do toque.
                        onChanged(ocasioesFixas.where(marcadas.contains).toList());
                      }
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArmarioVazio extends StatelessWidget {
  const _ArmarioVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Cadastre uma peça antes de montar um look',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Cadastrar peça',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UploadView()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
    );
  }
}
