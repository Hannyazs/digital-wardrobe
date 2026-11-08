// Cadastro, login e logout (E9.F2.1). Conta e serviços falsos: nunca toca no
// Supabase nem na API. Ver docs/PBIs/E9-autenticacao/E9-F2-contas-no-app/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException;

import 'package:guarda_roupa_app/core/auth/auth_service.dart';
import 'package:guarda_roupa_app/main.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/peca_parada.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/auth/login_view.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

import 'support/auth_service_falso.dart';
import 'support/look_service_sem_historico.dart';
import 'support/pagina_da_lista.dart';
import 'support/preferencia_service_sem_evitadas.dart';
import 'support/sugestao_service_sem_look_do_dia.dart';

/// Peças paradas "do servidor", por usuário: cada conta vê só as suas.
class _PecaServicePorUsuario extends PecaService with PaginaDaLista {
  _PecaServicePorUsuario(this.auth, this.paradasPorEmail);

  final AuthServiceFalso auth;
  final Map<String, List<PecaParada>> paradasPorEmail;
  final buscasPor = <String?>[];

  @override
  Future<List<Peca>> listarPecas() async => [];

  @override
  Future<List<PecaParada>> listarParadas({required DateTime hoje, int limite = 1}) async {
    buscasPor.add(auth.email);
    return (paradasPorEmail[auth.email] ?? []).take(limite).toList();
  }

  @override
  Future<void> adiarLembrete(String id, {required DateTime hoje}) async {}
}

PecaParada _parada(String id, String categoria) =>
    PecaParada(
      peca: Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: categoria),
      ultimoUso: null,
      diasParada: 120,
    );

Future<void> _abrir(
  WidgetTester tester,
  AuthServiceFalso auth, {
  PecaService? pecas,
  Size tamanho = const Size(800, 1400),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(auth.fechar);
  await tester.pumpWidget(AppComConta(
    auth: auth,
    overrides: [
      pecaServiceProvider.overrideWithValue(pecas ?? _PecaServicePorUsuario(auth, const {})),
      lookServiceProvider.overrideWithValue(LookServiceSemHistorico()),
      sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
      preferenciaServiceProvider.overrideWithValue(PreferenciaServiceSemEvitadas()),
    ],
  ));
  await tester.pumpAndSettle();
}

final _campoEmail = find.widgetWithText(TextFormField, 'E-mail');
final _campoSenha = find.widgetWithText(TextFormField, 'Senha');
final _campoConfirmacao = find.widgetWithText(TextFormField, 'Confirmar senha');
final _botaoEntrar = find.widgetWithText(ElevatedButton, 'Entrar');
final _botaoCriar = find.widgetWithText(ElevatedButton, 'Criar conta');

Future<void> _entrar(WidgetTester tester, String email, String senha) async {
  await tester.enterText(_campoEmail, email);
  await tester.enterText(_campoSenha, senha);
  await tester.tap(_botaoEntrar);
  await tester.pumpAndSettle();
}

Future<void> _sair(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Sair da conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
  await tester.pumpAndSettle();
}

void main() {
  group('sem sessão', () {
    testWidgets('o app abre no login, no visual das outras telas', (tester) async {
      await _abrir(tester, AuthServiceFalso());

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Guarda-Roupa Virtual'), findsOneWidget);
      expect(find.text('Que bom te ver!'), findsOneWidget);
      expect(_campoEmail, findsOneWidget);
      expect(_campoSenha, findsOneWidget);
      expect(_botaoEntrar, findsOneWidget);
      expect(find.text('Não tem conta? Criar conta'), findsOneWidget);
    });

    testWidgets('campos vazios ou e-mail inválido não chamam o servidor', (tester) async {
      final auth = AuthServiceFalso();
      await _abrir(tester, auth);

      await tester.tap(_botaoEntrar);
      await tester.pumpAndSettle();
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      await tester.enterText(_campoEmail, 'sem-arroba');
      await tester.tap(_botaoEntrar);
      await tester.pumpAndSettle();
      expect(find.text('E-mail inválido.'), findsOneWidget);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  group('login', () {
    testWidgets('credenciais corretas abrem a Casa', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await auth.sair();
      await _abrir(tester, auth);

      await _entrar(tester, 'ana@exemplo.com', 'senha123');

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Olá!'), findsOneWidget);
      expect(auth.usuarioId, AuthServiceFalso.idDe('ana@exemplo.com'));
    });

    testWidgets('mostra carregamento no botão enquanto entra', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await auth.sair();
      await _abrir(tester, auth);

      await tester.enterText(_campoEmail, 'ana@exemplo.com');
      await tester.enterText(_campoSenha, 'senha123');
      await tester.tap(_botaoEntrar);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('credenciais erradas: mensagem clara e a tela continua usável', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await auth.sair();
      await _abrir(tester, auth);

      await _entrar(tester, 'ana@exemplo.com', 'errada');
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.byType(LoginView), findsOneWidget);

      // Corrige e entra, sem recarregar nada.
      await tester.enterText(_campoSenha, 'senha123');
      await tester.tap(_botaoEntrar);
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('sem internet: mensagem de conexão, sem travar', (tester) async {
      await _abrir(tester, AuthServiceFalso(erroDeRede: true));

      await _entrar(tester, 'ana@exemplo.com', 'senha123');
      expect(
        find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
        findsOneWidget,
      );
      expect(tester.widget<ElevatedButton>(_botaoEntrar).onPressed, isNotNull);
    });
  });

  group('cadastro', () {
    Future<void> irParaCadastro(WidgetTester tester) async {
      await tester.tap(find.text('Não tem conta? Criar conta'));
      await tester.pumpAndSettle();
    }

    testWidgets('cria a conta e entra direto (confirmação de e-mail desligada)', (tester) async {
      final auth = AuthServiceFalso();
      await _abrir(tester, auth);
      await irParaCadastro(tester);

      expect(find.text('Crie sua conta.'), findsOneWidget);
      await tester.enterText(_campoEmail, 'bia@exemplo.com');
      await tester.enterText(_campoSenha, 'segredo1');
      await tester.enterText(_campoConfirmacao, 'segredo1');
      await tester.tap(_botaoCriar);
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(auth.usuarioId, AuthServiceFalso.idDe('bia@exemplo.com'));
    });

    testWidgets('com confirmação de e-mail ligada, mostra o aviso e não entra', (tester) async {
      await _abrir(tester, AuthServiceFalso(exigeConfirmacao: true));
      await irParaCadastro(tester);

      await tester.enterText(_campoEmail, 'bia@exemplo.com');
      await tester.enterText(_campoSenha, 'segredo1');
      await tester.enterText(_campoConfirmacao, 'segredo1');
      await tester.tap(_botaoCriar);
      await tester.pumpAndSettle();

      expect(find.text('Confirme seu e-mail'), findsOneWidget);
      expect(find.textContaining('bia@exemplo.com'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      await tester.tap(find.text('Voltar para entrar'));
      await tester.pumpAndSettle();
      expect(_botaoEntrar, findsOneWidget);
    });

    testWidgets('senha curta e confirmação diferente são avisadas antes de enviar', (tester) async {
      final auth = AuthServiceFalso();
      await _abrir(tester, auth);
      await irParaCadastro(tester);

      await tester.enterText(_campoEmail, 'bia@exemplo.com');
      await tester.enterText(_campoSenha, '123');
      await tester.enterText(_campoConfirmacao, '124');
      await tester.tap(_botaoCriar);
      await tester.pumpAndSettle();

      expect(find.text('Use pelo menos 6 caracteres.'), findsOneWidget);
      expect(find.text('As senhas não são iguais.'), findsOneWidget);
      expect(auth.usuarioId, isNull);
    });

    testWidgets('e-mail já cadastrado: mensagem clara', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await auth.sair();
      await _abrir(tester, auth);
      await irParaCadastro(tester);

      await tester.enterText(_campoEmail, 'ana@exemplo.com');
      await tester.enterText(_campoSenha, 'segredo1');
      await tester.enterText(_campoConfirmacao, 'segredo1');
      await tester.tap(_botaoCriar);
      await tester.pumpAndSettle();

      expect(find.text('Já existe uma conta com este e-mail. Tente entrar.'), findsOneWidget);
    });

    testWidgets('dá para voltar do cadastro para o login', (tester) async {
      await _abrir(tester, AuthServiceFalso());
      await irParaCadastro(tester);
      expect(_campoConfirmacao, findsOneWidget);

      await tester.tap(find.text('Já tenho conta: entrar'));
      await tester.pumpAndSettle();
      expect(_campoConfirmacao, findsNothing);
      expect(_botaoEntrar, findsOneWidget);
    });
  });

  group('sessão e logout', () {
    testWidgets('com sessão guardada, o app reabre direto na Casa', (tester) async {
      await _abrir(tester, AuthServiceFalso(logadoComo: 'ana@exemplo.com'));

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(LoginView), findsNothing);
    });

    testWidgets('sair pede confirmação; cancelar mantém a sessão', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await _abrir(tester, auth);

      await tester.tap(find.byTooltip('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(find.textContaining('ana@exemplo.com'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(auth.saidas, 0);
    });

    testWidgets('sair volta ao login, com o formulário limpo', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await _abrir(tester, auth);

      await _sair(tester);
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(auth.saidas, 1);
      // O formulário começa limpo.
      expect(tester.widget<TextFormField>(_campoEmail).controller!.text, isEmpty);
    });

    testWidgets('depois do logout, nada da conta anterior fica em memória', (tester) async {
      final auth = AuthServiceFalso(
        logadoComo: 'ana@exemplo.com',
        outrasContas: {'bia@exemplo.com': 'senha456'},
      );
      final pecas = _PecaServicePorUsuario(auth, {
        'ana@exemplo.com': [_parada('vestido-da-ana', 'Vestidos')],
        'bia@exemplo.com': [_parada('calca-da-bia', 'Calças')],
      });
      await _abrir(tester, auth, pecas: pecas);

      // Ana entra e vê o aviso da peça parada dela.
      expect(find.text('Peça parada'), findsOneWidget);
      expect(find.textContaining('Vestidos'), findsWidgets);
      await tester.tap(find.text('Lembrar depois'));
      await tester.pumpAndSettle();

      await _sair(tester);
      await _entrar(tester, 'bia@exemplo.com', 'senha456');

      // Bia vê o aviso dela (o "já mostrado" da Ana não vale para ela) e nada da Ana.
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Peça parada'), findsOneWidget);
      expect(find.textContaining('Calças'), findsWidgets);
      expect(find.textContaining('Vestidos'), findsNothing);
      expect(pecas.buscasPor, ['ana@exemplo.com', 'bia@exemplo.com']);
    });
  });

  group('sessão expirada (E9.F2.2)', () {
    testWidgets('a API recusa o token: volta ao login com o aviso', (tester) async {
      final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
      await _abrir(tester, auth);
      expect(find.byType(HomeShell), findsOneWidget);

      // O que o AuthInterceptor faz quando o token não renova.
      await auth.encerrarSessaoExpirada();
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);

      // Entrar de novo some com o aviso.
      await _entrar(tester, 'ana@exemplo.com', 'senha123');
      expect(find.byType(HomeShell), findsOneWidget);
      expect(auth.estado.aviso, isNull);
    });

    testWidgets('sair de propósito não mostra aviso de sessão expirada', (tester) async {
      await _abrir(tester, AuthServiceFalso(logadoComo: 'ana@exemplo.com'));
      await _sair(tester);
      expect(find.text('Sua sessão expirou. Entre de novo.'), findsNothing);
    });
  });

  group('esqueci minha senha (E9.F2.3)', () {
    testWidgets('o link fica no login (não no cadastro) e leva o e-mail digitado', (tester) async {
      await _abrir(tester, AuthServiceFalso());
      expect(find.text('Esqueci minha senha'), findsOneWidget);

      await tester.tap(find.text('Não tem conta? Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Esqueci minha senha'), findsNothing);
      await tester.tap(find.text('Já tenho conta: entrar'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoEmail, 'ana@exemplo.com');
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Esqueci minha senha'), findsOneWidget);
      expect(tester.widget<TextFormField>(_campoEmail).controller!.text, 'ana@exemplo.com');
    });

    testWidgets('pedir o link confirma sem revelar se a conta existe', (tester) async {
      final auth = AuthServiceFalso();
      await _abrir(tester, auth);
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoEmail, 'ninguem@exemplo.com');
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();

      expect(auth.pedidosDeRedefinicao, ['ninguem@exemplo.com']);
      expect(find.textContaining('Se houver uma conta com ninguem@exemplo.com'), findsOneWidget);

      await tester.tap(find.text('Voltar para entrar'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
      expect(_botaoEntrar, findsOneWidget);
    });

    testWidgets('e-mail inválido não envia; erro de rede aparece sem travar', (tester) async {
      final auth = AuthServiceFalso(erroDeRede: true);
      await _abrir(tester, auth);
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      await tester.enterText(_campoEmail, 'sem-arroba');
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail inválido.'), findsOneWidget);

      await tester.enterText(_campoEmail, 'ana@exemplo.com');
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Enviar link')).onPressed, isNotNull);
    });

    testWidgets('abrir o link leva à tela de nova senha; salvar abre a Casa e o login vale', (tester) async {
      final auth = AuthServiceFalso(outrasContas: {'ana@exemplo.com': 'antiga1'});
      await _abrir(tester, auth);

      auth.abrirLinkDeRecuperacao('ana@exemplo.com');
      await tester.pumpAndSettle();

      expect(find.text('Quase lá!'), findsOneWidget); // cabeçalho da tela de nova senha
      expect(find.text('Conta: ana@exemplo.com'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nova senha'), 'nova123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar nova senha'), 'nova123');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(auth.senhaDe('ana@exemplo.com'), 'nova123');

      // Sai e entra com a senha nova.
      await _sair(tester);
      await _entrar(tester, 'ana@exemplo.com', 'nova123');
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('nova senha: curta, diferente da confirmação ou igual à antiga', (tester) async {
      final auth = AuthServiceFalso(outrasContas: {'ana@exemplo.com': 'antiga1'});
      await _abrir(tester, auth);
      auth.abrirLinkDeRecuperacao('ana@exemplo.com');
      await tester.pumpAndSettle();

      final nova = find.widgetWithText(TextFormField, 'Nova senha');
      final confirmar = find.widgetWithText(TextFormField, 'Confirmar nova senha');
      await tester.enterText(nova, '123');
      await tester.enterText(confirmar, '456');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(find.text('Use pelo menos 6 caracteres.'), findsOneWidget);
      expect(find.text('As senhas não são iguais.'), findsOneWidget);

      await tester.enterText(nova, 'antiga1');
      await tester.enterText(confirmar, 'antiga1');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(find.text('A nova senha precisa ser diferente da atual.'), findsOneWidget);
      expect(find.text('Quase lá!'), findsOneWidget);
    });

    testWidgets('"Cancelar e sair" na nova senha volta ao login', (tester) async {
      final auth = AuthServiceFalso(outrasContas: {'ana@exemplo.com': 'antiga1'});
      await _abrir(tester, auth);
      auth.abrirLinkDeRecuperacao('ana@exemplo.com');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar e sair'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
      expect(auth.senhaDe('ana@exemplo.com'), 'antiga1');
    });

    testWidgets('link vencido: aviso claro com opção de pedir outro', (tester) async {
      final auth = AuthServiceFalso();
      await _abrir(tester, auth);

      auth.abrirLinkInvalido('O link de redefinição expirou ou já foi usado. Peça um link novo abaixo.');
      await tester.pumpAndSettle();
      expect(find.text('O link de redefinição expirou ou já foi usado. Peça um link novo abaixo.'), findsOneWidget);

      await tester.tap(find.text('Pedir um link novo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Esqueci minha senha'), findsOneWidget);
      expect(auth.estado.aviso, isNull);
    });
  });

  group('mensagens de erro do Supabase', () {
    test('link de redefinição: vencido, outro navegador ou erro que não é do link', () {
      expect(
        mensagemDeLinkInvalido(const AuthException('Email link is invalid or has expired',
            statusCode: 'otp_expired', code: 'access_denied')),
        'O link de redefinição expirou ou já foi usado. Peça um link novo abaixo.',
      );
      expect(
        mensagemDeLinkInvalido(const AuthException('Code verifier could not be found in local storage.')),
        startsWith('Não deu para usar este link. Abra-o no mesmo navegador'),
      );
      expect(mensagemDeLinkInvalido(AuthRetryableFetchException()), isNull);
      expect(mensagemDeLinkInvalido(Exception('qualquer')), isNull);
    });

    test('senha igual à anterior', () {
      expect(mensagemDeErro(const AuthException('x', statusCode: '422', code: 'same_password')),
          'A nova senha precisa ser diferente da atual.');
    });

    test('códigos conhecidos viram mensagens em português', () {
      expect(mensagemDeErro(const AuthException('x', statusCode: '400', code: 'invalid_credentials')),
          'E-mail ou senha incorretos.');
      expect(mensagemDeErro(const AuthException('x', statusCode: '422', code: 'user_already_exists')),
          'Já existe uma conta com este e-mail. Tente entrar.');
      expect(mensagemDeErro(const AuthException('x', statusCode: '422', code: 'weak_password')),
          'Senha fraca. Use pelo menos 6 caracteres.');
      expect(mensagemDeErro(const AuthException('x', statusCode: '429', code: 'over_request_rate_limit')),
          'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.');
    });

    test('falha de rede e erro desconhecido não mostram detalhes técnicos', () {
      const semConexao = 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      expect(mensagemDeErro(AuthRetryableFetchException()), semConexao);
      expect(mensagemDeErro(Exception('socket')), semConexao);
      expect(mensagemDeErro(const AuthException('boom', statusCode: '500', code: 'unexpected_failure')),
          'Não foi possível concluir agora. Tente de novo.');
    });
  });
}
