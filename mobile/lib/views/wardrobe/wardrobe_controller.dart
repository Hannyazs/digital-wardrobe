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

/// Filtro de armário (E2.F2.1): cor, estação e ocasião, combinados com E
/// lógico. `null` num campo significa "sem restrição" nessa dimensão —
/// não existe opção "nenhum" explícita porque cor/estação/ocasião são
/// campos opcionais na peça, e filtrar por "sem cor" não é um caso de uso
/// pedido na PBI.
class FiltroArmario {
  const FiltroArmario({this.corPrincipal, this.estacao, this.ocasiao});

  final String? corPrincipal;
  final String? estacao;
  final String? ocasiao;

  bool get ativo => corPrincipal != null || estacao != null || ocasiao != null;

  FiltroArmario copyWith({
    String? Function()? corPrincipal,
    String? Function()? estacao,
    String? Function()? ocasiao,
  }) {
    return FiltroArmario(
      corPrincipal: corPrincipal != null ? corPrincipal() : this.corPrincipal,
      estacao: estacao != null ? estacao() : this.estacao,
      ocasiao: ocasiao != null ? ocasiao() : this.ocasiao,
    );
  }
}

/// Estado do filtro ativo na `WardrobeView`. `autoDispose` pelo mesmo motivo
/// de [pecaListProvider]: não há razão pra reter o filtro depois que a tela
/// de armário sai da árvore de widgets.
final filtroArmarioProvider = StateProvider.autoDispose<FiltroArmario>(
  (ref) => const FiltroArmario(),
);

/// Aplica o filtro sobre a lista já carregada (filtragem é client-side —
/// `GET /pecas` não tem query params, a lista inteira já veio de uma vez).
List<Peca> filtrarPecas(List<Peca> pecas, FiltroArmario filtro) {
  return pecas.where((peca) {
    if (filtro.corPrincipal != null && peca.corPrincipal != filtro.corPrincipal) {
      return false;
    }
    if (filtro.estacao != null && peca.estacao != filtro.estacao) {
      return false;
    }
    if (filtro.ocasiao != null && !peca.ocasioes.contains(filtro.ocasiao)) {
      return false;
    }
    return true;
  }).toList();
}

/// Valores distintos (não nulos) de um campo livre (cor/estação), ordenados
/// alfabeticamente — essas dimensões não têm lista fixa como [ocasioesFixas],
/// então as opções do filtro vêm só do que o usuário já cadastrou.
List<String> _valoresDistintos(List<Peca> pecas, String? Function(Peca) campo) {
  final valores = pecas.map(campo).whereType<String>().toSet().toList();
  valores.sort();
  return valores;
}

List<String> coresDisponiveis(List<Peca> pecas) =>
    _valoresDistintos(pecas, (p) => p.corPrincipal);

List<String> estacoesDisponiveis(List<Peca> pecas) =>
    _valoresDistintos(pecas, (p) => p.estacao);

/// Opções do filtro de ocasião: as predefinidas (sempre) mais as
/// personalizadas ("Outros") que já existem em alguma peça do usuário.
List<String> ocasioesDisponiveis(List<Peca> pecas) {
  final extras = pecas
      .expand((p) => p.ocasioes)
      .where((o) => !ocasioesFixas.contains(o))
      .toSet()
      .toList()
    ..sort();
  return [...ocasioesFixas, ...extras];
}
