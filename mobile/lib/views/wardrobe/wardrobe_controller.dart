import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../models/peca.dart';
import '../upload/upload_controller.dart' show pecaServiceProvider;

/// Quantas peças cada página traz (E11.F1.2). O servidor aceita até 100.
const tamanhoDaPaginaDePecas = 20;

/// O que se pede ao servidor: um recorte do armário (por categorias, ou a
/// gaveta "Outras") com um [FiltroPecas]. É a chave dos providers paginados,
/// por isso compara por valor.
class ConsultaPecas {
  const ConsultaPecas({
    this.categorias = const {},
    this.outras = false,
    this.filtro = const FiltroPecas(),
  });

  /// Peças de uma gaveta; [gavetaOutras] vira "categorias fora da lista fixa".
  factory ConsultaPecas.daGaveta(Gaveta gaveta,
      [FiltroPecas filtro = const FiltroPecas()]) {
    return identical(gaveta, gavetaOutras)
        ? ConsultaPecas(outras: true, filtro: filtro)
        : ConsultaPecas(categorias: gaveta.categorias.toSet(), filtro: filtro);
  }

  /// Peças de uma categoria; `'Outras'` junta as de categoria desconhecida.
  factory ConsultaPecas.daCategoria(String categoria,
      [FiltroPecas filtro = const FiltroPecas()]) {
    return categoria == 'Outras'
        ? ConsultaPecas(outras: true, filtro: filtro)
        : ConsultaPecas(categorias: {categoria}, filtro: filtro);
  }

  final Set<String> categorias;
  final bool outras;
  final FiltroPecas filtro;

  ConsultaPecas comFiltro(FiltroPecas novo) =>
      ConsultaPecas(categorias: categorias, outras: outras, filtro: novo);

  @override
  bool operator ==(Object other) =>
      other is ConsultaPecas &&
      other.outras == outras &&
      setEquals(other.categorias, categorias) &&
      other.filtro == filtro;

  @override
  int get hashCode =>
      Object.hash(outras, Object.hashAllUnordered(categorias), filtro);
}

/// Peças já carregadas de uma [ConsultaPecas], mais o que falta para pedir a
/// próxima página.
class PecasPaginadas {
  const PecasPaginadas({
    required this.itens,
    required this.total,
    required this.recebidas,
    required this.temMais,
    this.carregandoMais = false,
    this.erroProximaPagina,
  });

  /// Sem repetição de `id`, na ordem do servidor.
  final List<Peca> itens;

  /// Total que satisfaz a consulta (`X-Total-Count`); `null` se o servidor não informou.
  final int? total;

  /// Quantas peças o servidor já entregou: é o deslocamento da próxima página.
  /// Pode passar de `itens.length` quando a lista mudou entre as páginas e a
  /// deduplicação descartou um item repetido.
  final int recebidas;
  final bool temMais;
  final bool carregandoMais;

  /// Erro da última tentativa de carregar a página seguinte; as [itens] já
  /// mostradas continuam valendo.
  final Object? erroProximaPagina;

  PecasPaginadas copyWith({
    bool? carregandoMais,
    Object? erroProximaPagina,
    bool limparErro = false,
  }) {
    return PecasPaginadas(
      itens: itens,
      total: total,
      recebidas: recebidas,
      temMais: temMais,
      carregandoMais: carregandoMais ?? this.carregandoMais,
      erroProximaPagina:
          limparErro ? null : (erroProximaPagina ?? this.erroProximaPagina),
    );
  }
}

/// Carrega peças de uma [ConsultaPecas] aos poucos (E11.F1.2). `build` traz a
/// primeira página; [carregarMais] acrescenta a seguinte.
class PecasPaginadasNotifier
    extends AutoDisposeFamilyAsyncNotifier<PecasPaginadas, ConsultaPecas> {
  /// Riverpod 2.x não tem `ref.mounted`: depois de descartado, mudar `state` lança.
  bool _descartado = false;

  @override
  Future<PecasPaginadas> build(ConsultaPecas arg) async {
    ref.onDispose(() => _descartado = true);
    final pagina = await ref
        .read(pecaServiceProvider)
        .listarPagina(arg, limite: tamanhoDaPaginaDePecas);
    return PecasPaginadas(
      itens: _semRepeticao(const [], pagina.itens),
      total: pagina.total,
      recebidas: pagina.itens.length,
      temMais: _haMais(pagina.itens.length, pagina.itens.length, pagina.total),
    );
  }

  /// Pede a próxima página. Ignora o pedido se já há uma em andamento ou se
  /// não há mais: a tela pode chamar à vontade (ex.: ao construir o rodapé).
  /// Se falhar, as peças já carregadas ficam e [PecasPaginadas.erroProximaPagina]
  /// é preenchido; chamar de novo tenta outra vez.
  Future<void> carregarMais() async {
    final atual = state.valueOrNull;
    if (atual == null || !atual.temMais || atual.carregandoMais) return;
    state = AsyncData(atual.copyWith(carregandoMais: true, limparErro: true));
    try {
      final pagina = await ref.read(pecaServiceProvider).listarPagina(
            arg,
            limite: tamanhoDaPaginaDePecas,
            deslocamento: atual.recebidas,
          );
      if (_descartado) return;
      final recebidas = atual.recebidas + pagina.itens.length;
      final total = pagina.total ?? atual.total;
      state = AsyncData(PecasPaginadas(
        itens: _semRepeticao(atual.itens, pagina.itens),
        total: total,
        recebidas: recebidas,
        temMais: _haMais(pagina.itens.length, recebidas, total),
      ));
    } catch (erro) {
      if (_descartado) return;
      state = AsyncData(
          atual.copyWith(carregandoMais: false, erroProximaPagina: erro));
    }
  }

  /// Página cheia = pode haver mais; se o total é conhecido, só enquanto faltar.
  bool _haMais(int veioNaPagina, int recebidas, int? total) =>
      veioNaPagina >= tamanhoDaPaginaDePecas &&
      (total == null || recebidas < total);

  /// Deduplicação por `id`: a limitação do offset pode repetir uma peça entre páginas.
  List<Peca> _semRepeticao(List<Peca> jaCarregadas, List<Peca> novas) {
    final vistos = {for (final p in jaCarregadas) p.id};
    return [...jaCarregadas, ...novas.where((p) => vistos.add(p.id))];
  }
}

/// Peças de uma consulta, paginadas. `autoDispose`: a lista é rebuscada sempre
/// que nenhuma tela a observa mais (ex.: ao voltar do cadastro).
final pecasPaginadasProvider = AsyncNotifierProvider.autoDispose
    .family<PecasPaginadasNotifier, PecasPaginadas, ConsultaPecas>(
        PecasPaginadasNotifier.new);

/// Quantas peças satisfazem a consulta, sem trazer as peças (pede uma página de
/// uma peça só e lê `X-Total-Count`). Alimenta "N peças de M" e "Ver N peças".
final totalDePecasProvider = FutureProvider.autoDispose
    .family<int, ConsultaPecas>((ref, consulta) async {
  final pagina =
      await ref.read(pecaServiceProvider).listarPagina(consulta, limite: 1);
  return pagina.total ?? pagina.itens.length;
});

/// Chamar depois de criar, editar ou excluir uma peça: as listas paginadas e
/// as contagens voltam a ser buscadas. Aceita `WidgetRef` e `Ref`.
void invalidarPecas(dynamic ref) {
  ref.invalidate(pecasPaginadasProvider);
  ref.invalidate(totalDePecasProvider);
}

/// Agrupa peças por categoria na ordem fixa de [categoriasFixas].
/// Categoria fora dessa lista (o banco aceita `String` livre) cai num
/// grupo final "Outras", em vez de sumir da tela. A ordem das peças
/// dentro de cada grupo é a mesma da lista recebida (o backend já devolve
/// em ordem decrescente de criação).
Map<String, List<Peca>> agruparPorCategoria(List<Peca> pecas) {
  final grupos = <String, List<Peca>>{};
  for (final categoria in categoriasFixas) {
    final doGrupo = pecas.where((p) => p.categoria == categoria).toList();
    if (doGrupo.isNotEmpty) {
      grupos[categoria] = doGrupo;
    }
  }
  final outras = pecas.where((p) => !categoriasFixas.contains(p.categoria)).toList();
  if (outras.isNotEmpty) {
    grupos['Outras'] = outras;
  }
  return grupos;
}

/// Peças de uma gaveta. [gavetaOutras] recebe as de categoria desconhecida.
List<Peca> pecasDaGaveta(Gaveta gaveta, List<Peca> pecas) {
  if (identical(gaveta, gavetaOutras)) {
    return pecas.where((p) => !categoriasFixas.contains(p.categoria)).toList();
  }
  return pecas.where((p) => gaveta.categorias.contains(p.categoria)).toList();
}

/// Gavetas com pelo menos uma peça, na ordem de [gavetasDoArmario]
/// ("Outras" por último, só se houver peça fora das categorias fixas).
Map<Gaveta, List<Peca>> agruparPorGaveta(List<Peca> pecas) {
  final grupos = <Gaveta, List<Peca>>{};
  for (final gaveta in [...gavetasDoArmario, gavetaOutras]) {
    final doGrupo = pecasDaGaveta(gaveta, pecas);
    if (doGrupo.isNotEmpty) grupos[gaveta] = doGrupo;
  }
  return grupos;
}

/// Seções de dentro de uma gaveta: uma por categoria quando a gaveta junta
/// várias (ex.: Camisetas e Camisas); uma por subcategoria quando a gaveta é
/// de uma categoria só (ex.: Vestidos → Longo, Midi). Peças sem subcategoria
/// ficam numa seção com o nome da categoria, por último.
Map<String, List<Peca>> secoesDaGaveta(Gaveta gaveta, List<Peca> pecas) {
  final daGaveta = pecasDaGaveta(gaveta, pecas);
  if (gaveta.categorias.length != 1) return agruparPorCategoria(daGaveta);

  // "Midi" e "midi" são a mesma seção; vale a grafia da primeira peça.
  final porSubcategoria = <String, List<Peca>>{};
  final nomeDaChave = <String, String>{};
  final semSubcategoria = <Peca>[];
  for (final peca in daGaveta) {
    final sub = peca.subcategoria?.trim() ?? '';
    if (sub.isEmpty) {
      semSubcategoria.add(peca);
    } else {
      final chave = sub.toLowerCase();
      nomeDaChave.putIfAbsent(chave, () => sub);
      porSubcategoria.putIfAbsent(chave, () => []).add(peca);
    }
  }
  final chaves = porSubcategoria.keys.toList()..sort();
  return {
    for (final chave in chaves) nomeDaChave[chave]!: porSubcategoria[chave]!,
    if (semSubcategoria.isNotEmpty)
      porSubcategoria.isEmpty ? gaveta.categorias.single : 'Sem subcategoria': semSubcategoria,
  };
}

/// Subcategorias já usadas em peças da [categoria] (sem repetir por maiúsculas,
/// na grafia da primeira peça, em ordem alfabética), menos a já digitada em
/// [atual]. Atalhos do formulário de cadastro.
List<String> subcategoriasUsadas(List<Peca> pecas, String? categoria, {String atual = ''}) {
  if (categoria == null) return const [];
  final porChave = <String, String>{};
  for (final peca in pecas.where((p) => p.categoria == categoria)) {
    final sub = peca.subcategoria?.trim() ?? '';
    if (sub.isNotEmpty) porChave.putIfAbsent(sub.toLowerCase(), () => sub);
  }
  porChave.remove(atual.trim().toLowerCase());
  final chaves = porChave.keys.toList()..sort();
  return [for (final c in chaves) porChave[c]!];
}

/// Filtro de peças, usado no armário e na montagem de look. Cada critério
/// aceita vários valores: dentro de um critério vale OU (Azul ou Preto), entre
/// critérios vale E (cor E estação). Conjunto vazio = sem restrição.
class FiltroPecas {
  const FiltroPecas({this.cores = const {}, this.estacoes = const {}, this.ocasioes = const {}});

  final Set<String> cores;
  final Set<String> estacoes;
  final Set<String> ocasioes;

  bool get ativo => quantidade > 0;

  /// Quantos valores estão marcados (o número no botão de filtros).
  int get quantidade => cores.length + estacoes.length + ocasioes.length;

  FiltroPecas alternarCor(String cor) => FiltroPecas(
        cores: _alternar(cores, cor),
        estacoes: estacoes,
        ocasioes: ocasioes,
      );

  FiltroPecas alternarEstacao(String estacao) => FiltroPecas(
        cores: cores,
        estacoes: _alternar(estacoes, estacao),
        ocasioes: ocasioes,
      );

  FiltroPecas alternarOcasiao(String ocasiao) => FiltroPecas(
        cores: cores,
        estacoes: estacoes,
        ocasioes: _alternar(ocasioes, ocasiao),
      );

  @override
  bool operator ==(Object other) =>
      other is FiltroPecas &&
      setEquals(other.cores, cores) &&
      setEquals(other.estacoes, estacoes) &&
      setEquals(other.ocasioes, ocasioes);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(cores),
        Object.hashAllUnordered(estacoes),
        Object.hashAllUnordered(ocasioes),
      );
}

Set<String> _alternar(Set<String> valores, String valor) =>
    valores.contains(valor) ? ({...valores}..remove(valor)) : {...valores, valor};

const _todasAsEstacoes = 'Todas as estações';

/// Filtro ativo na aba Armário (e nas gavetas abertas a partir dela). Sem
/// `autoDispose`: o `HomeShell` mantém a aba montada e o filtro deve
/// sobreviver à troca de aba e à ida e volta de uma gaveta.
final filtroArmarioProvider = StateProvider<FiltroPecas>((ref) => const FiltroPecas());

/// Filtro da montagem de look, separado do armário. Sem `autoDispose` (a aba
/// de montagem fica montada no `HomeShell`); a montagem o limpa depois de
/// salvar um look.
final filtroMontagemProvider = StateProvider<FiltroPecas>((ref) => const FiltroPecas());

/// Filtro da tela "Editar peças" de um look salvo (E3.F5.2); a tela o limpa
/// ao abrir, para não herdar o filtro de uma edição anterior.
final filtroEdicaoLookProvider = StateProvider<FiltroPecas>((ref) => const FiltroPecas());

/// Aplica o filtro sobre uma lista de peças. Hoje o filtro vale no servidor
/// (`GET /pecas`, E11.F1.1): esta função é a **referência das regras** que ele
/// replica (`backend/app/services/peca_consulta.py`) e serve de servidor falso
/// nos testes. Peça marcada "Todas as estações" serve para qualquer estação
/// filtrada, como no motor de sugestões.
List<Peca> filtrarPecas(List<Peca> pecas, FiltroPecas filtro) {
  return pecas.where((peca) {
    // Peça multicolorida aparece no filtro de qualquer uma das suas cores.
    if (filtro.cores.isNotEmpty && !coresDaPeca(peca).any(filtro.cores.contains)) {
      return false;
    }
    if (filtro.estacoes.isNotEmpty &&
        !peca.estacoes.any(filtro.estacoes.contains) &&
        !peca.estacoes.contains(_todasAsEstacoes)) {
      return false;
    }
    if (filtro.ocasioes.isNotEmpty && !peca.ocasioes.any(filtro.ocasioes.contains)) {
      return false;
    }
    return true;
  }).toList();
}

/// Opções de um critério de filtro: a lista fixa inteira (não há endpoint de
/// facetas, então não dá para saber o que existe nas páginas ainda não
/// carregadas) e, depois, os valores livres das peças carregadas, em ordem
/// alfabética. [selecionados] entram sempre, para poderem ser desmarcados
/// mesmo que nenhuma peça os tenha mais (ex.: depois de editar a peça).
List<String> _opcoes(Iterable<String> existentes, List<String> ordem, Set<String> selecionados) {
  final valores = {...existentes.where((v) => v.trim().isNotEmpty), ...selecionados};
  final extras = valores.where((v) => !ordem.contains(v)).toList()..sort();
  return [...ordem, ...extras];
}

List<String> coresDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) => _opcoes(
      pecas.expand(coresDaPeca),
      [for (final c in coresFixas) c.nome],
      selecionadas,
    );

List<String> estacoesDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) =>
    _opcoes(pecas.expand((p) => p.estacoes), estacoesFixas, selecionadas);

List<String> ocasioesDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) =>
    _opcoes(pecas.expand((p) => p.ocasioes), ocasioesFixas, selecionadas);
