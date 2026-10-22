import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sugestao.dart';
import '../../services/sugestao_service.dart';
import '../looks/montar_look_controller.dart' show lookServiceProvider;

final sugestaoServiceProvider = Provider<SugestaoService>((ref) => SugestaoService());

/// "Look sugerido – dd/mm" (nome padrão aprovado; editável depois, E5.F3.1).
String nomeLookSugerido(DateTime dia) {
  final dd = dia.day.toString().padLeft(2, '0');
  final mm = dia.month.toString().padLeft(2, '0');
  return 'Look sugerido – $dd/$mm';
}

class SugestoesState {
  const SugestoesState({
    this.filtros = const FiltroSugestoes(),
    this.pagina = 1,
    this.resultado,
    this.descartados = const [],
    this.salvando = const {},
  });

  final FiltroSugestoes filtros;
  final int pagina;

  /// `null` até o primeiro "Sugerir looks".
  final AsyncValue<PaginaSugestoes>? resultado;

  /// Looks descartados nesta sessão (ids das peças). Vivem só em memória:
  /// somem ao fechar o app, como aprovado ("descartar só durante a sessão").
  final List<List<String>> descartados;

  /// Chaves (`Sugestao.chave`) dos looks em gravação.
  final Set<String> salvando;

  SugestoesState copyWith({
    FiltroSugestoes? filtros,
    int? pagina,
    AsyncValue<PaginaSugestoes>? resultado,
    List<List<String>>? descartados,
    Set<String>? salvando,
  }) {
    return SugestoesState(
      filtros: filtros ?? this.filtros,
      pagina: pagina ?? this.pagina,
      resultado: resultado ?? this.resultado,
      descartados: descartados ?? this.descartados,
      salvando: salvando ?? this.salvando,
    );
  }
}

/// Uma instância por peça-base (E5.F2.2): `null` é a aba "Sugestões"; um id é
/// a tela empilhada a partir do detalhe da peça, que não compartilha filtros,
/// páginas nem descartes com a aba.
class SugestoesController extends AutoDisposeFamilyNotifier<SugestoesState, String?> {
  @override
  SugestoesState build(String? pecaBaseId) {
    // A aba vive o app inteiro (descartes da sessão sobrevivem à troca de aba);
    // a tela empilhada recomeça do zero a cada vez que é aberta.
    if (pecaBaseId == null) ref.keepAlive();
    return const SugestoesState();
  }

  void alterarFiltros(FiltroSugestoes filtros) {
    state = state.copyWith(filtros: filtros);
  }

  /// Tira o filtro em conflito com a peça-base e refaz a busca do início.
  /// `campo` vem de `ConflitoSugestao.filtro` (`ocasiao`, `estilo`, `estacao`, `cor`).
  Future<void> removerFiltro(String campo) {
    final f = state.filtros;
    state = state.copyWith(
      filtros: FiltroSugestoes(
        ocasiao: campo == 'ocasiao' ? null : f.ocasiao,
        estilo: campo == 'estilo' ? null : f.estilo,
        estacao: campo == 'estacao' ? null : f.estacao,
        cor: campo == 'cor' ? null : f.cor,
      ),
    );
    return sugerir();
  }

  Future<void> sugerir() => _buscar(1);

  Future<void> verOutras() => _buscar(state.pagina + 1);

  Future<void> tentarNovamente() => _buscar(state.pagina);

  /// Tira o look da sessão e recarrega a página: o backend completa com o
  /// próximo look, para a página continuar com 3 enquanto houver opções.
  Future<void> descartar(Sugestao sugestao) {
    state = state.copyWith(descartados: [...state.descartados, sugestao.pecaIds]);
    return _buscar(state.pagina);
  }

  /// Salva como look (`POST /looks`). Devolve `null` em sucesso ou a mensagem de erro.
  ///
  /// Em sucesso recarrega a página, como em [descartar]: o backend não sugere
  /// looks já salvos (E5.F1.3), então o card sai e a página é completada.
  /// Sem recarregar, "Ver outras" pularia um look (a página 2 é recalculada
  /// sem o look salvo).
  Future<String?> salvar(Sugestao sugestao, DateTime hoje) async {
    state = state.copyWith(salvando: {...state.salvando, sugestao.chave});
    try {
      await ref.read(lookServiceProvider).criarLook(
            nome: nomeLookSugerido(hoje),
            pecaIds: sugestao.pecaIds,
          );
    } catch (e) {
      return mensagemDeErroSugestoes(e, acao: 'salvar o look');
    } finally {
      state = state.copyWith(salvando: {...state.salvando}..remove(sugestao.chave));
    }
    await _buscar(state.pagina);
    return null;
  }

  Future<void> _buscar(int pagina) async {
    state = state.copyWith(pagina: pagina, resultado: const AsyncLoading());
    try {
      final resultado = await ref.read(sugestaoServiceProvider).sugerir(
            filtros: state.filtros,
            pecaBaseId: arg,
            pagina: pagina,
            descartados: state.descartados,
          );
      state = state.copyWith(resultado: AsyncData(resultado));
    } catch (e, st) {
      state = state.copyWith(
        resultado: AsyncError(mensagemDeErroSugestoes(e, acao: 'buscar sugestões'), st),
      );
    }
  }
}

/// `sugestoesProvider(null)` = aba (mantida viva por `keepAlive`);
/// `sugestoesProvider(pecaId)` = tela empilhada, descartada ao sair dela.
final sugestoesProvider =
    NotifierProvider.autoDispose.family<SugestoesController, SugestoesState, String?>(
  SugestoesController.new,
);

String mensagemDeErroSugestoes(Object erro, {required String acao}) {
  if (erro is DioException) {
    if (erro.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível $acao.';
    }
    switch (erro.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A operação demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        break;
    }
  }
  return 'Não foi possível $acao. Tente novamente.';
}
