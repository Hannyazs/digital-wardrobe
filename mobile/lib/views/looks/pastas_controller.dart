import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/look.dart';
import '../../models/pasta_look.dart';
import '../../services/pasta_service.dart';
import 'looks_controller.dart' show lookListProvider;
import 'montar_look_controller.dart' show lookServiceProvider;

/// Máximo de caracteres do nome da pasta (backend: `schemas/pasta.py`).
const nomeDaPastaMax = 40;

final pastaServiceProvider = Provider<PastaService>((ref) => PastaService());

/// Pastas de looks (E3.F6.2), em ordem alfabética, com a quantidade de looks.
class PastasController extends AsyncNotifier<List<PastaLook>> {
  @override
  Future<List<PastaLook>> build() => ref.read(pastaServiceProvider).listar();

  List<PastaLook> get _atuais => state.valueOrNull ?? const [];

  List<PastaLook> _ordenadas(Iterable<PastaLook> pastas) => pastas.toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

  Future<PastaLook> criar(String nome) async {
    final nova = await ref.read(pastaServiceProvider).criar(nome);
    state = AsyncData(_ordenadas([..._atuais, nova]));
    return nova;
  }

  Future<void> renomear(String id, String nome) async {
    final atualizada = await ref.read(pastaServiceProvider).renomear(id, nome);
    state = AsyncData(_ordenadas([for (final p in _atuais) p.id == id ? atualizada : p]));
  }

  /// Exclui só a pasta; os looks dela viram "Sem pasta". Se ela estava
  /// selecionada, a lista volta para "Todos".
  Future<void> excluir(String id) async {
    await ref.read(pastaServiceProvider).excluir(id);
    state = AsyncData([
      for (final p in _atuais)
        if (p.id != id) p,
    ]);
    if (ref.read(pastaSelecionadaProvider).pastaId == id) {
      ref.read(pastaSelecionadaProvider.notifier).state = SelecaoPasta.todos;
    }
    ref.invalidate(lookListProvider);
    ref.invalidate(looksDaPastaProvider);
  }
}

final pastasProvider = AsyncNotifierProvider<PastasController, List<PastaLook>>(PastasController.new);

/// Chip escolhido no topo da aba Looks: "Todos", "Sem pasta" ou uma pasta.
class SelecaoPasta {
  const SelecaoPasta._({this.pastaId, this.semPasta = false});

  const SelecaoPasta.pasta(String id) : this._(pastaId: id);

  static const todos = SelecaoPasta._();
  static const nenhuma = SelecaoPasta._(semPasta: true);

  final String? pastaId;
  final bool semPasta;

  bool get eTodos => pastaId == null && !semPasta;

  @override
  bool operator ==(Object other) =>
      other is SelecaoPasta && other.pastaId == pastaId && other.semPasta == semPasta;

  @override
  int get hashCode => Object.hash(pastaId, semPasta);
}

/// Sem `autoDispose`: `HomeShell` mantém a aba montada e a seleção deve
/// sobreviver à troca de aba (como `filtroLooksProvider`).
final pastaSelecionadaProvider = StateProvider<SelecaoPasta>((ref) => SelecaoPasta.todos);

/// Looks de uma pasta ou os sem pasta, filtrados no servidor. "Todos" usa
/// `lookListProvider`, compartilhado com as outras telas.
final looksDaPastaProvider =
    FutureProvider.autoDispose.family<List<Look>, SelecaoPasta>((ref, selecao) {
  return ref.watch(lookServiceProvider).listarLooksDaPasta(
        pastaId: selecao.pastaId,
        semPasta: selecao.semPasta,
      );
});

/// Depois de criar, editar, mover ou excluir um look: recarrega a lista de
/// todos os looks, a da pasta aberta e as contagens dos chips (a contagem só
/// considera looks não arquivados, então excluir um look também a muda).
void invalidarLooks(dynamic ref) {
  ref.invalidate(lookListProvider);
  ref.invalidate(looksDaPastaProvider);
  ref.invalidate(pastasProvider);
}

/// Mensagem de falha com a pasta; [acao] completa "Não foi possível <acao> a pasta".
String mensagemDeErroDaPasta(Object erro, {String acao = 'salvar'}) {
  if (erro is DioException) {
    final status = erro.response?.statusCode;
    if (status == 409) return 'Já existe uma pasta com esse nome.';
    final detalhe = erro.response?.data;
    if (status == 422 && detalhe is Map && detalhe['detail'] is String) {
      return detalhe['detail'] as String;
    }
    if (status == 401) return 'Sessão expirada ou inválida. Não foi possível $acao a pasta.';
    if (erro.type == DioExceptionType.connectionError) {
      return 'Sem conexão com o servidor. Não foi possível $acao a pasta.';
    }
  }
  return 'Não foi possível $acao a pasta. Tente novamente.';
}
