// Testes da tela de montagem manual de look (E3.F1.2).
// Mesmo padrão de peca_form_test.dart: PecaService/LookService falsos,
// nunca bate numa API real. Navega a partir de LooksView (FAB "Montar
// look"), como no fluxo real do app.
// Ver docs/PBIs/E3-F1-montagem-manual-looks/E3.F1.2-tela-de-montagem-do-look.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/look_service.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

Peca _peca(String id, String categoria) =>
    Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: categoria);

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _PecaServiceComDuasPecas extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        _peca('1', 'Camisetas'),
        _peca('2', 'Calças'),
      ];
}

// `listarLooks` também é sobrescrito nas duas classes abaixo porque
// `LooksView` (E3.F1.3) busca a lista ao montar e de novo ao voltar da
// montagem — sem isso, bateria numa API real dentro do teste.
class _LookServiceVazio extends LookService {
  @override
  Future<List<Look>> listarLooks() async => [];
}

class _LookServiceComSucesso extends LookService {
  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({required String nome, required List<String> pecaIds}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Look(
      id: 'look-1',
      nome: nome,
      criadoEm: DateTime.now(),
      pecas: pecaIds.map((id) => _peca(id, 'Camisetas')).toList(),
    );
  }
}

class _LookServiceComErro extends LookService {
  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({required String nome, required List<String> pecaIds}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/looks'),
      type: DioExceptionType.connectionError,
    );
  }
}

Future<void> _abrirMontarLook(WidgetTester tester) async {
  await tester.tap(find.text('Montar look'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Armário vazio orienta a cadastrar uma peça, sem abrir grade', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    expect(find.text('Cadastre uma peça antes de montar um look'), findsOneWidget);
    expect(find.text('Cadastrar peça'), findsOneWidget);
    expect(find.text('Salvar look'), findsNothing);
  });

  testWidgets('Sem nome ou sem seleção, "Salvar look" permanece desabilitado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    ElevatedButton salvarButton() =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar look'));

    expect(salvarButton().onPressed, isNull);

    // Só nome, sem peça selecionada: ainda desabilitado.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.pump();
    expect(salvarButton().onPressed, isNull);
  });

  testWidgets('Nome e peça selecionada salvam o look e voltam para Looks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceComSucesso()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();

    final salvarButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Salvar look'),
    );
    expect(salvarButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(find.text('Look "Look de sexta" salvo.'), findsOneWidget);
    expect(find.text('Looks'), findsOneWidget);
    expect(find.text('Montar look'), findsOneWidget);
  });

  testWidgets('Falha no envio mostra mensagem de erro e mantém nome e seleção', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceComErro()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    // Continua na tela de montagem (não voltou para "Looks"), com o nome
    // já digitado preservado.
    expect(find.text('Looks'), findsNothing);
    expect(find.text('Look de sexta'), findsOneWidget);
  });
}
