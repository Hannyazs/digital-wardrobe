import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

/// O serviço de conta. Não tem implementação padrão: o `main.dart` injeta o
/// [SupabaseAuthService] e os testes, um falso.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('authServiceProvider precisa ser sobrescrito'),
);

/// Estado da conta (usuário, recuperação de senha, aviso para o login).
/// Começa com o estado atual e acompanha as mudanças.
final estadoDaContaProvider = StreamProvider<EstadoDaConta>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  yield auth.estado;
  yield* auth.mudancas;
});
