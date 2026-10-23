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
    List<String> coresSecundarias = const [],
    List<String> estacoes = const [],
    List<String> estilos = const [],
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
    List<String> coresSecundarias = const [],
    List<String> estacoes = const [],
    List<String> estilos = const [],
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
  mainEstacoesECores();

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
    expect(find.text('Dados da peça'), findsOneWidget);
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
    expect(find.text('Olá!'), findsOneWidget);
    expect(find.text('Dados da peça'), findsNothing);
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
    expect(find.text('Dados da peça'), findsOneWidget);
    expect(find.text('Vestidos'), findsWidgets);
    expect(find.text('Vestido longo'), findsOneWidget);
  });

  group('sugestão da IA (E7.F1.2)', () {
    const aviso = 'Sugerido pela IA — revise antes de salvar';

    Future<void> abrir(WidgetTester tester, Map<String, dynamic>? sugestao,
        {PecaService? service}) async {
      _telaAlta(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pecaServiceProvider.overrideWithValue(service ?? _PecaServiceComSucesso())],
          child: MaterialApp(
            home: PecaFormView(
              imagemUrl: 'http://localhost:8000/uploads/foto.png',
              sugestao: sugestao,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pré-preenche os campos e mostra o aviso', (tester) async {
      await abrir(tester, {
        'categoria': 'Camisetas',
        'subcategoria': 'gola V',
        'cor_principal': 'Azul',
        'tonalidade_cor': null,
      });

      expect(find.text(aviso), findsOneWidget);
      expect(find.text('Camisetas'), findsOneWidget);
      expect(find.text('gola V'), findsOneWidget);
      final azul = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Azul'));
      expect(azul.selected, isTrue);
      // Cor sem tonalidade: aplica a tonalidade sugerida para a cor.
      final vibrante = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Vibrante'));
      expect(vibrante.selected, isTrue);
    });

    testWidgets('sugestão vazia abre o formulário vazio e sem aviso', (tester) async {
      await abrir(tester, {
        'categoria': '',
        'subcategoria': null,
        'cor_principal': null,
        'tonalidade_cor': null,
      });

      expect(find.text(aviso), findsNothing);
      expect(find.text('Camisetas'), findsNothing);
    });

    testWidgets('sem sugestão (fallback sem remoção de fundo) não mostra aviso', (tester) async {
      await abrir(tester, null);
      expect(find.text(aviso), findsNothing);
    });

    testWidgets('valor fora das listas é ignorado', (tester) async {
      await abrir(tester, {'categoria': 'Chapéus', 'cor_principal': 'Turquesa'});

      expect(find.text(aviso), findsNothing);
      expect(find.text('Chapéus'), findsNothing);
    });

    testWidgets('o valor que eu escolho vence a sugestão ao salvar', (tester) async {
      final service = _PecaServiceCapturando();
      await abrir(tester, {'categoria': 'Camisetas', 'cor_principal': 'Azul'}, service: service);

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camisas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(service.categoria, 'Camisas');
      expect(service.corPrincipal, 'Azul');
    });
  });
}

class _PecaServiceCapturando extends _PecaServiceComSucesso {
  String? categoria;
  String? corPrincipal;

  @override
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    List<String> coresSecundarias = const [],
    List<String> estacoes = const [],
    List<String> estilos = const [],
    String? modelagem,
    List<String> ocasioes = const [],
  }) {
    this.categoria = categoria;
    this.corPrincipal = corPrincipal;
    return super.criarPeca(imagemUrl: imagemUrl, categoria: categoria);
  }
}

void _telaAltaParaCores(WidgetTester tester) => _telaAlta(tester);

class _PecaServiceCapturandoCores extends _PecaServiceComSucesso {
  List<String> estacoes = [];
  List<String> estilos = [];
  List<String> coresSecundarias = [];
  String? corPrincipal;

  @override
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    List<String> coresSecundarias = const [],
    List<String> estacoes = const [],
    List<String> estilos = const [],
    String? modelagem,
    List<String> ocasioes = const [],
  }) {
    this.corPrincipal = corPrincipal;
    this.coresSecundarias = coresSecundarias;
    this.estacoes = estacoes;
    this.estilos = estilos;
    return super.criarPeca(imagemUrl: imagemUrl, categoria: categoria);
  }
}

void mainEstacoesECores() {
  group('várias estações e multicolorido', () {
    Future<_PecaServiceCapturandoCores> abrir(WidgetTester tester) async {
      _telaAltaParaCores(tester);
      final service = _PecaServiceCapturandoCores();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pecaServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: PecaFormView(imagemUrl: 'http://localhost:8000/uploads/foto.png'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shorts').last);
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('marca mais de uma estação e salva todas', (tester) async {
      final service = await abrir(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Outono'));
      await tester.tap(find.widgetWithText(FilterChip, 'Inverno'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(service.estacoes, ['Outono', 'Inverno']);
    });

    testWidgets('marca mais de um estilo e salva todos', (tester) async {
      final service = await abrir(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Elegante'));
      await tester.tap(find.widgetWithText(FilterChip, 'Casual').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(service.estilos, ['Casual', 'Elegante']);
    });

    testWidgets('"Todas as estações" exclui as outras e vice-versa', (tester) async {
      final service = await abrir(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Verão'));
      await tester.tap(find.widgetWithText(FilterChip, 'Todas as estações'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Verão')).selected,
        isFalse,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Inverno'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(service.estacoes, ['Inverno']);
    });

    testWidgets('multicolorido pede a cor predominante e as demais', (tester) async {
      final service = await abrir(tester);

      await tester.tap(find.text('Multicolorido: cores principais'));
      await tester.pumpAndSettle();
      expect(find.text('Selecione a cor predominante'), findsOneWidget);
      expect(find.text('Se houver mais de uma cor, selecione as demais'), findsOneWidget);
      // Sem predominante, não confirma.
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

      final dialogo = find.byType(AlertDialog);
      await tester.tap(find.descendant(of: dialogo, matching: find.text('Azul')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: dialogo, matching: find.text('Rosa')).last);
      await tester.tap(find.descendant(of: dialogo, matching: find.text('Branco')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Multicolorido: Azul + Branco, Rosa'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(service.corPrincipal, 'Azul');
      expect(service.coresSecundarias, ['Branco', 'Rosa']);
    });
  });
}
