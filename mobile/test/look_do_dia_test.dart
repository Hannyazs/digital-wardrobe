// Testes do card "Look do dia" na Casa (E6.F1.2). Serviços falsos, nunca bate numa API real.
// Ver docs/PBIs/E6-F1-look-do-dia/E6.F1.2-card-look-do-dia.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/preferencia.dart';
import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart';
import 'package:guarda_roupa_app/views/home/home_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart'
    show nomeLookSugerido, sugestaoServiceProvider;
import 'support/look_service_sem_historico.dart';
import 'support/preferencia_service_sem_evitadas.dart';

/// "Backend" compartilhado entre os fakes: a ocasião salva persiste entre
/// aberturas do app (novos `ProviderScope`), como no banco.
class _Servidor {
  String? ocasiaoSalva;
}

Peca _peca(String id) => Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: 'Camisetas');

/// 2 looks por ocasião; respeita os descartes; `tem_mais` como o backend.
class _SugestaoServiceFake extends SugestaoService {
  _SugestaoServiceFake(this.servidor);

  final _Servidor servidor;
  final pedidos = <({String? ocasiao, List<List<String>> descartados, DateTime data})>[];
  Object? erro;
  bool armarioVazio = false;

  /// `Sugestao.chave` → id de um look que já existe salvo (E6.F1.3).
  final salvosNoServidor = <String, String>{};

  @override
  Future<LookDoDia> lookDoDia({
    required DateTime data,
    String? ocasiao,
    List<List<String>> descartados = const [],
  }) async {
    pedidos.add((ocasiao: ocasiao, descartados: descartados, data: data));
    if (erro != null) throw erro!;
    final usada = ocasiao ?? servidor.ocasiaoSalva ?? 'Casual';
    if (armarioVazio) {
      return LookDoDia(ocasiao: usada, motivo: 'Seu armário ainda não tem peças cadastradas.');
    }
    final chaves = descartados.map((ids) => ([...ids]..sort()).join(',')).toSet();
    final restantes = [
      for (var n = 1; n <= 2; n++)
        Sugestao(
          pecas: [_peca('$usada-cima$n'), _peca('$usada-baixo$n')],
          explicacoes: ['Look $n para $usada.'],
        ),
    ].where((s) => !chaves.contains(s.chave)).toList();
    if (restantes.isEmpty) {
      return LookDoDia(ocasiao: usada, motivo: 'Não há mais sugestões com esses filtros.');
    }
    return LookDoDia(
      look: restantes.first,
      lookSalvoId: salvosNoServidor[restantes.first.chave],
      ocasiao: usada,
      temMais: restantes.length > 1,
    );
  }
}

class _PreferenciaServiceFake extends PreferenciaServiceSemEvitadas {
  _PreferenciaServiceFake(this.servidor);

  final _Servidor servidor;
  bool falhar = false;

  @override
  Future<Preferencia> atualizar(Map<String, dynamic> campos) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/preferencias'),
        type: DioExceptionType.connectionError,
      );
    }
    servidor.ocasiaoSalva = campos['ocasiao_look_do_dia'] as String;
    return Preferencia(ocasiaoLookDoDia: servidor.ocasiaoSalva);
  }
}

class _LookServiceFake extends LookServiceSemHistorico {
  final criados = <({String nome, List<String> pecaIds})>[];
  final usos = <({String lookId, DateTime data})>[];
  bool falharCriar = false;

  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    if (falharCriar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks'),
        type: DioExceptionType.connectionError,
      );
    }
    criados.add((nome: nome, pecaIds: pecaIds));
    return Look(
      id: 'look-${criados.length}',
      nome: nome,
      criadoEm: DateTime(2026),
      pecas: pecaIds.map(_peca).toList(),
    );
  }

  @override
  Future<void> registrarUso(String lookId, DateTime data) async {
    usos.add((lookId: lookId, data: data));
  }
}

class _Cena {
  _Cena() {
    sugestoes = _SugestaoServiceFake(servidor);
    preferencias = _PreferenciaServiceFake(servidor);
  }

  final servidor = _Servidor();
  late final _SugestaoServiceFake sugestoes;
  late final _PreferenciaServiceFake preferencias;
  final looks = _LookServiceFake();
}

Future<void> _abrirCasa(WidgetTester tester, _Cena cena) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // Chave nova a cada abertura: simula reabrir o app (estado em memória zerado).
      key: UniqueKey(),
      overrides: [
        sugestaoServiceProvider.overrideWithValue(cena.sugestoes),
        preferenciaServiceProvider.overrideWithValue(cena.preferencias),
        lookServiceProvider.overrideWithValue(cena.looks),
      ],
      child: const MaterialApp(home: HomeView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _escolherOcasiao(WidgetTester tester, String ocasiao) async {
  await tester.tap(find.byKey(const ValueKey('look-do-dia-ocasiao')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(ocasiao).last);
  await tester.pumpAndSettle();
}

String _ocasiaoNoSeletor(WidgetTester tester) =>
    tester.widget<DropdownButton<String>>(find.byKey(const ValueKey('look-do-dia-ocasiao'))).value!;

void main() {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);

  testWidgets('Sem preferência salva, o card abre com um look Casual (data de hoje)', (tester) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    expect(find.text('Look do dia'), findsOneWidget);
    expect(_ocasiaoNoSeletor(tester), 'Casual');
    expect(find.text('Look 1 para Casual.'), findsOneWidget);
    expect(cena.sugestoes.pedidos.single.ocasiao, isNull); // backend escolhe
    expect(cena.sugestoes.pedidos.single.data, hoje);
  });

  testWidgets('Com ocasião salva, o card abre nela', (tester) async {
    final cena = _Cena()..servidor.ocasiaoSalva = 'Trabalho';
    await _abrirCasa(tester, cena);

    expect(_ocasiaoNoSeletor(tester), 'Trabalho');
    expect(find.text('Look 1 para Trabalho.'), findsOneWidget);
  });

  testWidgets('Trocar a ocasião muda o look, grava a preferência e vale ao reabrir o app', (
    tester,
  ) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    await _escolherOcasiao(tester, 'Trabalho');
    expect(find.text('Look 1 para Trabalho.'), findsOneWidget);
    expect(cena.servidor.ocasiaoSalva, 'Trabalho');

    await _abrirCasa(tester, cena); // "reabre o app"
    expect(_ocasiaoNoSeletor(tester), 'Trabalho');
    expect(find.text('Look 1 para Trabalho.'), findsOneWidget);
  });

  testWidgets('Se gravar a ocasião falhar, o look muda mesmo assim e aparece mensagem', (tester) async {
    final cena = _Cena();
    cena.preferencias.falhar = true;
    await _abrirCasa(tester, cena);

    await _escolherOcasiao(tester, 'Festa');

    expect(find.text('Look 1 para Festa.'), findsOneWidget);
    expect(find.textContaining('Não foi possível lembrar a ocasião'), findsOneWidget);
    expect(cena.servidor.ocasiaoSalva, isNull);
  });

  testWidgets('"Outra sugestão" descarta o atual e mostra outro; sem mais, o botão desabilita', (
    tester,
  ) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Outra sugestão'));
    await tester.pumpAndSettle();

    expect(cena.sugestoes.pedidos.last.descartados, [
      ['Casual-cima1', 'Casual-baixo1'],
    ]);
    expect(find.text('Look 2 para Casual.'), findsOneWidget);
    expect(find.text('Look 1 para Casual.'), findsNothing);
    final botao = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Outra sugestão'));
    expect(botao.onPressed, isNull);
  });

  testWidgets('"Salvar" cria o look com o nome padrão e marca como salvo', (tester) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(cena.looks.criados.single.nome, nomeLookSugerido(hoje));
    expect(cena.looks.criados.single.pecaIds, ['Casual-cima1', 'Casual-baixo1']);
    expect(find.text('Salvo'), findsOneWidget);
    expect(find.text('Look salvo em Armário › Looks.'), findsOneWidget);
  });

  testWidgets('"Usei hoje" salva uma vez só e registra o uso com a data de hoje', (tester) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    expect(cena.looks.criados, hasLength(1)); // não criou de novo
    expect(cena.looks.usos.single.lookId, 'look-1');
    expect(cena.looks.usos.single.data, hoje);
    expect(find.text('Usado hoje'), findsOneWidget);
    expect(find.text('Uso registrado para hoje.'), findsOneWidget);
  });

  testWidgets('"Usei hoje" sem salvar antes cria o look e registra o uso', (tester) async {
    final cena = _Cena();
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    expect(cena.looks.criados, hasLength(1));
    expect(cena.looks.usos.single.lookId, 'look-1');
    expect(find.text('Salvo'), findsOneWidget);
  });

  testWidgets('Falha ao salvar mostra mensagem e o look continua', (tester) async {
    final cena = _Cena();
    cena.looks.falharCriar = true;
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    expect(cena.looks.usos, isEmpty);
    expect(find.text('Look 1 para Casual.'), findsOneWidget);
  });

  testWidgets('Armário insuficiente mostra o motivo; atalhos continuam', (tester) async {
    final cena = _Cena();
    cena.sugestoes.armarioVazio = true;
    await _abrirCasa(tester, cena);

    expect(find.text('Seu armário ainda não tem peças cadastradas.'), findsOneWidget);
    expect(find.text('Usei hoje'), findsNothing);
    expect(find.text('Adicionar peça'), findsOneWidget);
    expect(find.text('Calendário de looks'), findsOneWidget);
  });

  testWidgets('Erro de rede mostra "Tentar novamente", que refaz a busca', (tester) async {
    final cena = _Cena();
    cena.sugestoes.erro = DioException(
      requestOptions: RequestOptions(path: '/sugestoes/look-do-dia'),
      type: DioExceptionType.connectionError,
    );
    await _abrirCasa(tester, cena);

    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('Adicionar peça'), findsOneWidget);

    cena.sugestoes.erro = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Look 1 para Casual.'), findsOneWidget);
  });

  // --- E6.F1.3: look do dia que já é um look salvo ---

  testWidgets('Look que já existe aparece como "Já salvo", sem opção de salvar de novo', (
    tester,
  ) async {
    final cena = _Cena();
    cena.sugestoes.salvosNoServidor['Casual-baixo1,Casual-cima1'] = 'look-antigo';
    await _abrirCasa(tester, cena);

    expect(find.text('Look 1 para Casual.'), findsOneWidget); // continua sendo sugerido
    expect(find.text('Este look já está em Armário › Looks.'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);
    final botao = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Já salvo'));
    expect(botao.onPressed, isNull);
  });

  testWidgets('"Usei hoje" num look que já existe registra o uso nele, sem criar outro', (
    tester,
  ) async {
    final cena = _Cena();
    cena.sugestoes.salvosNoServidor['Casual-baixo1,Casual-cima1'] = 'look-antigo';
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    expect(cena.looks.criados, isEmpty);
    expect(cena.looks.usos.single.lookId, 'look-antigo');
    expect(cena.looks.usos.single.data, hoje);
  });

  testWidgets('"Outra sugestão" para um look que não existe volta a permitir salvar', (tester) async {
    final cena = _Cena();
    cena.sugestoes.salvosNoServidor['Casual-baixo1,Casual-cima1'] = 'look-antigo';
    await _abrirCasa(tester, cena);

    await tester.tap(find.text('Outra sugestão'));
    await tester.pumpAndSettle();

    expect(find.text('Look 2 para Casual.'), findsOneWidget);
    expect(find.text('Este look já está em Armário › Looks.'), findsNothing);
    final botao = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar'));
    expect(botao.onPressed, isNotNull);
  });
}
