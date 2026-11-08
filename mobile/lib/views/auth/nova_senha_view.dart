import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import 'widgets/caixa_de_mensagem.dart';

/// Definir a senha nova (E9.F2.3). Aparece quando a pessoa abre o link do
/// e-mail de redefinição: o Supabase já abriu uma sessão de recuperação, e o
/// app só mostra o armário depois da senha nova (ou de cancelar, que sai).
class NovaSenhaView extends ConsumerStatefulWidget {
  const NovaSenhaView({super.key});

  @override
  ConsumerState<NovaSenhaView> createState() => _NovaSenhaViewState();
}

class _NovaSenhaViewState extends ConsumerState<NovaSenhaView> {
  final _form = GlobalKey<FormState>();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();

  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_enviando) return;
    setState(() => _erro = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      // Deu certo: a raiz do app troca esta tela pela Casa.
      await ref.read(authServiceProvider).definirNovaSenha(_senha.text);
    } on AuthErro catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (erro) {
      if (mounted) setState(() => _erro = mensagemDeErro(erro));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authServiceProvider).email;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const ScreenHeader(
            titulo: 'Nova senha',
            subtitulo: 'Quase lá!',
            textoSecundario: 'escolha uma senha que você lembre',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (email != null) ...[
                        Text('Conta: $email', style: AppTextStyles.corpo()),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _senha,
                        enabled: !_enviando,
                        obscureText: !_senhaVisivel,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nova senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: 'Pelo menos $senhaMinima caracteres.',
                          suffixIcon: IconButton(
                            tooltip: _senhaVisivel ? 'Esconder senha' : 'Mostrar senha',
                            icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        validator: (valor) {
                          if ((valor ?? '').isEmpty) return 'Informe a nova senha.';
                          if (valor!.length < senhaMinima) return 'Use pelo menos $senhaMinima caracteres.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmacao,
                        enabled: !_enviando,
                        obscureText: !_senhaVisivel,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _salvar(),
                        decoration: const InputDecoration(
                          labelText: 'Confirmar nova senha',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (valor) => (valor ?? '') != _senha.text ? 'As senhas não são iguais.' : null,
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        CaixaDeMensagem(_erro!),
                      ],
                      const SizedBox(height: 20),
                      AppButton(label: 'Salvar nova senha', loading: _enviando, onPressed: _salvar),
                      const SizedBox(height: 8),
                      AppButton(
                        variant: AppButtonVariant.text,
                        label: 'Cancelar e sair',
                        onPressed: _enviando ? null : () => ref.read(authServiceProvider).sair(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
