// Testes de renomear look salvo (E5.F3.1). LookService falso, nunca bate numa API real.
// Ver docs/PBIs/E5-F3-renomear-look/E5.F3.1-renomear-look.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'support/look_service_sem_historico.dart';

Look _look(String nome) => Look(
      id: 'l1',
      nome: nome,
      criadoEm: DateTime(2026, 10, 1),
      pecas: [Peca(id: 'p1', imagemUrl: '/uploads/p1.png', categoria: 'Camisetas')],
    );

/// Fake com estado: `atualizarLook` com `nome` muda o que `listarLooks` devolve.
class _LookServiceRenomear extends LookServiceSemHistorico {
  _LookServiceRenomear(this.look);

  Look look;
  bool falhar = false;
  final patches = <Map<String, dynamic>>[];

  @override
  Future<List<Look>> listarLooks() async => [look];

  @override
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    patches.add(campos);
    look = _look(campos['nome'] as String);
    return look;
  }
}

Future<void> _abrir(WidgetTester tester, _LookServiceRenomear service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [lookServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: LooksView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirDialogo(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Renomear'));
  await tester.pumpAndSettle();
}

Finder get _campo => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

void main() {
  testWidgets('Menu do card mantém a ordem; "Renomear" vem depois de "Alterar ocasião"', (tester) async {
    await _abrir(tester, _LookServiceRenomear(_look('Look sugerido – 07/03')));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final itens = tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .map((i) => i.value)
        .toList();
    // "Editar peças" (E3.F5.2) e "Excluir" (E3.F5.1) entraram depois.
    expect(itens, ['hoje', 'outra', 'ocasiao', 'renomear', 'editar-pecas', 'excluir']);
  });

  testWidgets('"Renomear" abre com o nome atual; salvar envia o nome sem espaços e atualiza o card', (
    tester,
  ) async {
    final service = _LookServiceRenomear(_look('Look sugerido – 07/03'));
    await _abrir(tester, service);

    await _abrirDialogo(tester);
    expect(find.text('Renomear look'), findsOneWidget);
    expect(tester.widget<TextField>(_campo).controller!.text, 'Look sugerido – 07/03');

    await tester.enterText(_campo, '  Trabalho segunda  ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(service.patches, [
      {'nome': 'Trabalho segunda'},
    ]);
    expect(find.text('Trabalho segunda'), findsOneWidget);
    expect(find.text('Look sugerido – 07/03'), findsNothing);
  });

  testWidgets('Cancelar não chama a API', (tester) async {
    final service = _LookServiceRenomear(_look('Look de sexta'));
    await _abrir(tester, service);

    await _abrirDialogo(tester);
    await tester.enterText(_campo, 'Outro nome');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.patches, isEmpty);
    expect(find.text('Look de sexta'), findsOneWidget);
  });

  testWidgets('Nome vazio ou só espaços deixa "Salvar" desabilitado', (tester) async {
    final service = _LookServiceRenomear(_look('Look de sexta'));
    await _abrir(tester, service);
    await _abrirDialogo(tester);

    TextButton salvar() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Salvar'));

    await tester.enterText(_campo, '   ');
    await tester.pump();
    expect(salvar().onPressed, isNull);

    await tester.enterText(_campo, '');
    await tester.pump();
    expect(salvar().onPressed, isNull);
    expect(service.patches, isEmpty);
  });

  testWidgets('Falha mostra mensagem e mantém o nome anterior', (tester) async {
    final service = _LookServiceRenomear(_look('Look de sexta'))..falhar = true;
    await _abrir(tester, service);

    await _abrirDialogo(tester);
    await tester.enterText(_campo, 'Novo nome');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível atualizar o look.'),
      findsOneWidget,
    );
    expect(find.text('Look de sexta'), findsOneWidget);
    expect(find.text('Novo nome'), findsNothing);
  });
}
