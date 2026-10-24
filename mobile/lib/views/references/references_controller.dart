import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/colecao.dart';
import '../../models/referencia.dart';
import '../../models/sugestao_de_look.dart';
import '../../services/colecao_service.dart';
import '../../services/referencia_service.dart';

/// Limite da nota no backend (`NOTA_MAX`).
const notaDaReferenciaMax = 500;

/// Limite do nome da coleção no backend (`NOME_MAX`).
const nomeDaColecaoMax = 40;

final referenciaServiceProvider =
    Provider<ReferenciaService>((ref) => ReferenciaService());
final colecaoServiceProvider =
    Provider<ColecaoService>((ref) => ColecaoService());

/// Abre a galeria e devolve a foto escolhida (`null` se cancelou). Provider
/// próprio para os testes trocarem o seletor nativo, que não é roteirizável.
final galeriaProvider = Provider<Future<XFile?> Function()>(
  (ref) => () => ImagePicker().pickImage(source: ImageSource.gallery),
);

/// `true` enquanto uma foto está sendo enviada (os botões "Adicionar" ficam
/// desabilitados, em qualquer tela do mural).
final enviandoReferenciaProvider = StateProvider<bool>((ref) => false);

/// Referências do mural (E8.F1.2). Sem `autoDispose`: a aba fica montada no
/// `HomeShell` e a lista não deve ser buscada de novo a cada troca de aba.
/// Guarda **todas** as referências; a grade de cada coleção filtra daqui.
class ReferenciasController extends AsyncNotifier<List<Referencia>> {
  @override
  Future<List<Referencia>> build() =>
      ref.read(referenciaServiceProvider).listar();

  List<Referencia> get _atuais => state.valueOrNull ?? const [];

  /// As quantidades por coleção vêm do servidor: depois de qualquer mudança
  /// de coleção, busca de novo (a lista já exibida continua na tela).
  void _recarregarContagens() => ref.invalidate(colecoesProvider);

  /// Envia a foto e a coloca no topo da lista. Em erro, a lista não muda e a
  /// exceção sobe para a tela mostrar a mensagem.
  Future<void> adicionar(XFile imagem,
      {String? nota, String? colecaoId}) async {
    final nova = await ref
        .read(referenciaServiceProvider)
        .criar(imagem, nota: nota, colecaoId: colecaoId);
    state = AsyncData([nova, ..._atuais]);
    _recarregarContagens();
  }

  /// Grava a nota (texto vazio = sem nota) e troca a referência na lista só
  /// depois que o servidor confirma; em erro a lista não muda.
  Future<void> atualizarNota(String id, String nota) async {
    final atualizada = await ref
        .read(referenciaServiceProvider)
        .atualizarNota(id, nota.trim().isEmpty ? null : nota.trim());
    state = AsyncData([for (final r in _atuais) r.id == id ? atualizada : r]);
  }

  /// Muda a referência de coleção (`null` = sem coleção).
  Future<void> mover(String id, String? colecaoId) async {
    final atualizada =
        await ref.read(referenciaServiceProvider).mover(id, colecaoId);
    state = AsyncData([for (final r in _atuais) r.id == id ? atualizada : r]);
    _recarregarContagens();
  }

  /// Liga a referência a um look salvo (`null` desliga).
  Future<void> ligarLook(String id, String? lookId) async {
    final atualizada = await ref.read(referenciaServiceProvider).ligarLook(id, lookId);
    state = AsyncData([for (final r in _atuais) r.id == id ? atualizada : r]);
  }

  /// Grava a lista de etiquetas (já editada pelo usuário); em erro a lista não muda.
  Future<void> atualizarEtiquetas(String id, List<String> etiquetas) async {
    final atualizada = await ref.read(referenciaServiceProvider).atualizarEtiquetas(id, etiquetas);
    state = AsyncData([for (final r in _atuais) r.id == id ? atualizada : r]);
  }

  /// Exclui no servidor e tira da lista; em erro a lista não muda.
  Future<void> excluir(String id) async {
    await ref.read(referenciaServiceProvider).excluir(id);
    state = AsyncData([
      for (final r in _atuais)
        if (r.id != id) r,
    ]);
    _recarregarContagens();
  }

  /// Uma coleção foi excluída: suas referências continuam, agora sem coleção
  /// (o servidor já fez o mesmo).
  void soltarDaColecao(String colecaoId) {
    state = AsyncData([
      for (final r in _atuais)
        if (r.colecaoId == colecaoId)
          r.semColecao()
        else
          r,
    ]);
  }
}

final referenciasProvider =
    AsyncNotifierProvider<ReferenciasController, List<Referencia>>(
        ReferenciasController.new);

/// Coleções do mural (E8.F2.2), em ordem alfabética (como o servidor devolve).
class ColecoesController extends AsyncNotifier<List<Colecao>> {
  @override
  Future<List<Colecao>> build() => ref.read(colecaoServiceProvider).listar();

  List<Colecao> get _atuais => state.valueOrNull ?? const [];

  List<Colecao> _ordenadas(Iterable<Colecao> colecoes) => colecoes.toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

  Future<void> criar(String nome) async {
    final nova = await ref.read(colecaoServiceProvider).criar(nome);
    state = AsyncData(_ordenadas([..._atuais, nova]));
  }

  Future<void> renomear(String id, String nome) async {
    final atualizada =
        await ref.read(colecaoServiceProvider).renomear(id, nome);
    state = AsyncData(
        _ordenadas([for (final c in _atuais) c.id == id ? atualizada : c]));
  }

  /// Exclui só a coleção; as referências dela viram "sem coleção".
  Future<void> excluir(String id) async {
    await ref.read(colecaoServiceProvider).excluir(id);
    state = AsyncData([
      for (final c in _atuais)
        if (c.id != id) c,
    ]);
    ref.read(referenciasProvider.notifier).soltarDaColecao(id);
  }
}

final colecoesProvider =
    AsyncNotifierProvider<ColecoesController, List<Colecao>>(
        ColecoesController.new);

/// Mensagem em português para uma falha de rede ou de validação do servidor;
/// [padrao] vale para qualquer outro erro.
String mensagemDeErro(Object erro, {required String padrao}) {
  if (erro is DioException) {
    final detalhe = erro.response?.data;
    final status = erro.response?.statusCode;
    if ((status == 422 || status == 409) &&
        detalhe is Map &&
        detalhe['detail'] is String) {
      return detalhe['detail'] as String;
    }
    if (erro.type == DioExceptionType.connectionError) {
      return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
    }
    if (erro.type == DioExceptionType.connectionTimeout ||
        erro.type == DioExceptionType.receiveTimeout ||
        erro.type == DioExceptionType.sendTimeout) {
      return 'A operação demorou demais. Tente novamente.';
    }
  }
  return padrao;
}

/// Falha com a referência; [acao] completa a frase "Não foi possível <acao>
/// referência" (ex.: `salvar a`, `excluir a`).
String mensagemDeErroDaReferencia(Object erro, {String acao = 'salvar a'}) =>
    mensagemDeErro(erro,
        padrao: 'Não foi possível $acao referência. Tente novamente.');

/// Falha com a coleção; [acao] completa "Não foi possível <acao> coleção".
String mensagemDeErroDaColecao(Object erro, {String acao = 'salvar a'}) =>
    mensagemDeErro(erro,
        padrao: 'Não foi possível $acao coleção. Tente novamente.');

/// Sugestão de look da IA para uma referência (E8.F5.3). `autoDispose`: cada vez
/// que a tela abre, a IA analisa de novo; `ref.invalidate` refaz ("Tentar de novo").
final sugestaoDeLookProvider =
    FutureProvider.autoDispose.family<SugestaoDeLook, String>((ref, referenciaId) {
  return ref.read(referenciaServiceProvider).sugerirLook(referenciaId);
});
