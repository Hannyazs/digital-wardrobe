import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sugestao.dart';
import '../looks/looks_controller.dart'
    show historicoMesProvider, historicoProvider, lookListProvider;
import '../looks/montar_look_controller.dart' show lookServiceProvider;
import '../preferences/preferences_controller.dart'
    show preferenciaServiceProvider, preferenciasProvider;
import '../suggestions/suggestions_controller.dart'
    show mensagemDeErroSugestoes, nomeLookSugerido, sugestaoServiceProvider;

/// Estado do card "Look do dia" (E6.F1.2). Descartes, looks salvos e usos
/// vivem só em memória ("Outra sugestão" vale durante a sessão).
class LookDoDiaState {
  const LookDoDiaState({
    this.ocasiao,
    this.resultado,
    this.descartados = const [],
    this.salvos = const {},
    this.usados = const {},
    this.ocupado = false,
  });

  /// Ocasião exibida no seletor; `null` até a primeira resposta (o backend
  /// devolve a salva nas preferências ou "Casual").
  final String? ocasiao;

  /// `null` antes da primeira busca.
  final AsyncValue<LookDoDia>? resultado;
  final List<List<String>> descartados;

  /// `Sugestao.chave` → id do look criado, para "Salvar" e "Usei hoje" não
  /// criarem o mesmo look duas vezes.
  final Map<String, String> salvos;

  /// Chaves dos looks com uso registrado hoje nesta sessão.
  final Set<String> usados;

  /// Salvando ou registrando uso: as ações ficam desabilitadas.
  final bool ocupado;

  Sugestao? get look => resultado?.valueOrNull?.look;

  /// Id do look já salvo para o look atual: salvo nesta sessão ou, desde a
  /// E6.F1.3, um look que já existia em Armário › Looks.
  String? get idSalvo {
    final atual = look;
    if (atual == null) return null;
    return salvos[atual.chave] ?? resultado?.valueOrNull?.lookSalvoId;
  }

  LookDoDiaState copyWith({
    String? ocasiao,
    AsyncValue<LookDoDia>? resultado,
    List<List<String>>? descartados,
    Map<String, String>? salvos,
    Set<String>? usados,
    bool? ocupado,
  }) {
    return LookDoDiaState(
      ocasiao: ocasiao ?? this.ocasiao,
      resultado: resultado ?? this.resultado,
      descartados: descartados ?? this.descartados,
      salvos: salvos ?? this.salvos,
      usados: usados ?? this.usados,
      ocupado: ocupado ?? this.ocupado,
    );
  }
}

class LookDoDiaController extends Notifier<LookDoDiaState> {
  /// Só a resposta mais recente vale (trocas rápidas de ocasião).
  int _pedido = 0;

  @override
  LookDoDiaState build() {
    // Aparece sem o usuário pedir: busca assim que a Casa lê o provider.
    Future.microtask(carregar);
    return const LookDoDiaState();
  }

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  Future<void> carregar() => _buscar(state.ocasiao);

  /// Troca a ocasião: o look muda mesmo que gravar a preferência falhe.
  /// Devolve a mensagem de erro da gravação, ou `null`.
  Future<String?> trocarOcasiao(String ocasiao) async {
    state = state.copyWith(ocasiao: ocasiao);
    final busca = _buscar(ocasiao);
    String? erro;
    try {
      await ref.read(preferenciaServiceProvider).atualizar({'ocasiao_look_do_dia': ocasiao});
      ref.invalidate(preferenciasProvider);
    } catch (_) {
      erro = 'Não foi possível lembrar a ocasião escolhida. O look foi trocado mesmo assim.';
    }
    await busca;
    return erro;
  }

  /// Tira o look atual da sessão e pede o próximo.
  Future<void> outraSugestao() {
    final atual = state.look;
    if (atual != null) {
      state = state.copyWith(descartados: [...state.descartados, atual.pecaIds]);
    }
    return _buscar(state.ocasiao);
  }

  /// "Salvar": cria o look "Look sugerido – dd/mm". Devolve o erro ou `null`.
  Future<String?> salvar() async {
    final look = state.look;
    // Já salvo (nesta sessão ou antes): não cria outro look igual (E6.F1.3).
    if (look == null || state.ocupado || state.idSalvo != null) return null;
    state = state.copyWith(ocupado: true);
    try {
      await _garantirSalvo(look);
      return null;
    } catch (e) {
      return mensagemDeErroSugestoes(e, acao: 'salvar o look');
    } finally {
      state = state.copyWith(ocupado: false);
    }
  }

  /// "Usei hoje": salva (se ainda não salvo nesta sessão) e registra o uso
  /// com a data de hoje. Devolve o erro ou `null`.
  Future<String?> usarHoje() async {
    final look = state.look;
    if (look == null || state.ocupado || state.usados.contains(look.chave)) return null;
    state = state.copyWith(ocupado: true);
    try {
      final id = await _garantirSalvo(look);
      await ref.read(lookServiceProvider).registrarUso(id, _hoje);
      state = state.copyWith(usados: {...state.usados, look.chave});
      ref.invalidate(historicoProvider);
      ref.invalidate(historicoMesProvider);
      return null;
    } catch (e) {
      return mensagemDeErroSugestoes(e, acao: 'registrar o uso');
    } finally {
      state = state.copyWith(ocupado: false);
    }
  }

  Future<String> _garantirSalvo(Sugestao look) async {
    final existente = state.idSalvo;
    if (existente != null) return existente;
    final criado = await ref.read(lookServiceProvider).criarLook(
          nome: nomeLookSugerido(_hoje),
          pecaIds: look.pecaIds,
        );
    state = state.copyWith(salvos: {...state.salvos, look.chave: criado.id});
    ref.invalidate(lookListProvider);
    return criado.id;
  }

  Future<void> _buscar(String? ocasiao) async {
    final pedido = ++_pedido;
    state = state.copyWith(resultado: const AsyncLoading());
    try {
      final resultado = await ref.read(sugestaoServiceProvider).lookDoDia(
            data: _hoje,
            ocasiao: ocasiao,
            descartados: state.descartados,
          );
      if (pedido != _pedido) return;
      state = state.copyWith(ocasiao: resultado.ocasiao, resultado: AsyncData(resultado));
    } catch (e, st) {
      if (pedido != _pedido) return;
      state = state.copyWith(
        resultado: AsyncError(mensagemDeErroSugestoes(e, acao: 'buscar o look do dia'), st),
      );
    }
  }
}

/// Sem `autoDispose`: a Casa fica montada no `HomeShell` e os descartes da
/// sessão precisam sobreviver à troca de aba.
final lookDoDiaProvider = NotifierProvider<LookDoDiaController, LookDoDiaState>(
  LookDoDiaController.new,
);
