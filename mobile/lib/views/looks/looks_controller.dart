import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/look.dart';
import 'montar_look_controller.dart' show lookServiceProvider;

/// Lista de looks do usuário (E3.F1.3). `autoDispose` para rebuscar sozinho
/// sempre que a tela de "Looks" for recriada (ex: ao voltar da montagem),
/// mesmo padrão de `pecaListProvider` (wardrobe_controller.dart).
final lookListProvider = FutureProvider.autoDispose<List<Look>>((ref) {
  return ref.watch(lookServiceProvider).listarLooks();
});
