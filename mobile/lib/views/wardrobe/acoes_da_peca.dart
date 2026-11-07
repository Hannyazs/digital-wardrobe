import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/peca.dart';
import '../../services/peca_service.dart';
import '../preferences/preferences_controller.dart' show evitadasProvider;
import '../upload/upload_controller.dart' show pecaServiceProvider;
import 'wardrobe_controller.dart';
import '../looks/pastas_controller.dart' show invalidarLooks;

/// Confirma e exclui a [peca] (E1.F3.1), de forma definitiva. Usada pelo
/// detalhe da peça e pelo "Doar" do aviso de peça parada (E13.F1.3).
///
/// Se a peça está em looks, o backend responde 409 e o usuário confirma de
/// novo que ela saia desses looks. Erros viram um aviso na parte de baixo da
/// tela. Devolve `true` só se a peça foi excluída; [aoMudarOcupado] avisa
/// quando a chamada à API começa e termina (para o indicador de carregamento).
Future<bool> confirmarEExcluirPeca(
  BuildContext context,
  WidgetRef ref,
  Peca peca, {
  String titulo = 'Excluir peça?',
  String mensagem = 'Essa ação não pode ser desfeita.',
  String confirmar = 'Excluir',
  ValueChanged<bool>? aoMudarOcupado,
}) async {
  final confirmou = await _perguntar(
    context,
    titulo: titulo,
    mensagem: mensagem,
    confirmar: confirmar,
  );
  if (confirmou != true || !context.mounted) return false;
  return _excluir(context, ref, peca, removerDosLooks: false, aoMudarOcupado: aoMudarOcupado);
}

Future<bool?> _perguntar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String confirmar,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
}

Future<bool> _excluir(
  BuildContext context,
  WidgetRef ref,
  Peca peca, {
  required bool removerDosLooks,
  ValueChanged<bool>? aoMudarOcupado,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  aoMudarOcupado?.call(true);
  try {
    await ref.read(pecaServiceProvider).excluirPeca(peca.id, removerDosLooks: removerDosLooks);
    invalidarPecas(ref);
    // Os looks que usavam a peça mudaram.
    invalidarLooks(ref);
    // O backend apaga em cascata a peça das evitadas (E4.F4.1).
    ref.invalidate(evitadasProvider);
    return true;
  } on DioException catch (e) {
    aoMudarOcupado?.call(false);
    final emLooks = PecaService.quantidadeDeLooksDoConflito(e);
    if (emLooks != null && context.mounted) {
      return _confirmarRemocaoDosLooks(context, ref, peca, emLooks, aoMudarOcupado);
    }
    messenger.showSnackBar(SnackBar(content: Text(_mensagemDeErro(e))));
    return false;
  } catch (_) {
    aoMudarOcupado?.call(false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível excluir a peça. Tente novamente.')),
    );
    return false;
  }
}

/// A peça está em looks salvos: só segue depois de o usuário aceitar que
/// ela saia deles (os looks continuam existindo, sem essa peça).
Future<bool> _confirmarRemocaoDosLooks(
  BuildContext context,
  WidgetRef ref,
  Peca peca,
  int quantidade,
  ValueChanged<bool>? aoMudarOcupado,
) async {
  final confirmou = await _perguntar(
    context,
    titulo: 'Peça usada em looks',
    mensagem: quantidade == 1
        ? 'Esta peça está em 1 look. Ao excluir, ela será removida desse look, '
            'que continuará salvo sem ela. Essa ação não pode ser desfeita.'
        : 'Esta peça está em $quantidade looks. Ao excluir, ela será removida '
            'desses looks, que continuarão salvos sem ela. Essa ação não pode ser desfeita.',
    confirmar: 'Excluir mesmo assim',
  );
  if (confirmou != true || !context.mounted) return false;
  return _excluir(context, ref, peca, removerDosLooks: true, aoMudarOcupado: aoMudarOcupado);
}

String _mensagemDeErro(DioException e) {
  if (e.response?.statusCode == 401) {
    return 'Sessão expirada ou inválida. Não foi possível excluir a peça.';
  }
  return 'Não foi possível excluir a peça. Tente novamente.';
}
