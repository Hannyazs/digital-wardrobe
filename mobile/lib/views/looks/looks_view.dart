import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../core/widgets/painel_de_filtros.dart';
import '../../models/look.dart';
import '../wardrobe/widgets/filtros_de_pecas.dart' show BarraDeFiltros;
import 'editar_pecas_look_view.dart';
import 'looks_controller.dart';
import 'montar_look_controller.dart' show lookServiceProvider;
import 'widgets/pecas_do_look.dart';
import 'montar_look_view.dart';

/// Looks salvos (E3.F1.3), exibidos na aba "Looks" do Armário — looks prontos
/// ficam junto das peças, separados da montagem. Sem `AppBar` própria: o
/// cabeçalho é o do Armário. O calendário de uso (E3.F4.3) fica na Casa.
/// Tocar num look não faz nada ainda — detalhe/edição é uma PBI futura.
class LooksView extends ConsumerWidget {
  const LooksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final looksAsync = ref.watch(lookListProvider);
    // Histórico só alimenta o rótulo "Usado há N dias": carregando ou com
    // erro vira "sem informação" (sem rótulo), nunca um erro na tela (E3.F4.4).
    final ultimosUsos = ultimoUsoPorLook(ref.watch(historicoProvider).valueOrNull ?? const []);

    return Scaffold(
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
            final total = looks.length == 1 ? '1 look' : '${looks.length} looks';
            return Column(
              children: [
                BarraDeFiltros(
                  texto: filtrados.length == looks.length ? total : '${filtrados.length} de $total',
                  quantidadeFiltros: filtro.ocasioes.length + (filtro.somenteFavoritos ? 1 : 0),
                  onFiltros: () => _abrirFiltros(context, looks),
                ),
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

  /// Favoritos (E3.F2.2) e ocasiões (E3.F3.3), combinados por E; entre as
  /// ocasiões vale OU. Só aparecem ocasiões que algum look tem.
  void _abrirFiltros(BuildContext context, List<Look> looks) {
    abrirPainelDeFiltros(
      context,
      secoes: (ref) {
        final filtro = ref.watch(filtroLooksProvider);
        return [
          SecaoDeFiltro(
            titulo: 'Mostrar',
            opcoes: const ['Favoritos'],
            selecionada: (_) => filtro.somenteFavoritos,
            // Lê o filtro atual (não o capturado no build): dois toques
            // seguidos não podem partir de um estado já superado.
            alternar: (_) => ref.read(filtroLooksProvider.notifier).update(
                  (f) => f.copyWith(somenteFavoritos: !f.somenteFavoritos),
                ),
          ),
          SecaoDeFiltro(
            titulo: 'Ocasião',
            opcoes: ocasioesDosLooks(looks, filtro.ocasioes),
            selecionada: filtro.ocasioes.contains,
            alternar: (o) =>
                ref.read(filtroLooksProvider.notifier).update((f) => f.alternarOcasiao(o)),
          ),
        ];
      },
      ativo: (ref) => ref.watch(filtroLooksProvider).ativo,
      limpar: (ref) => ref.read(filtroLooksProvider.notifier).state = const FiltroLooks(),
      rotuloResultado: (ref) {
        final total = filtrarLooks(looks, ref.watch(filtroLooksProvider)).length;
        return total == 1 ? 'Ver 1 look' : 'Ver $total looks';
      },
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

  /// Renomear (E5.F3.1): diálogo com o nome atual. Cancelar não chama a API;
  /// em falha, o nome anterior continua (a lista só muda quando recarrega).
  Future<void> _renomear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (_) => _RenomearDialog(nomeAtual: look.nome),
    );
    if (novoNome == null || novoNome == look.nome) return;
    try {
      await ref.read(lookServiceProvider).atualizarLook(look.id, {'nome': novoNome});
      ref.invalidate(lookListProvider);
      // O calendário da Casa mostra o nome do look nos dias de uso.
      ref.invalidate(historicoProvider);
      ref.invalidate(historicoMesProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemFavorito(error))));
    }
  }

  /// Excluir (E3.F5.1): o backend arquiva o look — os dias de uso continuam
  /// no calendário. Cancelar não chama a API.
  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir look?'),
        content: Text(
          '"${look.nome}" sai de Armário › Looks. '
          'Os dias em que você o usou continuam no calendário.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await ref.read(lookServiceProvider).excluirLook(look.id);
      ref.invalidate(lookListProvider);
      messenger.showSnackBar(SnackBar(content: Text('Look "${look.nome}" excluído.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemExclusao(error))));
    }
  }

  String _mensagemExclusao(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'Sessão expirada ou inválida. Não foi possível excluir o look.';
      if (status == 404) return 'Look não encontrado. Atualize a lista e tente novamente.';
      if (error.type == DioExceptionType.connectionError) {
        return 'Sem conexão com o servidor. Não foi possível excluir o look.';
      }
    }
    return 'Não foi possível excluir o look. Tente novamente.';
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
    // Tocar no card abre o mesmo menu do "⋮" — o card parecia tocável mas
    // não fazia nada.
    return _AbreMenuAoTocar(
      builder: (menuKey, abrirMenu) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: abrirMenu,
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
                      key: menuKey,
                      tooltip: 'Mais opções',
                      onSelected: (acao) {
                        switch (acao) {
                          case 'hoje':
                            _registrarUso(context, ref, DateTime.now(), descricaoData: 'para hoje');
                          case 'outra':
                            _registrarUsoEmOutraData(context, ref);
                          case 'ocasiao':
                            _alterarOcasiao(context, ref);
                          case 'renomear':
                            _renomear(context, ref);
                          case 'editar-pecas':
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EditarPecasLookView(look: look),
                              ),
                            );
                          case 'excluir':
                            _excluir(context, ref);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'hoje', child: Text('Usei hoje')),
                        PopupMenuItem(value: 'outra', child: Text('Usei em outra data…')),
                        PopupMenuItem(value: 'ocasiao', child: Text('Alterar ocasião')),
                        PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                        PopupMenuItem(value: 'editar-pecas', child: Text('Editar peças')),
                        PopupMenuItem(value: 'excluir', child: Text('Excluir')),
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
        ),
      ),
    );
  }
}

/// Guarda a chave do `PopupMenuButton` do card para o toque no card abri-lo.
class _AbreMenuAoTocar extends StatefulWidget {
  const _AbreMenuAoTocar({required this.builder});

  final Widget Function(GlobalKey<PopupMenuButtonState<String>> menuKey, VoidCallback abrirMenu)
      builder;

  @override
  State<_AbreMenuAoTocar> createState() => _AbreMenuAoTocarState();
}

class _AbreMenuAoTocarState extends State<_AbreMenuAoTocar> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) =>
      widget.builder(_menuKey, () => _menuKey.currentState?.showButtonMenu());
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

/// Diálogo de renomear: devolve o nome sem espaços nas pontas, ou `null` se
/// cancelado. "Salvar" fica desabilitado com o campo vazio (o backend também
/// recusa nome vazio com 422).
class _RenomearDialog extends StatefulWidget {
  const _RenomearDialog({required this.nomeAtual});

  final String nomeAtual;

  @override
  State<_RenomearDialog> createState() => _RenomearDialogState();
}

class _RenomearDialogState extends State<_RenomearDialog> {
  late final _controller = TextEditingController(text: widget.nomeAtual);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _controller.text.trim();
    if (nome.isNotEmpty) Navigator.of(context).pop(nome);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear look'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nome do look'),
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _salvar(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: _controller.text.trim().isEmpty ? null : _salvar,
          child: const Text('Salvar'),
        ),
      ],
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
