// Testes do formulário de metadados e cadastro da peça (E1.F2.1).
// Mesmo padrão de widget_test.dart: PecaService falso, nunca bate numa API
// real. Cobre a navegação a partir do resultado do processamento (E1.F1.3),
// a validação da categoria obrigatória, e os caminhos de sucesso/erro do
// envio para POST /pecas.
// Ver docs/PBIs/E1-F2-metadados-da-peca/E1.F2.1-formulario-e-cadastro-da-peca.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/upload/peca_form_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

/// O formulário (com os grupos de chips) é mais alto que a tela padrão de
/// teste (800x600): sem isso o botão de salvar fica fora da área tocável.
void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _PecaServiceComSucesso extends PecaService {
  @override
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Peca(id: 'peca-1', imagemUrl: imagemUrl, categoria: categoria);
  }
}

class _PecaServiceComErro extends PecaService {
  @override
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas'),
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
  testWidgets('Confirmar sem categoria impede o envio e sinaliza o campo obrigatório', (
    WidgetTester tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso())],
        child: const MaterialApp(
          home: PecaFormView(imagemUrl: 'http://localhost:8000/uploads/foto.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Selecione uma categoria'), findsOneWidget);
    // Ainda na tela do formulário — não navegou nem mostrou carregamento.
    expect(find.text('Detalhes da peça'), findsOneWidget);
  });

  testWidgets('Confirmar com categoria válida salva a peça e volta para o armário', (
    WidgetTester tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso())],
        child: const MaterialApp(
          home: PecaFormView(imagemUrl: 'http://localhost:8000/uploads/foto.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camisetas').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Pilha de navegação substituída pela Home (aba inicial do HomeShell
    // desde o redesign visual, Etapa 4) — não dá pra voltar e reenviar a
    // mesma peça.
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Detalhes da peça'), findsNothing);
  });

  testWidgets('Falha no envio mostra mensagem de erro e mantém os dados preenchidos', (
    WidgetTester tester,
  ) async {
    _telaAlta(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComErro())],
        child: const MaterialApp(
          home: PecaFormView(imagemUrl: 'http://localhost:8000/uploads/foto.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vestidos').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Subcategoria'), 'Vestido longo');

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    // Não navegou nem perdeu o que já tinha sido digitado.
    expect(find.text('Detalhes da peça'), findsOneWidget);
    expect(find.text('Vestidos'), findsWidgets);
    expect(find.text('Vestido longo'), findsOneWidget);
  });
}
