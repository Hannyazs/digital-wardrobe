import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_config.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_service.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'views/auth/login_view.dart';
import 'views/auth/nova_senha_view.dart';
import 'views/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AuthConfig.supabaseUrl,
    publishableKey: AuthConfig.supabasePublishableKey,
  );
  final auth = SupabaseAuthService(Supabase.instance.client.auth);
  ApiClient.usarConta(auth);
  runApp(AppComConta(auth: auth));
}

/// Raiz do app: um `ProviderScope` novo a cada troca de usuário (E9.F2.1).
///
/// Assim, no logout (ou ao entrar com outra conta) **todo** estado em memória
/// é descartado de uma vez — peças, looks, pastas, preferências, referências,
/// o aviso de peça parada — e também as telas abertas. Não depende de uma
/// lista de providers para invalidar, que ficaria desatualizada a cada
/// provider novo.
class AppComConta extends StatefulWidget {
  const AppComConta({super.key, required this.auth, this.overrides = const []});

  final AuthService auth;

  /// Só para testes: serviços falsos nos escopos criados.
  final List<Override> overrides;

  @override
  State<AppComConta> createState() => _AppComContaState();
}

class _AppComContaState extends State<AppComConta> {
  late String? _usuarioId = widget.auth.usuarioId;
  StreamSubscription<EstadoDaConta>? _assinatura;

  @override
  void initState() {
    super.initState();
    _assinatura = widget.auth.mudancas.listen((estado) {
      // A renovação do token repete o mesmo usuário: nada muda.
      if (estado.usuarioId != _usuarioId && mounted) setState(() => _usuarioId = estado.usuarioId);
    });
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('sessao-${_usuarioId ?? 'nenhuma'}'),
      overrides: [
        authServiceProvider.overrideWithValue(widget.auth),
        ...widget.overrides,
      ],
      child: const GuardaRoupaApp(),
    );
  }
}

class GuardaRoupaApp extends ConsumerWidget {
  const GuardaRoupaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final estado = ref.watch(estadoDaContaProvider).valueOrNull ?? auth.estado;
    final Widget inicio;
    if (estado.usuarioId == null) {
      inicio = const LoginView();
    } else if (estado.recuperandoSenha) {
      // Veio pelo link de "esqueci minha senha": define a nova antes de tudo.
      inicio = const NovaSenhaView();
    } else {
      inicio = const HomeShell();
    }
    return MaterialApp(
      title: 'Guarda-Roupa Virtual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: inicio,
    );
  }
}
