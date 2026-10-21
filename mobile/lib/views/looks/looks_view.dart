import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../models/look.dart';
import 'looks_controller.dart';
import 'historico_view.dart';
import 'montar_look_controller.dart' show lookServiceProvider;
import 'widgets/pecas_do_look.dart';
import 'montar_look_view.dart';

/// Listagem dos looks salvos (E3.F1.3). Tocar num look não faz nada ainda
/// — detalhe/edição é uma PBI futura, sem endpoint próprio hoje.
class LooksView extends ConsumerWidget {
  const LooksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final looksAsync = ref.watch(lookListProvider);
    // Histórico só alimenta o rótulo "Usado há N dias": carregando ou com
    // erro vira "sem informação" (sem rótulo), nunca um erro na tela (E3.F4.4).
    final ultimosUsos = ultimoUsoPorLook(ref.watch(historicoProvider).valueOrNull ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Looks'),
        actions: [
          IconButton(
            tooltip: 'Histórico de looks usados',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoricoView()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lookListProvider);
          ref.invalidate(historicoProvider);
          await ref.read(lookListProvider.future);
        },
        child: looksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Erro(
            mensagem: _mensagemDeErro(error),
            onTentarNovamente: () => ref.invalidate(lookListProvider),
          ),
          data: (looks) {
            if (looks.isEmpty) return const _SemLooks();
            final filtro = ref.watch(filtroLooksProvider);
            final filtrados = filtrarLooks(looks, filtro);
            return Column(
              children: [
                _PainelFiltros(filtro: filtro),
                Expanded(
                  child: filtrados.isEmpty
                      ? _SemResultadoFiltro(
                          filtro: filtro,
                          onLimpar: () =>
                              ref.read(filtroLooksProvider.notifier).state = const FiltroLooks(),
                        )
                      : _ListaDeLooks(looks: filtrados, ultimosUsos: ultimosUsos),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // `HomeShell` mantém Armário e Looks montados ao mesmo tempo
        // (`IndexedStack`) — sem uma hero tag própria, este FAB colide com o
        // de `WardrobeView` (mesma tag padrão em todo `FloatingActionButton`).
        heroTag: 'looks-montar-look-fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MontarLookView()),
          );
        },
        icon: const Icon(Icons.checkroom),
        label: const Text('Montar look'),
      ),
    );
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Sessão expirada ou inválida. Não foi possível carregar seus looks.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
        case DioExceptionType.connectionError:
          return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
        default:
          return 'Não foi possível carregar seus looks. Tente novamente.';
      }
    }
    return 'Não foi possível carregar seus looks. Tente novamente.';
  }
}

class _ListaDeLooks extends StatelessWidget {
  const _ListaDeLooks({required this.looks, required this.ultimosUsos});

  final List<Look> looks;

  /// `lookId` → último dia de uso (E3.F4.4).
  final Map<String, DateTime> ultimosUsos;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: looks.length,
      itemBuilder: (context, index) => _LookCard(look: looks[index], ultimoUso: ultimosUsos[looks[index].id]),
    );
  }
}

class _PainelFiltros extends ConsumerWidget {
  const _PainelFiltros({required this.filtro});

  final FiltroLooks filtro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('Favoritos'),
              selected: filtro.somenteFavoritos,
              // Lê o filtro atual (não o capturado no build): dois toques
              // seguidos não podem partir de um estado já superado.
              onSelected: (selecionado) => ref.read(filtroLooksProvider.notifier).state =
                  ref.read(filtroLooksProvider).copyWith(somenteFavoritos: selecionado),
            ),
            for (final ocasiao in ocasioesFixas)
              FilterChip(
                label: Text(ocasiao),
                selected: filtro.ocasioes.contains(ocasiao),
                // Seleção múltipla: tocar de novo desmarca.
                onSelected: (_) => ref.read(filtroLooksProvider.notifier).state =
                    ref.read(filtroLooksProvider).alternarOcasiao(ocasiao),
              ),
          ],
        ),
      ),
    );
  }
}

class _SemResultadoFiltro extends StatelessWidget {
  const _SemResultadoFiltro({required this.filtro, required this.onLimpar});

  final FiltroLooks filtro;
  final VoidCallback onLimpar;

  /// Só "Favoritos" ativo mantém o texto específico da E3.F2.2; qualquer
  /// filtro de ocasião cita o que está ativo.
  String get _titulo {
    if (filtro.ocasioes.isEmpty) return 'Nenhum look favorito ainda';
    final nomes = filtro.ocasioes.map((o) => '"$o"').join(', ');
    final ocasioes = filtro.ocasioes.length == 1 ? 'da ocasião $nomes' : 'das ocasiões $nomes';
    return filtro.somenteFavoritos ? 'Nenhum look favorito $ocasioes' : 'Nenhum look $ocasioes';
  }

  String get _dica => filtro.ocasioes.isEmpty
      ? 'Toque no coração de um look para favoritá-lo'
      : 'Tente outro filtro ou limpe os filtros';

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
                Icon(filtro.ocasioes.isEmpty ? Icons.favorite_border : Icons.filter_alt_off, size: 64),
                const SizedBox(height: 16),
                Text(_titulo, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_dica, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(onPressed: onLimpar, child: const Text('Limpar filtros')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ids de looks com `POST /usos` em andamento (bloqueio de toque duplo).
final registrandoUsoProvider = StateProvider<Set<String>>((ref) => {});

class _LookCard extends ConsumerWidget {
  const _LookCard({required this.look, this.ultimoUso});

  final Look look;

  /// Último dia de uso (E3.F4.4); `null` = nunca usado ou histórico indisponível.
  final DateTime? ultimoUso;

  Future<void> _alternarFavorito(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lookServiceProvider).atualizarLook(look.id, {'favorito': !look.favorito});
      ref.invalidate(lookListProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemFavorito(error))));
    }
  }

  Future<void> _alterarOcasiao(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final escolha = await showModalBottomSheet<_EscolhaOcasioes>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeletorOcasioesSheet(atuais: look.ocasioes),
    );
    if (escolha == null) return; // sheet dispensado, nada a fazer
    try {
      // Lista vazia limpa as ocasiões no backend (`null` seria recusado).
      await ref.read(lookServiceProvider).atualizarLook(look.id, {'ocasioes': escolha.valores});
      ref.invalidate(lookListProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemFavorito(error))));
    }
  }

  Future<void> _registrarUso(
    BuildContext context,
    WidgetRef ref,
    DateTime data, {
    required String descricaoData,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final emAndamento = ref.read(registrandoUsoProvider);
    // Evita registro duplicado por toque duplo enquanto o POST está em curso.
    if (emAndamento.contains(look.id)) return;
    ref.read(registrandoUsoProvider.notifier).state = {...emAndamento, look.id};
    try {
      await ref.read(lookServiceProvider).registrarUso(look.id, data);
      ref.invalidate(historicoProvider);
      ref.invalidate(historicoMesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Uso de "${look.nome}" registrado $descricaoData.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemUso(error))));
    } finally {
      ref.read(registrandoUsoProvider.notifier).state =
          ref.read(registrandoUsoProvider).where((id) => id != look.id).toSet();
    }
  }

  Future<void> _registrarUsoEmOutraData(BuildContext context, WidgetRef ref) async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje, // sem datas futuras (o backend também recusa)
    );
    if (escolhida == null || !context.mounted) return; // cancelado: nada é enviado
    final dd = escolhida.day.toString().padLeft(2, '0');
    final mm = escolhida.month.toString().padLeft(2, '0');
    await _registrarUso(context, ref, escolhida, descricaoData: 'em $dd/$mm/${escolhida.year}');
  }

  String _mensagemUso(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Sessão expirada ou inválida. Não foi possível registrar o uso.';
      }
      if (status == 404) {
        return 'Look não encontrado. Atualize a lista e tente novamente.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Sem conexão com o servidor. Não foi possível registrar o uso.';
      }
    }
    return 'Não foi possível registrar o uso. Tente novamente.';
  }

  String _mensagemFavorito(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Sessão expirada ou inválida. Não foi possível atualizar o look.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Sem conexão com o servidor. Não foi possível atualizar o look.';
      }
    }
    return 'Não foi possível atualizar o look. Tente novamente.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    look.nome,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: look.favorito ? 'Remover dos favoritos' : 'Favoritar',
                  icon: Icon(look.favorito ? Icons.favorite : Icons.favorite_border),
                  color: look.favorito ? Colors.redAccent : null,
                  onPressed: () => _alternarFavorito(context, ref),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (acao) {
                    switch (acao) {
                      case 'hoje':
                        _registrarUso(context, ref, DateTime.now(), descricaoData: 'para hoje');
                      case 'outra':
                        _registrarUsoEmOutraData(context, ref);
                      case 'ocasiao':
                        _alterarOcasiao(context, ref);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'hoje', child: Text('Usei hoje')),
                    PopupMenuItem(value: 'outra', child: Text('Usei em outra data…')),
                    PopupMenuItem(value: 'ocasiao', child: Text('Alterar ocasião')),
                  ],
                ),
              ],
            ),
            if (look.ocasioes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final ocasiao in look.ocasioes)
                      Chip(label: Text(ocasiao), visualDensity: VisualDensity.compact),
                  ],
                ),
              ),
            if (ultimoUso != null) _RotuloDeUso(ultimoUso: ultimoUso!),
            const SizedBox(height: 8),
            PecasDoLook(pecas: look.pecas),
          ],
        ),
      ),
    );
  }
}

/// "Usado há N dias"; em cor de aviso quando o último uso é recente
/// (<= [diasDeRepeticaoRecente] dias). Só informa: não bloqueia nem reordena.
class _RotuloDeUso extends StatelessWidget {
  const _RotuloDeUso({required this.ultimoUso});

  final DateTime ultimoUso;

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final recente = repeticaoRecente(ultimoUso, hoje);
    final cor = recente ? Colors.orange.shade800 : Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: cor),
          const SizedBox(width: 4),
          Text(
            rotuloDeRecencia(ultimoUso, hoje),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cor,
                  fontWeight: recente ? FontWeight.w600 : null,
                ),
          ),
        ],
      ),
    );
  }
}

/// Resultado do bottom sheet: embrulha a lista para distinguir "nenhuma
/// ocasião" (`valores` vazio) de sheet dispensado (resultado `null`).
class _EscolhaOcasioes {
  const _EscolhaOcasioes(this.valores);

  final List<String> valores;
}

/// Marcação múltipla das ocasiões de um look. Ocasiões já salvas fora de
/// `ocasioesFixas` (ex.: vindas de outro cliente) aparecem marcadas e são
/// mantidas, para não sumirem sem o usuário perceber.
class _SeletorOcasioesSheet extends StatefulWidget {
  const _SeletorOcasioesSheet({required this.atuais});

  final List<String> atuais;

  @override
  State<_SeletorOcasioesSheet> createState() => _SeletorOcasioesSheetState();
}

class _SeletorOcasioesSheetState extends State<_SeletorOcasioesSheet> {
  late final Set<String> _marcadas = {...widget.atuais};

  List<String> get _opcoes => [
        ...ocasioesFixas,
        ...widget.atuais.where((o) => !ocasioesFixas.contains(o)),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final ocasiao in _opcoes)
                  CheckboxListTile(
                    title: Text(ocasiao),
                    value: _marcadas.contains(ocasiao),
                    onChanged: (marcada) => setState(
                      () => marcada == true ? _marcadas.add(ocasiao) : _marcadas.remove(ocasiao),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: _marcadas.isEmpty ? null : () => setState(_marcadas.clear),
                  child: const Text('Sem ocasião'),
                ),
                const Spacer(),
                ElevatedButton(
                  // Ordem canônica (a de `_opcoes`), não a da marcação.
                  onPressed: () => Navigator.of(context).pop(
                    _EscolhaOcasioes(_opcoes.where(_marcadas.contains).toList()),
                  ),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemLooks extends StatelessWidget {
  const _SemLooks();

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
                Icon(Icons.style_outlined, size: 64),
                SizedBox(height: 16),
                Text('Você ainda não tem nenhum look salvo'),
                SizedBox(height: 8),
                Text('Toque em "Montar look" para criar o primeiro'),
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
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                Text(mensagem, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onTentarNovamente,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
