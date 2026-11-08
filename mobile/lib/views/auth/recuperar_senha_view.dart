import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import 'widgets/caixa_de_mensagem.dart';

/// "Esqueci minha senha" (E9.F2.3): pede o e-mail e manda o link de
/// redefinição. A resposta é a mesma exista ou não a conta, para não revelar
/// quem tem cadastro.
class RecuperarSenhaView extends ConsumerStatefulWidget {
  const RecuperarSenhaView({super.key, this.emailInicial = ''});

  final String emailInicial;

  @override
  ConsumerState<RecuperarSenhaView> createState() => _RecuperarSenhaViewState();
}

class _RecuperarSenhaViewState extends ConsumerState<RecuperarSenhaView> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInicial);

  bool _enviando = false;
  String? _erro;
  String? _enviadoPara;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    setState(() => _erro = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      await ref.read(authServiceProvider).pedirRedefinicaoDeSenha(_email.text);
      if (mounted) setState(() => _enviadoPara = _email.text.trim());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _enviadoPara == null ? _formulario() : _confirmacao(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informe o e-mail da sua conta. Vamos enviar um link para você criar uma senha nova.',
            style: AppTextStyles.corpo(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            enabled: !_enviando,
            autofocus: widget.emailInicial.isEmpty,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _enviar(),
            decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
            validator: validarEmail,
          ),
          if (_erro != null) ...[
            const SizedBox(height: 16),
            CaixaDeMensagem(_erro!),
          ],
          const SizedBox(height: 20),
          AppButton(label: 'Enviar link', icon: Icons.send_outlined, loading: _enviando, onPressed: _enviar),
        ],
      ),
    );
  }

  Widget _confirmacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaixaDeMensagem(
          'Se houver uma conta com $_enviadoPara, enviamos um link para criar uma senha nova. '
          'Abra o link neste mesmo navegador. Não chegou? Veja a caixa de spam.',
          erro: false,
        ),
        const SizedBox(height: 20),
        AppButton(label: 'Voltar para entrar', onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 8),
        AppButton(
          variant: AppButtonVariant.text,
          label: 'Enviar de novo',
          onPressed: () => setState(() => _enviadoPara = null),
        ),
      ],
    );
  }
}

/// Validação de e-mail compartilhada pelas telas de conta.
String? validarEmail(String? valor) {
  final email = valor?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'E-mail inválido.';
  return null;
}
