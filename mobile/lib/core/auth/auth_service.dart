import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro de autenticação com a mensagem pronta para a tela, em português.
class AuthErro implements Exception {
  const AuthErro(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'AuthErro($mensagem)';
}

/// Resultado do cadastro: com a confirmação de e-mail desligada no Supabase a
/// pessoa já entra; ligada, ela precisa confirmar o e-mail antes (E9.F2.1).
enum ResultadoCadastro { entrou, confirmarEmail }

/// Tipo do aviso que a tela de login mostra ao abrir.
enum TipoDeAviso {
  /// A sessão venceu e não renovou (E9.F2.2).
  sessaoExpirada,

  /// O link de redefinição de senha expirou ou é inválido (E9.F2.3).
  linkInvalido,
}

/// Aviso para a tela de login, explicando por que a pessoa está lá.
class AvisoDaConta {
  const AvisoDaConta(this.tipo, this.mensagem);

  final TipoDeAviso tipo;
  final String mensagem;
}

/// Foto do estado da conta, emitida a cada mudança.
class EstadoDaConta {
  const EstadoDaConta({this.usuarioId, this.recuperandoSenha = false, this.aviso});

  /// Id do usuário logado (`sub` do token), ou `null` sem sessão.
  final String? usuarioId;

  /// A pessoa abriu o link de "esqueci minha senha" e precisa definir a nova
  /// antes de usar o app (E9.F2.3).
  final bool recuperandoSenha;

  /// Aviso pendente para a tela de login.
  final AvisoDaConta? aviso;
}

/// Conta do usuário no app (E9.F2.1–E9.F2.3). Fica atrás desta interface para
/// os testes usarem um serviço falso, sem tocar no Supabase.
abstract class AuthService {
  EstadoDaConta get estado;

  /// Emite o estado a cada mudança (login, logout, sessão restaurada,
  /// recuperação de senha, aviso). Pode repetir o mesmo usuário.
  Stream<EstadoDaConta> get mudancas;

  String? get usuarioId => estado.usuarioId;

  /// E-mail do usuário logado, para mostrar na tela.
  String? get email;

  /// Token para as chamadas à API (E9.F2.2): o da sessão atual, renovado
  /// antes se já tiver vencido. `null` sem sessão.
  Future<String?> tokenDeAcesso();

  /// Pede um token novo ao Supabase. Chamadas simultâneas compartilham a
  /// mesma renovação. `null` se não deu para renovar.
  Future<String?> renovarToken();

  /// A API recusou o token mesmo depois de renovar: encerra a sessão local e
  /// leva ao login com o aviso de sessão expirada.
  Future<void> encerrarSessaoExpirada();

  Future<void> entrar({required String email, required String senha});

  Future<ResultadoCadastro> cadastrar({required String email, required String senha});

  /// Logout pedido pela pessoa (sem aviso no login).
  Future<void> sair();

  /// Envia o e-mail de redefinição. Não revela se existe conta com o e-mail.
  Future<void> pedirRedefinicaoDeSenha(String email);

  /// Define a senha nova depois de abrir o link do e-mail (E9.F2.3).
  Future<void> definirNovaSenha(String senha);

  /// Some com o aviso da tela de login (a pessoa já leu ou agiu).
  void descartarAviso();
}

/// Implementação real, sobre o `supabase_flutter`. A sessão fica guardada
/// pela própria biblioteca (no Chrome, no armazenamento local do navegador),
/// e ela mesma renova o token pouco antes de vencer.
///
/// O `onAuthStateChange` do Supabase repete todos os eventos desde o início
/// para quem se inscreve depois: por isso o evento de recuperação de senha,
/// disparado ainda no `Supabase.initialize` (ao ler o link na URL), chega aqui.
class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._auth) {
    _assinatura = _auth.onAuthStateChange.listen(_aoMudar, onError: _aoFalhar);
  }

  final GoTrueClient _auth;
  final _controller = StreamController<EstadoDaConta>.broadcast();
  late final StreamSubscription<AuthState> _assinatura;

  bool _recuperandoSenha = false;
  AvisoDaConta? _aviso;

  /// Logout pedido pela pessoa: o `signedOut` seguinte não é "sessão expirada".
  bool _saidaVoluntaria = false;
  Future<String?>? _renovacao;

  @override
  EstadoDaConta get estado =>
      EstadoDaConta(usuarioId: _auth.currentUser?.id, recuperandoSenha: _recuperandoSenha, aviso: _aviso);

  @override
  Stream<EstadoDaConta> get mudancas => _controller.stream;

  @override
  String? get email => _auth.currentUser?.email;

  void _emitir() => _controller.add(estado);

  void _aoMudar(AuthState evento) {
    switch (evento.event) {
      case AuthChangeEvent.passwordRecovery:
        _recuperandoSenha = true;
        _aviso = null;
      case AuthChangeEvent.signedIn:
        _aviso = null;
      case AuthChangeEvent.signedOut:
        _recuperandoSenha = false;
        if (!_saidaVoluntaria) {
          _aviso = const AvisoDaConta(TipoDeAviso.sessaoExpirada, 'Sua sessão expirou. Entre de novo.');
        }
        _saidaVoluntaria = false;
      default:
        break;
    }
    _emitir();
  }

  /// Erros que chegam pelo stream do Supabase. Só os do link do e-mail viram
  /// aviso; os demais (ex.: falha de rede ao renovar) já são tratados em
  /// outro lugar e não devem assustar a pessoa.
  void _aoFalhar(Object erro, StackTrace _) {
    final mensagem = mensagemDeLinkInvalido(erro);
    if (mensagem == null) return;
    _aviso = AvisoDaConta(TipoDeAviso.linkInvalido, mensagem);
    _emitir();
  }

  @override
  Future<String?> tokenDeAcesso() async {
    final sessao = _auth.currentSession;
    if (sessao == null) return null;
    if (sessao.isExpired) return renovarToken();
    return sessao.accessToken;
  }

  @override
  Future<String?> renovarToken() {
    return _renovacao ??= () async {
      try {
        final resposta = await _auth.refreshSession();
        return resposta.session?.accessToken;
      } catch (_) {
        return null;
      } finally {
        _renovacao = null;
      }
    }();
  }

  @override
  Future<void> encerrarSessaoExpirada() async {
    if (_auth.currentSession == null) return;
    _saidaVoluntaria = false;
    try {
      await _auth.signOut();
    } catch (_) {
      // A sessão local é apagada mesmo sem rede.
    }
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    _aviso = null;
    try {
      await _auth.signInWithPassword(email: email.trim(), password: senha);
    } catch (erro) {
      throw AuthErro(mensagemDeErro(erro));
    }
  }

  @override
  Future<ResultadoCadastro> cadastrar({required String email, required String senha}) async {
    _aviso = null;
    try {
      final resposta = await _auth.signUp(email: email.trim(), password: senha);
      return resposta.session != null ? ResultadoCadastro.entrou : ResultadoCadastro.confirmarEmail;
    } catch (erro) {
      throw AuthErro(mensagemDeErro(erro));
    }
  }

  @override
  Future<void> sair() async {
    _saidaVoluntaria = true;
    _aviso = null;
    try {
      await _auth.signOut();
    } catch (_) {
      // Sem rede, o Supabase não consegue revogar a sessão no servidor, mas a
      // sessão local já foi apagada: para a pessoa, ela saiu.
    }
  }

  @override
  Future<void> pedirRedefinicaoDeSenha(String email) async {
    try {
      // No Chrome o link volta para a própria origem do app (que precisa estar
      // nas "Redirect URLs" do Supabase). No celular ainda não há link
      // profundo configurado: vale o "Site URL" do projeto.
      await _auth.resetPasswordForEmail(email.trim(), redirectTo: kIsWeb ? Uri.base.origin : null);
    } catch (erro) {
      // E-mail inexistente não dá erro no Supabase; os erros possíveis aqui
      // (rede, limite de envios, e-mail mal formado) não revelam contas.
      throw AuthErro(mensagemDeErro(erro));
    }
  }

  @override
  Future<void> definirNovaSenha(String senha) async {
    try {
      await _auth.updateUser(UserAttributes(password: senha));
    } catch (erro) {
      throw AuthErro(mensagemDeErro(erro));
    }
    _recuperandoSenha = false;
    _emitir();
  }

  @override
  void descartarAviso() {
    if (_aviso == null) return;
    _aviso = null;
    _emitir();
  }

  void dispose() {
    _assinatura.cancel();
    _controller.close();
  }
}

/// Traduz os erros do Supabase Auth para mensagens claras, sem detalhes
/// técnicos. Códigos: https://supabase.com/docs/guides/auth/debugging/error-codes
String mensagemDeErro(Object erro) {
  if (erro is AuthRetryableFetchException) return _semConexao;
  if (erro is AuthException) {
    switch (erro.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha incorretos.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Já existe uma conta com este e-mail. Tente entrar.';
      case 'weak_password':
        return 'Senha fraca. Use pelo menos $senhaMinima caracteres.';
      case 'same_password':
        return 'A nova senha precisa ser diferente da atual.';
      case 'email_not_confirmed':
        return 'Confirme seu e-mail antes de entrar (veja sua caixa de entrada).';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'E-mail inválido.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.';
      case 'signup_disabled':
        return 'Novos cadastros estão desativados no momento.';
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
        return 'Sua sessão expirou. Entre de novo.';
    }
    if (erro.statusCode == null) return _semConexao;
    return 'Não foi possível concluir agora. Tente de novo.';
  }
  // Falha de rede antes de chegar ao Supabase (ex.: sem internet).
  return _semConexao;
}

/// Mensagem para um link de redefinição que não funcionou, ou `null` se o
/// erro não tem a ver com o link (E9.F2.3).
///
/// - Link vencido ou já usado: o Supabase volta com `error=access_denied` e
///   `error_code=otp_expired` na URL.
/// - Link aberto em outro navegador: falta o código guardado quando o pedido
///   foi feito (fluxo PKCE), e a troca do código falha.
String? mensagemDeLinkInvalido(Object erro) {
  if (erro is! AuthException) return null;
  const pedirOutro = 'Peça um link novo abaixo.';
  final codigos = {erro.code, erro.statusCode};
  if (codigos.contains('otp_expired')) {
    return 'O link de redefinição expirou ou já foi usado. $pedirOutro';
  }
  if (codigos.contains('access_denied') ||
      codigos.contains('flow_state_not_found') ||
      codigos.contains('flow_state_expired') ||
      codigos.contains('bad_code_verifier') ||
      erro is AuthPKCEGrantCodeExchangeError ||
      erro.message.toLowerCase().contains('code verifier')) {
    return 'Não deu para usar este link. Abra-o no mesmo navegador em que pediu a redefinição, '
        'ou peça um novo. $pedirOutro';
  }
  return null;
}

const _semConexao = 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';

/// Mínimo de caracteres da senha (padrão do Supabase Auth).
const senhaMinima = 6;
