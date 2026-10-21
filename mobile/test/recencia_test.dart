// Testes do aviso de repetição recente nos cards de look (E3.F4.4).
// Ver docs/PBIs/E3-F4-historico-de-looks/E3.F4.4-aviso-de-repeticao-recente.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/uso_look.dart';
import 'package:guarda_roupa_app/views/looks/looks_controller.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;

import 'support/look_service_sem_historico.dart';

Look _look(String id, String nome) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      pecas: [Peca(id: 'p$id', imagemUrl: '/uploads/$id.png', categoria: 'Camisetas')],
    );

UsoLook _uso(String id, String lookId, DateTime dia) =>
    UsoLook(id: id, lookId: lookId, usadoEm: dia, look: _look(lookId, 'x'));

/// Fake com estado: `registrarUso` passa a aparecer no histórico devolvido.
class _LookServiceRecencia extends LookServiceSemHistorico {
  _LookServiceRecencia(this.looks, this.usos, {this.historicoFalha = false});

  final List<Look> looks;
  List<UsoLook> usos;
  final bool historicoFalha;

  @override
  Future<List<Look>> listarLooks() async => looks;

  @override
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async {
    if (historicoFalha) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/historico'),
        type: DioExceptionType.connectionError,
      );
    }
    return List.of(usos);
  }

  @override
  Future<void> registrarUso(String lookId, DateTime data) async {
    usos = [_uso('novo', lookId, DateTime(data.year, data.month, data.day)), ...usos];
  }
}

Future<void> _abrir(WidgetTester tester, _LookServiceRecencia service) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lookServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: LooksView()),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _corDoTexto(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style?.color;

void main() {
  final hoje = DateTime.now();
  DateTime haDias(int n) => DateTime(hoje.year, hoje.month, hoje.day - n);

  group('ultimoUsoPorLook', () {
    test('fica com o uso mais recente de cada look, ignorando a hora', () {
      final mapa = ultimoUsoPorLook([
        _uso('1', 'a', DateTime(2026, 10, 10, 23, 30)),
        _uso('2', 'a', DateTime(2026, 10, 15)),
        _uso('3', 'a', DateTime(2026, 10, 12)),
        _uso('4', 'b', DateTime(2026, 9, 30)),
      ]);

      expect(mapa, {'a': DateTime(2026, 10, 15), 'b': DateTime(2026, 9, 30)});
      expect(ultimoUsoPorLook([]), isEmpty);
    });
  });

  group('rotuloDeRecencia / repeticaoRecente', () {
    final ref = DateTime(2026, 10, 18, 9, 0);

    test('hoje, ontem e N dias', () {
      expect(rotuloDeRecencia(DateTime(2026, 10, 18), ref), 'Usado hoje');
      expect(rotuloDeRecencia(DateTime(2026, 10, 17), ref), 'Usado ontem');
      expect(rotuloDeRecencia(DateTime(2026, 10, 15), ref), 'Usado há 3 dias');
      expect(rotuloDeRecencia(DateTime(2026, 10, 8), ref), 'Usado há 10 dias');
    });

    test('conta dias de calendário, não 24h', () {
      // Uso às 23h de ontem e "agora" 01h de hoje: continua sendo ontem.
      expect(rotuloDeRecencia(DateTime(2026, 10, 17, 23), DateTime(2026, 10, 18, 1)), 'Usado ontem');
    });

    test('virada de mês e de ano', () {
      expect(rotuloDeRecencia(DateTime(2026, 9, 30), DateTime(2026, 10, 1)), 'Usado ontem');
      expect(rotuloDeRecencia(DateTime(2026, 9, 25), DateTime(2026, 10, 2)), 'Usado há 7 dias');
      expect(rotuloDeRecencia(DateTime(2025, 12, 31), DateTime(2026, 1, 2)), 'Usado há 2 dias');
    });

    test('uso "no futuro" (tolerância de fuso do backend) conta como hoje', () {
      expect(rotuloDeRecencia(DateTime(2026, 10, 19), ref), 'Usado hoje');
    });

    test('recente quando <= $diasDeRepeticaoRecente dias', () {
      expect(repeticaoRecente(DateTime(2026, 10, 18), ref), isTrue);
      expect(repeticaoRecente(DateTime(2026, 10, 11), ref), isTrue); // 7 dias
      expect(repeticaoRecente(DateTime(2026, 10, 10), ref), isFalse); // 8 dias
    });
  });

  testWidgets('Cards mostram hoje, ontem e há N dias; look nunca usado fica sem rótulo', (
    tester,
  ) async {
    await _abrir(
      tester,
      _LookServiceRecencia(
        [_look('a', 'Look A'), _look('b', 'Look B'), _look('c', 'Look C'), _look('d', 'Look D')],
        [
          _uso('1', 'a', haDias(0)),
          _uso('2', 'b', haDias(3)),
          _uso('3', 'c', haDias(10)),
        ],
      ),
    );

    expect(find.text('Usado hoje'), findsOneWidget);
    expect(find.text('Usado há 3 dias'), findsOneWidget);
    expect(find.text('Usado há 10 dias'), findsOneWidget);
    // 3 rótulos para 4 looks: o look D (nunca usado) não tem nenhum.
    expect(find.textContaining('Usado'), findsNWidgets(3));
  });

  testWidgets('Rótulo recente (<= 7 dias) tem destaque; de 8 dias em diante é neutro', (
    tester,
  ) async {
    await _abrir(
      tester,
      _LookServiceRecencia(
        [_look('a', 'Look A'), _look('b', 'Look B'), _look('c', 'Look C')],
        [
          _uso('1', 'a', haDias(7)),
          _uso('2', 'b', haDias(8)),
          _uso('3', 'c', haDias(1)),
        ],
      ),
    );

    final avisoA = _corDoTexto(tester, 'Usado há 7 dias');
    final neutroB = _corDoTexto(tester, 'Usado há 8 dias');
    final avisoC = _corDoTexto(tester, 'Usado ontem');

    expect(avisoA, Colors.orange.shade800);
    expect(avisoC, Colors.orange.shade800);
    expect(neutroB, isNot(Colors.orange.shade800));
  });

  testWidgets('Vários usos do mesmo look: o rótulo reflete o mais recente', (tester) async {
    await _abrir(
      tester,
      _LookServiceRecencia(
        [_look('a', 'Look A')],
        [_uso('1', 'a', haDias(20)), _uso('2', 'a', haDias(2)), _uso('3', 'a', haDias(9))],
      ),
    );

    expect(find.text('Usado há 2 dias'), findsOneWidget);
    expect(find.textContaining('Usado'), findsOneWidget);
  });

  testWidgets('Histórico falhando não afeta a lista: sem rótulos e sem erro na tela', (
    tester,
  ) async {
    await _abrir(
      tester,
      _LookServiceRecencia([_look('a', 'Look A')], [], historicoFalha: true),
    );

    expect(find.text('Look A'), findsOneWidget);
    expect(find.textContaining('Usado'), findsNothing);
    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('"Usei hoje" muda o rótulo do card para "Usado hoje" sem puxar para atualizar', (
    tester,
  ) async {
    await _abrir(
      tester,
      _LookServiceRecencia([_look('a', 'Look A')], [_uso('1', 'a', haDias(10))]),
    );
    expect(find.text('Usado há 10 dias'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usei hoje'));
    await tester.pumpAndSettle();

    expect(find.text('Usado hoje'), findsOneWidget);
    expect(find.text('Usado há 10 dias'), findsNothing);
  });
}
