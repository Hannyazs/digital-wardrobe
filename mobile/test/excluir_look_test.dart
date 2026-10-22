// Testes de excluir (arquivar) look salvo (E3.F5.1). LookService falso, nunca bate numa API real.
// Ver docs/PBIs/E3-F5-edicao-exclusao-looks/E3.F5.1-excluir-look.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'support/look_service_sem_historico.dart';

Look _look(String id, String nome) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 10, 1),
      pecas: [Peca(id: 'p$id', imagemUrl: '/uploads/p$id.png', categoria: 'Camisetas')],
    );

/// Fake com estado: excluir tira o look do que `listarLooks` devolve.
class _LookServiceExcluir extends LookServiceSemHistorico {
  _LookServiceExcluir(this.looks);

  List<Look> looks;
  DioException? erro;
  final excluidos = <String>[];

  @override
  Future<List<Look>> listarLooks() async => List.of(looks);

  @override
  Future<void> excluirLook(String id) async {
    if (erro != null) throw erro!;
    excluidos.add(id);
    looks = looks.where((l) => l.id != id).toList();
  }
}

Future<void> _abrir(WidgetTester tester, _LookServiceExcluir service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lookServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: LooksView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _excluirPrimeiro(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Excluir'));
  await tester.pumpAndSettle();
}

Finder get _confirmar =>
    find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, 'Excluir'));

void main() {
  testWidgets('Excluir pede confirmação explicando que o histórico fica', (tester) async {
    await _abrir(tester, _LookServiceExcluir([_look('1', 'Look de sexta')]));

    await _excluirPrimeiro(tester);

    expect(find.text('Excluir look?'), findsOneWidget);
    expect(find.textContaining('continuam no calendário'), findsOneWidget);
  });

  testWidgets('Cancelar não chama a API e o look fica', (tester) async {
    final service = _LookServiceExcluir([_look('1', 'Look de sexta')]);
    await _abrir(tester, service);

    await _excluirPrimeiro(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.excluidos, isEmpty);
    expect(find.text('Look de sexta'), findsOneWidget);
  });

  testWidgets('Confirmar exclui: o card some e os outros ficam', (tester) async {
    final service = _LookServiceExcluir([_look('1', 'Look de sexta'), _look('2', 'Look da faculdade')]);
    await _abrir(tester, service);

    await _excluirPrimeiro(tester);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(service.excluidos, ['1']);
    expect(find.text('Look de sexta'), findsNothing);
    expect(find.text('Look da faculdade'), findsOneWidget);
    expect(find.text('Look "Look de sexta" excluído.'), findsOneWidget);
  });

  testWidgets('Excluir o último look mostra o estado vazio', (tester) async {
    final service = _LookServiceExcluir([_look('1', 'Look de sexta')]);
    await _abrir(tester, service);

    await _excluirPrimeiro(tester);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(find.text('Você ainda não tem nenhum look salvo'), findsOneWidget);
  });

  testWidgets('Falha mostra mensagem e mantém o card', (tester) async {
    final service = _LookServiceExcluir([_look('1', 'Look de sexta')])
      ..erro = DioException(
        requestOptions: RequestOptions(path: '/looks/1'),
        type: DioExceptionType.connectionError,
      );
    await _abrir(tester, service);

    await _excluirPrimeiro(tester);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão com o servidor. Não foi possível excluir o look.'), findsOneWidget);
    expect(find.text('Look de sexta'), findsOneWidget);
  });
}
