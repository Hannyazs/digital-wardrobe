import 'dart:async';

import 'package:guarda_roupa_app/core/auth/auth_service.dart';

/// Conta falsa para os testes (E9.F2.1–E9.F2.3): guarda as contas em memória
/// e emite as mudanças de sessão como o Supabase faria.
class AuthServiceFalso extends AuthService {
  /// [logadoComo] já tem sessão (senha `senha123`); [outrasContas] existem
  /// (e-mail → senha) mas estão deslogadas.
  AuthServiceFalso({
    String? logadoComo,
    Map<String, String> outrasContas = const {},
    this.exigeConfirmacao = false,
    this.erroDeRede = false,
  }) {
    _contas.addAll(outrasContas);
    if (logadoComo != null) {
      _contas[logadoComo] = 'senha123';
      _logado = logadoComo;
    }
  }

  /// Simula a confirmação de e-mail ligada no Supabase.
  final bool exigeConfirmacao;

  /// Toda chamada falha como se estivesse sem internet.
  bool erroDeRede;

  /// A renovação do token falha (refresh token vencido ou revogado).
  bool renovacaoFalha = false;

  final _contas = <String, String>{};
  final _controller = StreamController<EstadoDaConta>.broadcast();
  String? _logado;
  bool _recuperando = false;
  AvisoDaConta? _aviso;
  int _versaoDoToken = 1;

  int saidas = 0;
  int renovacoes = 0;
  int expiracoes = 0;
  final pedidosDeRedefinicao = <String>[];

  /// O id do usuário é derivado do e-mail, para os testes conferirem.
  static String idDe(String email) => 'id-$email';

  String? senhaDe(String email) => _contas[email];

  @override
  EstadoDaConta get estado => EstadoDaConta(
        usuarioId: _logado == null ? null : idDe(_logado!),
        recuperandoSenha: _recuperando,
        aviso: _aviso,
      );

  @override
  String? get email => _logado;

  @override
  Stream<EstadoDaConta> get mudancas => _controller.stream;

  void _emitir() => _controller.add(estado);

  /// O token "atual" que o falso entrega (muda a cada renovação).
  String? get tokenAtual => _logado == null ? null : 'token-$_logado-v$_versaoDoToken';

  @override
  Future<String?> tokenDeAcesso() async => tokenAtual;

  @override
  Future<String?> renovarToken() async {
    renovacoes++;
    if (renovacaoFalha || _logado == null) return null;
    _versaoDoToken++;
    return tokenAtual;
  }

  @override
  Future<void> encerrarSessaoExpirada() async {
    if (_logado == null) return;
    expiracoes++;
    _logado = null;
    _recuperando = false;
    _aviso = const AvisoDaConta(TipoDeAviso.sessaoExpirada, 'Sua sessão expirou. Entre de novo.');
    _emitir();
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (erroDeRede) throw const AuthErro('Sem conexão com o servidor. Verifique sua internet e tente novamente.');
    final chave = email.trim();
    if (_contas[chave] != senha) throw const AuthErro('E-mail ou senha incorretos.');
    _logado = chave;
    _aviso = null;
    _emitir();
  }

  @override
  Future<ResultadoCadastro> cadastrar({required String email, required String senha}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (erroDeRede) throw const AuthErro('Sem conexão com o servidor. Verifique sua internet e tente novamente.');
    final chave = email.trim();
    if (_contas.containsKey(chave)) throw const AuthErro('Já existe uma conta com este e-mail. Tente entrar.');
    _contas[chave] = senha;
    if (exigeConfirmacao) return ResultadoCadastro.confirmarEmail;
    _logado = chave;
    _emitir();
    return ResultadoCadastro.entrou;
  }

  @override
  Future<void> sair() async {
    saidas++;
    _logado = null;
    _recuperando = false;
    _aviso = null;
    _emitir();
  }

  @override
  Future<void> pedirRedefinicaoDeSenha(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (erroDeRede) throw const AuthErro('Sem conexão com o servidor. Verifique sua internet e tente novamente.');
    // Como o Supabase: e-mail sem conta não dá erro.
    pedidosDeRedefinicao.add(email.trim());
  }

  @override
  Future<void> definirNovaSenha(String senha) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (erroDeRede) throw const AuthErro('Sem conexão com o servidor. Verifique sua internet e tente novamente.');
    if (_contas[_logado] == senha) throw const AuthErro('A nova senha precisa ser diferente da atual.');
    _contas[_logado!] = senha;
    _recuperando = false;
    _emitir();
  }

  @override
  void descartarAviso() {
    if (_aviso == null) return;
    _aviso = null;
    _emitir();
  }

  /// Como o Supabase ao abrir o link do e-mail: sessão de recuperação aberta.
  void abrirLinkDeRecuperacao(String email) {
    _logado = email;
    _recuperando = true;
    _aviso = null;
    _emitir();
  }

  /// Link vencido/inválido aberto: o Supabase não abre sessão, só avisa.
  void abrirLinkInvalido(String mensagem) {
    _aviso = AvisoDaConta(TipoDeAviso.linkInvalido, mensagem);
    _emitir();
  }

  void fechar() => _controller.close();
}
