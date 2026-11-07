import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/peca_parada.dart';
import '../upload/upload_controller.dart' show pecaServiceProvider;

/// A peça mais parada do armário, para o aviso na abertura do app (E13.F1.2);
/// `null` se não há nenhuma. Qualquer falha (rede, 401) também vira `null`: o
/// aviso é um extra e nunca atrapalha a abertura do app.
final pecaParadaProvider = FutureProvider.autoDispose<PecaParada?>((ref) async {
  try {
    final paradas = await ref.read(pecaServiceProvider).listarParadas(hoje: DateTime.now(), limite: 1);
    return paradas.isEmpty ? null : paradas.first;
  } catch (_) {
    return null;
  }
});

/// Se o aviso de peça parada já foi mostrado nesta sessão. Sem `autoDispose`
/// de propósito: vale até o app ser fechado, mesmo que a `HomeShell` seja
/// recriada (ex.: depois de cadastrar uma peça).
final avisoPecaParadaMostradoProvider = StateProvider<bool>((ref) => false);
