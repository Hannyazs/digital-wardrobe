import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../models/peca.dart';
import '../upload/upload_controller.dart' show pecaServiceProvider;

/// Lista de peças do usuário (E2.F1.1). `autoDispose` para rebuscar sozinho
/// sempre que a tela do armário for recriada (ex: ao voltar do cadastro).
final pecaListProvider = FutureProvider.autoDispose<List<Peca>>((ref) {
  return ref.watch(pecaServiceProvider).listarPecas();
});

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

  final porSubcategoria = <String, List<Peca>>{};
  final semSubcategoria = <Peca>[];
  for (final peca in daGaveta) {
    final sub = peca.subcategoria?.trim() ?? '';
    if (sub.isEmpty) {
      semSubcategoria.add(peca);
    } else {
      porSubcategoria.putIfAbsent(sub, () => []).add(peca);
    }
  }
  final nomes = porSubcategoria.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return {
    for (final nome in nomes) nome: porSubcategoria[nome]!,
    if (semSubcategoria.isNotEmpty)
      porSubcategoria.isEmpty ? gaveta.categorias.single : 'Sem subcategoria': semSubcategoria,
  };
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

/// Aplica o filtro sobre a lista já carregada (filtragem é client-side —
/// `GET /pecas` não tem query params, a lista inteira já veio de uma vez).
/// Peça marcada "Todas as estações" serve para qualquer estação filtrada,
/// como no motor de sugestões.
List<Peca> filtrarPecas(List<Peca> pecas, FiltroPecas filtro) {
  return pecas.where((peca) {
    if (filtro.cores.isNotEmpty && !filtro.cores.contains(peca.corPrincipal)) {
      return false;
    }
    if (filtro.estacoes.isNotEmpty &&
        !filtro.estacoes.contains(peca.estacao) &&
        peca.estacao != _todasAsEstacoes) {
      return false;
    }
    if (filtro.ocasioes.isNotEmpty && !peca.ocasioes.any(filtro.ocasioes.contains)) {
      return false;
    }
    return true;
  }).toList();
}

/// Valores que existem nas peças, na ordem de [ordem] e depois os demais em
/// ordem alfabética. [selecionados] entram sempre, para poderem ser desmarcados
/// mesmo que nenhuma peça os tenha mais (ex.: depois de editar a peça).
List<String> _opcoes(Iterable<String> existentes, List<String> ordem, Set<String> selecionados) {
  final valores = {...existentes.where((v) => v.trim().isNotEmpty), ...selecionados};
  final extras = valores.where((v) => !ordem.contains(v)).toList()..sort();
  return [...ordem.where(valores.contains), ...extras];
}

List<String> coresDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) => _opcoes(
      pecas.map((p) => p.corPrincipal).whereType<String>(),
      [for (final c in coresFixas) c.nome],
      selecionadas,
    );

List<String> estacoesDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) =>
    _opcoes(pecas.map((p) => p.estacao).whereType<String>(), estacoesFixas, selecionadas);

List<String> ocasioesDisponiveis(List<Peca> pecas, [Set<String> selecionadas = const {}]) =>
    _opcoes(pecas.expand((p) => p.ocasioes), ocasioesFixas, selecionadas);
