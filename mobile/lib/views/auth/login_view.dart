import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import 'recuperar_senha_view.dart';
import 'widgets/caixa_de_mensagem.dart';

/// Entrar ou criar conta com e-mail e senha (E9.F2.1), com o "Esqueci minha
/// senha" (E9.F2.3) e os avisos de sessão expirada (E9.F2.2) e de link de
/// redefinição inválido. Mesmo desenho das outras telas: cabeçalho com degradê
/// menta, campos e botões do tema.
///
/// Depois de entrar, quem troca para a `HomeShell` é a raiz do app (ela
/// observa a sessão); esta tela só chama o [AuthService].
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();

  bool _criandoConta = false;
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  /// Com a confirmação de e-mail ligada no Supabase, o cadastro não entra
  /// direto: mostra este aviso no lugar do formulário.
  String? _emailParaConfirmar;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  void _alternarModo() {
    setState(() {
      _criandoConta = !_criandoConta;
      _erro = null;
      _confirmacao.clear();
    });
  }

  void _esqueciSenha() {
    ref.read(authServiceProvider).descartarAviso();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RecuperarSenhaView(emailInicial: _email.text.trim()),
    ));
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    setState(() => _erro = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _enviando = true);
    final auth = ref.read(authServiceProvider);
    auth.descartarAviso();
    try {
      if (_criandoConta) {
        final resultado = await auth.cadastrar(email: _email.text, senha: _senha.text);
        if (resultado == ResultadoCadastro.confirmarEmail && mounted) {
          setState(() => _emailParaConfirmar = _email.text.trim());
        }
      } else {
        await auth.entrar(email: _email.text, senha: _senha.text);
      }
    } on AuthErro catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (erro) {
      if (mounted) setState(() => _erro = mensagemDeErro(erro));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _validarSenha(String? valor) {
    final senha = valor ?? '';
    if (senha.isEmpty) return 'Informe sua senha.';
    if (_criandoConta && senha.length < senhaMinima) {
      return 'Use pelo menos $senhaMinima caracteres.';
    }
    return null;
  }

  String? _validarConfirmacao(String? valor) {
    if ((valor ?? '') != _senha.text) return 'As senhas não são iguais.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ScreenHeader(
            titulo: 'Guarda-Roupa Virtual',
            subtitulo: _criandoConta ? 'Crie sua conta.' : 'Que bom te ver!',
            textoSecundario: 'seu armário, do seu jeito',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _emailParaConfirmar != null ? _avisoDeConfirmacao() : _formulario(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Por que a pessoa caiu no login: sessão vencida (E9.F2.2) ou link de
  /// redefinição que não funcionou (E9.F2.3).
  Widget? _aviso() {
    final aviso = ref.watch(estadoDaContaProvider).valueOrNull?.aviso;
    if (aviso == null) return null;
    return switch (aviso.tipo) {
      TipoDeAviso.sessaoExpirada => CaixaDeMensagem(aviso.mensagem, erro: false),
      TipoDeAviso.linkInvalido => CaixaDeMensagem(
          aviso.mensagem,
          acao: AppButton(variant: AppButtonVariant.text, label: 'Pedir um link novo', onPressed: _esqueciSenha),
        ),
    };
  }

  Widget _formulario() {
    final aviso = _aviso();
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (aviso != null) ...[aviso, const SizedBox(height: 16)],
            Text(_criandoConta ? 'CRIAR CONTA' : 'ENTRAR', style: AppTextStyles.labelCategoria()),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_enviando,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
              validator: validarEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senha,
              enabled: !_enviando,
              obscureText: !_senhaVisivel,
              autofillHints: [_criandoConta ? AutofillHints.newPassword : AutofillHints.password],
              textInputAction: _criandoConta ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _criandoConta ? null : (_) => _enviar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: _criandoConta ? 'Pelo menos $senhaMinima caracteres.' : null,
                suffixIcon: IconButton(
                  tooltip: _senhaVisivel ? 'Esconder senha' : 'Mostrar senha',
                  icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                ),
              ),
              validator: _validarSenha,
            ),
            if (!_criandoConta)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  variant: AppButtonVariant.text,
                  label: 'Esqueci minha senha',
                  onPressed: _enviando ? null : _esqueciSenha,
                ),
              ),
            if (_criandoConta) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmacao,
                enabled: !_enviando,
                obscureText: !_senhaVisivel,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validarConfirmacao,
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 16),
              CaixaDeMensagem(_erro!),
            ],
            SizedBox(height: _criandoConta ? 20 : 12),
            AppButton(
              label: _criandoConta ? 'Criar conta' : 'Entrar',
              loading: _enviando,
              onPressed: _enviar,
            ),
            const SizedBox(height: 8),
            AppButton(
              variant: AppButtonVariant.text,
              label: _criandoConta ? 'Já tenho conta: entrar' : 'Não tem conta? Criar conta',
              onPressed: _enviando ? null : _alternarModo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avisoDeConfirmacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.sageEscuro),
        const SizedBox(height: 12),
        Text('Confirme seu e-mail', style: AppTextStyles.subtitulo(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Enviamos um link para $_emailParaConfirmar. Abra o link e depois entre com seu e-mail e senha.',
          style: AppTextStyles.corpo(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Voltar para entrar',
          onPressed: () => setState(() {
            _emailParaConfirmar = null;
            _criandoConta = false;
            _senha.clear();
            _confirmacao.clear();
          }),
        ),
      ],
    );
  }
}
