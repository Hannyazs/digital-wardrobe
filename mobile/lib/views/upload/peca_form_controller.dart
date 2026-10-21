import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/envio_state.dart';
import 'upload_controller.dart' show pecaServiceProvider;

/// Estado e envio do formulário de metadados (E1.F2.1) — reaproveita
/// [EnvioState] (core/state/envio_state.dart), o mesmo formato já usado
/// pelo envio da foto (E1.F1.3). O `imagemUrl` do [EnvioSucesso] aqui é
/// simplesmente o mesmo recebido na criação, não um novo dado do backend.
class PecaFormController extends Notifier<EnvioState> {
  @override
  EnvioState build() => const EnvioIdle();

  /// Cria uma peça nova, ou edita uma existente quando [pecaId] é passado
  /// (E1.F3.1) — a imagem nunca muda na edição, só os metadados.
  Future<void> enviar({
    String? pecaId,
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    state = const Enviando();
    try {
      if (pecaId == null) {
        await ref.read(pecaServiceProvider).criarPeca(
              imagemUrl: imagemUrl,
              categoria: categoria,
              subcategoria: subcategoria,
              corPrincipal: corPrincipal,
              tonalidadeCor: tonalidadeCor,
              estacao: estacao,
              estilo: estilo,
              modelagem: modelagem,
              ocasioes: ocasioes,
            );
      } else {
        await ref.read(pecaServiceProvider).atualizarPeca(
              id: pecaId,
              categoria: categoria,
              subcategoria: subcategoria,
              corPrincipal: corPrincipal,
              tonalidadeCor: tonalidadeCor,
              estacao: estacao,
              estilo: estilo,
              modelagem: modelagem,
              ocasioes: ocasioes,
            );
      }
      state = EnvioSucesso(imagemUrl);
    } on DioException catch (e) {
      state = EnvioErro(_mensagemDeErro(e));
    } catch (_) {
      state = const EnvioErro('Não foi possível salvar a peça. Tente novamente.');
    }
  }

  void reset() {
    state = const EnvioIdle();
  }

  String _mensagemDeErro(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível salvar a peça.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A operação demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível salvar a peça. Tente novamente.';
    }
  }
}

final pecaFormProvider = NotifierProvider<PecaFormController, EnvioState>(
  PecaFormController.new,
);
