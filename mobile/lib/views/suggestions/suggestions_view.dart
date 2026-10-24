import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/peca_opcoes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/peca.dart';
import '../../models/sugestao.dart';
import '../../services/sugestao_service.dart';
import '../looks/looks_controller.dart' show lookListProvider;
import '../preferences/preferences_controller.dart' show mensagemDeErroAoCarregar, preferenciasProvider;
import 'suggestions_controller.dart';
import 'widgets/conteudo_sugestao.dart';
import 'widgets/secao_criatividade.dart';

/// Estações que fazem sentido como filtro ("Todas as estações" não é uma).
final _estacoesDoFiltro = estacoesFixas.where((e) => e != 'Todas as estações').toList();

/// Aba "Sugestões" (E5.F2.1): looks montados pelo motor de regras do backend
/// (`POST /sugestoes`) só com peças do usuário. Nada é buscado ao abrir a aba —
/// só ao tocar "Sugerir looks".
///
/// Com [pecaBase] (E5.F2.2) é a tela empilhada "Montar looks com esta peça":
/// todos os pedidos levam `peca_base_id`, o estado é próprio (não mexe na aba)
/// e a primeira busca acontece ao abrir.
class SuggestionsView extends ConsumerStatefulWidget {
  const SuggestionsView({super.key, this.pecaBase});

  final Peca? pecaBase;

  @override
  ConsumerState<SuggestionsView> createState() => _SuggestionsViewState();
}

class _SuggestionsViewState extends ConsumerState<SuggestionsView> {
  /// Gravação do nível de criatividade em andamento (se houver). "Sugerir
  /// looks" espera por ela: o backend lê o nível salvo, então pedir antes de
  /// gravar geraria com o valor antigo.
  Future<bool>? _salvandoNivel;

  Future<bool> _salvarNivel(int nivel) {
    final messenger = ScaffoldMessenger.of(context);
    final futuro = () async {
      final erro = await ref.read(preferenciasProvider.notifier).atualizar(
        {'criatividade': nivel},
        (p) => p.copyWith(criatividade: nivel),
      );
      if (erro != null) messenger.showSnackBar(SnackBar(content: Text(erro)));
      return erro == null;
    }();
    _salvandoNivel = futuro;
    // Looks que já estão na tela foram gerados com o nível antigo: ao gravar o
    // novo, a lista é refeita sozinha (sem isso a régua parecia não mudar nada
    // até a pessoa tocar de novo em "Sugerir looks").
    futuro.then((gravou) {
      if (!gravou || !mounted) return;
      final provider = sugestoesProvider(widget.pecaBase?.id);
      final estado = ref.read(provider);
      if (estado.resultado != null && !estado.resultado!.isLoading) {
        ref.read(provider.notifier).sugerir();
      }
    });
    return futuro;
  }

  Future<void> _sugerir(SugestoesController controller) async {
    await _salvandoNivel;
    await controller.sugerir();
  }

  @override
  void initState() {
    super.initState();
    if (widget.pecaBase != null) {
      // Fora do build: provider não pode mudar durante a montagem da árvore.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(sugestoesProvider(widget.pecaBase!.id).notifier).sugerir();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pecaBase = widget.pecaBase;
    final provider = sugestoesProvider(pecaBase?.id);
    final estado = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final filtros = estado.filtros;
    final carregando = estado.resultado?.isLoading ?? false;
    final preferencia = ref.watch(preferenciasProvider);

    return Scaffold(
      appBar: pecaBase == null ? null : AppBar(title: const Text('Looks com esta peça')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (pecaBase == null)
            const ScreenHeader(
              titulo: 'Suas sugestões',
              subtitulo: 'Looks montados só com as suas peças.',
            )
          else
            _CabecalhoPecaBase(peca: pecaBase),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FiltroDropdown(
                  rotulo: 'Ocasião',
                  opcoes: ocasioesFixas,
                  valor: filtros.ocasiao,
                  aoMudar: (v) => controller.alterarFiltros(FiltroSugestoes(
                    ocasiao: v, estilo: filtros.estilo, estacao: filtros.estacao, cor: filtros.cor,
                  )),
                ),
                _FiltroDropdown(
                  rotulo: 'Estilo',
                  opcoes: estilosFixos,
                  valor: filtros.estilo,
                  aoMudar: (v) => controller.alterarFiltros(FiltroSugestoes(
                    ocasiao: filtros.ocasiao, estilo: v, estacao: filtros.estacao, cor: filtros.cor,
                  )),
                ),
                _FiltroDropdown(
                  rotulo: 'Estação',
                  opcoes: _estacoesDoFiltro,
                  valor: filtros.estacao,
                  aoMudar: (v) => controller.alterarFiltros(FiltroSugestoes(
                    ocasiao: filtros.ocasiao, estilo: filtros.estilo, estacao: v, cor: filtros.cor,
                  )),
                ),
                _FiltroDropdown(
                  rotulo: 'Cor',
                  opcoes: coresFixas.map((c) => c.nome).toList(),
                  valor: filtros.cor,
                  aoMudar: (v) => controller.alterarFiltros(FiltroSugestoes(
                    ocasiao: filtros.ocasiao, estilo: filtros.estilo, estacao: filtros.estacao, cor: v,
                  )),
                ),
                const SizedBox(height: 4),
                preferencia.when(
                  data: (p) => SecaoCriatividade(nivel: p.criatividade, onSalvar: _salvarNivel),
                  loading: () => const SizedBox.shrink(),
                  error: (erro, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(mensagemDeErroAoCarregar(erro))),
                        TextButton(
                          onPressed: () => ref.invalidate(preferenciasProvider),
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Sugerir looks',
                  icon: Icons.auto_awesome,
                  loading: carregando,
                  onPressed: () => _sugerir(controller),
                ),
                const SizedBox(height: 20),
                _Resultado(estado: estado, pecaBaseId: pecaBase?.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura e nome da peça fixa no topo da tela empilhada.
class _CabecalhoPecaBase extends StatelessWidget {
  const _CabecalhoPecaBase({required this.peca});

  final Peca peca;

  @override
  Widget build(BuildContext context) {
    final nome =
        [peca.categoria, if (peca.subcategoria?.isNotEmpty ?? false) peca.subcategoria].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              AppConstants.resolveMediaUrl(peca.imagemUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Todos os looks terão esta peça',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(nome),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nome do campo do filtro como aparece no botão "Remover filtro de <campo>".
const _rotuloDoFiltro = {
  'ocasiao': 'ocasião',
  'estilo': 'estilo',
  'estacao': 'estação',
  'cor': 'cor',
};

class _FiltroDropdown extends StatelessWidget {
  const _FiltroDropdown({
    required this.rotulo,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final List<String> opcoes;
  final String? valor;
  final ValueChanged<String?> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String?>(
        // `initialValue` só vale na criação: a chave com o valor recria o
        // campo se o estado mudar por fora (ex.: "Remover filtro", E5.F2.2).
        key: ValueKey('filtro-$rotulo-$valor'),
        initialValue: valor,
        decoration: InputDecoration(labelText: rotulo, isDense: true),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Qualquer')),
          for (final opcao in opcoes) DropdownMenuItem<String?>(value: opcao, child: Text(opcao)),
        ],
        onChanged: aoMudar,
      ),
    );
  }
}

class _Resultado extends ConsumerWidget {
  const _Resultado({required this.estado, required this.pecaBaseId});

  final SugestoesState estado;
  final String? pecaBaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sugestoesProvider(pecaBaseId).notifier);
    final resultado = estado.resultado;

    if (resultado == null) {
      return const _Mensagem(
        icone: Icons.auto_awesome,
        texto: 'Escolha os filtros (ou deixe em "Qualquer") e toque em "Sugerir looks".',
      );
    }

    return resultado.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (erro, _) => Column(
        children: [
          _Mensagem(icone: Icons.error_outline, texto: erro.toString()),
          AppButton(label: 'Tentar novamente', onPressed: controller.tentarNovamente),
        ],
      ),
      data: (pagina) {
        if (pagina.conflitos.isNotEmpty) {
          // A peça-base não combina com um filtro ativo (E5.F2.2).
          return Column(
            children: [
              for (final c in pagina.conflitos) ...[
                _Mensagem(icone: Icons.filter_alt_off_outlined, texto: c.mensagem),
                AppButton(
                  label: 'Remover filtro de ${_rotuloDoFiltro[c.filtro] ?? c.filtro}',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => controller.removerFiltro(c.filtro),
                ),
              ],
            ],
          );
        }
        if (pagina.looks.isEmpty) {
          return _Mensagem(
            icone: Icons.info_outline,
            texto: pagina.motivo ?? 'Nenhuma sugestão encontrada.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final sugestao in pagina.looks)
              _CardSugestao(sugestao: sugestao, estado: estado, pecaBaseId: pecaBaseId),
            const SizedBox(height: 8),
            if (pagina.temMais)
              AppButton(
                label: 'Ver outras',
                variant: AppButtonVariant.secondary,
                onPressed: controller.verOutras,
              )
            else
              const _Mensagem(
                icone: Icons.check_circle_outline,
                texto: 'Não há mais sugestões com esses filtros.',
              ),
          ],
        );
      },
    );
  }
}

class _CardSugestao extends ConsumerWidget {
  const _CardSugestao({required this.sugestao, required this.estado, required this.pecaBaseId});

  final Sugestao sugestao;
  final SugestoesState estado;
  final String? pecaBaseId;

  Future<void> _salvar(BuildContext context, WidgetRef ref) async {
    final erro =
        await ref.read(sugestoesProvider(pecaBaseId).notifier).salvar(sugestao, DateTime.now());
    if (!context.mounted) return;
    if (erro == null) ref.invalidate(lookListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erro ?? 'Look salvo em Armário › Looks.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salvando = estado.salvando.contains(sugestao.chave);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConteudoSugestao(sugestao: sugestao),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Descartar',
                  variant: AppButtonVariant.text,
                  onPressed: () =>
                      ref.read(sugestoesProvider(pecaBaseId).notifier).descartar(sugestao),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Salvar',
                  icon: Icons.bookmark_add_outlined,
                  variant: AppButtonVariant.secondary,
                  loading: salvando,
                  onPressed: () => _salvar(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icone, size: 40, color: AppColors.sage),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
