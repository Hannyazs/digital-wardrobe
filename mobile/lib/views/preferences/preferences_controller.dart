import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/evitadas.dart';
import '../../models/preferencia.dart';
import '../../services/preferencia_service.dart';

final preferenciaServiceProvider = Provider<PreferenciaService>((ref) => PreferenciaService());

/// Preferências de estilo do usuário (E4.F1.2). `autoDispose`: rebusca ao
/// reabrir a tela. Cada mudança é salva na hora (sem botão "Salvar") com
/// atualização otimista — ver [PreferenciasController.atualizar].
final preferenciasProvider =
    AsyncNotifierProvider.autoDispose<PreferenciasController, Preferencia>(
  PreferenciasController.new,
);

/// Peças e pares de peças evitados (E4.F4.2/E4.F4.3). Separado de
/// [preferenciasProvider] porque vem de outro endpoint e é lido também fora da
/// tela de preferências (detalhe da peça). Invalidar depois de marcar,
/// desmarcar ou excluir uma peça.
final evitadasProvider = FutureProvider.autoDispose<Evitadas>((ref) {
  return ref.watch(preferenciaServiceProvider).listarEvitadas();
});

class PreferenciasController extends AutoDisposeAsyncNotifier<Preferencia> {
  /// Último estado confirmado pelo servidor: para onde voltar se um `PATCH` falhar.
  Preferencia _confirmado = const Preferencia();

  /// Mudanças enviadas e ainda sem resposta.
  int _pendentes = 0;

  /// Fila: as chamadas vão ao servidor uma por vez, na ordem em que o usuário
  /// as fez, para uma resposta antiga não sobrescrever uma mudança mais nova.
  Future<void> _fila = Future<void>.value();

  @override
  Future<Preferencia> build() async {
    final preferencia = await ref.read(preferenciaServiceProvider).obter();
    _confirmado = preferencia;
    return preferencia;
  }

  /// Aplica [otimista] na tela na hora e envia [campos] (`PATCH`). Em falha,
  /// volta ao último estado confirmado e devolve uma mensagem para a tela
  /// mostrar; em sucesso devolve `null`.
  Future<String?> atualizar(
    Map<String, dynamic> campos,
    Preferencia Function(Preferencia atual) otimista,
  ) {
    final atual = state.valueOrNull;
    if (atual == null) return Future.value(null); // ainda carregando: nada a alterar
    state = AsyncData(otimista(atual));
    _pendentes++;

    final resultado = _fila.then<String?>((_) async {
      try {
        final confirmado = await ref.read(preferenciaServiceProvider).atualizar(campos);
        _confirmado = confirmado;
        if (_pendentes == 1) state = AsyncData(confirmado);
        return null;
      } catch (error) {
        state = AsyncData(_confirmado);
        return mensagemDeErroAoSalvar(error);
      } finally {
        _pendentes--;
      }
    });
    _fila = resultado;
    return resultado;
  }
}

String mensagemDeErroAoSalvar(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível salvar a preferência.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Sem conexão com o servidor. Não foi possível salvar a preferência.';
    }
    if (error.response?.statusCode == 422) {
      return 'Esse valor não é aceito. Não foi possível salvar a preferência.';
    }
  }
  return 'Não foi possível salvar a preferência. Tente novamente.';
}

String mensagemDeErroAoCarregar(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível carregar suas preferências.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível carregar suas preferências. Tente novamente.';
    }
  }
  return 'Não foi possível carregar suas preferências. Tente novamente.';
}

/// Marca ou desmarca [opcao] em [atual] (seções de chips: sobreposições,
/// estilos). A lista devolvida segue a ordem de [ordem] (a lista fixa) e, ao
/// fim, os valores fora dela, na ordem em que já estavam — nunca a ordem dos
/// toques, para o mesmo conjunto gravar sempre igual.
List<String> alternarNaLista(List<String> atual, String opcao, List<String> ordem) {
  final marcadas = {...atual};
  marcadas.contains(opcao) ? marcadas.remove(opcao) : marcadas.add(opcao);
  return [
    ...ordem.where(marcadas.contains),
    // Valores fora da lista fixa só existem se já estavam salvos (a seção só
    // exibe a lista fixa e o que está em `atual`), então só podem sair.
    ...atual.where((valor) => marcadas.contains(valor) && !ordem.contains(valor)),
  ];
}

/// Mensagem para falhas ao marcar/desmarcar itens evitados; [acao] completa
/// a frase (ex.: "atualizar a peça").
String mensagemDeErroEvitadas(Object error, String acao) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Sessão expirada ou inválida. Não foi possível $acao.';
    if (status == 404) return 'Peça não encontrada. Ela pode ter sido excluída.';
    if (error.type == DioExceptionType.connectionError) {
      return 'Sem conexão com o servidor. Não foi possível $acao.';
    }
  }
  return 'Não foi possível $acao. Tente novamente.';
}

