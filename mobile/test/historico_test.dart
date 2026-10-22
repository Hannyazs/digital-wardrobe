// Testes do histórico de looks utilizados, em formato de calendário (E3.F4.3).
// O calendário fica na Casa (reorganização da interface): os testes abrem a
// `HomeView`, onde ele é exibido. LookService falso, nunca bate numa API real.
// Ver docs/PBIs/E3-F4-historico-de-looks/E3.F4.3-tela-de-historico-de-looks.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/uso_look.dart';
import 'package:guarda_roupa_app/services/look_service.dart';
import 'package:guarda_roupa_app/models/peca.dart' show Peca;
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/home/home_view.dart';
import 'package:guarda_roupa_app/views/looks/looks_controller.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;
import 'support/sugestao_service_sem_look_do_dia.dart';

Look _look(String id, String nome) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      pecas: [Peca(id: 'p$id', imagemUrl: '/uploads/$id.png', categoria: 'Camisetas')],
    );

UsoLook _uso(String id, DateTime dia, String nomeLook) =>
    UsoLook(id: id, lookId: 'l$id', usadoEm: dia, look: _look('l$id', nomeLook));

/// Fake com estado que respeita `de`/`ate` como o backend e registra as chamadas.
class _LookServiceHistorico extends LookService {
  _LookServiceHistorico(this.usos, {this.erroAoListar, this.erroAoRemover = false});

  List<UsoLook> usos;
  final DioException? erroAoListar;
  final bool erroAoRemover;
  final removidos = <String>[];
  final consultas = <({DateTime? de, DateTime? ate, int? limite})>[];

  @override
  Future<List<Look>> listarLooks() async => [_look('1', 'Look de sexta')];

  @override
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async {
    consultas.add((de: de, ate: ate, limite: limite));
    if (erroAoListar != null) throw erroAoListar!;
    return usos
        .where((u) => (de == null || !u.usadoEm.isBefore(de)) && (ate == null || !u.usadoEm.isAfter(ate)))
        .toList();
  }

  @override
  Future<void> removerUso(String usoId) async {
    if (erroAoRemover) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/usos/$usoId'),
        type: DioExceptionType.connectionError,
      );
    }
    removidos.add(usoId);
    usos = usos.where((u) => u.id != usoId).toList();
  }

  @override
  Future<void> registrarUso(String lookId, DateTime data) async {
    usos = [_uso('novo', DateTime(data.year, data.month, data.day), 'Look de sexta'), ...usos];
  }
}

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _LentoHistorico extends LookService {
  @override
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return [];
  }
}

/// A grade + lista do dia ocupam mais que a tela de teste padrão (800x600).
void _telaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _abrirHistorico(WidgetTester tester, LookService service) async {
  _telaGrande(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lookServiceProvider.overrideWithValue(service),
        sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
      ],
      child: const MaterialApp(home: HomeView()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final agora = DateTime.now();
  final hojeDia = DateTime(agora.year, agora.month, agora.day);
  final mesAtual = DateTime(agora.year, agora.month);
  final mesAnterior = DateTime(agora.year, agora.month - 1);
  final dia15Anterior = DateTime(mesAnterior.year, mesAnterior.month, 15);

  group('funções puras', () {
    test('usosPorDia agrupa pelo dia (sem hora), preservando a ordem', () {
      final mapa = usosPorDia([
        _uso('1', DateTime(2026, 10, 18), 'A'),
        _uso('2', DateTime(2026, 10, 18), 'B'),
        _uso('3', DateTime(2026, 10, 17), 'C'),
      ]);

      expect(mapa.keys, [DateTime(2026, 10, 18), DateTime(2026, 10, 17)]);
      expect(mapa[DateTime(2026, 10, 18)]!.map((u) => u.id), ['1', '2']);
      expect(usosPorDia([]), isEmpty);
    });

    test('rotuloDoDia: Hoje, Ontem e dd/MM/yyyy (inclusive virada de mês)', () {
      final ref = DateTime(2026, 10, 18);
      expect(rotuloDoDia(DateTime(2026, 10, 18), ref), 'Hoje');
      expect(rotuloDoDia(DateTime(2026, 10, 17), ref), 'Ontem');
      expect(rotuloDoDia(DateTime(2026, 10, 3), ref), '03/10/2026');
      expect(rotuloDoDia(DateTime(2026, 9, 30), DateTime(2026, 10, 1)), 'Ontem');
    });

    test('rotuloDoMes usa nomes em português', () {
      expect(rotuloDoMes(DateTime(2026, 10)), 'Outubro 2026');
      expect(rotuloDoMes(DateTime(2027, 3)), 'Março 2027');
    });

    test('UsoLook.fromJson lê o contrato de UsoLookRead', () {
      final uso = UsoLook.fromJson({
        'id': 'u1',
        'look_id': 'l1',
        'usado_em': '2026-10-10',
        'look': {
          'id': 'l1',
          'nome': 'Look',
          'criado_em': '2026-10-01T10:00:00Z',
          'pecas': <dynamic>[],
          'favorito': false,
          'ocasiao': null,
        },
      });
      expect(uso.usadoEm, DateTime(2026, 10, 10));
      expect(uso.look.nome, 'Look');
    });
  });

  testWidgets('Mostra carregamento enquanto busca o mês', (tester) async {
    _telaGrande(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lookServiceProvider.overrideWithValue(_LentoHistorico()),
          sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Abre no mês atual com hoje selecionado e busca só esse mês', (tester) async {
    final service = _LookServiceHistorico([
      _uso('1', hojeDia, 'Look A'),
      _uso('2', hojeDia, 'Look B'),
    ]);
    await _abrirHistorico(tester, service);

    expect(find.text(rotuloDoMes(mesAtual)), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget); // um cabeçalho para os dois usos
    expect(find.text('Look A'), findsOneWidget);
    expect(find.text('Look B'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    // Uma única consulta, restrita ao mês visível (não ao histórico inteiro).
    expect(service.consultas, hasLength(1));
    expect(service.consultas.single.de, DateTime(mesAtual.year, mesAtual.month, 1));
    expect(service.consultas.single.ate, DateTime(mesAtual.year, mesAtual.month + 1, 0));
    expect(service.consultas.single.limite, 500);
  });

  testWidgets('A grade marca só os dias que têm uso', (tester) async {
    await _abrirHistorico(tester, _LookServiceHistorico([_uso('1', hojeDia, 'Look A')]));

    expect(find.byKey(ValueKey('marca-${hojeDia.day}')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('marca-')),
        findsOneWidget);
  });

  testWidgets('Dia sem uso mostra orientação para registrar', (tester) async {
    await _abrirHistorico(tester, _LookServiceHistorico([]));

    expect(find.text('Nenhum look usado — Hoje'), findsOneWidget);
    expect(find.textContaining('Usei hoje'), findsOneWidget);
  });

  testWidgets('Mês anterior busca aquele mês, limpa a seleção e permite escolher um dia', (
    tester,
  ) async {
    final service = _LookServiceHistorico([
      _uso('1', hojeDia, 'Look A'),
      _uso('2', dia15Anterior, 'Look Antigo'),
    ]);
    await _abrirHistorico(tester, service);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();

    expect(find.text(rotuloDoMes(mesAnterior)), findsOneWidget);
    expect(service.consultas.last.de, DateTime(mesAnterior.year, mesAnterior.month, 1));
    expect(service.consultas.last.ate, DateTime(mesAnterior.year, mesAnterior.month + 1, 0));
    expect(find.text('Toque num dia para ver os looks usados'), findsOneWidget);
    expect(find.text('Look A'), findsNothing);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.text('Look Antigo'), findsOneWidget);
    const dd = '15';
    final mm = mesAnterior.month.toString().padLeft(2, '0');
    expect(find.text('$dd/$mm/${mesAnterior.year}'), findsOneWidget);

    // Voltar ao mês atual reseleciona hoje.
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    expect(find.text('Look A'), findsOneWidget);
  });

  testWidgets('No mês atual, "Próximo mês" fica desabilitado', (tester) async {
    await _abrirHistorico(tester, _LookServiceHistorico([]));

    final botao = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(botao.onPressed, isNull);
  });

  testWidgets('Erro de rede mostra mensagem e "Tentar novamente"', (tester) async {
    await _abrirHistorico(
      tester,
      _LookServiceHistorico(
        [],
        erroAoListar: DioException(
          requestOptions: RequestOptions(path: '/looks/historico'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    // O calendário segue navegável durante o erro.
    expect(find.byTooltip('Mês anterior'), findsOneWidget);
  });

  testWidgets('401 mostra mensagem de sessão inválida', (tester) async {
    final opts = RequestOptions(path: '/looks/historico');
    await _abrirHistorico(
      tester,
      _LookServiceHistorico(
        [],
        erroAoListar: DioException(
          requestOptions: opts,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: opts, statusCode: 401),
        ),
      ),
    );

    expect(
      find.text('Sessão expirada ou inválida. Não foi possível carregar seu histórico.'),
      findsOneWidget,
    );
  });

  testWidgets('Remover com confirmação apaga o registro; cancelar mantém', (tester) async {
    final service = _LookServiceHistorico([
      _uso('1', hojeDia, 'Look A'),
      _uso('2', hojeDia, 'Look B'),
    ]);
    await _abrirHistorico(tester, service);

    // Cancelar: nada muda.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Remover este registro?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(service.removidos, isEmpty);
    expect(find.text('Look A'), findsOneWidget);

    // Confirmar: some da lista do dia.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(service.removidos, ['1']);
    expect(find.text('Look A'), findsNothing);
    expect(find.text('Look B'), findsOneWidget);
  });

  testWidgets('Remover o último uso do dia tira a marcação e mostra a orientação', (tester) async {
    await _abrirHistorico(tester, _LookServiceHistorico([_uso('1', hojeDia, 'Look A')]));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum look usado — Hoje'), findsOneWidget);
    expect(find.byKey(ValueKey('marca-${hojeDia.day}')), findsNothing);
  });

  testWidgets('Falha ao remover mostra SnackBar e mantém o registro', (tester) async {
    await _abrirHistorico(
      tester,
      _LookServiceHistorico([_uso('1', hojeDia, 'Look A')], erroAoRemover: true),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível remover o registro.'),
      findsOneWidget,
    );
    expect(find.text('Look A'), findsOneWidget);
  });

  testWidgets('Uso registrado em Armário › Looks aparece no calendário da Casa', (tester) async {
    _telaGrande(tester);
    final service = _LookServiceHistorico([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lookServiceProvider.overrideWithValue(service),
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Casa abre com o calendário, ainda sem marcação.
    expect(find.text('Calendário de looks'), findsOneWidget);
    expect(find.byKey(ValueKey('marca-${hojeDia.day}')), findsNothing);

    // Armário › Looks › menu do card › "Usei hoje" (E3.F4.2).
    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    expect(find.text(rotuloDoMes(mesAtual)), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.byKey(ValueKey('marca-${hojeDia.day}')), findsOneWidget);
  });
}
