import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/look.dart';
import '../../services/look_service.dart';

/// Ids das peças selecionadas na grade de montagem (E3.F1.2). `autoDispose`
/// para começar vazio sempre que a tela de montagem é reaberta.
final selecaoLookProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

final lookServiceProvider = Provider<LookService>((ref) => LookService());

/// Estado do envio de `POST /looks`. Não reaproveita o `EnvioState`
/// compartilhado (core/state/envio_state.dart): aquele exige um `imagemUrl`
/// obrigatório no sucesso, que não existe para um look (não é uma imagem
/// única) — forçar um valor fake seria pior que este sealed class próprio.
sealed class MontagemLookState {
  const MontagemLookState();
}

class MontagemIdle extends MontagemLookState {
  const MontagemIdle();
}

class MontagemEnviando extends MontagemLookState {
  const MontagemEnviando();
}

class MontagemSucesso extends MontagemLookState {
  const MontagemSucesso(this.look);

  final Look look;
}

class MontagemErro extends MontagemLookState {
  const MontagemErro(this.mensagem);

  final String mensagem;
}

class MontagemLookController extends Notifier<MontagemLookState> {
  @override
  MontagemLookState build() => const MontagemIdle();

  Future<void> salvar({required String nome, required Set<String> pecaIds}) async {
    state = const MontagemEnviando();
    try {
      final look = await ref
          .read(lookServiceProvider)
          .criarLook(nome: nome, pecaIds: pecaIds.toList());
      state = MontagemSucesso(look);
    } on DioException catch (e) {
      state = MontagemErro(_mensagemDeErro(e));
    } catch (_) {
      state = const MontagemErro('Não foi possível salvar o look. Tente novamente.');
    }
  }

  void reset() {
    state = const MontagemIdle();
  }

  String _mensagemDeErro(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível salvar o look.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A operação demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível salvar o look. Tente novamente.';
    }
  }
}

final montagemLookProvider = NotifierProvider<MontagemLookController, MontagemLookState>(
  MontagemLookController.new,
);
